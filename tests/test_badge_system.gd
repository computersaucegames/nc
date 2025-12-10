extends Node

## Simple test script for Badge System
## Run this in Godot to verify badges work correctly

func _ready():
	print("\n=== BADGE SYSTEM TESTS ===\n")

	test_badge_loading()
	test_badge_activation()
	test_badge_state_tracking()
	test_badge_modifiers()

	print("\n=== ALL TESTS COMPLETE ===\n")

func test_badge_loading():
	print("TEST 1: Loading badge resources...")

	var intimidator = load("res://resources/badges/intimidator.tres")
	var start_expert = load("res://resources/badges/start_expert.tres")
	var clear_air = load("res://resources/badges/clear_air_specialist.tres")

	assert(intimidator != null, "Intimidator badge should load")
	assert(start_expert != null, "Start Expert badge should load")
	assert(clear_air != null, "Clear Air Specialist badge should load")

	print("  ✓ Intimidator: %s" % intimidator.badge_name)
	print("  ✓ Start Expert: %s" % start_expert.badge_name)
	print("  ✓ Clear Air Specialist: %s" % clear_air.badge_name)
	print("  PASSED\n")

func test_badge_activation():
	print("TEST 2: Badge activation conditions...")

	var clear_air = load("res://resources/badges/clear_air_specialist.tres")
	var pilot = PilotState.new()
	pilot.name = "Test Pilot"
	pilot.is_clear_air = true

	var context = {
		"roll_type": "movement",
		"sector": null
	}

	var should_activate = clear_air.should_activate(pilot, context)
	assert(should_activate, "Clear Air badge should activate when pilot is in clear air")
	print("  ✓ Clear Air Specialist activates when in clear air")

	pilot.is_clear_air = false
	should_activate = clear_air.should_activate(pilot, context)
	assert(not should_activate, "Clear Air badge should NOT activate when pilot is not in clear air")
	print("  ✓ Clear Air Specialist does not activate when not in clear air")
	print("  PASSED\n")

func test_badge_state_tracking():
	print("TEST 3: Badge state tracking...")

	var intimidator = load("res://resources/badges/intimidator.tres")
	var pilot = PilotState.new()
	pilot.name = "Test Pilot"
	pilot.is_attacking = true
	pilot.badge_states = {}

	# Update state 3 times (should reach threshold)
	for i in range(3):
		intimidator.update_state(pilot)

	var badge_state = pilot.badge_states.get("intimidator", {})
	var count = badge_state.get("consecutive_attacking_rounds", 0)
	assert(count == 3, "Should track 3 consecutive attacking rounds")
	print("  ✓ Tracked %d consecutive attacking rounds" % count)

	# Test activation with state
	var context = {
		"roll_type": "overtaking",
		"sector": null
	}
	var should_activate = intimidator.should_activate(pilot, context)
	assert(should_activate, "Intimidator should activate after 3 rounds")
	print("  ✓ Intimidator activates after 3 consecutive attacking rounds")

	# Test reset when not attacking
	pilot.is_attacking = false
	intimidator.update_state(pilot)
	badge_state = pilot.badge_states.get("intimidator", {})
	count = badge_state.get("consecutive_attacking_rounds", 0)
	assert(count == 0, "Should reset when not attacking")
	print("  ✓ State resets when condition no longer met")
	print("  PASSED\n")

func test_badge_modifiers():
	print("TEST 4: Badge modifiers...")

	var clear_air = load("res://resources/badges/clear_air_specialist.tres")
	var pilot = PilotState.new()
	pilot.name = "Test Pilot"
	pilot.is_clear_air = true
	pilot.badge_states = {}

	# Create a mock pilot resource with the badge
	var pilot_resource = Pilot.new()
	pilot_resource.pilot_name = "Test Pilot"
	# Use append for typed arrays in Godot 4
	pilot_resource.equipped_badges.append(clear_air)
	pilot.pilot_data = pilot_resource

	var context = {
		"roll_type": "movement",
		"sector": null
	}

	var modifiers = BadgeSystem.get_active_modifiers(pilot, context)
	assert(modifiers.size() == 1, "Should return 1 modifier")
	print("  ✓ BadgeSystem returned %d modifier(s)" % modifiers.size())

	var modifier = modifiers[0]
	assert(modifier.type == Dice.ModType.FLAT_BONUS, "Should be FLAT_BONUS type")
	assert(modifier.value == 1, "Should be +1 bonus")
	assert(modifier.source == "Clear Air Specialist", "Source should be badge name")
	print("  ✓ Modifier: +%d from '%s'" % [modifier.value, modifier.source])
	print("  PASSED\n")
