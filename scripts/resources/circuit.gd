
# Circuit.gd
extends Resource
class_name Circuit

@export var circuit_name: String = "Unnamed Circuit"
@export var country: String = ""
@export var total_laps: int = 3
@export var sectors: Array[Sector] = []
@export var display_scene: PackedScene = null  # The scene containing the circuit visual display
@export var runs_counter_clockwise: bool = false  # If true, circuit runs counter-clockwise
@export var available_sector_badges: Array[Badge] = []  # Badges that can be earned on this circuit

func get_total_length() -> int:
	var total: int = 0
	for sector in sectors:
		total += sector.length_in_gap
	return total

func get_sector_count() -> int:
	return sectors.size()

func get_lap_length() -> int:
	return get_total_length()

func get_race_length() -> int:
	return get_total_length() * total_laps


# Example of creating a circuit in code or inspector:
func create_example_circuit() -> Circuit:
	var circuit = Circuit.new()
	circuit.circuit_name = "Monaco Street Circuit"
	circuit.country = "Monaco"
	circuit.total_laps = 5
	
	# Sector 1: Tight corners
	var sector1 = Sector.new()
	sector1.sector_name = "Harbor Chicane"
	sector1.length_in_gap = 4
	sector1.grey_threshold = 6
	sector1.green_threshold = 11
	sector1.purple_threshold = 16
	sector1.red_movement = 1
	sector1.grey_movement = 2
	sector1.green_movement = 3
	sector1.purple_movement = 4
	
	# Sector 2: Long straight
	var sector2 = Sector.new()
	sector2.sector_name = "Tunnel Run"
	sector2.length_in_gap = 6
	sector2.grey_threshold = 4
	sector2.green_threshold = 8
	sector2.purple_threshold = 14
	sector2.red_movement = 1
	sector2.grey_movement = 3
	sector2.green_movement = 4
	sector2.purple_movement = 5
	
	# Sector 3: Technical section
	var sector3 = Sector.new()
	sector3.sector_name = "Casino Square"
	sector3.length_in_gap = 5
	sector3.grey_threshold = 7
	sector3.green_threshold = 12
	sector3.purple_threshold = 17
	sector3.red_movement = 0
	sector3.grey_movement = 2
	sector3.green_movement = 3
	sector3.purple_movement = 4
	
	circuit.sectors = [sector1, sector2, sector3]
	return circuit
