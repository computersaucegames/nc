# FinState.gd
extends Resource
class_name FinState

# Core fin data
var fin_data: Fin  # The Fin resource this state represents

# Badge system state tracking
var badge_states: Dictionary = {}  # Tracks runtime state for each badge (e.g., consecutive rounds)
var temporary_badges: Array[Badge] = []  # Badges earned during this race

# Initialize from Fin resource
func setup_from_fin_resource(fin_resource: Fin) -> void:
	fin_data = fin_resource

# Get a specific stat by name (string)
func get_stat(stat_name: String) -> int:
	if fin_data == null:
		push_error("FinState has no fin_data set")
		return 0

	match stat_name.to_upper():
		"THRUST":
			return fin_data.THRUST
		"FORM":
			return fin_data.FORM
		"RESPONSE":
			return fin_data.RESPONSE
		"SYNC":
			return fin_data.SYNC
		_:
			push_error("Unknown fin stat: %s" % stat_name)
			return 0

# Get all badges (equipped + temporary)
func get_all_badges() -> Array[Badge]:
	if fin_data == null:
		return []
	return fin_data.equipped_badges + temporary_badges

# Add a temporary badge earned during race
func add_temporary_badge(badge: Badge) -> void:
	if badge not in temporary_badges:
		temporary_badges.append(badge)

# Remove a temporary badge (e.g., from wear & tear)
func remove_temporary_badge(badge: Badge) -> void:
	temporary_badges.erase(badge)

# Clear all temporary badges (called at race end for non-seasonal badges)
func clear_temporary_badges() -> void:
	temporary_badges.clear()
	badge_states.clear()
