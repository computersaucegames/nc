extends Node

## Script to update Mountain and Pizza circuits with fin stats and adjusted gates
## Run this once in Godot to update the track files

# Mapping of pilot stats to complementary fin stats
const PILOT_TO_FIN_MAPPING = {
	Sector.CheckType.TWITCH: Sector.FinStatType.RESPONSE,  # Quick reactions
	Sector.CheckType.CRAFT: Sector.FinStatType.FORM,       # Technical precision
	Sector.CheckType.SYNC: Sector.FinStatType.SYNC,        # Neural connection
	Sector.CheckType.EDGE: Sector.FinStatType.THRUST       # Aggressive power
}

func _ready():
	print("\n=== UPDATING CIRCUITS FOR FIN STATS ===\n")

	update_circuit("res://resources/circuits/mountain_track.tres", "Mountain Circuit")
	update_circuit("res://resources/circuits/pizza_circuit.tres", "Pizza Circuit")

	print("\n=== CIRCUIT UPDATES COMPLETE ===\n")
	print("NOTE: You may need to restart Godot or reload the resources for changes to take effect")

func update_circuit(path: String, circuit_name: String):
	print("Updating %s..." % circuit_name)

	var circuit = load(path) as Circuit
	if circuit == null:
		print("  ✗ ERROR: Could not load circuit at %s" % path)
		return

	var sectors_updated = 0

	for sector in circuit.sectors:
		# Add fin stat type based on pilot check type
		var old_fin_stat = sector.fin_stat_type
		sector.fin_stat_type = PILOT_TO_FIN_MAPPING[sector.check_type]

		# Adjust gates for combined pilot+fin stats
		# Old range: pilot stat (1-8) + d20 (1-20) = 2-28
		# New range: pilot stat (1-8) + fin stat (1-8) + d20 (1-20) = 3-36
		# Gates roughly doubled, with slight adjustment for balance

		var old_grey = sector.grey_threshold
		var old_green = sector.green_threshold
		var old_purple = sector.purple_threshold

		sector.grey_threshold = 9
		sector.green_threshold = 18
		sector.purple_threshold = 27

		print("  ✓ %s: fin_stat=%s, gates: %d/%d/%d → %d/%d/%d" % [
			sector.sector_name,
			_get_fin_stat_name(sector.fin_stat_type),
			old_grey, old_green, old_purple,
			sector.grey_threshold, sector.green_threshold, sector.purple_threshold
		])

		sectors_updated += 1

	# Save the updated circuit
	var result = ResourceSaver.save(circuit, path)
	if result == OK:
		print("  ✓ Saved %s with %d sectors updated\n" % [circuit_name, sectors_updated])
	else:
		print("  ✗ ERROR: Failed to save circuit (error code: %d)\n" % result)

func _get_fin_stat_name(fin_stat_type: Sector.FinStatType) -> String:
	match fin_stat_type:
		Sector.FinStatType.THRUST:
			return "THRUST"
		Sector.FinStatType.FORM:
			return "FORM"
		Sector.FinStatType.RESPONSE:
			return "RESPONSE"
		Sector.FinStatType.SYNC:
			return "SYNC"
		Sector.FinStatType.NONE:
			return "NONE"
		_:
			return "UNKNOWN"
