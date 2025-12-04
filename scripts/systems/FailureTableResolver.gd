# FailureTableResolver.gd
# Handles rolling on sector failure tables when a pilot gets a red result
extends RefCounted
class_name FailureTableResolver

# Roll on a failure table and get the consequence
static func resolve_failure(pilot, sector: Sector) -> Dictionary:
	# Get the failure consequence from the sector's table
	var consequence_text = sector.get_random_failure_consequence()

	# Parse the consequence to extract penalty
	var penalty = parse_consequence_penalty(consequence_text)

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
		"penalty_gaps": penalty
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
