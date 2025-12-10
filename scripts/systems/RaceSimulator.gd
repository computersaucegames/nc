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
signal failure_table_triggered(pilot: PilotState, sector: Sector, consequence: String, roll_result: Dice.DiceResult)
signal overflow_penalty_applied(pilot: PilotState, penalty_gaps: int)
signal overflow_penalty_deferred(pilot: PilotState, penalty_gaps: int)
signal badge_activated(pilot: PilotState, badge_name: String, effect_description: String)
signal negative_badge_applied(pilot: PilotState, badge: Badge)
signal pilot_crashed(pilot: PilotState, sector: Sector, reason: String)
signal w2w_failure_triggered(failing_pilot: PilotState, other_pilot: PilotState, sector: Sector)
signal w2w_failure_roll_result(failing_pilot: PilotState, consequence: String, roll_result: Dice.DiceResult)
signal w2w_contact_triggered(failing_pilot: PilotState, other_pilot: PilotState, consequence: Dictionary)
signal w2w_avoidance_roll_required(pilot: PilotState, modified_gates: Dictionary)
signal w2w_avoidance_roll_result(avoiding_pilot: PilotState, roll_result: Dice.DiceResult, description: String)
signal w2w_dual_crash(pilot1: PilotState, pilot2: PilotState, sector: Sector)
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

	# Set race start status for all pilots and clear other statuses
	for pilot in pilots:
		pilot.is_race_start = true
		pilot.is_clear_air = false
		pilot.is_attacking = false
		pilot.is_defending = false
		pilot.is_wheel_to_wheel = false
		pilot.is_in_train = false
		pilot.is_dueling = false

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

	# Create sequence
	current_focus_sequence = RaceStartSequence.new(event, self)

	# Enter Focus Mode state
	race_mode = RaceMode.FOCUS_MODE

	# Connect to Focus Mode advance signal
	current_focus_advance_callback = func():
		_advance_focus_sequence()
	FocusMode.focus_mode_advance_requested.connect(current_focus_advance_callback)

	# Activate Focus Mode (UI will display grid)
	FocusMode.activate(event)

	# Trigger race start signal
	focus_mode_triggered.emit(pilots, "Race Start")

# Generic handler for focus sequence advancement (Milestone 2)
func _advance_focus_sequence():
	if not current_focus_sequence:
		push_error("No active focus sequence!")
		return

	var result = current_focus_sequence.advance()

	# Emit signal if requested
	if result.emit_signal != "":
		_emit_sequence_signal(result.emit_signal, result.signal_data)

	# Exit focus mode if done
	if result.exit_focus_mode:
		_exit_focus_mode()

# Helper to emit signals from sequence results
func _emit_sequence_signal(signal_name: String, signal_data):
	# Emit the signal dynamically based on name
	match signal_name:
		"race_start_rolls":
			race_start_rolls.emit(signal_data)
		"race_start_complete":
			pass  # No specific signal, just exit focus mode
		"failure_table_complete":
			pass  # Failure table already emitted in sequence
		"red_result_complete":
			pass  # No specific signal, just exit focus mode
		"w2w_rolls_complete":
			pass  # W2W rolls already emitted in sequence
		"w2w_failure_table_complete":
			pass  # W2W failure table already emitted in sequence
		"w2w_avoidance_complete":
			pass  # W2W avoidance already emitted in sequence
		"w2w_complete":
			pass  # No specific signal, just exit focus mode
		_:
			push_warning("Unknown sequence signal: " + signal_name)

# Helper to exit focus mode and resume race
func _exit_focus_mode():
	# Disconnect the advance callback
	if current_focus_advance_callback.is_valid():
		FocusMode.focus_mode_advance_requested.disconnect(current_focus_advance_callback)

	FocusMode.deactivate()
	race_mode = RaceMode.RUNNING

	# Determine what to do next based on sequence type
	var was_race_start = current_focus_sequence and current_focus_sequence.sequence_name == "RaceStart"
	current_focus_sequence = null

	if was_race_start:
		# Start first round after race start
		process_round()
	else:
		# Resume current round after focus mode
		resume_round()

# [Milestone 2] Old race start methods removed - logic moved to RaceStartSequence

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

# Current focus sequence (Milestone 2: sequence extraction)
var current_focus_sequence: FocusSequence = null

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

	# Calculate actual destination using MovementProcessor logic (handles sector boundaries)
	var destination = MoveProc.calculate_destination_position(pilot, movement, current_circuit)
	var target_sector_idx = destination["sector"]
	var target_gap = destination["gap"]
	var target_sector = current_circuit.sectors[target_sector_idx]

	# Count how many other pilots are already at this exact position
	var pilots_at_target = []
	for other in pilots:
		if other == pilot or other.finished or other.did_not_finish:
			continue

		# Check if other pilot is at the target position
		if other.current_sector == target_sector_idx and other.gap_in_sector == target_gap:
			pilots_at_target.append(other)

	# If we've reached capacity, block this pilot from moving into that position
	if pilots_at_target.size() >= target_sector.max_side_by_side:
		# Recursively reduce movement until we find a valid position
		var adjusted_movement = check_capacity_blocking(pilot, movement - 1, sector)

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

# Check if all pilots have finished or DNF'd
func check_race_finished() -> bool:
	for pilot in pilots:
		if not pilot.finished and not pilot.did_not_finish:
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

	# Create sequence
	current_focus_sequence = W2WFailureSequence.new(event, self)

	# Enter Focus Mode state
	race_mode = RaceMode.FOCUS_MODE

	# Connect to Focus Mode advance signal
	current_focus_advance_callback = func():
		_advance_focus_sequence()
	FocusMode.focus_mode_advance_requested.connect(current_focus_advance_callback)

	# Activate Focus Mode (UI will display)
	FocusMode.activate(event)

# [Milestone 2] Old W2W methods removed - logic moved to W2WFailureSequence

# Process red result in Focus Mode (failure table)
func process_red_result_focus_mode(pilot: PilotState, sector: Sector, initial_roll: Dice.DiceResult):
	# Emit focus mode trigger event
	focus_mode_triggered.emit([pilot], "Failure Table - %s" % sector.sector_name)

	# Create Focus Mode event for red result
	var event = FocusMode.create_red_result_event(pilot, sector, initial_roll)

	# Create sequence
	current_focus_sequence = RedResultSequence.new(event, self)

	# Enter Focus Mode state
	race_mode = RaceMode.FOCUS_MODE

	# Connect to Focus Mode advance signal
	current_focus_advance_callback = func():
		_advance_focus_sequence()
	FocusMode.focus_mode_advance_requested.connect(current_focus_advance_callback)

	# Activate Focus Mode (UI will display)
	FocusMode.activate(event)

# [Milestone 2] Old red result methods removed - logic moved to RedResultSequence

# Exit focus mode and continue racing
func exit_focus_mode():
	if race_mode == RaceMode.FOCUS_MODE:
		race_mode = RaceMode.RUNNING
		process_round()

# Timer callback for auto-advancement
func _on_auto_advance():
	if race_mode == RaceMode.RUNNING:
		process_round()
