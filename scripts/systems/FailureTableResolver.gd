# FailureTableResolver.gd
# Handles rolling on sector failure tables when a pilot gets a red result
extends RefCounted
class_name FailureTableResolver

# Roll on a failure table and get the consequence
static func resolve_failure(pilot, sector: Sector) -> Dictionary:
	# Get the failure consequence from the sector's table
	var consequence_text = sector.get_random_failure_consequence()

	# Parse the consequence to extract penalty and badge reference
	var penalty = parse_consequence_penalty(consequence_text)
	var badge_id = parse_consequence_badge(consequence_text)

	# Make a roll for the failure table (using the sector's failure table check type)
	var stat_value = pilot.get_stat(sector.failure_table_check_type)
	var check_name = _get_check_type_string(sector.failure_table_check_type)

	# Use same gates as the sector
	var gates = {
		"grey": sector.grey_threshold,
		"green": sector.green_threshold,
		"purple": sector.purple_threshold
	}

	var roll_result = Dice.roll_d20(stat_value, check_name, [], gates, {
		"pilot": pilot,
		"sector": sector,
		"context": "failure_table"
	})

	return {
		"consequence_text": consequence_text,
		"roll_result": roll_result,
		"description": consequence_text,
		"penalty_gaps": penalty,
		"badge_id": badge_id
	}

# Parse consequence text to extract gap penalty
# Examples:
#   "Lock brakes - lose 1 Gap" → 1
#   "Miss apex - lose 2 Gap" → 2
#   "Scrub speed - no penalty" → 0
static func parse_consequence_penalty(text: String) -> int:
	var lower_text = text.to_lower()

	# Check for "no penalty" pattern
	if "no penalty" in lower_text:
		return 0

	# Check for "lose X gap" pattern
	var regex = RegEx.new()
	regex.compile("lose\\s+(\\d+)\\s+gap")
	var result = regex.search(lower_text)

	if result:
		return result.get_string(1).to_int()

	# Default to 0 if no penalty found
	return 0

# Parse consequence text to extract badge reference
# Examples:
#   "Lock brakes - lose 2 Gap [badge:shaky_brakes]" → "shaky_brakes"
#   "Spin out - lose 1 Gap [badge:rattled]" → "rattled"
#   "Wide line - no penalty" → ""
static func parse_consequence_badge(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[badge:([a-z_]+)\\]")
	var result = regex.search(text)

	if result:
		return result.get_string(1)

	return ""

# Load a badge resource by badge_id
# Returns null if not found
static func load_badge(badge_id: String) -> Badge:
	if badge_id == "":
		return null

	# Try loading from negative badges directory first
	var negative_path = "res://resources/badges/negative/%s.tres" % badge_id
	if ResourceLoader.exists(negative_path):
		return load(negative_path) as Badge

	# Fall back to main badges directory
	var main_path = "res://resources/badges/%s.tres" % badge_id
	if ResourceLoader.exists(main_path):
		return load(main_path) as Badge

	push_error("Badge not found: %s" % badge_id)
	return null

# Apply a negative badge to a pilot based on failure roll tier
# - PURPLE: no badge
# - GREEN: base badge (-1)
# - GREY: severe badge (-2)
# - RED: will be crash (handled separately)
static func apply_badge_based_on_tier(pilot_state, base_badge_id: String, tier: Dice.Tier) -> bool:
	if base_badge_id == "":
		return false

	# Determine which badge to apply based on tier
	var badge_id_to_apply = ""
	match tier:
		Dice.Tier.PURPLE:
			# No badge on purple - they saved well
			return false
		Dice.Tier.GREEN:
			# Apply base badge (-1)
			badge_id_to_apply = base_badge_id
		Dice.Tier.GREY:
			# Apply severe badge (-2)
			badge_id_to_apply = base_badge_id + "_severe"
		Dice.Tier.RED:
			# RED will be crash - handle separately
			# For now, apply severe badge
			badge_id_to_apply = base_badge_id + "_severe"

	if badge_id_to_apply == "":
		return false

	return apply_badge_to_pilot(pilot_state, badge_id_to_apply)

# Apply a negative badge to a pilot (adds to temporary_badges)
static func apply_badge_to_pilot(pilot_state, badge_id: String) -> bool:
	var badge = load_badge(badge_id)
	if badge == null:
		return false

	# Check if pilot already has this badge
	for existing_badge in pilot_state.temporary_badges:
		if existing_badge.badge_id == badge_id:
			# Already has this badge, don't add duplicate
			return false

	# Add to temporary badges
	pilot_state.temporary_badges.append(badge)
	return true

# Helper to convert check type enum to string
static func _get_check_type_string(check_type: Sector.CheckType) -> String:
	match check_type:
		Sector.CheckType.TWITCH:
			return "twitch"
		Sector.CheckType.CRAFT:
			return "craft"
		Sector.CheckType.SYNC:
			return "sync"
		Sector.CheckType.EDGE:
			return "edge"
		_:
			return "unknown"
