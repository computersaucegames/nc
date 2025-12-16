extends Node

## Tests for Mechanic and MechanicState system

func _ready():
	print("\n=== MECHANIC SYSTEM TESTS ===\n")

	test_mechanic_resource_loading()
	test_mechanic_state_setup()
	test_mechanic_stat_access()
	test_mechanic_badge_system()
	test_pilot_mechanic_integration()

	print("\n=== ALL MECHANIC TESTS COMPLETE ===\n")

func test_mechanic_resource_loading():
	print("TEST 1: Mechanic resource loading...")

	# Load default mechanic
	var default_mechanic = load("res://resources/mechanics/default_crew.tres") as Mechanic
	assert(default_mechanic != null, "Should load default mechanic resource")
	assert(default_mechanic.mechanic_name == "Standard Pit Crew", "Should have correct name")
	assert(default_mechanic.mechanic_id == "default_crew", "Should have correct ID")

	# Check stats
	assert(default_mechanic.BUILD == 7, "Should have BUILD = 7")
	assert(default_mechanic.RIG == 6, "Should have RIG = 6")
	assert(default_mechanic.COOL == 5, "Should have COOL = 5")

	print("  ✓ Default mechanic loaded successfully")
	print("  ✓ Stats: BUILD=%d, RIG=%d, COOL=%d" % [default_mechanic.BUILD, default_mechanic.RIG, default_mechanic.COOL])
	print("  PASSED\n")

func test_mechanic_state_setup():
	print("TEST 2: MechanicState setup from resource...")

	# Create mechanic resource
	var mechanic = Mechanic.new()
	mechanic.mechanic_name = "Test Crew"
	mechanic.mechanic_id = "test"
	mechanic.BUILD = 8
	mechanic.RIG = 7
	mechanic.COOL = 6

	# Setup state from resource
	var mechanic_state = MechanicState.new()
	mechanic_state.setup_from_mechanic_resource(mechanic)

	assert(mechanic_state.mechanic_name == "Test Crew", "Should copy name")
	assert(mechanic_state.mechanic_id == "test", "Should copy ID")
	assert(mechanic_state.build == 8, "Should copy BUILD stat")
	assert(mechanic_state.rig == 7, "Should copy RIG stat")
	assert(mechanic_state.cool == 6, "Should copy COOL stat")

	print("  ✓ MechanicState setup correctly")
	print("  PASSED\n")

func test_mechanic_stat_access():
	print("TEST 3: Mechanic stat access by name...")

	var mechanic_state = MechanicState.new()
	mechanic_state.build = 8
	mechanic_state.rig = 7
	mechanic_state.cool = 6

	# Test get_stat by name
	assert(mechanic_state.get_stat("build") == 8, "Should get BUILD by name")
	assert(mechanic_state.get_stat("rig") == 7, "Should get RIG by name")
	assert(mechanic_state.get_stat("cool") == 6, "Should get COOL by name")
	assert(mechanic_state.get_stat("BUILD") == 8, "Should be case-insensitive")
	assert(mechanic_state.get_stat("unknown") == 5, "Should return 5 for unknown stat")

	print("  ✓ All stat access methods work correctly")
	print("  PASSED\n")

func test_mechanic_badge_system():
	print("TEST 4: Mechanic badge system...")

	var mechanic_state = MechanicState.new()
	mechanic_state.build = 7

	# Test adding badges
	var badge1 = Badge.new()
	badge1.badge_id = "test_badge_1"
	badge1.badge_name = "Test Badge 1"

	mechanic_state.add_temporary_badge(badge1)
	assert(mechanic_state.temporary_badges.size() == 1, "Should have 1 badge")

	# Test duplicate prevention
	mechanic_state.add_temporary_badge(badge1)
	assert(mechanic_state.temporary_badges.size() == 1, "Should not add duplicate")

	# Test adding different badge
	var badge2 = Badge.new()
	badge2.badge_id = "test_badge_2"
	badge2.badge_name = "Test Badge 2"

	mechanic_state.add_temporary_badge(badge2)
	assert(mechanic_state.temporary_badges.size() == 2, "Should have 2 badges")

	# Test removing badge
	mechanic_state.remove_temporary_badge(badge1)
	assert(mechanic_state.temporary_badges.size() == 1, "Should have 1 badge after removal")

	# Test clearing all badges
	mechanic_state.clear_temporary_badges()
	assert(mechanic_state.temporary_badges.size() == 0, "Should have 0 badges after clear")

	print("  ✓ Badge system works correctly")
	print("  PASSED\n")

func test_pilot_mechanic_integration():
	print("TEST 5: Pilot-Mechanic integration...")

	# Load pilot resource
	var pilot_resource = load("res://resources/pilots/buoy.tres") as Pilot
	if pilot_resource == null:
		print("  ⚠ Warning: Could not load pilot resource, skipping test")
		print("  SKIPPED\n")
		return

	# Create pilot state
	var pilot_state = PilotState.new()
	pilot_state.setup_from_pilot_resource(pilot_resource, 1, "")

	# Setup default mechanic
	pilot_state.setup_default_mechanic()

	assert(pilot_state.mechanic_state != null, "Should have mechanic_state")
	assert(pilot_state.mechanic_state.mechanic_name == "Standard Pit Crew", "Should have default crew")
	assert(pilot_state.mechanic_state.build == 7, "Should have crew stats")

	print("  ✓ Pilot successfully integrated with mechanic")
	print("  ✓ Mechanic: %s (BUILD=%d, RIG=%d, COOL=%d)" % [
		pilot_state.mechanic_state.mechanic_name,
		pilot_state.mechanic_state.build,
		pilot_state.mechanic_state.rig,
		pilot_state.mechanic_state.cool
	])
	print("  PASSED\n")
