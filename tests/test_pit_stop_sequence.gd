extends Node

## Tests for pit stop sequence and decision logic

var race_sim: RaceSimulator
var circuit: Circuit
var pilot_state: PilotState
var mechanic: Mechanic

func _ready():
	print("\n=== PIT STOP SEQUENCE TESTS ===\n")

	# Setup test environment
	setup_test_environment()

	# Run tests
	test_pit_stop_decision_logic()
	test_pit_entry_available_detection()
	test_badge_clearing_normal()
	test_badge_clearing_severe()
	test_mechanic_roll_system()
	test_pit_stop_cost_calculation()
	test_pilot_state_tracking()

	print("\n=== ALL PIT STOP TESTS COMPLETE ===\n")

func setup_test_environment():
	print("Setting up test environment...")

	# Load circuit with pit lane
	circuit = load("res://resources/circuits/mountain_track.tres") as Circuit
	assert(circuit != null, "Should load Mountain Circuit")
	assert(circuit.has_pit_lane, "Circuit should have pit lane")

	# Load default mechanic
	mechanic = load("res://resources/mechanics/default_crew.tres") as Mechanic
	assert(mechanic != null, "Should load default mechanic")

	# Create test pilot
	pilot_state = PilotState.new()
	pilot_state.name = "Test Pilot"
	pilot_state.craft = 8
	pilot_state.sync = 7
	pilot_state.edge = 6

	# Setup fin with badges
	var fin = Fin.new()
	fin.fin_name = "Test Fin"
	fin.SPEED = 5
	fin.HANDLING = 5
	pilot_state.setup_fin(fin)

	# Setup mechanic
	pilot_state.setup_mechanic(mechanic)

	print("  ✓ Test environment ready\n")

func test_pit_stop_decision_logic():
	print("TEST 1: Pit stop decision logic...")

	# Test 1: No pit lane - should not pit
	var no_pit_circuit = Circuit.new()
	no_pit_circuit.has_pit_lane = false
	var round_proc = RoundProcessor.new(null)
	var should_pit = round_proc._should_pilot_pit(pilot_state, no_pit_circuit)
	assert(not should_pit, "Should not pit when circuit has no pit lane")

	# Test 2: Not on pit entry sector - should not pit
	pilot_state.current_sector = 0  # S0 doesn't have pit entry
	should_pit = round_proc._should_pilot_pit(pilot_state, circuit)
	assert(not should_pit, "Should not pit when not on pit entry sector")

	# Test 3: On pit entry sector but no badges - should not pit
	pilot_state.current_sector = 7  # S7 has pit_entry_available
	pilot_state.fin_state.temporary_badges.clear()
	should_pit = round_proc._should_pilot_pit(pilot_state, circuit)
	assert(not should_pit, "Should not pit when no badges to clear")

	# Test 4: On pit entry sector with badges - should pit
	var rattled_badge = load("res://resources/badges/rattled.tres") as Badge
	pilot_state.fin_state.add_temporary_badge(rattled_badge)
	should_pit = round_proc._should_pilot_pit(pilot_state, circuit)
	assert(should_pit, "Should pit when on entry sector with badges")

	print("  ✓ Decision logic works correctly")
	print("  PASSED\n")

func test_pit_entry_available_detection():
	print("TEST 2: Pit entry availability detection...")

	# Check S7 has pit entry available
	var s7 = circuit.sectors[7]
	assert(s7.pit_entry_available, "S7 should allow pit entry")
	assert(s7.sector_name == "S7: Downhill Straight", "Should be correct sector")

	# Check other sectors don't allow pit entry
	var other_sectors_correct = true
	for i in range(circuit.sectors.size()):
		if i != 7:
			if circuit.sectors[i].pit_entry_available:
				other_sectors_correct = false
				break

	assert(other_sectors_correct, "Only S7 should allow pit entry")

	print("  ✓ Only S7 allows pit entry")
	print("  PASSED\n")

func test_badge_clearing_normal():
	print("TEST 3: Badge clearing - normal badges...")

	# Setup pilot with normal badges
	pilot_state.fin_state.temporary_badges.clear()
	var rattled = load("res://resources/badges/rattled.tres") as Badge
	var sluggish = load("res://resources/badges/sluggish.tres") as Badge
	pilot_state.fin_state.add_temporary_badge(rattled)
	pilot_state.fin_state.add_temporary_badge(sluggish)

	assert(pilot_state.fin_state.temporary_badges.size() == 2, "Should have 2 badges before pit")

	# Simulate GREEN box roll (should clear normal badges)
	var mock_sequence = PitStopSequence.new(null, null)
	var green_roll = Dice.DiceResult.new()
	green_roll.tier = Dice.Tier.GREEN

	var cleared = mock_sequence._clear_fin_badges(pilot_state, green_roll)

	assert(cleared.size() == 2, "Should clear 2 badges")
	assert(pilot_state.fin_state.temporary_badges.size() == 0, "All normal badges should be cleared")

	print("  ✓ Normal badges cleared on GREEN roll")
	print("  PASSED\n")

func test_badge_clearing_severe():
	print("TEST 4: Badge clearing - severe badges...")

	# Setup pilot with severe badge
	pilot_state.fin_state.temporary_badges.clear()
	var rattled_severe = load("res://resources/badges/rattled_severe.tres") as Badge
	pilot_state.fin_state.add_temporary_badge(rattled_severe)

	# Test 1: GREEN roll should NOT clear severe badges
	var mock_sequence = PitStopSequence.new(null, null)
	var green_roll = Dice.DiceResult.new()
	green_roll.tier = Dice.Tier.GREEN

	var cleared = mock_sequence._clear_fin_badges(pilot_state, green_roll)
	assert(cleared.size() == 0, "GREEN roll should not clear severe badges")
	assert(pilot_state.fin_state.temporary_badges.size() == 1, "Severe badge should remain")

	# Test 2: PURPLE roll should clear severe badges
	var purple_roll = Dice.DiceResult.new()
	purple_roll.tier = Dice.Tier.PURPLE

	cleared = mock_sequence._clear_fin_badges(pilot_state, purple_roll)
	assert(cleared.size() == 1, "PURPLE roll should clear severe badges")
	assert(pilot_state.fin_state.temporary_badges.size() == 0, "All badges should be cleared")

	print("  ✓ Severe badges only cleared on PURPLE roll")
	print("  PASSED\n")

func test_mechanic_roll_system():
	print("TEST 5: Mechanic roll system...")

	# Test mechanic stats are used correctly
	assert(pilot_state.mechanic_state != null, "Pilot should have mechanic")
	assert(pilot_state.mechanic_state.rig > 0, "Mechanic should have RIG stat")
	assert(pilot_state.mechanic_state.cool > 0, "Mechanic should have COOL stat")

	# Test stat retrieval
	var rig_stat = pilot_state.mechanic_state.get_stat("rig")
	var cool_stat = pilot_state.mechanic_state.get_stat("cool")
	var build_stat = pilot_state.mechanic_state.get_stat("build")

	assert(rig_stat == mechanic.RIG, "RIG stat should match mechanic resource")
	assert(cool_stat == mechanic.COOL, "COOL stat should match mechanic resource")
	assert(build_stat == mechanic.BUILD, "BUILD stat should match mechanic resource")

	print("  ✓ Mechanic stats retrieved correctly")
	print("  PASSED\n")

func test_pit_stop_cost_calculation():
	print("TEST 6: Pit stop cost calculation...")

	# Get pit sectors
	var pit_entry = circuit.pit_lane_sectors[0]
	var pit_box = circuit.pit_lane_sectors[1]
	var pit_exit = circuit.pit_lane_sectors[2]

	# Calculate base cost
	var base_cost = pit_entry.length_in_gap + pit_box.length_in_gap + pit_exit.length_in_gap
	assert(base_cost == 7, "Base pit stop cost should be 7 gaps (2+3+2)")

	# Test penalty calculation
	var mock_sequence = PitStopSequence.new(null, null)

	# GREEN roll = 0 penalty
	var green_roll = Dice.DiceResult.new()
	green_roll.tier = Dice.Tier.GREEN
	var penalty = mock_sequence._calculate_pit_penalty(green_roll, pit_entry)
	assert(penalty == 0, "GREEN roll should have 0 penalty")

	# GREY roll = 1 gap penalty
	var grey_roll = Dice.DiceResult.new()
	grey_roll.tier = Dice.Tier.GREY
	penalty = mock_sequence._calculate_pit_penalty(grey_roll, pit_entry)
	assert(penalty == 1, "GREY roll should have 1 gap penalty")

	# RED roll = 2 gap penalty
	var red_roll = Dice.DiceResult.new()
	red_roll.tier = Dice.Tier.RED
	penalty = mock_sequence._calculate_pit_penalty(red_roll, pit_entry)
	assert(penalty == 2, "RED roll should have 2 gap penalty")

	# Best case: All GREEN = 7 gaps total
	# Worst case: All RED = 7 + (2+2+2) = 13 gaps total

	print("  ✓ Pit stop costs calculated correctly")
	print("  ✓ Base cost: 7 gaps")
	print("  ✓ Best case: 7 gaps, Worst case: 13 gaps")
	print("  PASSED\n")

func test_pilot_state_tracking():
	print("TEST 7: Pilot state tracking during pit stop...")

	# Test entering pit lane
	pilot_state.enter_pit_lane(7)
	assert(pilot_state.is_in_pit_lane, "Should be in pit lane")
	assert(pilot_state.pit_lane_stage == 0, "Should be at pit entry stage")
	assert(pilot_state.sectors_before_pit_entry == 7, "Should remember entry sector")

	# Test advancing through stages
	assert(pilot_state.is_in_pit_entry(), "Should be in pit entry")
	pilot_state.advance_pit_stage()

	assert(pilot_state.is_in_pit_box(), "Should be in pit box")
	pilot_state.advance_pit_stage()

	assert(pilot_state.is_in_pit_exit(), "Should be in pit exit")

	# Test exiting pit lane
	var rejoin_sector = circuit.pit_exit_rejoin_sector
	pilot_state.exit_pit_lane(rejoin_sector)

	assert(not pilot_state.is_in_pit_lane, "Should not be in pit lane")
	assert(pilot_state.pit_lane_stage == -1, "Stage should be reset")
	assert(pilot_state.pit_stops_completed == 1, "Should have 1 completed pit stop")
	assert(pilot_state.current_sector == rejoin_sector, "Should be on rejoin sector")
	assert(pilot_state.gap_in_sector == 0, "Should start at beginning of rejoin sector")

	print("  ✓ Pilot state tracked correctly through pit stop")
	print("  PASSED\n")
