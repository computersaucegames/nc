extends Node

## Advanced test for fin badges in actual race simulation
## Tests that fin badges correctly apply to rolls during races

func _ready():
	print("\n=== FIN BADGES IN RACE SIMULATION TESTS ===\n")

	test_fin_badge_applies_to_movement_roll()
	test_fin_badge_applies_to_overtaking_roll()
	test_multiple_fin_badges()
	test_fin_badge_earning()
	test_negative_fin_badges_from_failures()

	print("\n=== ALL FIN RACE TESTS COMPLETE ===\n")

func test_fin_badge_applies_to_movement_roll():
	print("TEST 1: Fin badge applies to movement roll...")

	# Load resources
	var circuit = load("res://resources/circuits/test_tracks/test_alpha.tres")
	if circuit == null:
		print("  ⚠ Warning: Could not load test circuit, skipping test")
		print("  SKIPPED\n")
		return

	var pilot_resource = load("res://resources/pilots/buoy.tres")

	# Create fin with Lightweight Frame badge (+1 movement)
	var fin_resource = Fin.new()
	fin_resource.fin_name = "Test Fin"
	fin_resource.THRUST = 6
	fin_resource.FORM = 6
	fin_resource.RESPONSE = 6
	fin_resource.SYNC = 6

	var lightweight_badge = load("res://resources/badges/fins/lightweight_frame.tres")
	fin_resource.equipped_badges.append(lightweight_badge)

	# Setup pilot with fin
	var pilot_state = PilotState.new()
	pilot_state.setup_from_pilot_resource(pilot_resource, 1, "")
	pilot_state.setup_fin(fin_resource)

	# Create a sector to roll on
	var sector = circuit.sectors[0]

	# Create context for movement roll
	var context = {
		"roll_type": "movement",
		"sector": sector,
		"round": 1,
		"pilot": pilot_state
	}

	# Get modifiers from pilot badges
	var pilot_mods = BadgeSystem.get_active_modifiers(pilot_state, context)

	# Get modifiers from fin badges
	var fin_mods = BadgeSystem.get_active_modifiers_for_fin(pilot_state.fin_state, context)

	# Lightweight Frame should always trigger on movement rolls
	assert(fin_mods.size() >= 1, "Fin should have at least 1 modifier (Lightweight Frame)")

	var has_lightweight = false
	for mod in fin_mods:
		if mod.source == "Lightweight Frame":
			has_lightweight = true
			assert(mod.type == Dice.ModType.FLAT_BONUS, "Should be FLAT_BONUS")
			assert(mod.value == 1, "Should be +1")
			print("  ✓ Lightweight Frame badge active: +%d to movement" % mod.value)

	assert(has_lightweight, "Should have Lightweight Frame modifier")

	print("  ✓ Fin badge correctly applies to movement roll")
	print("  PASSED\n")

func test_fin_badge_applies_to_overtaking_roll():
	print("TEST 2: Fin badge applies to overtaking roll...")

	# Load resources
	var circuit = load("res://resources/circuits/test_tracks/test_alpha.tres")
	if circuit == null:
		print("  ⚠ Warning: Could not load test circuit, skipping test")
		print("  SKIPPED\n")
		return

	var pilot_resource = load("res://resources/pilots/buoy.tres")

	# Create fin with Overtuned Thrusters badge (+1 overtaking when attacking)
	var fin_resource = Fin.new()
	fin_resource.fin_name = "Test Fin"
	fin_resource.THRUST = 8
	fin_resource.FORM = 5
	fin_resource.RESPONSE = 6
	fin_resource.SYNC = 6

	var thrusters_badge = load("res://resources/badges/fins/overtuned_thrusters.tres")
	fin_resource.equipped_badges.append(thrusters_badge)

	# Setup pilot with fin
	var pilot_state = PilotState.new()
	pilot_state.setup_from_pilot_resource(pilot_resource, 1, "")
	pilot_state.setup_fin(fin_resource)

	# Set pilot as attacking
	pilot_state.is_attacking = true

	# Create a sector
	var sector = circuit.sectors[0]

	# Create context for overtaking roll
	var context = {
		"roll_type": "overtaking",
		"sector": sector,
		"pilot": pilot_state
	}

	# Get modifiers from fin badges
	var fin_mods = BadgeSystem.get_active_modifiers_for_fin(pilot_state.fin_state, context)

	# Overtuned Thrusters should trigger when attacking
	var has_thrusters = false
	for mod in fin_mods:
		if mod.source == "Overtuned Thrusters":
			has_thrusters = true
			assert(mod.type == Dice.ModType.FLAT_BONUS, "Should be FLAT_BONUS")
			assert(mod.value == 1, "Should be +1")
			print("  ✓ Overtuned Thrusters badge active: +%d to overtaking" % mod.value)

	assert(has_thrusters, "Should have Overtuned Thrusters modifier when attacking")

	# Test that it doesn't trigger when not attacking
	pilot_state.is_attacking = false
	fin_mods = BadgeSystem.get_active_modifiers_for_fin(pilot_state.fin_state, context)

	has_thrusters = false
	for mod in fin_mods:
		if mod.source == "Overtuned Thrusters":
			has_thrusters = true

	assert(not has_thrusters, "Should NOT have Overtuned Thrusters when not attacking")
	print("  ✓ Overtuned Thrusters correctly deactivates when not attacking")

	print("  PASSED\n")

func test_multiple_fin_badges():
	print("TEST 3: Multiple fin badges stack correctly...")

	# Load resources
	var circuit = load("res://resources/circuits/test_tracks/test_alpha.tres")
	if circuit == null:
		print("  ⚠ Warning: Could not load test circuit, skipping test")
		print("  SKIPPED\n")
		return

	var pilot_resource = load("res://resources/pilots/buoy.tres")

	# Create fin with multiple badges
	var fin_resource = Fin.new()
	fin_resource.fin_name = "Test Fin"
	fin_resource.THRUST = 7
	fin_resource.FORM = 6
	fin_resource.RESPONSE = 7
	fin_resource.SYNC = 6

	# Add Lightweight Frame (always on for movement)
	var lightweight_badge = load("res://resources/badges/fins/lightweight_frame.tres")
	fin_resource.equipped_badges.append(lightweight_badge)

	# Add Aerodynamic Shell (on when clear air)
	var aero_badge = load("res://resources/badges/fins/aerodynamic_shell.tres")
	fin_resource.equipped_badges.append(aero_badge)

	# Setup pilot with fin
	var pilot_state = PilotState.new()
	pilot_state.setup_from_pilot_resource(pilot_resource, 1, "")
	pilot_state.setup_fin(fin_resource)

	# Set pilot in clear air
	pilot_state.is_clear_air = true

	# Create context
	var sector = circuit.sectors[0]
	var context = {
		"roll_type": "movement",
		"sector": sector,
		"pilot": pilot_state
	}

	# Get modifiers
	var fin_mods = BadgeSystem.get_active_modifiers_for_fin(pilot_state.fin_state, context)

	# Should have both badges active
	assert(fin_mods.size() >= 2, "Should have at least 2 active fin badges")

	var total_bonus = 0
	for mod in fin_mods:
		if mod.type == Dice.ModType.FLAT_BONUS:
			total_bonus += mod.value
			print("  ✓ %s: +%d" % [mod.source, mod.value])

	assert(total_bonus >= 2, "Total bonus should be at least +2")
	print("  ✓ Multiple fin badges stack correctly: total +%d" % total_bonus)

	print("  PASSED\n")

func test_fin_badge_earning():
	print("TEST 4: Fins can earn badges during race...")

	# Create a fin
	var fin_resource = Fin.new()
	fin_resource.fin_name = "Test Fin"
	fin_resource.THRUST = 7
	fin_resource.FORM = 6
	fin_resource.RESPONSE = 7
	fin_resource.SYNC = 6

	var fin_state = FinState.new()
	fin_state.setup_from_fin_resource(fin_resource)

	# Create a sector with tags
	var sector = Sector.new()
	sector.sector_name = "Technical Section"
	sector.check_type = Sector.CheckType.CRAFT
	sector.sector_tags.append("technical")  # Use append for typed array
	sector.grey_threshold = 5
	sector.green_threshold = 10
	sector.purple_threshold = 15

	# Simulate GREEN result
	var roll_result = Dice.DiceResult.new()
	roll_result.final_total = 12  # GREEN tier
	roll_result.tier = Dice.Tier.GREEN

	# Track sector completion
	BadgeSystem.track_fin_sector_completion(fin_state, sector, roll_result)

	# Check that tracking worked
	var tag_state = fin_state.badge_states.get("sector_tag_technical", {})
	var green_count = tag_state.get("green_plus_count", 0)

	assert(green_count == 1, "Should have tracked 1 GREEN result")
	print("  ✓ Tracked GREEN result in technical sector")

	# Simulate another GREEN result
	BadgeSystem.track_fin_sector_completion(fin_state, sector, roll_result)

	tag_state = fin_state.badge_states.get("sector_tag_technical", {})
	green_count = tag_state.get("green_plus_count", 0)

	assert(green_count == 2, "Should have tracked 2 GREEN results")
	print("  ✓ Tracked multiple GREEN results: %d" % green_count)

	# Note: We can't easily test badge awarding without creating earnable badges
	# but the tracking mechanism works

	print("  PASSED\n")

func test_negative_fin_badges_from_failures():
	print("TEST 5: Fins receive negative badges from failures...")

	# Create a fin
	var fin_resource = Fin.new()
	fin_resource.fin_name = "Test Fin"
	fin_resource.THRUST = 6
	fin_resource.FORM = 6
	fin_resource.RESPONSE = 6
	fin_resource.SYNC = 6

	var fin_state = FinState.new()
	fin_state.setup_from_fin_resource(fin_resource)

	# Test applying negative badge (GREEN tier - base badge)
	var badge_applied = FailureTableResolver.apply_badge_based_on_tier_to_fin(fin_state, "rattled", Dice.Tier.GREEN)
	assert(badge_applied, "Should successfully apply rattled badge to fin")
	assert(fin_state.temporary_badges.size() == 1, "Fin should have 1 temporary badge")
	assert(fin_state.temporary_badges[0].badge_id == "rattled", "Badge should be 'rattled'")
	print("  ✓ GREEN tier failure applies base negative badge to fin")

	# Test applying severe badge (GREY tier)
	var fin_state2 = FinState.new()
	fin_state2.setup_from_fin_resource(fin_resource)

	var severe_applied = FailureTableResolver.apply_badge_based_on_tier_to_fin(fin_state2, "rattled", Dice.Tier.GREY)
	assert(severe_applied, "Should successfully apply rattled_severe badge to fin")
	assert(fin_state2.temporary_badges.size() == 1, "Fin should have 1 temporary badge")
	assert(fin_state2.temporary_badges[0].badge_id == "rattled_severe", "Badge should be 'rattled_severe'")
	print("  ✓ GREY tier failure applies severe negative badge to fin")

	# Test that PURPLE doesn't apply badge
	var fin_state3 = FinState.new()
	fin_state3.setup_from_fin_resource(fin_resource)

	var purple_applied = FailureTableResolver.apply_badge_based_on_tier_to_fin(fin_state3, "rattled", Dice.Tier.PURPLE)
	assert(not purple_applied, "PURPLE tier should not apply badge")
	assert(fin_state3.temporary_badges.size() == 0, "Fin should have 0 temporary badges")
	print("  ✓ PURPLE tier failure does not apply badge to fin")

	# Test that badges don't duplicate
	badge_applied = FailureTableResolver.apply_badge_based_on_tier_to_fin(fin_state, "rattled", Dice.Tier.GREEN)
	assert(not badge_applied, "Should not apply duplicate badge")
	assert(fin_state.temporary_badges.size() == 1, "Fin should still have only 1 temporary badge")
	print("  ✓ Duplicate badges are prevented")

	# Test that negative badges apply modifiers
	var circuit = load("res://resources/circuits/test_tracks/test_alpha.tres")
	if circuit != null:
		var pilot_resource = load("res://resources/pilots/buoy.tres")
		var pilot_state = PilotState.new()
		pilot_state.setup_from_pilot_resource(pilot_resource, 1, "")
		pilot_state.setup_fin(fin_resource)
		pilot_state.fin = fin_state  # Use the fin_state with rattled badge

		var sector = circuit.sectors[0]
		var context = {
			"roll_type": "movement",
			"sector": sector,
			"pilot": pilot_state
		}

		# Get modifiers from fin badges
		var fin_mods = BadgeSystem.get_active_modifiers_for_fin(fin_state, context)

		# Rattled should apply -1 penalty
		var has_rattled = false
		for mod in fin_mods:
			if mod.source == "Rattled":
				has_rattled = true
				assert(mod.type == Dice.ModType.FLAT_PENALTY, "Should be FLAT_PENALTY")
				assert(mod.value == 1, "Should be -1 penalty")
				print("  ✓ Rattled badge applies -%d penalty to fin rolls" % mod.value)

		assert(has_rattled, "Should have Rattled modifier active")

	print("  PASSED\n")
