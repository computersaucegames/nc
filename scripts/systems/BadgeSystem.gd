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
