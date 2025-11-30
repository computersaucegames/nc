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
		pilot_state.pilot_id = i  # Set the pilot ID for UI tracking
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

# Track W2W pairs already processed in Focus Mode this round
var processed_w2w_pairs: Array = []

# Track individual pilots who have already moved this round
var pilots_processed_this_round: Array = []

# Current Focus Mode advance callback (to disconnect when done)
var current_focus_advance_callback: Callable

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

		# Skip if this pilot already moved this round
		if pilot in pilots_processed_this_round:
			continue

		# Check if this pilot is in a W2W situation
		var w2w_partner = get_unprocessed_w2w_partner(pilot, wheel_to_wheel_pairs)
		if w2w_partner != null:
			# Trigger Focus Mode for this W2W pair
			process_w2w_focus_mode(pilot, w2w_partner)
		else:
			# Normal turn processing
			process_pilot_turn(pilot)
			# Mark pilot as processed
			pilots_processed_this_round.append(pilot)

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

	# Check for capacity blocking
	final_movement = check_capacity_blocking(pilot, final_movement, sector)

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

# Check if the target position has reached capacity (max fins side-by-side)
# If blocked, reduce movement to stay one gap behind the blocking fins
func check_capacity_blocking(pilot: PilotState, movement: int, sector: Sector) -> int:
	if movement <= 0:
		return movement

	# Calculate where the pilot would end up
	var target_gap = pilot.gap_in_sector + movement
	var target_sector = pilot.current_sector

	# Count how many other pilots are already at this exact position
	var pilots_at_target = 0
	for other in pilots:
		if other == pilot or other.finished:
			continue

		# Check if other pilot is at the target position
		if other.current_sector == target_sector and other.gap_in_sector == target_gap:
			pilots_at_target += 1

	# If we've reached capacity, block this pilot from moving into that position
	if pilots_at_target >= sector.max_side_by_side:
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

		return adjusted_movement

	return movement

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
				# Return the partner
				return pair[1] if pair[0] == pilot else pair[0]
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

		# Resume auto-advance by starting next round
		auto_advance_timer.start(auto_advance_delay)

# Execute rolls for both W2W pilots
func _execute_w2w_rolls(pilot1: PilotState, pilot2: PilotState, event: FocusModeManager.FocusModeEvent):
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
	var move_result1 = MoveProc.apply_movement(pilot1, final_movement1, current_circuit)
	pilot_moved.emit(pilot1, final_movement1)
	handle_movement_results(pilot1, move_result1)

	# Handle overtaking for pilot2
	var final_movement2 = handle_overtaking(pilot2, movement2, sector)
	# Check for capacity blocking
	final_movement2 = check_capacity_blocking(pilot2, final_movement2, sector)
	var move_result2 = MoveProc.apply_movement(pilot2, final_movement2, current_circuit)
	pilot_moved.emit(pilot2, final_movement2)
	handle_movement_results(pilot2, move_result2)

	# Mark both pilots as processed for this round
	pilots_processed_this_round.append(pilot1)
	pilots_processed_this_round.append(pilot2)

# Exit focus mode and continue racing
func exit_focus_mode():
	if race_mode == RaceMode.FOCUS_MODE:
		race_mode = RaceMode.RUNNING
		process_round()

# Timer callback for auto-advancement
func _on_auto_advance():
	if race_mode == RaceMode.RUNNING:
		process_round()
