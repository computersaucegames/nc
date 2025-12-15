extends RefCounted
class_name RoundProcessor

## Handles round orchestration and pilot processing order
##
## Responsibilities:
## - Round lifecycle (start, process pilots, finish)
## - W2W pair detection and tracking
## - Duel detection (consecutive W2W rounds)
## - Pilot processing order and tracking
## - Position/status updates between rounds
## - Race completion checks
##
## Does NOT handle:
## - Individual pilot turn execution (TurnProcessor)
## - Focus Mode sequence execution (RaceSimulator)
## - Movement calculation (MovementProcessor)

# Preload helper classes
const StatusCalc = preload("res://scripts/systems/StatusCalculator.gd")
const MoveProc = preload("res://scripts/systems/MovementProcessor.gd")

## Result of round processing
class RoundResult extends RefCounted:
	enum Status {
		COMPLETED,              # Round completed, schedule next round
		NEEDS_W2W_FOCUS,        # W2W detected - needs focus mode
		RACE_FINISHED           # All pilots finished/DNF'd
	}

	var status: Status = Status.COMPLETED
	var w2w_pilot1: PilotState = null
	var w2w_pilot2: PilotState = null

	static func completed() -> RoundResult:
		var result = RoundResult.new()
		result.status = Status.COMPLETED
		return result

	static func needs_w2w_focus(pilot1: PilotState, pilot2: PilotState) -> RoundResult:
		var result = RoundResult.new()
		result.status = Status.NEEDS_W2W_FOCUS
		result.w2w_pilot1 = pilot1
		result.w2w_pilot2 = pilot2
		return result

	static func race_finished() -> RoundResult:
		var result = RoundResult.new()
		result.status = Status.RACE_FINISHED
		return result

## Reference to RaceSimulator (for signals and data access)
var race_sim: RaceSimulator

## Round state tracking
var processed_w2w_pairs: Array = []
var pilots_processed_this_round: Array = []
var current_round_w2w_pairs: Array = []

## Constructor
func _init(simulator: RaceSimulator):
	race_sim = simulator

## Process a complete round of racing
## Returns RoundResult indicating what happened
func process_round(round_number: int, pilots: Array, circuit: Circuit) -> RoundResult:
	# Emit round started signal
	race_sim.round_started.emit(round_number)

	# Clear processed tracking for this round
	processed_w2w_pairs.clear()
	pilots_processed_this_round.clear()

	# Update positions
	MoveProc.update_all_positions(pilots)

	# Calculate all pilot statuses
	StatusCalc.calculate_all_statuses(pilots)

	# Update badge states based on new statuses
	BadgeSystem.update_all_badge_states(pilots)

	# Update fin badge states
	for pilot in pilots:
		if pilot.fin_state != null:
			BadgeSystem.update_fin_badge_states(pilot.fin_state, pilot)

	# Check for wheel-to-wheel situations
	current_round_w2w_pairs = StatusCalc.get_wheel_to_wheel_pairs(pilots)
	for pair in current_round_w2w_pairs:
		race_sim.wheel_to_wheel_detected.emit(pair[0], pair[1])

	# Check for duels (2+ consecutive rounds of W2W)
	_check_for_duels(pilots)

	# Process pilots starting from index 0
	return _process_pilots_from_index(0, pilots, circuit)

## Resume processing pilots after Focus Mode
func resume_round(pilots: Array, circuit: Circuit) -> RoundResult:
	# Update positions and statuses after W2W resolution
	MoveProc.update_all_positions(pilots)
	StatusCalc.calculate_all_statuses(pilots)

	# Update badge states based on new statuses
	BadgeSystem.update_all_badge_states(pilots)

	# Update fin badge states
	for pilot in pilots:
		if pilot.fin_state != null:
			BadgeSystem.update_fin_badge_states(pilot.fin_state, pilot)

	# Continue processing remaining pilots
	return _process_pilots_from_index(0, pilots, circuit)  # Will skip already-processed pilots

## Check for duels (2+ consecutive rounds of W2W between same pair)
func _check_for_duels(pilots: Array):
	for pilot in pilots:
		if pilot.is_dueling and pilot.consecutive_w2w_rounds == 2:
			# This is the first round of the duel - emit signal
			var partner = pilot.wheel_to_wheel_with[0] if pilot.wheel_to_wheel_with.size() > 0 else null
			if partner != null:
				# Only emit once per duel (check if we haven't already emitted for this pair)
				var pair_key = _get_pair_key(pilot, partner)
				if pair_key not in processed_w2w_pairs:  # Reuse this tracking to avoid duplicate duel signals
					race_sim.duel_started.emit(pilot, partner, pilot.consecutive_w2w_rounds)
					processed_w2w_pairs.append(pair_key)  # Mark as emitted

## Internal function to process pilots starting from a given index
func _process_pilots_from_index(start_index: int, pilots: Array, circuit: Circuit) -> RoundResult:
	# Process each pilot in position order
	for i in range(start_index, pilots.size()):
		var pilot = pilots[i]

		if race_sim.race_mode != race_sim.RaceMode.RUNNING:
			# Exit if mode changed (Focus Mode triggered)
			# Return completed status - RaceSimulator will handle resuming
			return RoundResult.completed()

		if not MoveProc.can_pilot_race(pilot):
			continue

		# Skip if this pilot already moved this round
		if pilot in pilots_processed_this_round:
			continue

		# Check if this pilot is in a W2W situation
		var w2w_partner = _get_unprocessed_w2w_partner(pilot, pilots)
		if w2w_partner != null:
			# Mark this pair as processed
			var pair_key = _get_pair_key(pilot, w2w_partner)
			processed_w2w_pairs.append(pair_key)

			# Mark both pilots as individually processed (so they don't get processed again after focus mode)
			pilots_processed_this_round.append(pilot)
			pilots_processed_this_round.append(w2w_partner)

			# Return W2W result - RaceSimulator will trigger focus mode
			return RoundResult.needs_w2w_focus(pilot, w2w_partner)
		else:
			# Normal turn processing via RaceSimulator
			race_sim.process_pilot_turn(pilot)

			# Mark pilot as processed
			pilots_processed_this_round.append(pilot)

	# All pilots processed - check for race finish
	if _check_race_finished(pilots):
		return RoundResult.race_finished()
	else:
		return RoundResult.completed()

## Get W2W partner if not already processed
func _get_unprocessed_w2w_partner(pilot: PilotState, pilots: Array):
	for pair in current_round_w2w_pairs:
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

## Generate unique key for a pilot pair
func _get_pair_key(pilot1: PilotState, pilot2: PilotState) -> String:
	var names = [pilot1.name, pilot2.name]
	names.sort()
	return names[0] + "_" + names[1]

## Check if all pilots have finished or DNF'd
func _check_race_finished(pilots: Array) -> bool:
	for pilot in pilots:
		if not pilot.finished and not pilot.did_not_finish:
			return false
	return true
