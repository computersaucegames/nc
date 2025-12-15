extends FocusSequence
class_name RedResultSequence

## Multi-stage sequence for red result (failure table) Focus Mode
##
## Stage 1: Roll on failure table, determine consequences (crash, badge, penalty)
## Stage 2: Apply reduced movement with penalties

var race_sim: RaceSimulator  # Reference to race simulator
var pilot: PilotState
var sector: Sector
var initial_roll: Dice.DiceResult
var failure_result: Dictionary = {}
var base_movement: int = 0

func _init(event: FocusModeManager.FocusModeEvent, simulator: RaceSimulator):
	super._init(event)
	sequence_name = "RedResult"
	race_sim = simulator
	pilot = focus_event.pilots[0]  # Single pilot for red result
	sector = focus_event.sector
	initial_roll = focus_event.metadata.get("initial_roll")

func get_stage_count() -> int:
	return 2

func get_stage_name(stage: int) -> String:
	match stage:
		0: return "Failure Table Roll"
		1: return "Apply Movement"
		_: return "Unknown"

func execute_stage(stage: int) -> StageResult:
	var result = StageResult.new()

	match stage:
		0:  # Roll on failure table
			_execute_failure_table_roll(result)

		1:  # Apply movement
			_apply_red_result_movement(result)

	return result

func _execute_failure_table_roll(result: StageResult):
	# Roll on the failure table
	failure_result = race_sim.FailureTableRes.resolve_failure(pilot, sector)
	var failure_roll = failure_result.roll_result
	var consequence = failure_result.consequence_text
	var penalty_gaps = failure_result.penalty_gaps
	var badge_id = failure_result.badge_id

	# Emit failure table result event
	race_sim.failure_table_triggered.emit(pilot, sector, consequence, failure_roll)

	# Check if this is a crash (RED tier on failure table roll)
	if failure_roll.tier == Dice.Tier.RED:
		# CRASH! Pilot DNF
		pilot.crash("Crashed", race_sim.current_round)
		focus_event.metadata["crashed"] = true
		focus_event.metadata["consequence"] = consequence
		focus_event.metadata["initial_roll"] = initial_roll
		focus_event.roll_results = [failure_roll]
		focus_event.movement_outcomes = [0]  # No movement for crashed pilots

		# Emit crash signal
		race_sim.pilot_crashed.emit(pilot, sector, consequence)

		# Re-emit event to update UI with crash
		FocusMode.focus_mode_activated.emit(focus_event)

		# Exit immediately - pilot is out
		result.exit_focus_mode = true
		result.requires_user_input = false
		return

	# Apply negative badge based on failure roll tier (not crash)
	# PURPLE: no badge, GREEN: -1 badge, GREY: -2 badge
	if badge_id != "":
		var badge_applied = race_sim.FailureTableRes.apply_badge_based_on_tier(pilot, badge_id, failure_roll.tier)
		if badge_applied:
			# Get the actual badge that was applied (might be base or _severe version)
			var applied_badge_id = badge_id
			if failure_roll.tier == Dice.Tier.GREY:
				applied_badge_id = badge_id + "_severe"
			var badge = race_sim.FailureTableRes.load_badge(applied_badge_id)
			if badge:
				race_sim.negative_badge_applied.emit(pilot, badge)

		# Apply the same badge to the pilot's fin if they have one
		if pilot.fin != null:
			var fin_badge_applied = race_sim.FailureTableRes.apply_badge_based_on_tier_to_fin(pilot.fin, badge_id, failure_roll.tier)
			if fin_badge_applied:
				# Get the actual badge that was applied
				var applied_badge_id = badge_id
				if failure_roll.tier == Dice.Tier.GREY:
					applied_badge_id = badge_id + "_severe"
				var badge = race_sim.FailureTableRes.load_badge(applied_badge_id)
				if badge:
					# TODO: Add signal for fin badge application if needed
					pass

	# Store failure data in event
	focus_event.roll_results = [failure_roll]
	focus_event.metadata["consequence"] = consequence
	focus_event.metadata["initial_roll"] = initial_roll
	focus_event.metadata["penalty_gaps"] = penalty_gaps
	if badge_id != "":
		focus_event.metadata["badge_id"] = badge_id

	# Calculate total penalty: NEW penalty from this failure + any EXISTING pending penalty
	var total_penalty = penalty_gaps
	if pilot.penalty_next_turn > 0:
		total_penalty += pilot.penalty_next_turn
		# Log that we're applying the previous pending penalty
		race_sim.overflow_penalty_applied.emit(pilot, pilot.penalty_next_turn)
		pilot.penalty_next_turn = 0  # Clear it since we're accounting for it now

	# Calculate movement (base red_movement minus total penalty, minimum 0)
	base_movement = max(0, sector.red_movement - total_penalty)

	# Calculate NEW overflow penalty (penalty that exceeds available movement)
	var overflow_penalty = max(0, total_penalty - sector.red_movement)
	if overflow_penalty > 0:
		pilot.penalty_next_turn = overflow_penalty
		focus_event.metadata["overflow_penalty"] = overflow_penalty
		# Log that penalty is being deferred to next turn
		race_sim.overflow_penalty_deferred.emit(pilot, overflow_penalty)

	focus_event.movement_outcomes = [base_movement]

	# Re-emit event to update UI with failure table results
	FocusMode.focus_mode_activated.emit(focus_event)

	# Continue to movement stage
	result.emit_signal = "failure_table_complete"
	result.continue_sequence = true
	result.requires_user_input = true

func _apply_red_result_movement(result: StageResult):
	# Handle overtaking
	var final_movement = race_sim.handle_overtaking(pilot, base_movement, sector)
	# Check for capacity blocking
	final_movement = race_sim.check_capacity_blocking(pilot, final_movement, sector)

	# Capture state before movement
	var start_gap = pilot.gap_in_sector
	var start_distance = pilot.total_distance

	# Apply movement
	var move_result = race_sim.MoveProc.apply_movement(pilot, final_movement, race_sim.current_circuit)
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
	race_sim.handle_movement_results(pilot, move_result)

	# Exit focus mode and resume round
	result.emit_signal = "red_result_complete"
	result.exit_focus_mode = true
	result.requires_user_input = false
