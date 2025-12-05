extends Node
class_name RaceSimulator

# Preload the helper classes
const StatusCalc = preload("res://scripts/systems/StatusCalculator.gd")
const OvertakeRes = preload("res://scripts/systems/OvertakeResolver.gd")
const MoveProc = preload("res://scripts/systems/MovementProcessor.gd")
const StartHandler = preload("res://scripts/systems/RaceStartHandler.gd")
const FailureTableRes = preload("res://scripts/systems/FailureTableResolver.gd")

# Signals for the event-heavy system
signal race_started(circuit: Circuit, pilots: Array)
signal race_start_rolls(pilot_results: Array)
signal round_started(round_number: int)
signal pilot_rolling(pilot: PilotState, sector: Sector)
signal pilot_rolled(pilot: PilotState, result: Dice.DiceResult)
signal pilot_moved(pilot: PilotState, movement: int)
signal pilot_movement_details(pilot_name: String, start_gap: int, start_distance: int, movement: int, end_gap: int, end_distance: int, sector_completed: bool, momentum: int)
signal overtake_detected(overtaking_pilot: PilotState, overtaken_pilot: PilotState)
signal overtake_attempt(attacker: PilotState, defender: PilotState, attacker_roll: Dice.DiceResult, defender_roll: Dice.DiceResult)
signal overtake_completed(overtaking_pilot: PilotState, overtaken_pilot: PilotState)
signal overtake_blocked(attacker: PilotState, defender: PilotState)
signal capacity_blocked(pilot: PilotState, blocking_pilots: Array, intended_movement: int, actual_movement: int)
signal sector_completed(pilot: PilotState, sector: Sector, momentum: int)
signal lap_completed(pilot: PilotState, lap_number: int)
signal pilot_finished(pilot: PilotState, finish_position: int)
signal wheel_to_wheel_detected(pilot1: PilotState, pilot2: PilotState)
signal duel_started(pilot1: PilotState, pilot2: PilotState, round_number: int)
signal focus_mode_triggered(pilots: Array, reason: String)
signal failure_table_triggered(pilot: PilotState, sector: Sector, consequence: String)
signal overflow_penalty_applied(pilot: PilotState, penalty_gaps: int)
signal overflow_penalty_deferred(pilot: PilotState, penalty_gaps: int)
signal badge_activated(pilot: PilotState, badge_name: String, effect_description: String)
signal race_finished(final_positions: Array)

# Race states
enum RaceMode {
	STOPPED,
	RUNNING,
	PAUSED,
	FOCUS_MODE,
	FINISHED
}

# Core race data
var current_circuit: Circuit
var pilots: Array[PilotState] = []
var race_mode: RaceMode = RaceMode.STOPPED
var current_round: int = 0

# Auto-advance timer
var auto_advance_timer: Timer
var auto_advance_delay: float = 1.5  # Seconds between automatic rounds

func _ready():
	# Setup timer for auto advancement
	auto_advance_timer = Timer.new()
	auto_advance_timer.timeout.connect(_on_auto_advance)
	auto_advance_timer.one_shot = true
	add_child(auto_advance_timer)

# Start a new race
func start_race(circuit: Circuit, pilot_list: Array):
	current_circuit = circuit
	race_mode = RaceMode.STOPPED  # Stay stopped until grid is confirmed
	current_round = 0

	# Initialize pilot states
	pilots.clear()
	for i in range(pilot_list.size()):
		var pilot_state = PilotState.new()
		pilot_state.pilot_id = i  # Set the pilot ID for UI tracking

		# Handle different pilot data formats
		var pilot_data = pilot_list[i]
		if pilot_data is Dictionary and pilot_data.has("pilot"):
			# New format: {"pilot": Pilot resource, "headshot": "path"}
			var pilot_resource = pilot_data["pilot"]
			var headshot = pilot_data.get("headshot", "")
			pilot_state.setup_from_pilot_resource(pilot_resource, i + 1, headshot)
		elif pilot_data is Pilot:
			# Direct Pilot resource (no headshot)
			pilot_state.setup_from_pilot_resource(pilot_data, i + 1, "")
		elif pilot_data is Dictionary:
			# Legacy format: {"name": "...", "twitch": X, ...}
			pilot_state.setup_from_dict(pilot_data, i + 1)
		else:
			push_error("Invalid pilot data type: %s" % typeof(pilot_data))

		pilots.append(pilot_state)

	# Use StartHandler to setup grid
	StartHandler.form_starting_grid(pilots, circuit)

	# Initialize badge states for all pilots
	BadgeSystem.reset_all_badge_states(pilots)

	race_started.emit(current_circuit, pilots)

	# Don't execute race start yet - wait for UI to show grid and user to confirm

# Begin the race start in Focus Mode
func begin_race_start_focus_mode():
	# Get the start sector
	var start_sector_idx = StartHandler.find_start_sector(current_circuit)
	var start_sector = current_circuit.sectors[start_sector_idx]

	# Create Focus Mode event for race start
	var event = FocusMode.create_race_start_event(pilots, start_sector)

	# Enter Focus Mode state
	race_mode = RaceMode.FOCUS_MODE

	# Connect to Focus Mode advance signal
	current_focus_advance_callback = func():
		_on_race_start_focus_advance(event)
	FocusMode.focus_mode_advance_requested.connect(current_focus_advance_callback)

	# Activate Focus Mode (UI will display grid)
	FocusMode.activate(event)

# Handle Focus Mode advancement during race start
func _on_race_start_focus_advance(event: FocusModeManager.FocusModeEvent):
	# Check what stage we're in
	if event.roll_results.size() == 0:
		# Stage 1: Execute all twitch rolls
		_execute_race_start_rolls(event)
	else:
		# Stage 2: Apply movement in twitch order and start race
		_apply_race_start_movement(event)

		# Disconnect the advance callback
		if current_focus_advance_callback.is_valid():
			FocusMode.focus_mode_advance_requested.disconnect(current_focus_advance_callback)

		FocusMode.deactivate()
		race_mode = RaceMode.RUNNING

		# Start the first round
		process_round()

# Execute twitch rolls for all pilots at race start
func _execute_race_start_rolls(event: FocusModeManager.FocusModeEvent):
	var start_sector = event.sector

	# Prepare gates from sector thresholds
	var gates = {
		"grey": start_sector.grey_threshold,
		"green": start_sector.green_threshold,
		"purple": start_sector.purple_threshold
	}

	# Roll twitch for all pilots (regardless of sector type)
	for pilot in pilots:
		pilot_rolling.emit(pilot, start_sector)

		# Get badge modifiers for race start
		var context = {
			"roll_type": "race_start",
			"is_race_start": true,
			"sector": start_sector
		}
		var modifiers = BadgeSystem.get_active_modifiers(pilot, context)

		# Emit badge activation events
		var active_badges = BadgeSystem.get_active_badges_info(pilot, context)
		for badge_info in active_badges:
			badge_activated.emit(pilot, badge_info["name"], badge_info["effect"])

		var roll = Dice.roll_d20(pilot.twitch, "twitch", modifiers, gates, {
			"context": "race_start",
			"pilot": pilot.name
		})
		pilot_rolled.emit(pilot, roll)
		event.roll_results.append(roll)

		# Calculate movement for this roll (use final_total, not tier enum!)
		var movement = start_sector.get_movement_for_roll(roll.final_total)
		event.movement_outcomes.append(movement)

	# Sort pilots by twitch roll (highest first), ties broken by grid_position (lowest first)
	var sorted_pilots_with_rolls = []
	for i in range(pilots.size()):
		sorted_pilots_with_rolls.append({
			"pilot": pilots[i],
			"roll": event.roll_results[i],
			"movement": event.movement_outcomes[i]
		})

	sorted_pilots_with_rolls.sort_custom(func(a, b):
		# First sort by roll total (descending)
		if a.roll.final_total != b.roll.final_total:
			return a.roll.final_total > b.roll.final_total
		# Tie-breaker: grid position (ascending)
		return a.pilot.grid_position < b.pilot.grid_position
	)

	# Store sorted order in metadata for movement phase
	event.metadata["sorted_pilots"] = sorted_pilots_with_rolls

	# Re-emit event to update UI with roll results
	FocusMode.focus_mode_activated.emit(event)

# Apply movement for all pilots in twitch order
func _apply_race_start_movement(event: FocusModeManager.FocusModeEvent):
	var sorted_pilots_with_rolls = event.metadata["sorted_pilots"]

	# Process each pilot in twitch order
	for entry in sorted_pilots_with_rolls:
		var pilot = entry.pilot
		var movement = entry.movement

		# Capture state before movement
		var start_gap = pilot.gap_in_sector
		var start_distance = pilot.total_distance

		# Apply movement (no overtaking at race start, pilots are at different gaps)
		var move_result = MoveProc.apply_movement(pilot, movement, current_circuit)
		pilot_moved.emit(pilot, movement)

		# Emit detailed movement info
		var sector_completed = move_result.sectors_completed.size() > 0
		var momentum = move_result.momentum_gained[0] if move_result.momentum_gained.size() > 0 else 0
		pilot_movement_details.emit(pilot.name, start_gap, start_distance, movement, pilot.gap_in_sector, pilot.total_distance, sector_completed, momentum)

		handle_movement_results(pilot, move_result)

	# Update all positions after race start
	MoveProc.update_all_positions(pilots)

	# Emit race start rolls for any UI that wants to display them
	var signal_data = []
	for entry in sorted_pilots_with_rolls:
		signal_data.append({
			"pilot": entry.pilot,
			"roll": entry.roll
		})
	race_start_rolls.emit(signal_data)

# Pause the race
func pause_race():
	race_mode = RaceMode.PAUSED
	auto_advance_timer.stop()

# Resume from pause
func resume_race():
	if race_mode == RaceMode.PAUSED:
		race_mode = RaceMode.RUNNING
		process_round()

# Track W2W pairs already processed in Focus Mode this round
var processed_w2w_pairs: Array = []

# Track individual pilots who have already moved this round
var pilots_processed_this_round: Array = []

# Current Focus Mode advance callback (to disconnect when done)
var current_focus_advance_callback: Callable

# Track wheel-to-wheel pairs for the current round (persists during focus mode)
var current_round_w2w_pairs: Array = []

# Process a single round of racing
func process_round():
	if race_mode != RaceMode.RUNNING:
		return

	current_round += 1
	round_started.emit(current_round)

	# Clear processed tracking for this round
	processed_w2w_pairs.clear()
	pilots_processed_this_round.clear()

	# Update positions
	MoveProc.update_all_positions(pilots)

	# Calculate all pilot statuses
	StatusCalc.calculate_all_statuses(pilots)

	# Update badge states based on new statuses
	BadgeSystem.update_all_badge_states(pilots)

	# Check for wheel-to-wheel situations
	current_round_w2w_pairs = StatusCalc.get_wheel_to_wheel_pairs(pilots)
	for pair in current_round_w2w_pairs:
		wheel_to_wheel_detected.emit(pair[0], pair[1])

	# Check for duels (2+ consecutive rounds of W2W)
	for pilot in pilots:
		if pilot.is_dueling and pilot.consecutive_w2w_rounds == 2:
			# This is the first round of the duel - emit signal
			var partner = pilot.wheel_to_wheel_with[0] if pilot.wheel_to_wheel_with.size() > 0 else null
			if partner != null:
				# Only emit once per duel (check if we haven't already emitted for this pair)
				var pair_key = _get_pair_key(pilot, partner)
				if pair_key not in processed_w2w_pairs:  # Reuse this tracking to avoid duplicate duel signals
					duel_started.emit(pilot, partner, pilot.consecutive_w2w_rounds)
					processed_w2w_pairs.append(pair_key)  # Mark as emitted

	# Process pilots starting from index 0
	_process_pilots_from_index(0)

# Resume processing pilots after Focus Mode
func resume_round():
	# Update positions and statuses after W2W resolution
	MoveProc.update_all_positions(pilots)
	StatusCalc.calculate_all_statuses(pilots)

	# Update badge states based on new statuses
	BadgeSystem.update_all_badge_states(pilots)

	# Continue processing remaining pilots
	_process_pilots_from_index(0)  # Will skip already-processed pilots

# Internal function to process pilots starting from a given index
func _process_pilots_from_index(start_index: int):
	# Process each pilot in position order
	for i in range(start_index, pilots.size()):
		var pilot = pilots[i]

		if race_mode != RaceMode.RUNNING:
			return  # Exit if mode changed (Focus Mode triggered)

		if not MoveProc.can_pilot_race(pilot):
			continue

		# Skip if this pilot already moved this round
		if pilot in pilots_processed_this_round:
			continue

		# Check if this pilot is in a W2W situation
		var w2w_partner = get_unprocessed_w2w_partner(pilot, current_round_w2w_pairs)
		if w2w_partner != null:
			# Trigger Focus Mode for this W2W pair
			process_w2w_focus_mode(pilot, w2w_partner)
			return  # Exit - will resume after Focus Mode completes
		else:
			# Normal turn processing
			process_pilot_turn(pilot)
			# Mark pilot as processed
			pilots_processed_this_round.append(pilot)

	# All pilots processed - check for race finish
	if check_race_finished():
		finish_race()
	else:
		# Schedule next round
		auto_advance_timer.start(auto_advance_delay)

# Process a single pilot's turn
func process_pilot_turn(pilot: PilotState):
	var sector = current_circuit.sectors[pilot.current_sector]

	# Emit that pilot is about to roll
	pilot_rolling.emit(pilot, sector)

	# Make the sector roll
	var roll_result = make_pilot_roll(pilot, sector)
	pilot_rolled.emit(pilot, roll_result)

	# TODO: Issue #3 - Consecutive RED results lose first overflow penalty
	# If pilot has penalty_next_turn > 0 and rolls RED again, the RED check below
	# skips penalty application (lines 330-336), causing the first penalty to be lost.
	# Consider moving penalty application to before this RED check, or accumulating penalties.
	# See KNOWN_ISSUES.md for details.

	# Check if this is a red result - trigger failure table focus mode
	if roll_result.tier == Dice.Tier.RED:
		process_red_result_focus_mode(pilot, sector, roll_result)
		return  # Exit - will resume after focus mode

	# Calculate base movement
	var base_movement = MoveProc.calculate_base_movement(sector, roll_result)

	# Apply overflow penalty from previous failure table (if any)
	if pilot.penalty_next_turn > 0:
		var penalty_applied = min(pilot.penalty_next_turn, base_movement)
		base_movement = max(0, base_movement - pilot.penalty_next_turn)
		# Log the penalty application
		overflow_penalty_applied.emit(pilot, penalty_applied)
		pilot.penalty_next_turn = 0  # Clear the penalty after applying

	# Handle overtaking
	var final_movement = handle_overtaking(pilot, base_movement, sector)

	# Check for capacity blocking
	final_movement = check_capacity_blocking(pilot, final_movement, sector)

	# Capture state before movement
	var start_gap = pilot.gap_in_sector
	var start_distance = pilot.total_distance

	# Apply movement
	var move_result = MoveProc.apply_movement(pilot, final_movement, current_circuit)
	pilot_moved.emit(pilot, final_movement)

	# Emit detailed movement info
	var sector_completed = move_result.sectors_completed.size() > 0
	var momentum = move_result.momentum_gained[0] if move_result.momentum_gained.size() > 0 else 0
	pilot_movement_details.emit(pilot.name, start_gap, start_distance, final_movement, pilot.gap_in_sector, pilot.total_distance, sector_completed, momentum)

	# Handle sector/lap completion
	handle_movement_results(pilot, move_result)

# Make a dice roll for a pilot
func make_pilot_roll(pilot: PilotState, sector: Sector) -> Dice.DiceResult:
	var stat_value = pilot.get_stat(sector.check_type)  # This works fine now!
	var modifiers = []

	# Apply poor start disadvantage if applicable
	if pilot.has_poor_start and current_round == 1:
		modifiers.append(Dice.create_disadvantage("Poor Start"))
		pilot.has_poor_start = false

	# Add modifiers from badges
	var context = {
		"roll_type": "movement",
		"sector": sector,
		"round": current_round
	}
	var badge_mods = BadgeSystem.get_active_modifiers(pilot, context)
	modifiers.append_array(badge_mods)

	# Emit badge activation events
	var active_badges = BadgeSystem.get_active_badges_info(pilot, context)
	for badge_info in active_badges:
		badge_activated.emit(pilot, badge_info["name"], badge_info["effect"])
	
	var gates = {
		"grey": sector.grey_threshold,
		"green": sector.green_threshold,
		"purple": sector.purple_threshold
	}

	# DEBUG: Log the gates and sector info
	print("DEBUG make_pilot_roll: %s rolling on %s" % [pilot.name, sector.sector_name])
	print("  Gates: grey=%d, green=%d, purple=%d" % [gates["grey"], gates["green"], gates["purple"]])

	# Convert enum to string for the dice display/logging
	var check_name = sector.get_check_type_string()  # "twitch", "craft", etc.
	
	return Dice.roll_d20(stat_value, check_name, modifiers, gates, {
		"pilot": pilot.name,
		"sector": sector.sector_name,
		"status": pilot.get_status_string()
	})

# Handle overtaking attempts and return adjusted movement
func handle_overtaking(pilot: PilotState, base_movement: int, sector: Sector) -> int:
	var overtake_attempts = OvertakeRes.check_potential_overtakes(pilot, base_movement, pilots)
	
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
		
		overtake_detected.emit(pilot, defender)
		overtake_attempt.emit(pilot, defender, result_obj.attacker_roll, result_obj.defender_roll)
		
		if result_obj.success:
			overtake_completed.emit(pilot, defender)
		else:
			overtake_blocked.emit(pilot, defender)
	
	return overtake_chain["final_movement"]

# Check if the target position has reached capacity (max fins side-by-side)
# If blocked, reduce movement to stay one gap behind the blocking fins
func check_capacity_blocking(pilot: PilotState, movement: int, sector: Sector) -> int:
	if movement <= 0:
		return movement

	# Calculate where the pilot would end up
	var target_gap = pilot.gap_in_sector + movement
	var target_sector = pilot.current_sector

	# Count how many other pilots are already at this exact position
	var pilots_at_target = []
	for other in pilots:
		if other == pilot or other.finished:
			continue

		# Check if other pilot is at the target position
		if other.current_sector == target_sector and other.gap_in_sector == target_gap:
			pilots_at_target.append(other)

	# If we've reached capacity, block this pilot from moving into that position
	if pilots_at_target.size() >= sector.max_side_by_side:
		# Reduce movement to stay one gap behind
		var adjusted_movement = max(0, movement - 1)
		# Make sure we don't end up at the same position
		while adjusted_movement > 0:
			var new_target = pilot.gap_in_sector + adjusted_movement
			var count_at_new_target = 0
			for other in pilots:
				if other == pilot or other.finished:
					continue
				if other.current_sector == target_sector and other.gap_in_sector == new_target:
					count_at_new_target += 1

			if count_at_new_target < sector.max_side_by_side:
				break  # Found a valid position
			adjusted_movement -= 1

		# Emit signal that this pilot was blocked by capacity
		capacity_blocked.emit(pilot, pilots_at_target, movement, adjusted_movement)
		return adjusted_movement

	return movement

# Handle the results of movement (sectors, laps, finishing)
func handle_movement_results(pilot: PilotState, move_result):
	# Emit events for completed sectors
	for i in range(move_result.sectors_completed.size()):
		var completed_sector = move_result.sectors_completed[i]
		var momentum = move_result.momentum_gained[i] if i < move_result.momentum_gained.size() else 0
		sector_completed.emit(pilot, completed_sector, momentum)
	
	# Handle lap completion
	if move_result.lap_completed:
		lap_completed.emit(pilot, move_result.new_lap_number)
	
	# Handle race finish for this pilot
	if move_result.race_finished:
		handle_pilot_finish(pilot)

# Handle a pilot finishing the race
func handle_pilot_finish(pilot: PilotState):
	# Count finish position
	var finish_position = 1
	for other in pilots:
		if other.finished and other != pilot:
			finish_position += 1

	pilot.finish_race(finish_position, current_round)
	pilot_finished.emit(pilot, finish_position)

# Check if all pilots have finished
func check_race_finished() -> bool:
	for pilot in pilots:
		if not pilot.finished:
			return false
	return true

# End the race
func finish_race():
	race_mode = RaceMode.FINISHED
	auto_advance_timer.stop()
	
	var final_positions = MoveProc.get_finish_order(pilots)
	race_finished.emit(final_positions)

# Get W2W partner if not already processed
func get_unprocessed_w2w_partner(pilot: PilotState, w2w_pairs: Array):
	for pair in w2w_pairs:
		if pair[0] == pilot or pair[1] == pilot:
			# Check if this pair was already processed
			var pair_key = _get_pair_key(pair[0], pair[1])
			if pair_key not in processed_w2w_pairs:
				# Get the partner
				var partner = pair[1] if pair[0] == pilot else pair[0]
				# Make sure partner hasn't been processed individually either
				if partner not in pilots_processed_this_round:
					return partner
	return null

# Generate unique key for a pilot pair
func _get_pair_key(pilot1: PilotState, pilot2: PilotState) -> String:
	var names = [pilot1.name, pilot2.name]
	names.sort()
	return names[0] + "_" + names[1]

# Process wheel-to-wheel situation in Focus Mode
func process_w2w_focus_mode(pilot1: PilotState, pilot2: PilotState):
	# Mark this pair as processed
	var pair_key = _get_pair_key(pilot1, pilot2)
	processed_w2w_pairs.append(pair_key)

	# Get the sector for both pilots (should be same)
	var sector = current_circuit.sectors[pilot1.current_sector]

	# Create Focus Mode event
	var event = FocusMode.create_wheel_to_wheel_event(pilot1, pilot2, sector)

	# Enter Focus Mode state
	race_mode = RaceMode.FOCUS_MODE

	# Connect to Focus Mode advance signal (store for manual disconnect later)
	current_focus_advance_callback = func():
		_on_focus_mode_advance(pilot1, pilot2, event)
	FocusMode.focus_mode_advance_requested.connect(current_focus_advance_callback)

	# Activate Focus Mode (UI will display)
	FocusMode.activate(event)

# Handle Focus Mode advancement (player clicked continue)
func _on_focus_mode_advance(pilot1: PilotState, pilot2: PilotState, event: FocusModeManager.FocusModeEvent):
	# Check what stage we're in
	if event.roll_results.size() == 0:
		# Stage 1: Show the rolls
		_execute_w2w_rolls(pilot1, pilot2, event)
	else:
		# Stage 2: Rolls are done, apply movement and deactivate
		_apply_w2w_movement(pilot1, pilot2, event)

		# Disconnect the advance callback
		if current_focus_advance_callback.is_valid():
			FocusMode.focus_mode_advance_requested.disconnect(current_focus_advance_callback)

		FocusMode.deactivate()
		race_mode = RaceMode.RUNNING

		# Resume the current round to process remaining pilots
		resume_round()

# Execute rolls for both W2W pilots
func _execute_w2w_rolls(pilot1: PilotState, pilot2: PilotState, event: FocusModeManager.FocusModeEvent):
	# TODO: Issue #1 - Overflow penalties not applied during W2W focus mode
	# This function bypasses the normal process_pilot_turn() flow, which means
	# penalty_next_turn is never applied for pilots in W2W. Need to apply
	# overflow penalties here before rolling. See KNOWN_ISSUES.md for details.

	var sector = event.sector

	# Roll for both pilots
	pilot_rolling.emit(pilot1, sector)
	var roll1 = make_pilot_roll(pilot1, sector)
	pilot_rolled.emit(pilot1, roll1)

	pilot_rolling.emit(pilot2, sector)
	var roll2 = make_pilot_roll(pilot2, sector)
	pilot_rolled.emit(pilot2, roll2)

	# Store rolls in event
	event.roll_results = [roll1, roll2]

	# TODO: Issue #2 - RED results during W2W don't trigger failure tables
	# If either pilot rolls RED here, they just get red_movement without
	# triggering a failure table. This may be intentional (to avoid nested
	# focus modes), but should be documented or reconsidered.
	# See KNOWN_ISSUES.md for details.

	# Calculate movement outcomes
	var movement1 = MoveProc.calculate_base_movement(sector, roll1)
	var movement2 = MoveProc.calculate_base_movement(sector, roll2)
	event.movement_outcomes = [movement1, movement2]

	# Re-emit event to update UI with roll results
	FocusMode.focus_mode_activated.emit(event)

# Apply movement for W2W pilots after rolls shown
func _apply_w2w_movement(pilot1: PilotState, pilot2: PilotState, event: FocusModeManager.FocusModeEvent):
	var sector = event.sector
	var movement1 = event.movement_outcomes[0]
	var movement2 = event.movement_outcomes[1]

	# Handle overtaking for pilot1
	var final_movement1 = handle_overtaking(pilot1, movement1, sector)
	# Check for capacity blocking
	final_movement1 = check_capacity_blocking(pilot1, final_movement1, sector)

	# Capture state before movement
	var start_gap1 = pilot1.gap_in_sector
	var start_distance1 = pilot1.total_distance

	var move_result1 = MoveProc.apply_movement(pilot1, final_movement1, current_circuit)
	pilot_moved.emit(pilot1, final_movement1)

	# Emit detailed movement info
	var sector_completed1 = move_result1.sectors_completed.size() > 0
	var momentum1 = move_result1.momentum_gained[0] if move_result1.momentum_gained.size() > 0 else 0
	pilot_movement_details.emit(pilot1.name, start_gap1, start_distance1, final_movement1, pilot1.gap_in_sector, pilot1.total_distance, sector_completed1, momentum1)

	handle_movement_results(pilot1, move_result1)

	# Handle overtaking for pilot2
	var final_movement2 = handle_overtaking(pilot2, movement2, sector)
	# Check for capacity blocking
	final_movement2 = check_capacity_blocking(pilot2, final_movement2, sector)

	# Capture state before movement
	var start_gap2 = pilot2.gap_in_sector
	var start_distance2 = pilot2.total_distance

	var move_result2 = MoveProc.apply_movement(pilot2, final_movement2, current_circuit)
	pilot_moved.emit(pilot2, final_movement2)

	# Emit detailed movement info
	var sector_completed2 = move_result2.sectors_completed.size() > 0
	var momentum2 = move_result2.momentum_gained[0] if move_result2.momentum_gained.size() > 0 else 0
	pilot_movement_details.emit(pilot2.name, start_gap2, start_distance2, final_movement2, pilot2.gap_in_sector, pilot2.total_distance, sector_completed2, momentum2)

	handle_movement_results(pilot2, move_result2)

# Process red result in Focus Mode (failure table)
func process_red_result_focus_mode(pilot: PilotState, sector: Sector, initial_roll: Dice.DiceResult):
	# Emit focus mode trigger event
	focus_mode_triggered.emit([pilot], "Failure Table - %s" % sector.sector_name)

	# Create Focus Mode event for red result
	var event = FocusMode.create_red_result_event(pilot, sector, initial_roll)

	# Enter Focus Mode state
	race_mode = RaceMode.FOCUS_MODE

	# Connect to Focus Mode advance signal
	current_focus_advance_callback = func():
		_on_red_result_focus_advance(pilot, sector, initial_roll, event)
	FocusMode.focus_mode_advance_requested.connect(current_focus_advance_callback)

	# Activate Focus Mode (UI will display)
	FocusMode.activate(event)

# Handle Focus Mode advancement for red result
func _on_red_result_focus_advance(pilot: PilotState, sector: Sector, initial_roll: Dice.DiceResult, event: FocusModeManager.FocusModeEvent):
	# Check what stage we're in
	if event.roll_results.size() == 0:
		# Stage 1: Roll on the failure table
		_execute_failure_table_roll(pilot, sector, initial_roll, event)
	else:
		# Stage 2: Apply movement and deactivate
		_apply_red_result_movement(pilot, sector, initial_roll, event)

		# Disconnect the advance callback
		if current_focus_advance_callback.is_valid():
			FocusMode.focus_mode_advance_requested.disconnect(current_focus_advance_callback)

		FocusMode.deactivate()
		race_mode = RaceMode.RUNNING

		# Resume the current round to process remaining pilots
		resume_round()

# Execute failure table roll
func _execute_failure_table_roll(pilot: PilotState, sector: Sector, initial_roll: Dice.DiceResult, event: FocusModeManager.FocusModeEvent):
	# Roll on the failure table
	var failure_result = FailureTableRes.resolve_failure(pilot, sector)
	var failure_roll = failure_result.roll_result
	var consequence = failure_result.consequence_text
	var penalty_gaps = failure_result.penalty_gaps

	# Emit failure table result event
	failure_table_triggered.emit(pilot, sector, consequence)

	# Store failure data in event
	event.roll_results = [failure_roll]
	event.metadata["consequence"] = consequence
	event.metadata["initial_roll"] = initial_roll
	event.metadata["penalty_gaps"] = penalty_gaps

	# Calculate movement (base red_movement minus penalty, minimum 0)
	var base_movement = max(0, sector.red_movement - penalty_gaps)

	# Calculate overflow penalty (penalty that exceeds available movement)
	var overflow_penalty = max(0, penalty_gaps - sector.red_movement)
	if overflow_penalty > 0:
		pilot.penalty_next_turn = overflow_penalty
		event.metadata["overflow_penalty"] = overflow_penalty
		# Log that penalty is being deferred to next turn
		overflow_penalty_deferred.emit(pilot, overflow_penalty)

	event.movement_outcomes = [base_movement]

	# Re-emit event to update UI with failure table results
	FocusMode.focus_mode_activated.emit(event)

# Apply movement after red result and failure table shown
func _apply_red_result_movement(pilot: PilotState, sector: Sector, initial_roll: Dice.DiceResult, event: FocusModeManager.FocusModeEvent):
	var base_movement = event.movement_outcomes[0]

	# Handle overtaking
	var final_movement = handle_overtaking(pilot, base_movement, sector)
	# Check for capacity blocking
	final_movement = check_capacity_blocking(pilot, final_movement, sector)

	# Capture state before movement
	var start_gap = pilot.gap_in_sector
	var start_distance = pilot.total_distance

	# Apply movement
	var move_result = MoveProc.apply_movement(pilot, final_movement, current_circuit)
	pilot_moved.emit(pilot, final_movement)

	# Emit detailed movement info
	var sector_completed = move_result.sectors_completed.size() > 0
	var momentum = move_result.momentum_gained[0] if move_result.momentum_gained.size() > 0 else 0
	pilot_movement_details.emit(pilot.name, start_gap, start_distance, final_movement, pilot.gap_in_sector, pilot.total_distance, sector_completed, momentum)

	# Handle sector/lap completion
	handle_movement_results(pilot, move_result)

# Exit focus mode and continue racing
func exit_focus_mode():
	if race_mode == RaceMode.FOCUS_MODE:
		race_mode = RaceMode.RUNNING
		process_round()

# Timer callback for auto-advancement
func _on_auto_advance():
	if race_mode == RaceMode.RUNNING:
		process_round()
