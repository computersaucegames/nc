# MechanicState.gd
extends RefCounted
class_name MechanicState

var mechanic_name: String = ""
var mechanic_id: String = ""

# Mechanic stats
var build: int = 5   # Repair/construction work
var rig: int = 5     # Equipment setup/handling
var cool: int = 5    # Staying calm under pressure

# Runtime state
var temporary_badges: Array[Badge] = []  # Could get negative badges from pit errors
var badge_states: Dictionary = {}  # For badge state tracking

# Initialize from mechanic resource
func setup_from_mechanic_resource(mechanic_resource: Mechanic) -> void:
	mechanic_name = mechanic_resource.mechanic_name
	mechanic_id = mechanic_resource.mechanic_id
	build = mechanic_resource.BUILD
	rig = mechanic_resource.RIG
	cool = mechanic_resource.COOL

# Get stat by name for pit rolls
func get_stat(stat_name: String) -> int:
	match stat_name.to_lower():
		"build":
			return build
		"rig":
			return rig
		"cool":
			return cool
		_:
			return 5

# Add a temporary badge to the mechanic
func add_temporary_badge(badge: Badge) -> void:
	# Check for duplicates
	for existing_badge in temporary_badges:
		if existing_badge.badge_id == badge.badge_id:
			return  # Already has this badge

	temporary_badges.append(badge)

# Remove a temporary badge from the mechanic
func remove_temporary_badge(badge: Badge) -> void:
	temporary_badges.erase(badge)

# Clear all temporary badges (e.g., at race end)
func clear_temporary_badges() -> void:
	temporary_badges.clear()
	badge_states.clear()
