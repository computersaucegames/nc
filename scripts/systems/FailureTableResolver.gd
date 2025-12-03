# FailureTableResolver.gd
# Handles rolling on sector failure tables when a pilot gets a red result
extends RefCounted
class_name FailureTableResolver

# Roll on a failure table and get the consequence
static func resolve_failure(pilot, sector: Sector) -> Dictionary:
	# Get the failure consequence from the sector's table
	var consequence_text = sector.get_random_failure_consequence()

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
		"description": consequence_text
	}

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
