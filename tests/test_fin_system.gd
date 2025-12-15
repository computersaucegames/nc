extends Node

## Comprehensive test script for Fin System
## Run this in Godot to verify fins and fin badges work correctly

func _ready():
	print("\n=== FIN SYSTEM TESTS ===\n")

	test_fin_loading()
	test_fin_state_creation()
	test_fin_assignment_to_pilot()
	test_fin_badge_loading()
	test_fin_badge_activation()
	test_fin_badge_modifiers()
	test_combined_pilot_and_fin_badges()
	test_race_integration()

	print("\n=== ALL FIN TESTS COMPLETE ===\n")

func test_fin_loading():
	print("TEST 1: Loading fin resources...")

	var interceptor = load("res://resources/fins/interceptor_mk7.tres")
	var bulwark = load("res://resources/fins/bulwark.tres")
	var equilibrium = load("res://resources/fins/equilibrium.tres")
	var scalpel = load("res://resources/fins/scalpel.tres")
	var thunderbolt = load("res://resources/fins/thunderbolt.tres")

	assert(interceptor != null, "Interceptor MK-VII should load")
	assert(bulwark != null, "Bulwark should load")
	assert(equilibrium != null, "Equilibrium should load")
	assert(scalpel != null, "Scalpel should load")
	assert(thunderbolt != null, "Thunderbolt should load")

	print("  ✓ Interceptor MK-VII: THRUST:%d, FORM:%d, RESPONSE:%d, SYNC:%d" %
		[interceptor.THRUST, interceptor.FORM, interceptor.RESPONSE, interceptor.SYNC])
	print("  ✓ Bulwark: THRUST:%d, FORM:%d, RESPONSE:%d, SYNC:%d" %
		[bulwark.THRUST, bulwark.FORM, bulwark.RESPONSE, bulwark.SYNC])
	print("  ✓ Equilibrium: THRUST:%d, FORM:%d, RESPONSE:%d, SYNC:%d" %
		[equilibrium.THRUST, equilibrium.FORM, equilibrium.RESPONSE, equilibrium.SYNC])

	# Verify stat ranges (should all be 1-8)
	assert(interceptor.THRUST >= 1 and interceptor.THRUST <= 8, "THRUST should be 1-8")
	assert(bulwark.FORM >= 1 and bulwark.FORM <= 8, "FORM should be 1-8")

	print("  PASSED\n")

func test_fin_state_creation():
	print("TEST 2: Creating FinState...")

	var fin_resource = load("res://resources/fins/interceptor_mk7.tres")
	var fin_state = FinState.new()
	fin_state.setup_from_fin_resource(fin_resource)

	assert(fin_state.fin_data != null, "FinState should have fin_data")
	assert(fin_state.fin_data == fin_resource, "FinState should reference the fin resource")

	# Test stat access
	var thrust = fin_state.get_stat("THRUST")
	var form = fin_state.get_stat("FORM")
	var response = fin_state.get_stat("RESPONSE")

	assert(thrust == fin_resource.THRUST, "get_stat('THRUST') should return correct value")
	assert(form == fin_resource.FORM, "get_stat('FORM') should return correct value")
	assert(response == fin_resource.RESPONSE, "get_stat('RESPONSE') should return correct value")

	print("  ✓ FinState created successfully")
	print("  ✓ Stat access working: THRUST=%d, FORM=%d, RESPONSE=%d" % [thrust, form, response])
	print("  PASSED\n")

func test_fin_assignment_to_pilot():
	print("TEST 3: Assigning fin to pilot...")

	var pilot_resource = load("res://resources/pilots/buoy.tres")
	var fin_resource = load("res://resources/fins/thunderbolt.tres")

	var pilot_state = PilotState.new()
	pilot_state.setup_from_pilot_resource(pilot_resource)

	# Assign fin
	pilot_state.setup_fin(fin_resource)

	assert(pilot_state.fin_state != null, "Pilot should have fin_state")
	assert(pilot_state.fin_state.fin_data == fin_resource, "Pilot's fin should be the assigned fin")

	print("  ✓ Pilot '%s' assigned fin '%s'" % [pilot_state.name, fin_resource.fin_name])
	print("  ✓ Fin THRUST: %d" % pilot_state.fin_state.get_stat("THRUST"))
	print("  PASSED\n")

func test_fin_badge_loading():
	print("TEST 4: Loading fin badge resources...")

	var reinforced_hull = load("res://resources/badges/fins/reinforced_hull.tres")
	var aerodynamic_shell = load("res://resources/badges/fins/aerodynamic_shell.tres")
	var overtuned_thrusters = load("res://resources/badges/fins/overtuned_thrusters.tres")
	var precision_calibration = load("res://resources/badges/fins/precision_calibration.tres")

	assert(reinforced_hull != null, "Reinforced Hull badge should load")
	assert(aerodynamic_shell != null, "Aerodynamic Shell badge should load")
	assert(overtuned_thrusters != null, "Overtuned Thrusters badge should load")
	assert(precision_calibration != null, "Precision Calibration badge should load")

	print("  ✓ Reinforced Hull: %s" % reinforced_hull.badge_name)
	print("  ✓ Aerodynamic Shell: %s" % aerodynamic_shell.badge_name)
	print("  ✓ Overtuned Thrusters: %s" % overtuned_thrusters.badge_name)
	print("  ✓ Precision Calibration: %s" % precision_calibration.badge_name)
	print("  PASSED\n")

func test_fin_badge_activation():
	print("TEST 5: Fin badge activation conditions...")

	var aerodynamic_shell = load("res://resources/badges/fins/aerodynamic_shell.tres")

	# Create pilot and fin
	var pilot_state = PilotState.new()
	pilot_state.name = "Test Pilot"
	pilot_state.is_clear_air = true

	var fin_resource = Fin.new()
	fin_resource.fin_name = "Test Fin"
	fin_resource.equipped_badges.append(aerodynamic_shell)

	var fin_state = FinState.new()
	fin_state.setup_from_fin_resource(fin_resource)

	# Create context
	var context = {
		"roll_type": "movement",
		"sector": null,
		"pilot": pilot_state
	}

	# Test activation
	var should_activate = aerodynamic_shell.should_activate(pilot_state, context)
	assert(should_activate, "Aerodynamic Shell should activate in clear air")
	print("  ✓ Aerodynamic Shell activates when pilot is in clear air")

	# Test deactivation
	pilot_state.is_clear_air = false
	should_activate = aerodynamic_shell.should_activate(pilot_state, context)
	assert(not should_activate, "Aerodynamic Shell should NOT activate when not in clear air")
	print("  ✓ Aerodynamic Shell does not activate when not in clear air")
	print("  PASSED\n")

func test_fin_badge_modifiers():
	print("TEST 6: Fin badge modifiers...")

	var aerodynamic_shell = load("res://resources/badges/fins/aerodynamic_shell.tres")

	# Create pilot
	var pilot_state = PilotState.new()
	pilot_state.name = "Test Pilot"
	pilot_state.is_clear_air = true

	# Create fin with badge
	var fin_resource = Fin.new()
	fin_resource.fin_name = "Test Fin"
	fin_resource.equipped_badges.append(aerodynamic_shell)

	var fin_state = FinState.new()
	fin_state.setup_from_fin_resource(fin_resource)

	# Get modifiers
	var context = {
		"roll_type": "movement",
		"sector": null,
		"pilot": pilot_state
	}

	var modifiers = BadgeSystem.get_active_modifiers_for_fin(fin_state, context)
	assert(modifiers.size() == 1, "Should return 1 modifier from fin badge")
	print("  ✓ BadgeSystem returned %d fin modifier(s)" % modifiers.size())

	var modifier = modifiers[0]
	assert(modifier.type == Dice.ModType.FLAT_BONUS, "Should be FLAT_BONUS type")
	assert(modifier.value == 1, "Should be +1 bonus")
	assert(modifier.source == "Aerodynamic Shell", "Source should be badge name")
	print("  ✓ Fin Modifier: +%d from '%s'" % [modifier.value, modifier.source])
	print("  PASSED\n")

func test_combined_pilot_and_fin_badges():
	print("TEST 7: Combined pilot + fin badge modifiers...")

	# Load badges
	var pilot_badge = load("res://resources/badges/clear_air_specialist.tres")
	var fin_badge = load("res://resources/badges/fins/aerodynamic_shell.tres")

	# Create pilot with badge
	var pilot_resource = Pilot.new()
	pilot_resource.pilot_name = "Test Pilot"
	pilot_resource.equipped_badges.append(pilot_badge)

	var pilot_state = PilotState.new()
	pilot_state.pilot_data = pilot_resource
	pilot_state.name = "Test Pilot"
	pilot_state.is_clear_air = true

	# Create fin with badge
	var fin_resource = Fin.new()
	fin_resource.fin_name = "Test Fin"
	fin_resource.equipped_badges.append(fin_badge)

	var fin_state = FinState.new()
	fin_state.setup_from_fin_resource(fin_resource)

	pilot_state.fin_state = fin_state

	# Get modifiers
	var context = {
		"roll_type": "movement",
		"sector": null,
		"pilot": pilot_state
	}

	var pilot_mods = BadgeSystem.get_active_modifiers(pilot_state, context)
	var fin_mods = BadgeSystem.get_active_modifiers_for_fin(fin_state, context)

	assert(pilot_mods.size() == 1, "Should get 1 pilot modifier")
	assert(fin_mods.size() == 1, "Should get 1 fin modifier")

	print("  ✓ Pilot badge active: %s (+%d)" % [pilot_mods[0].source, pilot_mods[0].value])
	print("  ✓ Fin badge active: %s (+%d)" % [fin_mods[0].source, fin_mods[0].value])
	print("  ✓ Total bonus: +%d" % (pilot_mods[0].value + fin_mods[0].value))
	print("  PASSED\n")

func test_race_integration():
	print("TEST 8: Race integration with fins...")

	# Load resources
	var pilot_resource = load("res://resources/pilots/buoy.tres")
	var fin_resource = load("res://resources/fins/interceptor_mk7.tres")

	# Create pilot list with fin assignment (new format)
	var pilot_list = [
		{
			"pilot": pilot_resource,
			"headshot": "",
			"fin": fin_resource
		}
	]

	# Load a test circuit
	var circuit = load("res://resources/circuits/test_tracks/test_alpha.tres")

	if circuit == null:
		print("  ⚠ Warning: Could not load test circuit, skipping race integration test")
		print("  SKIPPED\n")
		return

	# Create race simulator
	var race_sim = RaceSimulator.new()
	add_child(race_sim)

	# Start race
	race_sim.start_race(circuit, pilot_list)

	# Verify pilot has fin assigned
	assert(race_sim.pilots.size() == 1, "Should have 1 pilot")
	var pilot = race_sim.pilots[0]
	assert(pilot.fin_state != null, "Pilot should have fin assigned")
	assert(pilot.fin_state.fin_data == fin_resource, "Pilot should have correct fin")

	print("  ✓ Race initialized with fin-equipped pilot")
	print("  ✓ Pilot '%s' racing with '%s'" % [pilot.name, pilot.fin_state.fin_data.fin_name])

	# Clean up
	race_sim.queue_free()

	print("  PASSED\n")
