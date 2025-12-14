# PilotState.gd
extends Resource
class_name PilotState

# Core pilot data
var pilot_data: Resource  # Will be the full Pilot resource later
var pilot_id: int = 0  # Index in the pilots array (for UI tracking)
var name: String = "Unknown"
var headshot: String = ""  # Path to pilot headshot image

# Fin data (the craft this pilot is controlling)
var fin_state: FinState = null

# Race position data
var current_sector: int = 0
var gap_in_sector: int = 0
var current_lap: int = 1
var total_distance: int = 0  # Total Gap traveled (for position)
var position: int = 1
var grid_position: int = 1  # Starting position on the grid (used for tiebreakers)
var finished: bool = false  # Track if pilot has finished the race
var finish_round: int = 0  # Round number when pilot finished
var did_not_finish: bool = false  # Track if pilot crashed/DNF'd
var dnf_reason: String = ""  # Why they DNF'd (e.g., "Crashed", "Mechanical")
var dnf_round: int = 0  # Round number when pilot DNF'd

# Status flags
var is_race_start: bool = false  # Race start status (overrides other statuses)
var is_clear_air: bool = true
var is_attacking: bool = false
var is_defending: bool = false
var is_wheel_to_wheel: bool = false
var is_in_train: bool = false
var is_dueling: bool = false  # In a multi-round duel (2+ consecutive W2W rounds)

# Track who we're interacting with
var attacking_targets: Array = []  # Fins we're attacking
var defending_from: Array = []     # Fins attacking us
var wheel_to_wheel_with: Array = [] # Fins we're W2W with

# Duel tracking
var consecutive_w2w_rounds: int = 0  # How many rounds we've been W2W with same opponent
var last_w2w_partner_name: String = ""  # Who we were W2W with last round

# Race start effects
var has_poor_start: bool = false  # Will have disadvantage on first roll

# Badge system state tracking
var badge_states: Dictionary = {}  # Tracks runtime state for each badge (e.g., consecutive rounds)
var temporary_badges: Array[Badge] = []  # Negative badges earned during this race

# Failure table effects
var penalty_next_turn: int = 0  # Gap penalty to apply on next roll (from overflow)

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
	# DNF status overrides everything
	if did_not_finish:
		return "DNF - %s" % dnf_reason

	# Finished status
	if finished:
		return "Finished"

	# Race start status overrides all others
	if is_race_start:
		return "Race Start"

	var statuses = []
	if is_clear_air:
		statuses.append("Clear Air")
	if is_dueling:
		statuses.append("DUEL")
	elif is_wheel_to_wheel:
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

# Initialize from Pilot resource
func setup_from_pilot_resource(pilot_resource: Pilot, start_position: int = 1, headshot_path: String = "") -> void:
	pilot_data = pilot_resource
	name = pilot_resource.pilot_name
	position = start_position
	grid_position = start_position
	headshot = headshot_path

	# Copy stats from pilot resource
	twitch = pilot_resource.TWITCH
	craft = pilot_resource.CRAFT
	sync = pilot_resource.SYNC
	edge = pilot_resource.EDGE

# Assign a fin to this pilot
func setup_fin(fin_resource: Fin) -> void:
	fin_state = FinState.new()
	fin_state.setup_from_fin_resource(fin_resource)

# Initialize from dictionary (for easy setup - legacy support)
func setup_from_dict(data: Dictionary, start_position: int = 1) -> void:
	name = data.get("name", "Pilot %d" % start_position)
	position = start_position
	headshot = data.get("headshot", "")

	if data.has("twitch"):
		twitch = data.twitch
		craft = data.craft
		sync = data.sync
		edge = data.edge

# Reset status flags (called when recalculating)
func clear_statuses() -> void:
	is_race_start = false
	is_clear_air = true
	is_attacking = false
	is_defending = false
	is_wheel_to_wheel = false
	is_in_train = false
	is_dueling = false
	attacking_targets.clear()
	defending_from.clear()
	wheel_to_wheel_with.clear()

# Mark as finished
func finish_race(finish_position: int, round_number: int = 0) -> void:
	finished = true
	clear_statuses()
	position = finish_position
	finish_round = round_number

# Mark as DNF/crashed
func crash(reason: String = "Crashed", round_number: int = 0) -> void:
	did_not_finish = true
	dnf_reason = reason
	dnf_round = round_number
	clear_statuses()
