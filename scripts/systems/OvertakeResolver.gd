"We are currently crashing on overtakes because we have the pilot skills as strings. We need to convert to the new system"

# OvertakeResolver.gd
extends RefCounted
class_name OvertakeResolver

# Handles all overtaking detection and resolution
# This class is responsible ONLY for overtaking mechanics

signal overtake_detected(attacker, defender, excess_gap)
signal overtake_resolved(attacker, defender, success: bool, attacker_roll, defender_roll)

# Configuration
const DEFENDER_POSITION_BONUS = 2  # Bonus for holding position

# Result of an overtake attempt
class OvertakeResult:
	var success: bool = false
	var attacker_roll: Dice.DiceResult
	var defender_roll: Dice.DiceResult
	var adjusted_movement: int = 0  # How much the attacker actually moves
	
	func _init(is_success: bool, att_roll: Dice.DiceResult, def_roll: Dice.DiceResult):
		success = is_success
		attacker_roll = att_roll
		defender_roll = def_roll

# Check if movement would cause overtakes
static func check_potential_overtakes(attacker, planned_movement: int, all_pilots: Array) -> Array:
	var overtake_attempts = []
	var attacker_new_position = attacker.gap_in_sector + planned_movement
	
	for other in all_pilots:
		if other == attacker or other.finished:
			continue
		
		# Check if they're ahead of us now and we'd pass them
		if other.current_sector == attacker.current_sector:
			var currently_behind = attacker.gap_in_sector < other.gap_in_sector
			var would_be_ahead = attacker_new_position > other.gap_in_sector
			
			if currently_behind and would_be_ahead:
				var excess = attacker_new_position - other.gap_in_sector
				overtake_attempts.append({
					"defender": other,
					"excess_gap": excess,
					"defender_position": other.gap_in_sector
				})
		
		# TODO: Handle overtakes across sector boundaries
		# This gets complex and needs careful consideration
	
	# Sort by defender position - closest defenders first
	overtake_attempts.sort_custom(func(a, b): 
		return a["defender_position"] < b["defender_position"]
	)
	
	return overtake_attempts

# Resolve a single overtake attempt
static func resolve_overtake(
	attacker, 
	defender, 
	sector,  # Current sector for stat determination
	excess_gap: int,
	modifiers_attacker: Array = [],
	modifiers_defender: Array = []
) -> OvertakeResult:
	
	# Get the stat for this sector using the enum
	var check_type = sector.check_type  # This is now a Sector.CheckType enum
	var attacker_stat = attacker.get_stat(check_type)  # Pass enum directly
	var defender_stat = defender.get_stat(check_type)  # Pass enum directly
	
	# Get the string representation for display/logging
	var stat_name = sector.get_check_type_string()  # "twitch", "craft", etc.
	
	# Build modifiers for the contested roll
	var defender_mods = modifiers_defender.duplicate()
	defender_mods.append(Dice.create_bonus(DEFENDER_POSITION_BONUS, "Track Position"))
	
	var attacker_mods = modifiers_attacker.duplicate()
	attacker_mods.append(Dice.create_bonus(excess_gap, "Momentum"))
	
	# Make the contested rolls (use string for display)
	var defender_roll = Dice.roll_d20(defender_stat, stat_name, defender_mods, {}, {
		"context": "defend_position",
		"pilot": defender.name
	})
	
	var attacker_roll = Dice.roll_d20(attacker_stat, stat_name, attacker_mods, {}, {
		"context": "overtake_attempt", 
		"pilot": attacker.name
	})
	
	# Determine success
	var success = attacker_roll.final_total > defender_roll.final_total
	
	return OvertakeResult.new(success, attacker_roll, defender_roll)

# Process multiple overtake attempts in sequence
static func process_overtake_chain(
	attacker,
	planned_movement: int,
	overtake_attempts: Array,
	sector
) -> Dictionary:
	
	var final_movement = planned_movement
	var results = []
	var blocked_by = null
	
	for attempt in overtake_attempts:
		var defender = attempt["defender"]
		var excess_gap = attempt["excess_gap"]
		
		# Resolve the overtake
		var result = resolve_overtake(attacker, defender, sector, excess_gap)
		results.append({
			"defender": defender,
			"result": result
		})
		
		if not result.success:
			# Overtake blocked - adjust movement to slot behind this defender
			final_movement = defender.gap_in_sector - attacker.gap_in_sector - 1
			blocked_by = defender
			break  # Can't overtake anyone else if blocked
	
	return {
		"final_movement": final_movement,
		"original_movement": planned_movement,
		"results": results,
		"blocked_by": blocked_by
	}

# Utility function to describe overtake situation
static func describe_overtake_situation(attacker, defender, excess_gap: int) -> String:
	return "%s attempting to pass %s with %d Gap momentum advantage" % [
		attacker.name, defender.name, excess_gap
	]
