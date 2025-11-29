# scripts/systems/CircuitLoader.gd
extends RefCounted
class_name CircuitLoader

# Paths to circuit resources
const TEST_CIRCUITS_PATH = "res://resources/circuits/test_tracks/"
const RACE_CIRCUITS_PATH = "res://resources/circuits/race_tracks/"

# Load a specific circuit by filename
static func load_circuit(circuit_path: String) -> Circuit:
	var circuit = load(circuit_path) as Circuit
	if not circuit:
		push_error("Failed to load circuit: " + circuit_path)
		return null
	return circuit

# Get all test circuits
static func get_test_circuits() -> Array[Circuit]:
	var circuits: Array[Circuit] = []
	var dir = DirAccess.open(TEST_CIRCUITS_PATH)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var full_path = TEST_CIRCUITS_PATH + file_name
				var circuit = load(full_path) as Circuit
				if circuit:
					circuits.append(circuit)
			file_name = dir.get_next()
	
	return circuits

# Get circuit by name
static func get_circuit_by_name(name: String) -> Circuit:
	# First check test circuits
	var test_circuits = get_test_circuits()
	for circuit in test_circuits:
		if circuit.circuit_name == name:
			return circuit
	
	# Then check race circuits
	# ... similar logic for race circuits
	
	return null
