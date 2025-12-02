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

# Setup pilots on the starting grid in pairs
static func form_starting_grid(pilots: Array, circuit: Circuit) -> void:
	var start_sector = find_start_sector(circuit)

	for i in range(pilots.size()):
		var pilot = pilots[i]
		pilot.position = i + 1
		pilot.current_sector = start_sector

		# Position pilots in pairs at gaps 3, 2, 1
		# Positions 1-2: Gap 3
		# Positions 3-4: Gap 2
		# Positions 5-6: Gap 1
		# Positions 7+: Gap 0 (overflow, may need sector extension)
		var row = int(i / 2)  # Which row (0 = front row)
		var gap_position = max(3 - row, 0)

		pilot.gap_in_sector = gap_position
		pilot.current_lap = 1
		pilot.total_distance = gap_position

		# Store grid position for later reference
		pilot.grid_position = i + 1

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
	lines.append("")

	# Group pilots by rows (pairs)
	var rows = []
	for i in range(0, pilots.size(), 2):
		var row = []
		row.append(pilots[i])
		if i + 1 < pilots.size():
			row.append(pilots[i + 1])
		rows.append(row)

	# Display from front to back
	for row_idx in range(rows.size()):
		var row = rows[row_idx]
		var gap = 3 - row_idx
		if gap < 0:
			gap = 0

		var pilot_names = []
		for pilot in row:
			pilot_names.append("P%d: %s" % [pilot.grid_position, pilot.name])

		lines.append("Gap %d: %s" % [gap, " | ".join(pilot_names)])

	return "\n".join(lines)

# Get grid layout data for UI visualization
static func get_grid_layout_data(pilots: Array) -> Array:
	var layout = []

	# Group pilots by rows
	for i in range(0, pilots.size(), 2):
		var row_data = {
			"gap": 3 - int(i / 2),
			"pilots": []
		}

		row_data.pilots.append({
			"pilot": pilots[i],
			"grid_position": i + 1
		})

		if i + 1 < pilots.size():
			row_data.pilots.append({
				"pilot": pilots[i + 1],
				"grid_position": i + 2
			})

		layout.append(row_data)

	return layout
