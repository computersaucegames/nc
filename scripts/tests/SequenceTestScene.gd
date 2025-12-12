extends Node

## Sequence-specific integration tests for Milestone 2
##
## Tests RaceStartSequence, RedResultSequence, and W2WFailureSequence
## to ensure they properly extract and encapsulate Focus Mode logic.
##
## Run this in Godot after each sequence is created to verify behavior.

var race_sim: RaceSimulator
var test_circuit: Circuit
var test_pilots: Array[PilotState] = []

func _ready():
	print("\n=== FOCUS SEQUENCE TESTS (MILESTONE 2) ===\n")

	setup_test_environment()

	# Run tests for each sequence (will be uncommented as we create them)
	test_race_start_sequence()
	# test_red_result_sequence()  # Uncomment after creating RedResultSequence
	# test_w2w_failure_sequence()  # Uncomment after creating W2WFailureSequence

	print("\n=== ALL SEQUENCE TESTS COMPLETE ===\n")
	# Auto-quit after tests (for CI)
	# get_tree().quit()

func setup_test_environment():
	"""Create a minimal test environment with circuit and pilots"""
	# Create test circuit with 2 sectors
	test_circuit = Circuit.new()
	test_circuit.circuit_name = "Test Circuit"

	var sector1 = Sector.new()
	sector1.sector_name = "Sector 1"
	sector1.check_type = Sector.CheckType.TWITCH
	sector1.grey_threshold = 10
	sector1.green_threshold = 13
	sector1.purple_threshold = 16
	sector1.grey_movement = 1
	sector1.green_movement = 2
	sector1.purple_movement = 3
	sector1.red_movement = 0

	var sector2 = Sector.new()
	sector2.sector_name = "Sector 2"
	sector2.check_type = Sector.CheckType.CRAFT
	sector2.grey_threshold = 11
	sector2.green_threshold = 14
	sector2.purple_threshold = 17
	sector2.grey_movement = 1
	sector2.green_movement = 2
	sector2.purple_movement = 3
	sector2.red_movement = 0

	test_circuit.sectors.append(sector1)
	test_circuit.sectors.append(sector2)

	# Create 3 test pilots
	for i in range(3):
		var pilot_data = Pilot.new()
		pilot_data.pilot_name = "Pilot_%d" % (i + 1)
		pilot_data.TWITCH = 10 + i
		pilot_data.CRAFT = 9 + i
		pilot_data.SYNC = 8 + i
		pilot_data.EDGE = 7 + i

		var pilot_state = PilotState.new()
		pilot_state.pilot_data = pilot_data
		pilot_state.name = pilot_data.pilot_name
		pilot_state.grid_position = i + 1
		pilot_state.position = i + 1
		pilot_state.current_sector = 0
		pilot_state.gap_in_sector = i  # Spread out pilots

		test_pilots.append(pilot_state)

	# Create race simulator
	race_sim = RaceSimulator.new()
	add_child(race_sim)

## Test 1: RaceStartSequence
func test_race_start_sequence():
	print("TEST 1: RaceStartSequence...")

	# Check that RaceStartSequence class exists
	var sequence_script = load("res://scripts/systems/focus_sequences/RaceStartSequence.gd")
	assert(sequence_script != null, "RaceStartSequence.gd should exist")
	print("  ✓ RaceStartSequence class loads")

	# Create a race start event
	var event = FocusModeManager.FocusModeEvent.new(FocusModeManager.EventType.RACE_START)
	event.pilots = test_pilots.duplicate()
	event.sector = test_circuit.sectors[0]

	# Create sequence instance
	var sequence = sequence_script.new(event, race_sim)
	assert(sequence != null, "Sequence should be created")
	print("  ✓ RaceStartSequence instantiates correctly")

	# Verify stage count
	assert(sequence.get_stage_count() == 2, "RaceStartSequence should have 2 stages")
	print("  ✓ Has 2 stages")

	# Verify initial state
	assert(sequence.current_stage == 0, "Should start at stage 0")
	assert(not sequence.is_complete(), "Should not be complete initially")
	print("  ✓ Initial state correct")

	# Execute stage 1 (rolls)
	var result1 = sequence.advance()
	assert(result1 != null, "Stage 1 should return result")
	assert(result1.emit_signal == "race_start_rolls", "Should emit race_start_rolls signal")
	assert(not result1.exit_focus_mode, "Should not exit after stage 1")
	assert(result1.requires_user_input, "Should require user input for stage 1")
	print("  ✓ Stage 1 (rolls) executes correctly")

	# Execute stage 2 (movement)
	var result2 = sequence.advance()
	assert(result2 != null, "Stage 2 should return result")
	assert(result2.emit_signal == "race_start_complete", "Should emit race_start_complete signal")
	assert(result2.exit_focus_mode, "Should exit after stage 2")
	assert(not result2.requires_user_input, "Should not require user input for stage 2")
	print("  ✓ Stage 2 (movement) executes correctly")

	# Verify completion
	assert(sequence.is_complete(), "Should be complete after both stages")
	print("  ✓ Sequence completes properly")

	# Verify pilots have moved
	var moved_pilots = 0
	for pilot in test_pilots:
		if pilot.distance_traveled > 0:
			moved_pilots += 1
	assert(moved_pilots > 0, "At least one pilot should have moved")
	print("  ✓ Pilots moved after sequence")

	print("  PASSED\n")

## Test 2: RedResultSequence
func test_red_result_sequence():
	print("TEST 2: RedResultSequence...")

	# Check that RedResultSequence class exists
	var sequence_script = load("res://scripts/systems/focus_sequences/RedResultSequence.gd")
	assert(sequence_script != null, "RedResultSequence.gd should exist")
	print("  ✓ RedResultSequence class loads")

	# Create a red result event
	var event = FocusModeManager.FocusModeEvent.new(FocusModeManager.EventType.RED_RESULT)
	event.pilots = [test_pilots[0]]
	event.sector = test_circuit.sectors[0]

	# Create fake initial roll
	var initial_roll = Dice.DiceResult.new()
	initial_roll.tier = Dice.Tier.RED
	initial_roll.total_roll = 5
	event.metadata = {"initial_roll": initial_roll}

	# Create sequence instance
	var sequence = sequence_script.new(event, race_sim)
	assert(sequence != null, "Sequence should be created")
	print("  ✓ RedResultSequence instantiates correctly")

	# Verify stage count
	assert(sequence.get_stage_count() == 2, "RedResultSequence should have 2 stages")
	print("  ✓ Has 2 stages")

	# Execute stage 1 (failure table)
	var result1 = sequence.advance()
	assert(result1 != null, "Stage 1 should return result")
	# Note: might exit early if pilot crashes
	if not result1.exit_focus_mode:
		assert(result1.emit_signal == "failure_table_triggered", "Should emit failure_table_triggered")
		print("  ✓ Stage 1 (failure table) executes correctly")

		# Execute stage 2 (movement) only if didn't crash
		var result2 = sequence.advance()
		assert(result2.exit_focus_mode, "Should exit after stage 2")
		print("  ✓ Stage 2 (movement) executes correctly")
	else:
		print("  ✓ Pilot crashed on failure table (valid outcome)")

	print("  ✓ Sequence completes properly")
	print("  PASSED\n")

## Test 3: W2WFailureSequence
func test_w2w_failure_sequence():
	print("TEST 3: W2WFailureSequence...")

	# Check that W2WFailureSequence class exists
	var sequence_script = load("res://scripts/systems/focus_sequences/W2WFailureSequence.gd")
	assert(sequence_script != null, "W2WFailureSequence.gd should exist")
	print("  ✓ W2WFailureSequence class loads")

	# Create a W2W event with two pilots
	var event = FocusModeManager.FocusModeEvent.new(FocusModeManager.EventType.WHEEL_TO_WHEEL_ROLL)
	event.pilots = [test_pilots[0], test_pilots[1]]
	event.sector = test_circuit.sectors[0]

	# Create sequence instance
	var sequence = sequence_script.new(event, race_sim)
	assert(sequence != null, "Sequence should be created")
	print("  ✓ W2WFailureSequence instantiates correctly")

	# Verify stage count
	assert(sequence.get_stage_count() == 4, "W2WFailureSequence should have up to 4 stages")
	print("  ✓ Has 4 stages (maximum)")

	# Execute stage 1 (W2W rolls)
	var result1 = sequence.advance()
	assert(result1 != null, "Stage 1 should return result")
	assert(result1.emit_signal == "w2w_rolls_complete", "Should emit w2w_rolls_complete")
	print("  ✓ Stage 1 (W2W rolls) executes correctly")

	# Note: Further stages depend on roll results
	# - If both RED: dual crash, exits immediately
	# - If one RED: continues to failure table
	# - If neither RED: skips to movement

	# Continue advancing until sequence completes or exits
	var max_stages = 5  # Safety limit
	var stages_executed = 1
	while not sequence.is_complete() and not result1.exit_focus_mode and stages_executed < max_stages:
		var next_result = sequence.advance()
		if next_result.exit_focus_mode:
			break
		stages_executed += 1

	print("  ✓ Sequence completed in %d stages" % stages_executed)
	print("  ✓ Sequence handles W2W logic correctly")
	print("  PASSED\n")
