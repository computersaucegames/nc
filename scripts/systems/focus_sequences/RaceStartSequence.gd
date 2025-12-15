extends FocusSequence
class_name RaceStartSequence

## Multi-stage sequence for race start Focus Mode
##
## Stage 1: Execute race start rolls (all pilots, TWITCH)
## Stage 2: Apply movement from rolls in sorted order

var race_sim: RaceSimulator  # Reference to race simulator
var start_sector: Sector
var all_pilots: Array[PilotState]
var sorted_pilots_with_rolls: Array = []  # Store sorted results for stage 2

func _init(event: FocusModeManager.FocusModeEvent, simulator: RaceSimulator):
	super._init(event)
	sequence_name = "RaceStart"
	race_sim = simulator
	start_sector = event.sector
	all_pilots = event.pilots.duplicate()

func get_stage_count() -> int:
	return 2

func get_stage_name(stage: int) -> String:
	match stage:
		0: return "Race Start Rolls"
		1: return "Apply Movement"
		_: return "Unknown"

func execute_stage(stage: int) -> StageResult:
	var result = StageResult.new()

	match stage:
		0:  # Execute race start rolls
			_execute_race_start_rolls(result)

		1:  # Apply movement
			_apply_race_start_movement()
			result.emit_signal = "race_start_complete"
			result.continue_sequence = false
			result.exit_focus_mode = true
			result.requires_user_input = false

	return result

func _execute_race_start_rolls(result: StageResult):
	# Prepare gates from sector thresholds
	var gates = {
		"grey": start_sector.grey_threshold,
		"green": start_sector.green_threshold,
		"purple": start_sector.purple_threshold
	}

	var roll_results: Array = []
	var movement_outcomes: Array = []

	# Roll twitch for all pilots
	for pilot in all_pilots:
		# Calculate stat value: pilot twitch + fin response (if fin equipped)
		var stat_value = pilot.twitch
		if pilot.fin_state != null:
			var fin_response = pilot.fin_state.get_stat("RESPONSE")
			stat_value += fin_response

		# Get badge modifiers for race start
		var context = {
			"roll_type": "race_start",
			"is_race_start": true,
			"sector": start_sector,
			"pilot": pilot
		}
		var modifiers = BadgeSystem.get_active_modifiers(pilot, context)

		# Add modifiers from fin badges (if pilot has a fin)
		if pilot.fin_state != null:
			var fin_badge_mods = BadgeSystem.get_active_modifiers_for_fin(pilot.fin_state, context)
			modifiers.append_array(fin_badge_mods)

		# Roll TWITCH+RESPONSE for race start (combined pilot+fin stats)
		var roll = Dice.roll_d20(stat_value, "twitch", modifiers, gates, {
			"context": "race_start",
			"pilot": pilot.name
		})
		roll_results.append(roll)

		# Calculate movement for this roll
		var movement = start_sector.get_movement_for_roll(roll.final_total)
		movement_outcomes.append(movement)

		# Store in event for UI
		focus_event.roll_results.append(roll)
		focus_event.movement_outcomes.append(movement)

	# Sort pilots by twitch roll (highest first), ties broken by grid_position (lowest first)
	sorted_pilots_with_rolls = []
	for i in range(all_pilots.size()):
		sorted_pilots_with_rolls.append({
			"pilot": all_pilots[i],
			"roll": roll_results[i],
			"movement": movement_outcomes[i]
		})

	sorted_pilots_with_rolls.sort_custom(func(a, b):
		# First sort by roll total (descending)
		if a.roll.final_total != b.roll.final_total:
			return a.roll.final_total > b.roll.final_total
		# Tie-breaker: grid position (ascending)
		return a.pilot.grid_position < b.pilot.grid_position
	)

	# Store sorted order in metadata for movement phase
	focus_event.metadata["sorted_pilots"] = sorted_pilots_with_rolls

	# Prepare signal data
	var signal_data = []
	for entry in sorted_pilots_with_rolls:
		signal_data.append({
			"pilot": entry.pilot,
			"roll": entry.roll
		})

	# Emit race start rolls summary
	result.emit_signal = "race_start_rolls"
	result.signal_data = signal_data
	result.continue_sequence = true
	result.requires_user_input = true

	# Re-emit focus mode activation to update UI with roll results
	FocusMode.focus_mode_activated.emit(focus_event)

func _apply_race_start_movement():
	# Use the sorted pilots from stage 1
	var sorted_pilots = focus_event.metadata.get("sorted_pilots", sorted_pilots_with_rolls)

	# Process each pilot in twitch order
	for entry in sorted_pilots:
		var pilot: PilotState = entry.pilot
		var movement: int = entry.movement
		var sector = race_sim.current_circuit.sectors[pilot.current_sector]

		# Capture state before movement
		var start_gap = pilot.gap_in_sector
		var start_distance = pilot.total_distance

		# Check for capacity blocking during race start
		# (no overtaking at race start, but we still need to prevent overcrowding)
		var final_movement = race_sim.check_capacity_blocking(pilot, movement, sector)

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

		# Handle movement results (sector completion, lap completion, etc.)
		race_sim.handle_movement_results(pilot, move_result)

	# Update all positions after race start
	race_sim.MoveProc.update_all_positions(race_sim.pilots)

	# Clear race start status for all pilots (race has now begun)
	for pilot in race_sim.pilots:
		pilot.is_race_start = false
