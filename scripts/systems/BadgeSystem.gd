class_name BadgeSystem
extends RefCounted

## Badge System
## Central system for evaluating badge conditions and applying badge effects
## Used by RaceSimulator, OvertakeResolver, and other game systems

## Get all active modifiers from a pilot's equipped badges
## Returns an array of RollModifiers that should be applied to this roll
static func get_active_modifiers(pilot_state, context: Dictionary) -> Array:
	var modifiers = []

	# Get the pilot's equipped badges
	if not pilot_state.pilot_data:
		return modifiers

	var equipped_badges = pilot_state.pilot_data.get("equipped_badges", [])
	if equipped_badges.is_empty():
		return modifiers

	# Check each badge to see if it should activate
	for badge in equipped_badges:
		if badge == null:
			continue

		if badge.should_activate(pilot_state, context):
			var modifier = badge.create_modifier()
			modifiers.append(modifier)

	return modifiers

## Update badge states for all pilots after status calculation
## Call this each round after StatusCalculator runs
static func update_all_badge_states(pilots: Array) -> void:
	for pilot_state in pilots:
		update_pilot_badge_states(pilot_state)

## Update badge states for a single pilot
static func update_pilot_badge_states(pilot_state) -> void:
	# Get the pilot's equipped badges
	if not pilot_state.pilot_data:
		return

	var equipped_badges = pilot_state.pilot_data.get("equipped_badges", [])
	if equipped_badges.is_empty():
		return

	# Update each badge's state tracking
	for badge in equipped_badges:
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

	if not pilot_state.pilot_data:
		return debug_text + "  No pilot data\n"

	var equipped_badges = pilot_state.pilot_data.get("equipped_badges", [])
	if equipped_badges.is_empty():
		return debug_text + "  No equipped badges\n"

	for badge in equipped_badges:
		if badge == null:
			continue

		var is_active = badge.should_activate(pilot_state, context)
		debug_text += "  [%s] %s: %s\n" % [
			"ACTIVE" if is_active else "INACTIVE",
			badge.badge_name,
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
