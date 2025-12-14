extends RefCounted
class_name TurnProcessor

## Handles individual pilot turn execution
##
## Responsibilities:
## - Roll dice for pilot in sector
## - Calculate base movement from roll
## - Apply penalties from previous failures
## - Handle overtaking attempts
## - Check capacity blocking
## - Apply movement to pilot
## - Detect when Focus Mode is needed (RED results)
##
## Does NOT handle:
## - Round orchestration (RoundProcessor)
## - Focus Mode sequence execution (RaceSimulator)
## - Status calculation (StatusCalculator)

# Preload helper classes
const OvertakeRes = preload("res://scripts/systems/OvertakeResolver.gd")
const MoveProc = preload("res://scripts/systems/MovementProcessor.gd")

## Result of a pilot turn execution
class TurnResult extends RefCounted:
	enum Status {
		COMPLETED,           # Turn completed normally
		NEEDS_FOCUS_MODE,    # Red result - needs failure table focus mode
		CRASHED              # Pilot crashed (shouldn't happen in turn, but for future)
	}

	var status: Status = Status.COMPLETED
	var pilot: PilotState = null
	var roll_result: Dice.DiceResult = null
	var final_movement: int = 0
	var sector: Sector = null
	var move_result = null  # MovementProcessor result

	# For NEEDS_FOCUS_MODE status
	var initial_roll: Dice.DiceResult = null  # The red roll that triggered focus mode

	static func completed(p: PilotState, roll: Dice.DiceResult, movement: int, move_res) -> TurnResult:
		var result = TurnResult.new()
		result.status = Status.COMPLETED
		result.pilot = p
		result.roll_result = roll
		result.final_movement = movement
		result.move_result = move_res
		return result

	static func needs_focus_mode(p: PilotState, s: Sector, red_roll: Dice.DiceResult) -> TurnResult:
		var result = TurnResult.new()
		result.status = Status.NEEDS_FOCUS_MODE
		result.pilot = p
		result.sector = s
		result.initial_roll = red_roll
		result.roll_result = red_roll
		return result

## Reference to RaceSimulator (for signals and data access)
var race_sim: RaceSimulator

## Constructor
func _init(simulator: RaceSimulator):
	race_sim = simulator

## Process a single pilot's turn
## Returns TurnResult indicating what happened
func process_turn(pilot: PilotState, sector: Sector, circuit: Circuit, current_round: int, all_pilots: Array) -> TurnResult:
	# Emit that pilot is about to roll
	race_sim.pilot_rolling.emit(pilot, sector)

	# Make the sector roll
	var roll_result = make_roll(pilot, sector, current_round)
	race_sim.pilot_rolled.emit(pilot, roll_result)

	# Check if this is a red result - needs failure table focus mode
	if roll_result.tier == Dice.Tier.RED:
		return TurnResult.needs_focus_mode(pilot, sector, roll_result)

	# Calculate base movement
	var base_movement = MoveProc.calculate_base_movement(sector, roll_result)

	# Apply overflow penalty from previous failure table (if any)
	if pilot.penalty_next_turn > 0:
		var penalty_applied = min(pilot.penalty_next_turn, base_movement)
		base_movement = max(0, base_movement - pilot.penalty_next_turn)
		# Log the penalty application
		race_sim.overflow_penalty_applied.emit(pilot, penalty_applied)
		pilot.penalty_next_turn = 0  # Clear the penalty after applying

	# Handle overtaking
	var final_movement = handle_overtaking(pilot, base_movement, sector, all_pilots)

	# Check for capacity blocking
	final_movement = check_capacity_blocking(pilot, final_movement, sector, circuit, all_pilots)

	# Capture state before movement
	var start_gap = pilot.gap_in_sector
	var start_distance = pilot.total_distance

	# Apply movement
	var move_result = MoveProc.apply_movement(pilot, final_movement, circuit)
	race_sim.pilot_moved.emit(pilot, final_movement)

	# Emit detailed movement info
	var sector_completed = move_result.sectors_completed.size() > 0
	var momentum = move_result.momentum_gained[0] if move_result.momentum_gained.size() > 0 else 0
	race_sim.pilot_movement_details.emit(
		pilot.name,
		start_gap,
		start_distance,
		final_movement,
		pilot.gap_in_sector,
		pilot.total_distance,
		sector_completed,
		momentum
	)

	# Handle sector/lap completion
	_handle_movement_results(pilot, move_result, sector, roll_result)

	return TurnResult.completed(pilot, roll_result, final_movement, move_result)

## Make a dice roll for a pilot in a sector
func make_roll(pilot: PilotState, sector: Sector, current_round: int) -> Dice.DiceResult:
	var stat_value = pilot.get_stat(sector.check_type)
	var modifiers = []

	# Apply poor start disadvantage if applicable
	if pilot.has_poor_start and current_round == 1:
		modifiers.append(Dice.create_disadvantage("Poor Start"))
		pilot.has_poor_start = false

	# Add modifiers from badges
	var context = {
		"roll_type": "movement",
		"sector": sector,
		"round": current_round,
		"pilot": pilot  # Needed for fin badges to check pilot status
	}
	var badge_mods = BadgeSystem.get_active_modifiers(pilot, context)
	modifiers.append_array(badge_mods)

	# Add modifiers from fin badges (if pilot has a fin assigned)
	if pilot.fin_state != null:
		var fin_badge_mods = BadgeSystem.get_active_modifiers_for_fin(pilot.fin_state, context)
		modifiers.append_array(fin_badge_mods)

	# Emit badge activation events
	var active_badges = BadgeSystem.get_active_badges_info(pilot, context)
	for badge_info in active_badges:
		race_sim.badge_activated.emit(pilot, badge_info["name"], badge_info["effect"])

	var gates = {
		"grey": sector.grey_threshold,
		"green": sector.green_threshold,
		"purple": sector.purple_threshold
	}

	# DEBUG: Log the gates and sector info
	print("DEBUG make_roll: %s rolling on %s" % [pilot.name, sector.sector_name])
	print("  Gates: grey=%d, green=%d, purple=%d" % [gates["grey"], gates["green"], gates["purple"]])

	# Convert enum to string for the dice display/logging
	var check_name = sector.get_check_type_string()  # "twitch", "craft", etc.

	return Dice.roll_d20(stat_value, check_name, modifiers, gates, {
		"pilot": pilot.name,
		"sector": sector.sector_name,
		"status": pilot.get_status_string()
	})

## Handle overtaking attempts and return adjusted movement
func handle_overtaking(pilot: PilotState, base_movement: int, sector: Sector, all_pilots: Array) -> int:
	var overtake_attempts = OvertakeRes.check_potential_overtakes(pilot, base_movement, all_pilots)

	if overtake_attempts.size() == 0:
		return base_movement

	# Process the overtake chain
	var overtake_chain = OvertakeRes.process_overtake_chain(
		pilot, base_movement, overtake_attempts, sector
	)

	# Emit events for each overtake attempt
	for attempt_result in overtake_chain["results"]:
		var defender = attempt_result["defender"]
		var result_obj = attempt_result["result"]

		race_sim.overtake_detected.emit(pilot, defender)
		race_sim.overtake_attempt.emit(pilot, defender, result_obj.attacker_roll, result_obj.defender_roll)

		if result_obj.success:
			race_sim.overtake_completed.emit(pilot, defender)
		else:
			race_sim.overtake_blocked.emit(pilot, defender)

	return overtake_chain["final_movement"]

## Check if the target position has reached capacity (max fins side-by-side)
## If blocked, reduce movement to stay one gap behind the blocking fins
func check_capacity_blocking(pilot: PilotState, movement: int, sector: Sector, circuit: Circuit, all_pilots: Array) -> int:
	if movement <= 0:
		return movement

	# Calculate actual destination using MovementProcessor logic (handles sector boundaries)
	var destination = MoveProc.calculate_destination_position(pilot, movement, circuit)
	var target_sector_idx = destination["sector"]
	var target_gap = destination["gap"]
	var target_sector = circuit.sectors[target_sector_idx]

	# Count how many other pilots are already at this exact position
	var pilots_at_target = []
	for other in all_pilots:
		if other == pilot or other.finished or other.did_not_finish:
			continue

		# Check if other pilot is at the target position
		if other.current_sector == target_sector_idx and other.gap_in_sector == target_gap:
			pilots_at_target.append(other)

	# If we've reached capacity, block this pilot from moving into that position
	if pilots_at_target.size() >= target_sector.max_side_by_side:
		# Recursively reduce movement until we find a valid position
		var adjusted_movement = check_capacity_blocking(pilot, movement - 1, sector, circuit, all_pilots)

		# Emit signal that this pilot was blocked by capacity
		race_sim.capacity_blocked.emit(pilot, pilots_at_target, movement, adjusted_movement)
		return adjusted_movement

	return movement

## Handle the results of movement (sectors, laps, finishing)
## sector and roll_result are optional - only needed for badge tracking during normal sector rolls
func _handle_movement_results(pilot: PilotState, move_result, sector: Sector = null, roll_result: Dice.DiceResult = null):
	# Emit events for completed sectors
	for i in range(move_result.sectors_completed.size()):
		var completed_sector = move_result.sectors_completed[i]
		var momentum = move_result.momentum_gained[i] if i < move_result.momentum_gained.size() else 0
		race_sim.sector_completed.emit(pilot, completed_sector, momentum)

		# Track sector completion for badge earning (only if we have sector and roll_result)
		if sector != null and roll_result != null and completed_sector == sector:
			BadgeSystem.track_sector_completion(pilot, completed_sector, roll_result)
			# Check if any badges should be awarded
			if not race_sim.current_circuit.available_sector_badges.is_empty():
				var earned_badges = BadgeSystem.check_and_award_sector_badges(pilot, race_sim.current_circuit.available_sector_badges)
				# Emit signal for each earned badge
				for badge in earned_badges:
					race_sim.badge_earned.emit(pilot, badge)

			# Track sector completion for fin badge earning (if pilot has a fin)
			if pilot.fin_state != null:
				BadgeSystem.track_fin_sector_completion(pilot.fin_state, completed_sector, roll_result)
				# Check if any fin badges should be awarded
				if not race_sim.current_circuit.available_sector_badges.is_empty():
					var earned_fin_badges = BadgeSystem.check_and_award_fin_sector_badges(pilot.fin_state, race_sim.current_circuit.available_sector_badges)
					# Emit signal for each earned fin badge
					for badge in earned_fin_badges:
						race_sim.badge_earned.emit(pilot, badge)  # Still emit under pilot's name for UI

	# Handle lap completion
	if move_result.lap_completed:
		race_sim.lap_completed.emit(pilot, move_result.new_lap_number)

	# Handle race finish for this pilot
	if move_result.race_finished:
		_handle_pilot_finish(pilot)

## Handle a pilot finishing the race
func _handle_pilot_finish(pilot: PilotState):
	# Count finish position
	var finish_position = 1
	for other in race_sim.pilots:
		if other.finished and other != pilot:
			finish_position += 1

	pilot.finish_race(finish_position, race_sim.current_round)
	race_sim.pilot_finished.emit(pilot, finish_position)
