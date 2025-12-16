extends Node

## Tests for pit lane infrastructure

func _ready():
	print("\n=== PIT LANE INFRASTRUCTURE TESTS ===\n")

	test_circuit_pit_lane_config()
	test_pit_entry_sector()
	test_pit_box_sector()
	test_pit_exit_sector()
	test_pit_entry_availability()
	test_pit_lane_total_distance()

	print("\n=== ALL PIT LANE TESTS COMPLETE ===\n")

func test_circuit_pit_lane_config():
	print("TEST 1: Mountain Circuit pit lane configuration...")

	var circuit = load("res://resources/circuits/mountain_track.tres") as Circuit
	assert(circuit != null, "Should load Mountain Circuit")

	# Check pit lane is enabled
	assert(circuit.has_pit_lane == true, "Circuit should have pit lane")

	# Check pit lane sectors exist
	assert(circuit.pit_lane_sectors.size() == 3, "Should have 3 pit sectors")

	# Check entry/exit configuration
	assert(circuit.pit_entry_after_sector == 7, "Pit entry should be after sector 7 (S7)")
	assert(circuit.pit_exit_rejoin_sector == 9, "Pit exit should rejoin at sector 9 (S9)")

	print("  ✓ Circuit has pit lane enabled")
	print("  ✓ 3 pit sectors configured")
	print("  ✓ Entry after S7, rejoin at S9")
	print("  PASSED\n")

func test_pit_entry_sector():
	print("TEST 2: Pit Entry sector configuration...")

	var circuit = load("res://resources/circuits/mountain_track.tres") as Circuit
	var pit_entry = circuit.pit_lane_sectors[0]

	# Check sector properties
	assert(pit_entry.sector_name == "Pit Entry", "Should be named 'Pit Entry'")
	assert(pit_entry.is_pit_lane_sector == true, "Should be pit lane sector")
	assert(pit_entry.is_pit_entry == true, "Should be marked as pit entry")
	assert(pit_entry.is_pit_box == false, "Should not be pit box")
	assert(pit_entry.is_pit_exit == false, "Should not be pit exit")

	# Check length and mechanic stat
	assert(pit_entry.length_in_gap == 2, "Should be 2 gaps long")
	assert(pit_entry.mechanic_stat_type == "", "Should use pilot stat (empty string)")
	assert(pit_entry.carrythru == 0, "Should have 0 carrythru")

	# Check check type (CRAFT = 1)
	assert(pit_entry.check_type == Sector.CheckType.CRAFT, "Should use CRAFT check")

	# Check failure table exists
	assert(pit_entry.failure_table.size() > 0, "Should have failure table")
	assert(pit_entry.failure_table_check_type == Sector.CheckType.CRAFT, "Failure table should use CRAFT")

	print("  ✓ Pit Entry sector configured correctly")
	print("  ✓ Uses pilot CRAFT stat")
	print("  ✓ 2 gaps, CRAFT check")
	print("  PASSED\n")

func test_pit_box_sector():
	print("TEST 3: Pit Box sector configuration...")

	var circuit = load("res://resources/circuits/mountain_track.tres") as Circuit
	var pit_box = circuit.pit_lane_sectors[1]

	# Check sector properties
	assert(pit_box.sector_name == "Pit Box", "Should be named 'Pit Box'")
	assert(pit_box.is_pit_lane_sector == true, "Should be pit lane sector")
	assert(pit_box.is_pit_entry == false, "Should not be pit entry")
	assert(pit_box.is_pit_box == true, "Should be marked as pit box")
	assert(pit_box.is_pit_exit == false, "Should not be pit exit")

	# Check length and mechanic stat
	assert(pit_box.length_in_gap == 3, "Should be 3 gaps long")
	assert(pit_box.mechanic_stat_type == "rig", "Should use mechanic RIG stat")
	assert(pit_box.carrythru == 0, "Should have 0 carrythru")

	# Check check type (SYNC = 2)
	assert(pit_box.check_type == Sector.CheckType.SYNC, "Should use SYNC check")

	# Check failure table exists
	assert(pit_box.failure_table.size() > 0, "Should have failure table")
	assert(pit_box.failure_table_check_type == Sector.CheckType.SYNC, "Failure table should use SYNC")

	print("  ✓ Pit Box sector configured correctly")
	print("  ✓ Uses mechanic RIG stat")
	print("  ✓ 3 gaps, SYNC check")
	print("  PASSED\n")

func test_pit_exit_sector():
	print("TEST 4: Pit Exit sector configuration...")

	var circuit = load("res://resources/circuits/mountain_track.tres") as Circuit
	var pit_exit = circuit.pit_lane_sectors[2]

	# Check sector properties
	assert(pit_exit.sector_name == "Pit Exit", "Should be named 'Pit Exit'")
	assert(pit_exit.is_pit_lane_sector == true, "Should be pit lane sector")
	assert(pit_exit.is_pit_entry == false, "Should not be pit entry")
	assert(pit_exit.is_pit_box == false, "Should not be pit box")
	assert(pit_exit.is_pit_exit == true, "Should be marked as pit exit")

	# Check length and mechanic stat
	assert(pit_exit.length_in_gap == 2, "Should be 2 gaps long")
	assert(pit_exit.mechanic_stat_type == "cool", "Should use mechanic COOL stat")
	assert(pit_exit.carrythru == 0, "Should have 0 carrythru")

	# Check check type (EDGE = 3)
	assert(pit_exit.check_type == Sector.CheckType.EDGE, "Should use EDGE check")

	# Check failure table exists
	assert(pit_exit.failure_table.size() > 0, "Should have failure table")
	assert(pit_exit.failure_table_check_type == Sector.CheckType.EDGE, "Failure table should use EDGE")

	print("  ✓ Pit Exit sector configured correctly")
	print("  ✓ Uses mechanic COOL stat")
	print("  ✓ 2 gaps, EDGE check")
	print("  PASSED\n")

func test_pit_entry_availability():
	print("TEST 5: S7 pit entry availability...")

	var circuit = load("res://resources/circuits/mountain_track.tres") as Circuit

	# Find S7 (index 7)
	var s7 = circuit.sectors[7]
	assert(s7.sector_name == "S7: Downhill Straight", "Should be S7: Downhill Straight")
	assert(s7.pit_entry_available == true, "S7 should allow pit entry")

	# Verify other sectors don't have pit entry
	for i in range(circuit.sectors.size()):
		if i != 7:
			assert(circuit.sectors[i].pit_entry_available == false,
				"Only S7 should have pit_entry_available")

	print("  ✓ S7 marked with pit_entry_available")
	print("  ✓ No other sectors have pit entry")
	print("  PASSED\n")

func test_pit_lane_total_distance():
	print("TEST 6: Pit lane total distance...")

	var circuit = load("res://resources/circuits/mountain_track.tres") as Circuit

	# Calculate total pit lane distance
	var total_distance = 0
	for sector in circuit.pit_lane_sectors:
		total_distance += sector.length_in_gap

	assert(total_distance == 7, "Total pit lane distance should be 7 gaps (2+3+2)")

	# Verify bypassed sector
	var s8 = circuit.sectors[8]
	assert(s8.sector_name == "S8: Lower Esses Entry", "Sector 8 should be Lower Esses Entry")
	var s8_length = s8.length_in_gap

	print("  ✓ Pit lane total: %d gaps" % total_distance)
	print("  ✓ Bypassed S8: %d gaps" % s8_length)
	print("  ✓ Pit stop cost: %d gaps vs S8's %d gaps" % [total_distance, s8_length])
	print("  PASSED\n")
