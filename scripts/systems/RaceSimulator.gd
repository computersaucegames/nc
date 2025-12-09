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
	# Note: We don't emit pilot_rolling/pilot_rolled during race start
	# because we show a summary via race_start_rolls instead
	for pilot in pilots:
		# Get badge modifiers for race start
		var context = {
			"roll_type": "race_start",
			"is_race_start": true,
			"sector": start_sector
		}
		var modifiers = BadgeSystem.get_active_modifiers(pilot, context)

		# Don't emit badge activations during race start - badges are applied
		# to the roll but we show the results in the race_start_rolls summary

		var roll = Dice.roll_d20(pilot.twitch, "twitch", modifiers, gates, {
			"context": "race_start",
			"pilot": pilot.name
		})
		# Don't emit pilot_rolled here - we'll show summary via race_start_rolls
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

	# Emit race start rolls summary now that all rolls are complete
	var signal_data = []
	for entry in sorted_pilots_with_rolls:
		signal_data.append({
			"pilot": entry.pilot,
			"roll": entry.roll
		})
	race_start_rolls.emit(signal_data)

	# Re-emit event to update UI with roll results
	FocusMode.focus_mode_activated.emit(event)

# Apply movement for all pilots in twitch order
func _apply_race_start_movement(event: FocusModeManager.FocusModeEvent):
	var sorted_pilots_with_rolls = event.metadata["sorted_pilots"]

	# Process each pilot in twitch order
	for entry in sorted_pilots_with_rolls:
		var pilot = entry.pilot
		var movement = entry.movement
		var sector = current_circuit.sectors[pilot.current_sector]

		# Capture state before movement
		var start_gap = pilot.gap_in_sector
		var start_distance = pilot.total_distance

		# Check for capacity blocking during race start
		# (no overtaking at race start, but we still need to prevent overcrowding)
		var final_movement = check_capacity_blocking(pilot, movement, sector)

		# Apply movement
		var move_result = MoveProc.apply_movement(pilot, final_movement, current_circuit)
		pilot_moved.emit(pilot, final_movement)

		# Emit detailed movement info
		var sector_completed = move_result.sectors_completed.size() > 0
		var momentum = move_result.momentum_gained[0] if move_result.momentum_gained.size() > 0 else 0
		pilot_movement_details.emit(pilot.name, start_gap, start_distance, movement, pilot.gap_in_sector, pilot.total_distance, sector_completed, momentum)

		handle_movement_results(pilot, move_result)

	# Update all positions after race start
	MoveProc.update_all_positions(pilots)

	# Clear race start status for all pilots (race has now begun)
	for pilot in pilots:
		pilot.is_race_start = false

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
		# Stage 1: Execute initial rolls
		_execute_w2w_rolls(pilot1, pilot2, event)
		return

	# Check if this is a W2W failure sequence
	if event.metadata.get("w2w_failure", false):
		# W2W Failure Multi-stage sequence
		if not event.metadata.has("failure_consequence"):
			# Stage 2: Roll on W2W failure table
			_execute_w2w_failure_roll(event)
			return
		elif event.metadata.get("contact_triggered", false) and not event.metadata.has("avoidance_result"):
			# Stage 3: Avoidance save for non-failing pilot
			_execute_w2w_avoidance_save(event)
			return
		else:
			# Stage 4: Apply W2W failure movement and finish
			_apply_w2w_failure_movement(event)
	elif event.metadata.get("dual_crash", false):
		# Dual crash - just exit, both pilots already crashed
		pass
	else:
		# Normal W2W flow (no failures)
		_apply_w2w_movement(pilot1, pilot2, event)

	# Disconnect the advance callback
	if current_focus_advance_callback.is_valid():
		FocusMode.focus_mode_advance_requested.disconnect(current_focus_advance_callback)

	FocusMode.deactivate()
	race_mode = RaceMode.RUNNING

	# Mark both pilots as processed this round
	if pilot1 not in pilots_processed_this_round:
		pilots_processed_this_round.append(pilot1)
	if pilot2 not in pilots_processed_this_round:
		pilots_processed_this_round.append(pilot2)

	# Resume the current round to process remaining pilots
	resume_round()

# Execute rolls for both W2W pilots
func _execute_w2w_rolls(pilot1: PilotState, pilot2: PilotState, event: FocusModeManager.FocusModeEvent):
	var sector = event.sector

	# Apply any pending overflow penalties from previous failures
	# Store them to reduce movement later (after rolls are made)
	var pilot1_pending_penalty = pilot1.penalty_next_turn
	var pilot2_pending_penalty = pilot2.penalty_next_turn

	if pilot1_pending_penalty > 0:
		overflow_penalty_applied.emit(pilot1, pilot1_pending_penalty)
	if pilot2_pending_penalty > 0:
		overflow_penalty_applied.emit(pilot2, pilot2_pending_penalty)

	# Roll for both pilots
	pilot_rolling.emit(pilot1, sector)
	var roll1 = make_pilot_roll(pilot1, sector)
	pilot_rolled.emit(pilot1, roll1)

	pilot_rolling.emit(pilot2, sector)
	var roll2 = make_pilot_roll(pilot2, sector)
	pilot_rolled.emit(pilot2, roll2)

	# Store rolls in event
	event.roll_results = [roll1, roll2]

	# Check for RED results during W2W (new W2W failure system)
	var pilot1_red = (roll1.tier == Dice.Tier.RED)
	var pilot2_red = (roll2.tier == Dice.Tier.RED)

	# Handle dual RED crash (both pilots crash into each other)
	if pilot1_red and pilot2_red:
		# Both pilots crash!
		pilot1.crash("W2W Crash - both pilots lost control", current_round)
		pilot2.crash("W2W Crash - both pilots lost control", current_round)

		# Emit dual crash signal
		w2w_dual_crash.emit(pilot1, pilot2, sector)
		pilot_crashed.emit(pilot1, sector, "W2W Dual Crash")
		pilot_crashed.emit(pilot2, sector, "W2W Dual Crash")

		# Set event metadata for crash
		event.metadata["dual_crash"] = true
		event.movement_outcomes = [0, 0]  # No movement, both crashed

		# Re-emit event to update UI
		FocusMode.focus_mode_activated.emit(event)
		return  # Exit - both pilots out

	# Handle single RED (W2W failure sequence)
	if pilot1_red or pilot2_red:
		# Store which pilot failed and which needs to make avoidance save
		event.metadata["w2w_failure"] = true
		if pilot1_red:
			event.metadata["failing_pilot"] = pilot1
			event.metadata["avoiding_pilot"] = pilot2
		else:
			event.metadata["failing_pilot"] = pilot2
			event.metadata["avoiding_pilot"] = pilot1

		# We'll handle the W2W failure sequence on the next focus mode advance
		# For now, just show the rolls
		event.movement_outcomes = [0, 0]  # Will be calculated after failure resolution
		FocusMode.focus_mode_activated.emit(event)
		return  # Exit - will continue in advance handler

	# Normal W2W flow (no RED results)
	# Calculate movement outcomes
	var movement1 = MoveProc.calculate_base_movement(sector, roll1)
	var movement2 = MoveProc.calculate_base_movement(sector, roll2)

	# Apply pending penalties to movement
	if pilot1_pending_penalty > 0:
		movement1 = max(0, movement1 - pilot1_pending_penalty)
		pilot1.penalty_next_turn = 0  # Clear penalty after applying
	if pilot2_pending_penalty > 0:
		movement2 = max(0, movement2 - pilot2_pending_penalty)
		pilot2.penalty_next_turn = 0  # Clear penalty after applying

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

# Execute W2W failure table roll for the failing pilot
func _execute_w2w_failure_roll(event: FocusModeManager.FocusModeEvent):
	var failing_pilot = event.metadata["failing_pilot"]
	var avoiding_pilot = event.metadata["avoiding_pilot"]
	var sector = event.sector

	# Get W2W failure table (sector-specific or global)
	var failure_consequence = sector.get_random_w2w_failure()

	# Roll save on failure table using failure_table_check_type
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

	# Emit W2W failure triggered signal
	w2w_failure_triggered.emit(failing_pilot, avoiding_pilot, sector)

	# Emit failure roll result for logging
	w2w_failure_roll_result.emit(failing_pilot, failure_consequence["text"], failure_roll)

	# Apply negative badge based on failure roll tier (if badge specified)
	var badge_id = failure_consequence.get("badge_id", "")
	if badge_id != "":
		var badge_applied = FailureTableRes.apply_badge_based_on_tier(failing_pilot, badge_id, failure_roll.tier)
		if badge_applied:
			var applied_badge_id = badge_id
			if failure_roll.tier == Dice.Tier.GREY:
				applied_badge_id = badge_id + "_severe"
			var badge = FailureTableRes.load_badge(applied_badge_id)
			if badge:
				negative_badge_applied.emit(failing_pilot, badge)

	# Check if contact is triggered (RED or GREY on failure save)
	var triggers_contact = failure_consequence.get("triggers_contact", false)
	var contact_triggered = triggers_contact and (failure_roll.tier == Dice.Tier.RED or failure_roll.tier == Dice.Tier.GREY)

	event.metadata["contact_triggered"] = contact_triggered

	if contact_triggered:
		# Contact! Other pilot needs to make avoidance save
		w2w_contact_triggered.emit(failing_pilot, avoiding_pilot, failure_consequence)
	elif failure_roll.tier == Dice.Tier.RED:
		# RED without contact - only failing pilot crashes
		failing_pilot.crash("W2W Crash", current_round)
		event.metadata["failing_pilot_crashed_solo"] = true
		pilot_crashed.emit(failing_pilot, sector, failure_consequence["text"])

		# Avoiding pilot continues with normal movement
		var avoiding_roll = event.roll_results[1] if event.metadata["failing_pilot"] == event.pilots[0] else event.roll_results[0]
		event.metadata["avoiding_pilot_movement"] = MoveProc.calculate_base_movement(sector, avoiding_roll)
		event.metadata["failing_pilot_movement"] = 0

	# Calculate movement for failing pilot (reduced by penalty) if not already set
	if not event.metadata.has("failing_pilot_movement"):
		var penalty_gaps = failure_consequence.get("penalty_gaps", 0)
		var base_movement = max(0, sector.red_movement - penalty_gaps)
		event.metadata["failing_pilot_movement"] = base_movement

	# Calculate avoiding pilot movement if not already set and not crashed
	if not event.metadata.has("avoiding_pilot_movement") and not event.metadata.get("failing_pilot_crashed_solo", false):
		# Will be calculated during avoidance save if contact triggered
		# Otherwise use normal roll result
		if not contact_triggered:
			var avoiding_roll = event.roll_results[1] if event.metadata["failing_pilot"] == event.pilots[0] else event.roll_results[0]
			event.metadata["avoiding_pilot_movement"] = MoveProc.calculate_base_movement(sector, avoiding_roll)

	# Re-emit event to show failure roll result
	FocusMode.focus_mode_activated.emit(event)

# Execute avoidance save for the non-failing pilot
func _execute_w2w_avoidance_save(event: FocusModeManager.FocusModeEvent):
	var avoiding_pilot = event.metadata["avoiding_pilot"]
	var failing_pilot = event.metadata["failing_pilot"]
	var sector = event.sector

	# Calculate modified gates (normal gates + 2)
	var modified_gates = {
		"grey": sector.grey_threshold + 2,
		"green": sector.green_threshold + 2,
		"purple": sector.purple_threshold + 2
	}

	# Emit signal that avoidance roll is required
	w2w_avoidance_roll_required.emit(avoiding_pilot, modified_gates)

	# Roll Twitch save with modified gates
	var avoidance_roll = Dice.roll_d20(avoiding_pilot.twitch, "twitch", [], modified_gates, {
		"pilot": avoiding_pilot.name,
		"sector": sector.sector_name,
		"context": "w2w_avoidance"
	})

	event.metadata["avoidance_result"] = avoidance_roll

	# Apply consequences based on avoidance roll tier
	match avoidance_roll.tier:
		Dice.Tier.PURPLE:
			# Clean avoidance - full movement
			event.metadata["avoiding_pilot_movement"] = MoveProc.calculate_base_movement(sector, event.roll_results[1] if event.metadata["failing_pilot"] == event.metadata.get("pilot1") else event.roll_results[0])
			event.metadata["avoidance_description"] = "Clean avoidance! No penalty"

		Dice.Tier.GREEN:
			# Glancing contact - lose 1 gap
			var base_movement = MoveProc.calculate_base_movement(sector, event.roll_results[1] if event.metadata["failing_pilot"] == event.metadata.get("pilot1") else event.roll_results[0])
			event.metadata["avoiding_pilot_movement"] = max(0, base_movement - 1)
			event.metadata["avoidance_description"] = "Glancing contact - lose 1 Gap"

		Dice.Tier.GREY:
			# Heavy contact - lose 2 gaps + Rattled badge
			var base_movement = MoveProc.calculate_base_movement(sector, event.roll_results[1] if event.metadata["failing_pilot"] == event.metadata.get("pilot1") else event.roll_results[0])
			event.metadata["avoiding_pilot_movement"] = max(0, base_movement - 2)
			event.metadata["avoidance_description"] = "Heavy contact - lose 2 Gap + Rattled"

			# Apply Rattled badge (severe version)
			var badge_applied = FailureTableRes.apply_badge_based_on_tier(avoiding_pilot, "rattled", Dice.Tier.GREY)
			if badge_applied:
				var badge = FailureTableRes.load_badge("rattled_severe")
				if badge:
					negative_badge_applied.emit(avoiding_pilot, badge)

		Dice.Tier.RED:
			# Contact! Both crash
			failing_pilot.crash("W2W Crash", current_round)
			avoiding_pilot.crash("W2W Crash - failed avoidance", current_round)

			event.metadata["both_crashed"] = true
			pilot_crashed.emit(failing_pilot, sector, event.metadata["failure_consequence"]["text"])
			pilot_crashed.emit(avoiding_pilot, sector, "Failed to avoid W2W crash")

			event.metadata["failing_pilot_movement"] = 0
			event.metadata["avoiding_pilot_movement"] = 0
			event.metadata["avoidance_description"] = "CRASH! Failed to avoid contact"

	# Emit avoidance roll result for logging
	w2w_avoidance_roll_result.emit(avoiding_pilot, avoidance_roll, event.metadata["avoidance_description"])

	# Re-emit event to show avoidance roll result
	FocusMode.focus_mode_activated.emit(event)

# Apply movement after W2W failure has been resolved
func _apply_w2w_failure_movement(event: FocusModeManager.FocusModeEvent):
	var failing_pilot = event.metadata["failing_pilot"]
	var avoiding_pilot = event.metadata["avoiding_pilot"]
	var sector = event.sector

	# If both crashed, no movement to apply
	if event.metadata.get("both_crashed", false):
		return

	# Apply movement for failing pilot
	var failing_movement = event.metadata.get("failing_pilot_movement", 0)
	var avoiding_movement = event.metadata.get("avoiding_pilot_movement", 0)

	# Failing pilot movement (only if not crashed solo)
	if not event.metadata.get("failing_pilot_crashed_solo", false):
		var final_failing_movement = handle_overtaking(failing_pilot, failing_movement, sector)
		final_failing_movement = check_capacity_blocking(failing_pilot, final_failing_movement, sector)

		var start_gap_failing = failing_pilot.gap_in_sector
		var start_distance_failing = failing_pilot.total_distance

		var move_result_failing = MoveProc.apply_movement(failing_pilot, final_failing_movement, current_circuit)
		pilot_moved.emit(failing_pilot, final_failing_movement)

		var sector_completed_failing = move_result_failing.sectors_completed.size() > 0
		var momentum_failing = move_result_failing.momentum_gained[0] if move_result_failing.momentum_gained.size() > 0 else 0
		pilot_movement_details.emit(failing_pilot.name, start_gap_failing, start_distance_failing, final_failing_movement, failing_pilot.gap_in_sector, failing_pilot.total_distance, sector_completed_failing, momentum_failing)

		handle_movement_results(failing_pilot, move_result_failing)

	# Avoiding pilot movement
	var final_avoiding_movement = handle_overtaking(avoiding_pilot, avoiding_movement, sector)
	final_avoiding_movement = check_capacity_blocking(avoiding_pilot, final_avoiding_movement, sector)

	var start_gap_avoiding = avoiding_pilot.gap_in_sector
	var start_distance_avoiding = avoiding_pilot.total_distance

	var move_result_avoiding = MoveProc.apply_movement(avoiding_pilot, final_avoiding_movement, current_circuit)
	pilot_moved.emit(avoiding_pilot, final_avoiding_movement)

	var sector_completed_avoiding = move_result_avoiding.sectors_completed.size() > 0
	var momentum_avoiding = move_result_avoiding.momentum_gained[0] if move_result_avoiding.momentum_gained.size() > 0 else 0
	pilot_movement_details.emit(avoiding_pilot.name, start_gap_avoiding, start_distance_avoiding, final_avoiding_movement, avoiding_pilot.gap_in_sector, avoiding_pilot.total_distance, sector_completed_avoiding, momentum_avoiding)

	handle_movement_results(avoiding_pilot, move_result_avoiding)

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
	var badge_id = failure_result.badge_id

	# Emit failure table result event
	failure_table_triggered.emit(pilot, sector, consequence, failure_roll)

	# Check if this is a crash (RED tier on failure table roll)
	if failure_roll.tier == Dice.Tier.RED:
		# CRASH! Pilot DNF
		pilot.crash("Crashed", current_round)
		event.metadata["crashed"] = true
		event.metadata["consequence"] = consequence
		event.metadata["initial_roll"] = initial_roll
		event.roll_results = [failure_roll]
		event.movement_outcomes = [0]  # No movement for crashed pilots

		# Emit crash signal
		pilot_crashed.emit(pilot, sector, consequence)

		# Re-emit event to update UI with crash
		FocusMode.focus_mode_activated.emit(event)
		return  # Stop processing - pilot is out

	# Apply negative badge based on failure roll tier (not crash)
	# PURPLE: no badge, GREEN: -1 badge, GREY: -2 badge
	if badge_id != "":
		var badge_applied = FailureTableRes.apply_badge_based_on_tier(pilot, badge_id, failure_roll.tier)
		if badge_applied:
			# Get the actual badge that was applied (might be base or _severe version)
			var applied_badge_id = badge_id
			if failure_roll.tier == Dice.Tier.GREY:
				applied_badge_id = badge_id + "_severe"
			var badge = FailureTableRes.load_badge(applied_badge_id)
			if badge:
				negative_badge_applied.emit(pilot, badge)

	# Store failure data in event
	event.roll_results = [failure_roll]
	event.metadata["consequence"] = consequence
	event.metadata["initial_roll"] = initial_roll
	event.metadata["penalty_gaps"] = penalty_gaps
	if badge_id != "":
		event.metadata["badge_id"] = badge_id

	# Calculate total penalty: NEW penalty from this failure + any EXISTING pending penalty
	var total_penalty = penalty_gaps
	if pilot.penalty_next_turn > 0:
		total_penalty += pilot.penalty_next_turn
		# Log that we're applying the previous pending penalty
		overflow_penalty_applied.emit(pilot, pilot.penalty_next_turn)
		pilot.penalty_next_turn = 0  # Clear it since we're accounting for it now

	# Calculate movement (base red_movement minus total penalty, minimum 0)
	var base_movement = max(0, sector.red_movement - total_penalty)

	# Calculate NEW overflow penalty (penalty that exceeds available movement)
	var overflow_penalty = max(0, total_penalty - sector.red_movement)
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
