# DiceSystem.gd
# Autoload this as "Dice" for global access
extends Node

signal roll_complete(result: DiceResult)
signal tier_achieved(tier: String, roll_data: DiceResult)

# The four-tier outcome levels
enum Tier {
	RED,    # Critical Failure
	GREY,   # Mixed Success  
	GREEN,  # Success
	PURPLE  # Critical Success
}

# Different types of roll modifications that badges can apply
enum ModType {
	FLAT_BONUS,      # Simple +X to roll
	ADVANTAGE,       # Roll twice, take best
	DISADVANTAGE,    # Roll twice, take worst
	STAT_REPLACE,    # Use different stat
	REROLL_ONES,     # Reroll any 1s once
	MIN_TIER,        # Can't roll below a certain tier
	TIER_SHIFT,      # Shift result up/down one tier
}

# Roll modifier that can be applied by badges, relationships, etc
class RollModifier:
	var source: String = ""  # Where this came from (badge name, relationship, etc)
	var type: ModType
	var value: Variant  # Could be int for bonus, String for stat name, etc
	var description: String = ""
	
	func _init(mod_type: ModType, mod_value: Variant = 0, mod_source: String = ""):
		type = mod_type
		value = mod_value
		source = mod_source

# Dice result object containing all roll information
class DiceResult:
	var base_roll: int = 0           # The actual d20 roll
	var stat_value: int = 0          # The stat being used
	var stat_name: String = ""       # Which stat was used
	var flat_modifiers: int = 0      # Sum of all flat bonuses
	var final_total: int = 0         # base_roll + stat + modifiers
	
	var tier: Tier
	var tier_name: String
	
	var gates: Dictionary = {}       # The thresholds used
	var modifiers_applied: Array[String] = []  # List of what affected the roll
	var roll_log: Array[String] = [] # Detailed log of the roll process
	
	var context: Dictionary = {}     # Additional context (who rolled, sector, etc)
	
	func get_tier_color() -> Color:
		match tier:
			Tier.RED: return Color.RED
			Tier.GREY: return Color.GRAY
			Tier.GREEN: return Color.GREEN
			Tier.PURPLE: return Color.PURPLE
		return Color.WHITE
	
	func get_summary() -> String:
		return "%s (%d) = d20(%d) + %s(%d) + modifiers(%d)" % [
			tier_name, final_total, base_roll, stat_name, stat_value, flat_modifiers
		]

# Standard gate thresholds
const DEFAULT_GATES = {
	"grey": 10,   # Roll 10+ to avoid RED
	"green": 15,  # Roll 15+ for GREEN
	"purple": 20  # Roll 20+ for PURPLE
}

# Make a d20 roll with stat and modifiers
func roll_d20(
	stat_value: int,
	stat_name: String = "stat",
	modifiers: Array = [],  # Changed from Array[RollModifier]
	gates: Dictionary = DEFAULT_GATES,
	context: Dictionary = {}
) -> DiceResult:
	
	var result = DiceResult.new()
	result.stat_value = stat_value
	result.stat_name = stat_name
	result.gates = gates
	result.context = context
	
	# Track what stat we're actually using (can be changed by modifiers)
	var active_stat_value = stat_value
	var active_stat_name = stat_name
	
	# Check for stat replacement modifiers first
	for mod in modifiers:
		if mod.type == ModType.STAT_REPLACE:
			# mod.value should be a dictionary with "stat_name" and "stat_value"
			if mod.value is Dictionary:
				active_stat_name = mod.value.get("stat_name", stat_name)
				active_stat_value = mod.value.get("stat_value", stat_value)
				result.modifiers_applied.append("Using %s instead of %s" % [active_stat_name, stat_name])
				result.roll_log.append("Stat replaced: %s(%d) -> %s(%d)" % [
					stat_name, stat_value, active_stat_name, active_stat_value
				])
	
	# Check for advantage/disadvantage
	var has_advantage = false
	var has_disadvantage = false
	for mod in modifiers:
		if mod.type == ModType.ADVANTAGE:
			has_advantage = true
			result.modifiers_applied.append("Advantage from %s" % mod.source)
		elif mod.type == ModType.DISADVANTAGE:
			has_disadvantage = true
			result.modifiers_applied.append("Disadvantage from %s" % mod.source)
	
	# Make the actual roll(s)
	var roll1 = randi_range(1, 20)
	var roll2 = 0
	
	if has_advantage and not has_disadvantage:
		roll2 = randi_range(1, 20)
		result.base_roll = max(roll1, roll2)
		result.roll_log.append("Rolled with advantage: %d and %d, taking %d" % [roll1, roll2, result.base_roll])
	elif has_disadvantage and not has_advantage:
		roll2 = randi_range(1, 20)
		result.base_roll = min(roll1, roll2)
		result.roll_log.append("Rolled with disadvantage: %d and %d, taking %d" % [roll1, roll2, result.base_roll])
	else:
		# Normal roll or advantage+disadvantage cancel out
		result.base_roll = roll1
		if has_advantage and has_disadvantage:
			result.roll_log.append("Advantage and disadvantage cancel out")
		result.roll_log.append("Rolled: %d" % result.base_roll)
	
	# Apply reroll ones if present
	for mod in modifiers:
		if mod.type == ModType.REROLL_ONES and result.base_roll == 1:
			var new_roll = randi_range(1, 20)
			result.roll_log.append("Rerolled 1, got %d" % new_roll)
			result.base_roll = new_roll
			result.modifiers_applied.append("Rerolled 1 from %s" % mod.source)
			break  # Only reroll once
	
	# Calculate flat bonuses
	var flat_bonus = 0
	for mod in modifiers:
		if mod.type == ModType.FLAT_BONUS:
			flat_bonus += mod.value as int
			result.modifiers_applied.append("+%d from %s" % [mod.value, mod.source])
	
	# Calculate final total
	result.stat_value = active_stat_value
	result.stat_name = active_stat_name
	result.flat_modifiers = flat_bonus
	result.final_total = result.base_roll + active_stat_value + flat_bonus
	
	# Determine base tier from gates
	if result.final_total < gates.get("grey", DEFAULT_GATES["grey"]):
		result.tier = Tier.RED
		result.tier_name = "RED"
	elif result.final_total < gates.get("green", DEFAULT_GATES["green"]):
		result.tier = Tier.GREY
		result.tier_name = "GREY"
	elif result.final_total < gates.get("purple", DEFAULT_GATES["purple"]):
		result.tier = Tier.GREEN
		result.tier_name = "GREEN"
	else:
		result.tier = Tier.PURPLE
		result.tier_name = "PURPLE"
	
	# Apply tier modifications (min tier, tier shift)
	for mod in modifiers:
		if mod.type == ModType.MIN_TIER:
			var min_tier = mod.value as Tier
			if result.tier < min_tier:
				result.tier = min_tier
				result.tier_name = Tier.keys()[min_tier]
				result.modifiers_applied.append("Minimum tier %s from %s" % [result.tier_name, mod.source])
		elif mod.type == ModType.TIER_SHIFT:
			var shift = mod.value as int
			var new_tier_value = clampi(result.tier + shift, Tier.RED, Tier.PURPLE)
			result.tier = new_tier_value as Tier
			result.tier_name = Tier.keys()[new_tier_value]
			var shift_dir = "up" if shift > 0 else "down"
			result.modifiers_applied.append("Tier shifted %s by %s" % [shift_dir, mod.source])
	
	result.roll_log.append("Final: %d = %d(d20) + %d(%s) + %d(modifiers)" % [
		result.final_total, result.base_roll, active_stat_value, active_stat_name, flat_bonus
	])
	result.roll_log.append("Result: %s" % result.tier_name)
	
	# Emit signals
	roll_complete.emit(result)
	tier_achieved.emit(result.tier_name, result)
	
	return result

# Simplified helper for basic rolls
func quick_roll(stat_value: int, stat_name: String = "stat") -> DiceResult:
	return roll_d20(stat_value, stat_name)

# Helper to create common modifiers
func create_advantage(source: String = "unknown") -> RollModifier:
	return RollModifier.new(ModType.ADVANTAGE, true, source)

func create_disadvantage(source: String = "unknown") -> RollModifier:
	return RollModifier.new(ModType.DISADVANTAGE, true, source)

func create_bonus(amount: int, source: String = "unknown") -> RollModifier:
	return RollModifier.new(ModType.FLAT_BONUS, amount, source)

func create_stat_replacement(new_stat_name: String, new_stat_value: int, source: String = "unknown") -> RollModifier:
	return RollModifier.new(
		ModType.STAT_REPLACE, 
		{"stat_name": new_stat_name, "stat_value": new_stat_value},
		source
	)
