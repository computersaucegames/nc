extends FocusSequence
class_name W2WFailureSequence

## Multi-stage sequence for Wheel-to-Wheel failure Focus Mode
##
## This is the most complex sequence with up to 4 stages:
## Stage 1: W2W Rolls (both pilots)
## Stage 2: W2W Failure Table Roll (if one pilot got RED)
## Stage 3: Avoidance Save (if contact triggered)
## Stage 4: Apply Movement (both pilots)
##
## Edge cases:
## - Both RED: dual crash, exit after stage 1
## - Neither RED: normal W2W, apply movement and exit after stage 1
## - One RED without contact: failing pilot crashes, apply movement
## - One RED with contact + avoidance RED: both crash
## - One RED with contact + avoidance success: both move with penalties

var race_sim: RaceSimulator
var pilot1: PilotState
var pilot2: PilotState
var sector: Sector
var failing_pilot: PilotState
var avoiding_pilot: PilotState

func _init(event: FocusModeManager.FocusModeEvent, simulator: RaceSimulator):
	super._init(event)
	sequence_name = "W2WFailure"
	race_sim = simulator
	pilot1 = event.pilots[0]
	pilot2 = event.pilots[1]
	sector = event.sector

func get_stage_count() -> int:
	# Maximum 4 stages, but can exit early
	return 4

func get_stage_name(stage: int) -> String:
	match stage:
		0: return "W2W Rolls"
		1: return "W2W Failure Table"
		2: return "Avoidance Save"
		3: return "Apply Movement"
		_: return "Unknown"

func execute_stage(stage: int) -> StageResult:
	var result = StageResult.new()

	match stage:
		0:  # W2W Rolls
			_execute_w2w_rolls(result)

		1:  # Failure table (only if one RED)
			if event.metadata.get("w2w_failure", false):
				_execute_failure_table(result)
			else:
				# Skip to movement
				current_stage = 2
				return execute_stage(3)

		2:  # Avoidance save (only if contact triggered)
			if event.metadata.get("contact_triggered", false):
				_execute_avoidance_save(result)
			else:
				# Skip to movement
				current_stage = 2
				return execute_stage(3)

		3:  # Apply movement
			_apply_movement(result)

	return result

func _execute_w2w_rolls(result: StageResult):
	# Apply any pending overflow penalties from previous failures
	var pilot1_pending_penalty = pilot1.penalty_next_turn
	var pilot2_pending_penalty = pilot2.penalty_next_turn

	if pilot1_pending_penalty > 0:
		race_sim.overflow_penalty_applied.emit(pilot1, pilot1_pending_penalty)
	if pilot2_pending_penalty > 0:
		race_sim.overflow_penalty_applied.emit(pilot2, pilot2_pending_penalty)

	# Roll for both pilots
	race_sim.pilot_rolling.emit(pilot1, sector)
	var roll1 = race_sim.make_pilot_roll(pilot1, sector)
	race_sim.pilot_rolled.emit(pilot1, roll1)

	race_sim.pilot_rolling.emit(pilot2, sector)
	var roll2 = race_sim.make_pilot_roll(pilot2, sector)
	race_sim.pilot_rolled.emit(pilot2, roll2)

	# Store rolls in event
	event.roll_results = [roll1, roll2]

	# Check for RED results
	var pilot1_red = (roll1.tier == Dice.Tier.RED)
	var pilot2_red = (roll2.tier == Dice.Tier.RED)

	# Handle dual RED crash
	if pilot1_red and pilot2_red:
		pilot1.crash("W2W Crash - both pilots lost control", race_sim.current_round)
		pilot2.crash("W2W Crash - both pilots lost control", race_sim.current_round)

		# Emit signals
		race_sim.w2w_dual_crash.emit(pilot1, pilot2, sector)
		race_sim.pilot_crashed.emit(pilot1, sector, "W2W Dual Crash")
		race_sim.pilot_crashed.emit(pilot2, sector, "W2W Dual Crash")

		# Set event metadata
		event.metadata["dual_crash"] = true
		event.movement_outcomes = [0, 0]

		# Re-emit event to update UI
		FocusMode.focus_mode_activated.emit(event)

		# Exit immediately
		result.exit_focus_mode = true
		result.requires_user_input = false
		_mark_pilots_processed()
		return

	# Handle single RED (W2W failure sequence)
	if pilot1_red or pilot2_red:
		event.metadata["w2w_failure"] = true
		if pilot1_red:
			failing_pilot = pilot1
			avoiding_pilot = pilot2
		else:
			failing_pilot = pilot2
			avoiding_pilot = pilot1

		event.metadata["failing_pilot"] = failing_pilot
		event.metadata["avoiding_pilot"] = avoiding_pilot
		event.movement_outcomes = [0, 0]  # Will be calculated after failure resolution

		FocusMode.focus_mode_activated.emit(event)

		# Continue to failure table stage
		result.emit_signal = "w2w_rolls_complete"
		result.continue_sequence = true
		result.requires_user_input = true
		return

	# Normal W2W flow (no RED results)
	var movement1 = race_sim.MoveProc.calculate_base_movement(sector, roll1)
	var movement2 = race_sim.MoveProc.calculate_base_movement(sector, roll2)

	# Apply pending penalties
	if pilot1_pending_penalty > 0:
		movement1 = max(0, movement1 - pilot1_pending_penalty)
		pilot1.penalty_next_turn = 0
	if pilot2_pending_penalty > 0:
		movement2 = max(0, movement2 - pilot2_pending_penalty)
		pilot2.penalty_next_turn = 0

	event.movement_outcomes = [movement1, movement2]
	event.metadata["normal_w2w"] = true

	# Re-emit event to update UI
	FocusMode.focus_mode_activated.emit(event)

	# Skip to movement stage (jump over failure and avoidance stages)
	current_stage = 2
	result.emit_signal = "w2w_rolls_complete"
	result.continue_sequence = true
	result.requires_user_input = true

func _execute_failure_table(result: StageResult):
	# Get W2W failure consequence from sector
	var failure_consequence = sector.get_random_w2w_failure()

	# Roll save on failure table
	var stat_value = failing_pilot.get_stat(sector.failure_table_check_type)
	var check_name = sector.get_check_type_string()

	var gates = {
		"grey": sector.grey_threshold,
		"green": sector.green_threshold,
		"purple": sector.purple_threshold
	}

	var failure_roll = Dice.roll_d20(stat_value, check_name, [], gates, {
		"pilot": failing_pilot.name,
		"sector": sector.sector_name,
		"context": "w2w_failure"
	})

	# Store failure data
	event.metadata["failure_consequence"] = failure_consequence
	event.metadata["failure_roll"] = failure_roll

	# Emit signals
	race_sim.w2w_failure_triggered.emit(failing_pilot, avoiding_pilot, sector)
	race_sim.w2w_failure_roll_result.emit(failing_pilot, failure_consequence["text"], failure_roll)

	# Apply negative badge based on tier
	var badge_id = failure_consequence.get("badge_id", "")
	if badge_id != "":
		var badge_applied = race_sim.FailureTableRes.apply_badge_based_on_tier(failing_pilot, badge_id, failure_roll.tier)
		if badge_applied:
			var applied_badge_id = badge_id
			if failure_roll.tier == Dice.Tier.GREY:
				applied_badge_id = badge_id + "_severe"
			var badge = race_sim.FailureTableRes.load_badge(applied_badge_id)
			if badge:
				race_sim.negative_badge_applied.emit(failing_pilot, badge)

	# Check if contact is triggered
	var triggers_contact = failure_consequence.get("triggers_contact", false)
	var contact_triggered = triggers_contact and (failure_roll.tier == Dice.Tier.RED or failure_roll.tier == Dice.Tier.GREY)

	event.metadata["contact_triggered"] = contact_triggered

	if contact_triggered:
		# Contact! Continue to avoidance stage
		race_sim.w2w_contact_triggered.emit(failing_pilot, avoiding_pilot, failure_consequence)
	elif failure_roll.tier == Dice.Tier.RED:
		# RED without contact - only failing pilot crashes
		failing_pilot.crash("W2W Crash", race_sim.current_round)
		event.metadata["failing_pilot_crashed_solo"] = true
		race_sim.pilot_crashed.emit(failing_pilot, sector, failure_consequence["text"])

		# Avoiding pilot gets normal movement
		var avoiding_roll = event.roll_results[1] if failing_pilot == pilot1 else event.roll_results[0]
		event.metadata["avoiding_pilot_movement"] = race_sim.MoveProc.calculate_base_movement(sector, avoiding_roll)
		event.metadata["failing_pilot_movement"] = 0

	# Calculate movement if not already set
	if not event.metadata.has("failing_pilot_movement"):
		var penalty_gaps = failure_consequence.get("penalty_gaps", 0)
		event.metadata["failing_pilot_movement"] = max(0, sector.red_movement - penalty_gaps)

	if not event.metadata.has("avoiding_pilot_movement") and not contact_triggered:
		var avoiding_roll = event.roll_results[1] if failing_pilot == pilot1 else event.roll_results[0]
		event.metadata["avoiding_pilot_movement"] = race_sim.MoveProc.calculate_base_movement(sector, avoiding_roll)

	# Re-emit event
	FocusMode.focus_mode_activated.emit(event)

	# Continue to next stage or skip to movement
	if contact_triggered:
		result.emit_signal = "w2w_failure_table_complete"
		result.continue_sequence = true
		result.requires_user_input = true
	else:
		# Skip avoidance, go to movement
		current_stage = 2
		result.emit_signal = "w2w_failure_table_complete"
		result.continue_sequence = true
		result.requires_user_input = true

func _execute_avoidance_save(result: StageResult):
	# Calculate modified gates
	var modified_gates = {
		"grey": sector.grey_threshold + 2,
		"green": sector.green_threshold + 2,
		"purple": sector.purple_threshold + 2
	}

	# Emit signal
	race_sim.w2w_avoidance_roll_required.emit(avoiding_pilot, modified_gates)

	# Roll Twitch save
	var avoidance_roll = Dice.roll_d20(avoiding_pilot.twitch, "twitch", [], modified_gates, {
		"pilot": avoiding_pilot.name,
		"sector": sector.sector_name,
		"context": "w2w_avoidance"
	})

	event.metadata["avoidance_result"] = avoidance_roll

	# Apply consequences based on tier
	var avoidance_description = ""
	var avoiding_roll = event.roll_results[1] if failing_pilot == pilot1 else event.roll_results[0]
	var base_movement = race_sim.MoveProc.calculate_base_movement(sector, avoiding_roll)

	match avoidance_roll.tier:
		Dice.Tier.PURPLE:
			# Clean avoidance
			event.metadata["avoiding_pilot_movement"] = base_movement
			avoidance_description = "Clean avoidance! No penalty"

		Dice.Tier.GREEN:
			# Glancing contact - lose 1 gap
			event.metadata["avoiding_pilot_movement"] = max(0, base_movement - 1)
			avoidance_description = "Glancing contact - lose 1 Gap"

		Dice.Tier.GREY:
			# Heavy contact - lose 2 gaps + Rattled
			event.metadata["avoiding_pilot_movement"] = max(0, base_movement - 2)
			avoidance_description = "Heavy contact - lose 2 Gap + Rattled"

			# Apply Rattled badge
			var badge_applied = race_sim.FailureTableRes.apply_badge_based_on_tier(avoiding_pilot, "rattled", Dice.Tier.GREY)
			if badge_applied:
				var badge = race_sim.FailureTableRes.load_badge("rattled_severe")
				if badge:
					race_sim.negative_badge_applied.emit(avoiding_pilot, badge)

		Dice.Tier.RED:
			# Both crash!
			failing_pilot.crash("W2W Crash", race_sim.current_round)
			avoiding_pilot.crash("W2W Crash - failed avoidance", race_sim.current_round)

			event.metadata["both_crashed"] = true
			race_sim.pilot_crashed.emit(failing_pilot, sector, event.metadata["failure_consequence"]["text"])
			race_sim.pilot_crashed.emit(avoiding_pilot, sector, "Failed to avoid W2W crash")

			event.metadata["failing_pilot_movement"] = 0
			event.metadata["avoiding_pilot_movement"] = 0
			avoidance_description = "CRASH! Failed to avoid contact"

	event.metadata["avoidance_description"] = avoidance_description

	# Emit result signal
	race_sim.w2w_avoidance_roll_result.emit(avoiding_pilot, avoidance_roll, avoidance_description)

	# Re-emit event
	FocusMode.focus_mode_activated.emit(event)

	# Continue to movement
	result.emit_signal = "w2w_avoidance_complete"
	result.continue_sequence = true
	result.requires_user_input = true

func _apply_movement(result: StageResult):
	# Handle normal W2W (no failure)
	if event.metadata.get("normal_w2w", false):
		_apply_normal_w2w_movement()
		result.exit_focus_mode = true
		result.requires_user_input = false
		_mark_pilots_processed()
		return

	# Handle W2W failure cases
	if event.metadata.get("both_crashed", false):
		# Both crashed - no movement
		result.exit_focus_mode = true
		result.requires_user_input = false
		_mark_pilots_processed()
		return

	var failing_movement = event.metadata.get("failing_pilot_movement", 0)
	var avoiding_movement = event.metadata.get("avoiding_pilot_movement", 0)

	# Apply failing pilot movement (if not crashed solo)
	if not event.metadata.get("failing_pilot_crashed_solo", false):
		var final_failing_movement = race_sim.handle_overtaking(failing_pilot, failing_movement, sector)
		final_failing_movement = race_sim.check_capacity_blocking(failing_pilot, final_failing_movement, sector)

		var start_gap_failing = failing_pilot.gap_in_sector
		var start_distance_failing = failing_pilot.total_distance

		var move_result_failing = race_sim.MoveProc.apply_movement(failing_pilot, final_failing_movement, race_sim.current_circuit)
		race_sim.pilot_moved.emit(failing_pilot, final_failing_movement)

		var sector_completed_failing = move_result_failing.sectors_completed.size() > 0
		var momentum_failing = move_result_failing.momentum_gained[0] if move_result_failing.momentum_gained.size() > 0 else 0
		race_sim.pilot_movement_details.emit(
			failing_pilot.name,
			start_gap_failing,
			start_distance_failing,
			final_failing_movement,
			failing_pilot.gap_in_sector,
			failing_pilot.total_distance,
			sector_completed_failing,
			momentum_failing
		)

		race_sim.handle_movement_results(failing_pilot, move_result_failing)

	# Apply avoiding pilot movement
	var final_avoiding_movement = race_sim.handle_overtaking(avoiding_pilot, avoiding_movement, sector)
	final_avoiding_movement = race_sim.check_capacity_blocking(avoiding_pilot, final_avoiding_movement, sector)

	var start_gap_avoiding = avoiding_pilot.gap_in_sector
	var start_distance_avoiding = avoiding_pilot.total_distance

	var move_result_avoiding = race_sim.MoveProc.apply_movement(avoiding_pilot, final_avoiding_movement, race_sim.current_circuit)
	race_sim.pilot_moved.emit(avoiding_pilot, final_avoiding_movement)

	var sector_completed_avoiding = move_result_avoiding.sectors_completed.size() > 0
	var momentum_avoiding = move_result_avoiding.momentum_gained[0] if move_result_avoiding.momentum_gained.size() > 0 else 0
	race_sim.pilot_movement_details.emit(
		avoiding_pilot.name,
		start_gap_avoiding,
		start_distance_avoiding,
		final_avoiding_movement,
		avoiding_pilot.gap_in_sector,
		avoiding_pilot.total_distance,
		sector_completed_avoiding,
		momentum_avoiding
	)

	race_sim.handle_movement_results(avoiding_pilot, move_result_avoiding)

	# Exit focus mode
	result.exit_focus_mode = true
	result.requires_user_input = false
	_mark_pilots_processed()

func _apply_normal_w2w_movement():
	# Apply movement for both pilots (normal W2W, no failure)
	var movement1 = event.movement_outcomes[0]
	var movement2 = event.movement_outcomes[1]

	# Pilot 1
	var final_movement1 = race_sim.handle_overtaking(pilot1, movement1, sector)
	final_movement1 = race_sim.check_capacity_blocking(pilot1, final_movement1, sector)

	var start_gap1 = pilot1.gap_in_sector
	var start_distance1 = pilot1.total_distance

	var move_result1 = race_sim.MoveProc.apply_movement(pilot1, final_movement1, race_sim.current_circuit)
	race_sim.pilot_moved.emit(pilot1, final_movement1)

	var sector_completed1 = move_result1.sectors_completed.size() > 0
	var momentum1 = move_result1.momentum_gained[0] if move_result1.momentum_gained.size() > 0 else 0
	race_sim.pilot_movement_details.emit(pilot1.name, start_gap1, start_distance1, final_movement1, pilot1.gap_in_sector, pilot1.total_distance, sector_completed1, momentum1)

	race_sim.handle_movement_results(pilot1, move_result1)

	# Pilot 2
	var final_movement2 = race_sim.handle_overtaking(pilot2, movement2, sector)
	final_movement2 = race_sim.check_capacity_blocking(pilot2, final_movement2, sector)

	var start_gap2 = pilot2.gap_in_sector
	var start_distance2 = pilot2.total_distance

	var move_result2 = race_sim.MoveProc.apply_movement(pilot2, final_movement2, race_sim.current_circuit)
	race_sim.pilot_moved.emit(pilot2, final_movement2)

	var sector_completed2 = move_result2.sectors_completed.size() > 0
	var momentum2 = move_result2.momentum_gained[0] if move_result2.momentum_gained.size() > 0 else 0
	race_sim.pilot_movement_details.emit(pilot2.name, start_gap2, start_distance2, final_movement2, pilot2.gap_in_sector, pilot2.total_distance, sector_completed2, momentum2)

	race_sim.handle_movement_results(pilot2, move_result2)

func _mark_pilots_processed():
	# Mark both pilots as processed this round
	if pilot1 not in race_sim.pilots_processed_this_round:
		race_sim.pilots_processed_this_round.append(pilot1)
	if pilot2 not in race_sim.pilots_processed_this_round:
		race_sim.pilots_processed_this_round.append(pilot2)
