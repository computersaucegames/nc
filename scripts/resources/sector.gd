# Sector.gd
extends Resource
class_name Sector

# Define check types as an enum for better type safety
enum CheckType {
	TWITCH,
	CRAFT,
	SYNC,
	EDGE
}

@export var sector_name: String = "Unnamed Sector"
@export var length_in_gap: int = 5  # Total distance of this sector
@export var carrythru: int = 2  # Max excess Gap that can transfer to next sector
@export var check_type: CheckType = CheckType.EDGE
@export var is_start_sector: bool = false  # Is this where the race starts?

# Gate thresholds - the roll must meet or exceed these values
@export_group("Gate Thresholds")
@export var grey_threshold: int = 5   # Below this = Red (failure)
@export var green_threshold: int = 10  # Grey to Green
@export var purple_threshold: int = 15 # Green to Purple (crit)

# Movement rewards based on result (in Gap units)
@export_group("Movement Rewards")
@export var red_movement: int = 1    # Failure - minimal progress
@export var grey_movement: int = 2   # Neutral - slow progress  
@export var green_movement: int = 3  # Success - good progress
@export var purple_movement: int = 4 # Critical - maximum progress

# Optional: Specific failure consequences for this sector
@export var failure_table: Array[String] = [
	"Spin out - lose 1 Gap",
	"Lock up brakes - lose 2 Gap", 
	"Wide line - no penalty"
]

func get_movement_for_roll(roll_value: int) -> int:
	if roll_value < grey_threshold:
		return red_movement
	elif roll_value < green_threshold:
		return grey_movement
	elif roll_value < purple_threshold:
		return green_movement
	else:
		return purple_movement

func get_result_type(roll_value: int) -> String:
	if roll_value < grey_threshold:
		return "RED"
	elif roll_value < green_threshold:
		return "GREY"
	elif roll_value < purple_threshold:
		return "GREEN"
	else:
		return "PURPLE"

func get_random_failure_consequence() -> String:
	if failure_table.is_empty():
		return "Generic failure"
	return failure_table.pick_random()
	
# Helper function to get the check type as a string (for display/logging)
func get_check_type_string() -> String:
	match check_type:
		CheckType.TWITCH:
			return "twitch"
		CheckType.CRAFT:
			return "craft"
		CheckType.SYNC:
			return "sync"
		CheckType.EDGE:
			return "edge"
		_:
			return "unknown"

# Helper to get a descriptive name for the check type
func get_check_type_display_name() -> String:
	match check_type:
		CheckType.TWITCH:
			return "Twitch Reflexes"
		CheckType.CRAFT:
			return "Technical Craft"
		CheckType.SYNC:
			return "Neural Sync"
		CheckType.EDGE:
			return "Aggressive Edge"
		_:
			return "Unknown Check"
