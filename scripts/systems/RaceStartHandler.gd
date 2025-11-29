# RaceStartHandler.gd
extends RefCounted
class_name RaceStartHandler

# Handles race start procedures including grid formation and launch rolls

class StartResult:
	var pilot: PilotState
	var roll: Dice.DiceResult
	var effects: Dictionary  # Bonus applied, disadvantage, etc.

# Find the starting sector in a circuit
static func find_start_sector(circuit: Circuit) -> int:
	for i in range(circuit.sectors.size()):
		if circuit.sectors[i].is_start_sector:
			return i
	return 0  # Default to first sector if none marked

# Setup pilots on the starting grid
static func form_starting_grid(pilots: Array, circuit: Circuit) -> void:
	var start_sector = find_start_sector(circuit)
	
	for i in range(pilots.size()):
		var pilot = pilots[i]
		pilot.position = i + 1
		pilot.current_sector = start_sector
		pilot.gap_in_sector = -(i)  # Grid positions: 0, -1, -2, -3, etc.
		pilot.current_lap = 1
		pilot.total_distance = -(i)

# Execute launch procedure for all pilots
static func execute_launch_procedure(pilots: Array) -> Array:
	var results = []
	
	for pilot in pilots:
		var start_result = StartResult.new()
		start_result.pilot = pilot
		
		# Roll for launch reaction
		start_result.roll = Dice.roll_d20(pilot.twitch, "twitch", [], {}, {
			"context": "race_start",
			"pilot": pilot.name
		})
		
		# Apply effects based on roll
		start_result.effects = _apply_launch_effects(pilot, start_result.roll)
		
		results.append(start_result)
	
	return results

# Apply effects from launch roll
static func _apply_launch_effects(pilot: PilotState, roll: Dice.DiceResult) -> Dictionary:
	var effects = {
		"tier": roll.tier_name,
		"bonus_gap": 0,
		"has_disadvantage": false,
		"description": ""
	}
	
	match roll.tier:
		Dice.Tier.PURPLE:
			pilot.gap_in_sector += 1
			pilot.total_distance += 1
			effects.bonus_gap = 1
			effects.description = "Perfect launch! Gained position!"
			
		Dice.Tier.RED:
			pilot.has_poor_start = true
			effects.has_disadvantage = true
			effects.description = "Bogged down at the start!"
			
		Dice.Tier.GREEN:
			effects.description = "Good getaway!"
			
		_:
			effects.description = "Average start"
	
	return effects

# Check if pilots should be in formation lap
static func should_use_formation_lap(circuit: Circuit) -> bool:
	# Could check circuit properties, weather, etc.
	# For now, always false
	return false

# Get starting positions as a formatted string for display
static func get_grid_display(pilots: Array) -> String:
	var lines = []
	lines.append("STARTING GRID:")
	lines.append("--------------")
	
	for pilot in pilots:
		lines.append("P%d: %s" % [pilot.position, pilot.name])
	
	return "\n".join(lines)
