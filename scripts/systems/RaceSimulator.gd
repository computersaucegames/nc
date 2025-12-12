extends Node
class_name RaceSimulator

# Preload the helper classes
const StatusCalc = preload("res://scripts/systems/StatusCalculator.gd")
const OvertakeRes = preload("res://scripts/systems/OvertakeResolver.gd")
const MoveProc = preload("res://scripts/systems/MovementProcessor.gd")
const StartHandler = preload("res://scripts/systems/RaceStartHandler.gd")
const FailureTableRes = preload("res://scripts/systems/FailureTableResolver.gd")
const TurnProc = preload("res://scripts/systems/TurnProcessor.gd")
const RoundProc = preload("res://scripts/systems/RoundProcessor.gd")

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

# Processors (Milestone 3)
var turn_processor: TurnProc
var round_processor: RoundProc

func _ready():
	# Setup timer for auto advancement
	auto_advance_timer = Timer.new()
	auto_advance_timer.timeout.connect(_on_auto_advance)
	auto_advance_timer.one_shot = true
	add_child(auto_advance_timer)

	# Initialize processors (Milestone 3)
	turn_processor = TurnProc.new(self)
	round_processor = RoundProc.new(self)

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

# Current Focus Mode advance callback (to disconnect when done)
var current_focus_advance_callback: Callable

# Current focus sequence (Milestone 2: sequence extraction)
var current_focus_sequence: FocusSequence = null

# [Milestone 3] Round state tracking moved to RoundProcessor

# Process a single round of racing (Milestone 3: delegates to RoundProcessor)
func process_round():
	if race_mode != RaceMode.RUNNING:
		return

	current_round += 1

	# Use RoundProcessor to orchestrate the round
	var round_result = round_processor.process_round(current_round, pilots, current_circuit)

	# Handle the result
	_handle_round_result(round_result)

# Resume processing pilots after Focus Mode (Milestone 3: delegates to RoundProcessor)
func resume_round():
	# Use RoundProcessor to resume the round
	var round_result = round_processor.resume_round(pilots, current_circuit)

	# Handle the result
	_handle_round_result(round_result)

# Handle round result from RoundProcessor (Milestone 3)
func _handle_round_result(result: RoundProc.RoundResult):
	match result.status:
		RoundProc.RoundResult.Status.COMPLETED:
			# Schedule next round
			auto_advance_timer.start(auto_advance_delay)

		RoundProc.RoundResult.Status.NEEDS_W2W_FOCUS:
			# Trigger W2W focus mode
			process_w2w_focus_mode(result.w2w_pilot1, result.w2w_pilot2)
			# Don't schedule next round - will resume after focus mode

		RoundProc.RoundResult.Status.RACE_FINISHED:
			# Finish the race
			finish_race()

# [Milestone 3] Old round processing methods removed - logic moved to RoundProcessor

# Process a single pilot's turn (Milestone 3: delegates to TurnProcessor)
func process_pilot_turn(pilot: PilotState):
	var sector = current_circuit.sectors[pilot.current_sector]

	# Use TurnProcessor to execute the turn
	var turn_result = turn_processor.process_turn(pilot, sector, current_circuit, current_round, pilots)

	# Handle the result
	if turn_result.status == TurnProc.TurnResult.Status.NEEDS_FOCUS_MODE:
		# Red result - trigger failure table focus mode
		process_red_result_focus_mode(pilot, sector, turn_result.initial_roll)
		return  # Exit - will resume after focus mode

	# Turn completed normally - RoundProcessor continues with next pilot

# [Milestone 3] Old turn processing methods removed - logic moved to TurnProcessor and RoundProcessor

# End the race
func finish_race():
	race_mode = RaceMode.FINISHED
	auto_advance_timer.stop()

	var final_positions = MoveProc.get_finish_order(pilots)
	race_finished.emit(final_positions)

# Process wheel-to-wheel situation in Focus Mode
func process_w2w_focus_mode(pilot1: PilotState, pilot2: PilotState):
	# RoundProcessor already marked this pair as processed

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
