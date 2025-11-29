# Sector.gd
extends Resource
class_name Pilot

# Define stat types as an enum for better type safety
enum StatType {
	TWITCH,
	CRAFT,
	SYNC,
	EDGE
}

@export var pilot_name: String = "Unnamed Pilot"
@export var pilot_bio: String = "Example bio. He did that!"  

@export_group("Stats")
@export var TWITCH: int = 1 
@export var CRAFT: int = 1
@export var SYNC: int = 1
@export var EDGE: int = 1



"""func get_stat(roll_value: int) -> int:
	match StatType 
		return red_movement
	elif roll_value < green_threshold:
		return grey_movement
	elif roll_value < purple_threshold:
		return green_movement
	else:
		return purple_movement

# Helper function to get the stat type as a string (for display/logging)
func get_stat_type_string() -> String:
	match stat_type:
		StatType.TWITCH:
			return "twitch"
		StatType.CRAFT:
			return "craft"
		StatType.SYNC:
			return "sync"
		StatType.EDGE:
			return "edge"
		_:
			return "unknown"

# Helper to get a descriptive name for the stat type
func get_stat_type_display_name() -> String:
	match stat_type:
		StatType.TWITCH:
			return "Twitch Reflexes"
		StatType.CRAFT:
			return "Technical Craft"
		StatType.SYNC:
			return "Neural Sync"
		StatType.EDGE:
			return "Aggressive Edge"
		_:
			return "Unknown Stat"
			
			"""
			
			
