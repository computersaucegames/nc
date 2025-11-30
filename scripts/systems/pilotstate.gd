# PilotState.gd
extends Resource
class_name PilotState

# Core pilot data
var pilot_data: Resource  # Will be the full Pilot resource later
var pilot_id: int = 0  # Index in the pilots array (for UI tracking)
var name: String = "Unknown"

# Race position data
var current_sector: int = 0
var gap_in_sector: int = 0
var current_lap: int = 1
var total_distance: int = 0  # Total Gap traveled (for position)
var position: int = 1
var finished: bool = false  # Track if pilot has finished the race
var finish_round: int = 0  # Round number when pilot finished

# Status flags
var is_clear_air: bool = true
var is_attacking: bool = false
var is_defending: bool = false
var is_wheel_to_wheel: bool = false
var is_in_train: bool = false

# Track who we're interacting with
var attacking_targets: Array = []  # Fins we're attacking
var defending_from: Array = []     # Fins attacking us
var wheel_to_wheel_with: Array = [] # Fins we're W2W with

# Race start effects
var has_poor_start: bool = false  # Will have disadvantage on first roll

# Pilot stats (will be replaced by full pilot resource later)
var twitch: int = 5
var craft: int = 5
var sync: int = 5
var edge: int = 5

# Get a specific stat by name
func get_stat(check_type: Sector.CheckType) -> int:
	match check_type:
		Sector.CheckType.TWITCH:
			return twitch
		Sector.CheckType.CRAFT:
			return craft
		Sector.CheckType.SYNC:
			return sync
		Sector.CheckType.EDGE:
			return edge
		_:
			push_error("Unknown check type: %s" % check_type)
			return 0

# Get current status as a string for display
func get_status_string() -> String:
	var statuses = []
	if is_clear_air:
		statuses.append("Clear Air")
	if is_wheel_to_wheel:
		statuses.append("Wheel-to-Wheel")
	if is_attacking:
		statuses.append("Attacking")
	if is_defending:
		statuses.append("Defending")
	if is_in_train:
		statuses.append("TRAIN")
	
	if statuses.is_empty():
		return "Unknown"
	return " + ".join(statuses)

# Get position info as string for debugging
func get_position_string() -> String:
	return "P%d | Lap %d | Sector %d | Gap %d | Total: %d" % [
		position, current_lap, current_sector + 1, gap_in_sector, total_distance
	]

# Initialize from dictionary (for easy setup)
func setup_from_dict(data: Dictionary, start_position: int = 1) -> void:
	name = data.get("name", "Pilot %d" % start_position)
	position = start_position
	
	if data.has("twitch"):
		twitch = data.twitch
		craft = data.craft
		sync = data.sync
		edge = data.edge

# Reset status flags (called when recalculating)
func clear_statuses() -> void:
	is_clear_air = true
	is_attacking = false
	is_defending = false
	is_wheel_to_wheel = false
	is_in_train = false
	attacking_targets.clear()
	defending_from.clear()
	wheel_to_wheel_with.clear()

# Mark as finished
func finish_race(finish_position: int, round_number: int = 0) -> void:
	finished = true
	clear_statuses()
	position = finish_position
	finish_round = round_number
