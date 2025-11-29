# MovementProcessor.gd
extends RefCounted
class_name MovementProcessor

# Handles all movement application, sector completion, and lap counting
# This class is responsible ONLY for moving pilots through the track

# Result of movement processing
class MovementResult:
	var final_movement: int = 0
	var sectors_completed: Array = []  # List of completed sectors
	var lap_completed: bool = false
	var new_lap_number: int = 0
	var race_finished: bool = false
	
# Calculate base movement from a dice roll result
static func calculate_base_movement(sector: Sector, roll_result: Dice.DiceResult) -> int:
	return sector.get_movement_for_roll(roll_result.final_total)

# Apply movement to a pilot, handling sector and lap completion
static func apply_movement(
	pilot: PilotState, 
	movement: int, 
	circuit: Circuit
) -> MovementResult:
	
	var result = MovementResult.new()
	result.final_movement = movement
	
	# Calculate new position
	var new_gap = pilot.gap_in_sector + movement
	var current_sector = circuit.sectors[pilot.current_sector]
	
	# Check if we complete the current sector
	while new_gap >= current_sector.length_in_gap:
		# Complete this sector
		result.sectors_completed.append(current_sector)
		
		# Calculate excess and apply carrythru
		var excess = new_gap - current_sector.length_in_gap
		excess = min(excess, current_sector.carrythru)
		
		# Move to next sector
		pilot.current_sector += 1
		
		# Check for lap completion
		if pilot.current_sector >= circuit.sectors.size():
			pilot.current_sector = 0
			pilot.current_lap += 1
			result.lap_completed = true
			result.new_lap_number = pilot.current_lap
			
			# Check if race is finished for this pilot
			if pilot.current_lap > circuit.total_laps:
				result.race_finished = true
				break
		
		# Set position in new sector
		new_gap = excess
		
		# Get the new current sector for next iteration
		if pilot.current_sector < circuit.sectors.size():
			current_sector = circuit.sectors[pilot.current_sector]
		else:
			break  # Safety check
	
	# Apply final gap position
	pilot.gap_in_sector = new_gap
	
	# Update total distance
	pilot.total_distance += movement
	
	return result

# Process movement with overtake adjustments
static func apply_movement_with_overtakes(
	pilot: PilotState,
	base_movement: int,
	overtake_chain_result: Dictionary,  # From OvertakeResolver
	circuit: Circuit
) -> MovementResult:
	
	# Use adjusted movement from overtake resolution
	var final_movement = overtake_chain_result.get("final_movement", base_movement)
	
	# Apply the movement
	return apply_movement(pilot, final_movement, circuit)

# Calculate grid positions for race start
static func setup_grid_positions(pilots: Array, start_sector_index: int = 0) -> void:
	for i in range(pilots.size()):
		var pilot = pilots[i]
		pilot.position = i + 1
		pilot.current_sector = start_sector_index
		pilot.gap_in_sector = -(i)  # Grid positions: 0, -1, -2, -3, etc.
		pilot.current_lap = 1
		pilot.total_distance = -(i)  # Negative to reflect grid position

# Apply race start bonuses
static func apply_start_bonus(pilot: PilotState, start_roll: Dice.DiceResult) -> Dictionary:
	var effects = {
		"bonus_applied": false,
		"disadvantage_next": false,
		"description": ""
	}
	
	match start_roll.tier:
		Dice.Tier.PURPLE:
			# Excellent start - gain 1 Gap
			pilot.gap_in_sector += 1
			pilot.total_distance += 1
			effects.bonus_applied = true
			effects.description = "Perfect launch! (+1 Gap)"
		Dice.Tier.RED:
			# Poor start - disadvantage on first roll
			pilot.has_poor_start = true
			effects.disadvantage_next = true
			effects.description = "Poor start! (Disadvantage next roll)"
		Dice.Tier.GREEN:
			effects.description = "Good start"
		_:
			effects.description = "Average start"
	
	return effects

# Update positions for all pilots based on total distance
static func update_all_positions(pilots: Array) -> void:
	# Sort by total distance (highest first)
	pilots.sort_custom(func(a, b): return a.total_distance > b.total_distance)
	
	# Update position numbers
	for i in range(pilots.size()):
		if not pilots[i].finished:
			pilots[i].position = i + 1

# Check if a pilot can continue racing
static func can_pilot_race(pilot: PilotState) -> bool:
	return not pilot.finished

# Get pilots in finishing order
static func get_finish_order(pilots: Array) -> Array:
	var finished_pilots = []
	for pilot in pilots:
		if pilot.finished:
			finished_pilots.append(pilot)
	
	finished_pilots.sort_custom(func(a, b): return a.position < b.position)
	return finished_pilots
