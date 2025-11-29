extends Node
class_name RaceSimulator

# Preload the helper classes
const StatusCalc = preload("res://scripts/systems/StatusCalculator.gd")
const OvertakeRes = preload("res://scripts/systems/OvertakeResolver.gd")
const MoveProc = preload("res://scripts/systems/MovementProcessor.gd")
const StartHandler = preload("res://scripts/systems/RaceStartHandler.gd")

# Signals for the event-heavy system
signal race_started(circuit: Circuit, pilots: Array)
signal race_start_rolls(pilot_results: Array)
signal round_started(round_number: int)
signal pilot_rolling(pilot: PilotState, sector: Sector)
signal pilot_rolled(pilot: PilotState, result: Dice.DiceResult)
signal pilot_moved(pilot: PilotState, movement: int)
signal overtake_detected(overtaking_pilot: PilotState, overtaken_pilot: PilotState)
signal overtake_attempt(attacker: PilotState, defender: PilotState, attacker_roll: Dice.DiceResult, defender_roll: Dice.DiceResult)
signal overtake_completed(overtaking_pilot: PilotState, overtaken_pilot: PilotState)
signal overtake_blocked(attacker: PilotState, defender: PilotState)
signal sector_completed(pilot: PilotState, sector: Sector)
signal lap_completed(pilot: PilotState, lap_number: int)
signal pilot_finished(pilot: PilotState, finish_position: int)
signal wheel_to_wheel_detected(pilot1: PilotState, pilot2: PilotState)
signal focus_mode_triggered(pilots: Array, reason: String)
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
	race_mode = RaceMode.RUNNING
	current_round = 0
	
	# Initialize pilot states
	pilots.clear()
	for i in range(pilot_list.size()):
		var pilot_state = PilotState.new()
		pilot_state.setup_from_dict(pilot_list[i], i + 1)
		pilots.append(pilot_state)
	
	# Use StartHandler to setup grid
	StartHandler.form_starting_grid(pilots, circuit)
	
	race_started.emit(current_circuit, pilots)
	
	# Execute race start procedure
	execute_race_start()

# Handle the race start procedure
func execute_race_start():
	# Use StartHandler for launch procedure
	var start_results = StartHandler.execute_launch_procedure(pilots)
	
	# Convert to format expected by signal
	var signal_data = []
	for result in start_results:
		signal_data.append({
			"pilot": result.pilot,
			"roll": result.roll
		})
	
	# Emit the start results
	race_start_rolls.emit(signal_data)
	
	# Update positions after start bonuses
	MoveProc.update_all_positions(pilots)
	
	# Start the first round
	process_round()

# Pause the race
func pause_race():
	race_mode = RaceMode.PAUSED
	auto_advance_timer.stop()

# Resume from pause
func resume_race():
	if race_mode == RaceMode.PAUSED:
		race_mode = RaceMode.RUNNING
		process_round()

# Process a single round of racing
func process_round():
	if race_mode != RaceMode.RUNNING:
		return
	
	current_round += 1
	round_started.emit(current_round)
	
	# Update positions
	MoveProc.update_all_positions(pilots)
	
	# Calculate all pilot statuses
	StatusCalc.calculate_all_statuses(pilots)
	
	# Check for wheel-to-wheel situations
	var wheel_to_wheel_pairs = StatusCalc.get_wheel_to_wheel_pairs(pilots)
	for pair in wheel_to_wheel_pairs:
		wheel_to_wheel_detected.emit(pair[0], pair[1])
	
	# Process each pilot in position order
	for pilot in pilots:
		if race_mode != RaceMode.RUNNING:
			break
		
		if not MoveProc.can_pilot_race(pilot):
			continue
			
		process_pilot_turn(pilot)
	
	# Check for race finish
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
	
	# Calculate base movement
	var base_movement = MoveProc.calculate_base_movement(sector, roll_result)
	
	# Handle overtaking
	var final_movement = handle_overtaking(pilot, base_movement, sector)
	
	# Apply movement
	var move_result = MoveProc.apply_movement(pilot, final_movement, current_circuit)
	pilot_moved.emit(pilot, final_movement)
	
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
	
	# Future: Add modifiers from badges, status effects, etc.
	
	var gates = {
		"grey": sector.grey_threshold,
		"green": sector.green_threshold,
		"purple": sector.purple_threshold
	}
	
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

# Handle the results of movement (sectors, laps, finishing)
func handle_movement_results(pilot: PilotState, move_result):
	# Emit events for completed sectors
	for completed_sector in move_result.sectors_completed:
		sector_completed.emit(pilot, completed_sector)
	
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
	
	pilot.finish_race(finish_position)
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

# Exit focus mode and continue racing
func exit_focus_mode():
	if race_mode == RaceMode.FOCUS_MODE:
		race_mode = RaceMode.RUNNING
		process_round()

# Timer callback for auto-advancement
func _on_auto_advance():
	if race_mode == RaceMode.RUNNING:
		process_round()
