class_name BadgeSystem
extends RefCounted

## Badge System
## Central system for evaluating badge conditions and applying badge effects
## Used by RaceSimulator, OvertakeResolver, and other game systems

## Helper to get all badges (equipped + temporary) for a pilot
static func _get_all_badges(pilot_state) -> Array:
	var all_badges = []

	# Get equipped badges from pilot resource
	if pilot_state.pilot_data:
		if pilot_state.pilot_data is Pilot:
			all_badges.append_array(pilot_state.pilot_data.equipped_badges)
		elif pilot_state.pilot_data is Dictionary:
			all_badges.append_array(pilot_state.pilot_data.get("equipped_badges", []))

	# Add temporary badges (negative badges earned during race)
	all_badges.append_array(pilot_state.temporary_badges)

	return all_badges

## Get all active modifiers from a pilot's equipped badges and temporary badges
## Returns an array of RollModifiers that should be applied to this roll
static func get_active_modifiers(pilot_state, context: Dictionary) -> Array:
	var modifiers = []

	# Get all badges (equipped + temporary)
	var all_badges = _get_all_badges(pilot_state)
	if all_badges.is_empty():
		return modifiers

	# Check each badge to see if it should activate
	for badge in all_badges:
		if badge == null:
			continue

		if badge.should_activate(pilot_state, context):
			var modifier = badge.create_modifier()
			modifiers.append(modifier)

	return modifiers

## Get active badge info for logging/display
## Returns array of {name: String, description: String, modifier_type: String}
static func get_active_badges_info(pilot_state, context: Dictionary) -> Array:
	var active_badges = []

	# Get all badges (equipped + temporary)
	var all_badges = _get_all_badges(pilot_state)
	if all_badges.is_empty():
		return active_badges

	# Check each badge to see if it should activate
	for badge in all_badges:
		if badge == null:
			continue

		if badge.should_activate(pilot_state, context):
			var modifier_desc = _get_modifier_description(badge.modifier_type, badge.modifier_value)
			active_badges.append({
				"name": badge.badge_name,
				"description": badge.description,
				"effect": modifier_desc
			})

	return active_badges

## Helper to describe modifier type for display
static func _get_modifier_description(mod_type: Dice.ModType, value: int) -> String:
	match mod_type:
		Dice.ModType.FLAT_BONUS:
			return "+%d bonus" % value
		Dice.ModType.ADVANTAGE:
			return "Advantage (roll twice, take best)"
		Dice.ModType.DISADVANTAGE:
			return "Disadvantage (roll twice, take worst)"
		Dice.ModType.REROLL_ONES:
			return "Reroll 1s"
		Dice.ModType.TIER_SHIFT:
			return "Shift result %d tier" % value
		_:
			return "Special effect"

## Update badge states for all pilots after status calculation
## Call this each round after StatusCalculator runs
static func update_all_badge_states(pilots: Array) -> void:
	for pilot_state in pilots:
		update_pilot_badge_states(pilot_state)

## Update badge states for a single pilot
static func update_pilot_badge_states(pilot_state) -> void:
	# Get all badges (equipped + temporary)
	var all_badges = _get_all_badges(pilot_state)
	if all_badges.is_empty():
		return

	# Update each badge's state tracking
	for badge in all_badges:
		if badge == null:
			continue
		badge.update_state(pilot_state)

## Reset badge states for a pilot (e.g., at race start)
static func reset_pilot_badge_states(pilot_state) -> void:
	pilot_state.badge_states.clear()

## Reset badge states for all pilots (e.g., at race start)
static func reset_all_badge_states(pilots: Array) -> void:
	for pilot_state in pilots:
		reset_pilot_badge_states(pilot_state)

## Debug: Get all active badges for a pilot with their current state
static func get_active_badges_debug(pilot_state, context: Dictionary) -> String:
	var debug_text = "Active badges for %s:\n" % pilot_state.name

	# Get all badges (equipped + temporary)
	var all_badges = _get_all_badges(pilot_state)
	if all_badges.is_empty():
		return debug_text + "  No badges\n"

	for badge in all_badges:
		if badge == null:
			continue

		var is_active = badge.should_activate(pilot_state, context)
		var badge_type = " (TEMP)" if badge in pilot_state.temporary_badges else ""
		debug_text += "  [%s] %s%s: %s\n" % [
			"ACTIVE" if is_active else "INACTIVE",
			badge.badge_name,
			badge_type,
			badge.description
		]

		# Show state if badge tracks state
		if badge.state_property != "":
			var badge_state = pilot_state.badge_states.get(badge.badge_id, {})
			var state_value = badge_state.get(badge.state_property, 0)
			debug_text += "    State: %s = %d (requires %d)\n" % [
				badge.state_property,
				state_value,
				badge.requires_consecutive_rounds
			]

	return debug_text

## Track sector completion for badge earning
## Call this when a sector is completed with the roll result
static func track_sector_completion(pilot_state, sector: Sector, roll_result: Dice.DiceResult) -> void:
	# Get the result tier
	var result_tier = sector.get_result_type(roll_result.final_total)

	# Check each sector tag on this sector
	for tag in sector.sector_tags:
		var tag_key = "sector_tag_%s" % tag

		# Initialize tracking dictionary for this tag if needed
		if not pilot_state.badge_states.has(tag_key):
			pilot_state.badge_states[tag_key] = {
				"green_plus_count": 0,
				"purple_count": 0
			}

		var tag_state = pilot_state.badge_states[tag_key]

		# Increment counters based on result
		if result_tier == "PURPLE":
			tag_state["purple_count"] += 1
			tag_state["green_plus_count"] += 1  # Purple counts as green+
		elif result_tier == "GREEN":
			tag_state["green_plus_count"] += 1

## Check if any badges should be awarded based on sector performance
## Returns array of badge resources that were earned
static func check_and_award_sector_badges(pilot_state, available_badges: Array[Badge]) -> Array[Badge]:
	var earned_badges: Array[Badge] = []

	for badge in available_badges:
		if badge == null:
			continue

		# Skip if this badge doesn't track sector tags
		if badge.earned_by_sector_tag == "":
			continue

		# Skip if pilot already has this badge (equipped or temporary)
		if _pilot_has_badge(pilot_state, badge):
			continue

		# Check if requirements are met
		var tag_key = "sector_tag_%s" % badge.earned_by_sector_tag
		var tag_state = pilot_state.badge_states.get(tag_key, {})

		var green_plus_count = tag_state.get("green_plus_count", 0)
		var purple_count = tag_state.get("purple_count", 0)

		var green_requirement_met = (badge.requires_green_plus_count == 0 or green_plus_count >= badge.requires_green_plus_count)
		var purple_requirement_met = (badge.requires_purple_count == 0 or purple_count >= badge.requires_purple_count)

		if green_requirement_met and purple_requirement_met:
			# Award the badge!
			pilot_state.temporary_badges.append(badge)
			earned_badges.append(badge)

	return earned_badges

## Check if pilot already has a badge (equipped or temporary)
static func _pilot_has_badge(pilot_state, badge: Badge) -> bool:
	# Check temporary badges
	for temp_badge in pilot_state.temporary_badges:
		if temp_badge == badge or temp_badge.badge_id == badge.badge_id:
			return true

	# Check equipped badges
	if pilot_state.pilot_data:
		if pilot_state.pilot_data is Pilot:
			for equipped_badge in pilot_state.pilot_data.equipped_badges:
				if equipped_badge == badge or equipped_badge.badge_id == badge.badge_id:
					return true

	return false

## ====== FIN BADGE SYSTEM FUNCTIONS ======

## Helper to get all badges (equipped + temporary) for a fin
static func _get_all_fin_badges(fin_state: FinState) -> Array:
	var all_badges = []

	if fin_state == null or fin_state.fin_data == null:
		return all_badges

	# Get equipped badges from fin resource
	all_badges.append_array(fin_state.fin_data.equipped_badges)

	# Add temporary badges (badges earned during race)
	all_badges.append_array(fin_state.temporary_badges)

	return all_badges

## Get all active modifiers from a fin's equipped badges and temporary badges
## Returns an array of RollModifiers that should be applied to this roll
static func get_active_modifiers_for_fin(fin_state: FinState, context: Dictionary) -> Array:
	var modifiers = []

	if fin_state == null:
		return modifiers

	# Get all badges (equipped + temporary)
	var all_badges = _get_all_fin_badges(fin_state)
	if all_badges.is_empty():
		return modifiers

	# Check each badge to see if it should activate
	for badge in all_badges:
		if badge == null:
			continue

		# For fin badges, we need to pass the pilot_state from context
		# since badges check pilot status (attacking, defending, etc.)
		var pilot_state = context.get("pilot", null)
		if pilot_state == null:
			continue

		if badge.should_activate(pilot_state, context):
			var modifier = badge.create_modifier()
			modifiers.append(modifier)

	return modifiers

## Update badge states for a single fin
static func update_fin_badge_states(fin_state: FinState, pilot_state) -> void:
	if fin_state == null:
		return

	# Get all badges (equipped + temporary)
	var all_badges = _get_all_fin_badges(fin_state)
	if all_badges.is_empty():
		return

	# Update each badge's state tracking
	for badge in all_badges:
		if badge == null:
			continue
		badge.update_state(pilot_state)

## Reset badge states for a fin (e.g., at race start)
static func reset_fin_badge_states(fin_state: FinState) -> void:
	if fin_state == null:
		return
	fin_state.badge_states.clear()

## Track sector completion for fin badge earning
static func track_fin_sector_completion(fin_state: FinState, sector: Sector, roll_result: Dice.DiceResult) -> void:
	if fin_state == null:
		return

	# Get the result tier
	var result_tier = sector.get_result_type(roll_result.final_total)

	# Check each sector tag on this sector
	for tag in sector.sector_tags:
		var tag_key = "sector_tag_%s" % tag

		# Initialize tracking dictionary for this tag if needed
		if not fin_state.badge_states.has(tag_key):
			fin_state.badge_states[tag_key] = {
				"green_plus_count": 0,
				"purple_count": 0
			}

		var tag_state = fin_state.badge_states[tag_key]

		# Increment counters based on result
		if result_tier == "PURPLE":
			tag_state["purple_count"] += 1
			tag_state["green_plus_count"] += 1  # Purple counts as green+
		elif result_tier == "GREEN":
			tag_state["green_plus_count"] += 1

## Check if any fin badges should be awarded based on sector performance
## Returns array of badge resources that were earned
static func check_and_award_fin_sector_badges(fin_state: FinState, available_badges: Array[Badge]) -> Array[Badge]:
	if fin_state == null:
		return []

	var earned_badges: Array[Badge] = []

	for badge in available_badges:
		if badge == null:
			continue

		# Skip if this badge doesn't track sector tags
		if badge.earned_by_sector_tag == "":
			continue

		# Skip if fin already has this badge (equipped or temporary)
		if _fin_has_badge(fin_state, badge):
			continue

		# Check if requirements are met
		var tag_key = "sector_tag_%s" % badge.earned_by_sector_tag
		var tag_state = fin_state.badge_states.get(tag_key, {})

		var green_plus_count = tag_state.get("green_plus_count", 0)
		var purple_count = tag_state.get("purple_count", 0)

		var green_requirement_met = (badge.requires_green_plus_count == 0 or green_plus_count >= badge.requires_green_plus_count)
		var purple_requirement_met = (badge.requires_purple_count == 0 or purple_count >= badge.requires_purple_count)

		if green_requirement_met and purple_requirement_met:
			# Award the badge!
			fin_state.add_temporary_badge(badge)
			earned_badges.append(badge)

	return earned_badges

## Check if fin already has a badge (equipped or temporary)
static func _fin_has_badge(fin_state: FinState, badge: Badge) -> bool:
	if fin_state == null:
		return false

	# Check temporary badges
	for temp_badge in fin_state.temporary_badges:
		if temp_badge == badge or temp_badge.badge_id == badge.badge_id:
			return true

	# Check equipped badges
	if fin_state.fin_data:
		for equipped_badge in fin_state.fin_data.equipped_badges:
			if equipped_badge == badge or equipped_badge.badge_id == badge.badge_id:
				return true

	return false
