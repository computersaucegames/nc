extends PanelContainer
class_name FocusModeRollPanel

## Individual pilot roll display panel for Focus Mode
## Shows full breakdown of roll, stat, modifiers, and result

@onready var pilot_name_label: Label = $VBox/PilotName
@onready var sector_label: Label = $VBox/SectorInfo
@onready var pilot_info_label: Label = $VBox/PilotInfo
@onready var roll_container: VBoxContainer = $VBox/RollContainer
@onready var d20_result: Label = $VBox/RollContainer/D20Result
@onready var stat_bonus: Label = $VBox/RollContainer/StatBonus
@onready var modifiers_container: VBoxContainer = $VBox/RollContainer/ModifiersContainer
@onready var calculation_label: Label = $VBox/RollContainer/CalculationLabel
@onready var total_result: Label = $VBox/RollContainer/TotalResult
@onready var tier_result: Label = $VBox/RollContainer/TierResult
@onready var movement_result: Label = $VBox/MovementResult
@onready var resolution_label: Label = $VBox/ResolutionLabel

# Theme colors for tiers
const TIER_COLORS = {
	"RED": Color.RED,
	"GREY": Color.GRAY,
	"GREEN": Color.GREEN,
	"PURPLE": Color.PURPLE
}

func _ready():
	# Default panel styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)

## Setup display before roll is made
func setup_pre_roll_display(pilot: PilotState, sector):
	pilot_name_label.text = pilot.name
	sector_label.text = "Sector: %s (%s)" % [sector.sector_name, sector.get_check_type_string().to_upper()]

	# Show pilot current stats
	var stat_value = pilot.get_stat(sector.check_type)
	pilot_info_label.text = "Position: %d | %s: +%d" % [pilot.position, sector.get_check_type_string().capitalize(), stat_value]

	# Hide roll results until rolled
	roll_container.visible = false
	movement_result.visible = false
	resolution_label.visible = false

## Setup display with roll results
func setup_roll_display(pilot: PilotState, sector, roll_result: Dice.DiceResult, movement: int):
	print("DEBUG: Setting up roll display for %s - tier: %s, movement: %d" % [pilot.name, roll_result.tier_name, movement])

	pilot_name_label.text = pilot.name
	sector_label.text = "Sector: %s (%s)" % [sector.sector_name, sector.get_check_type_string().to_upper()]

	# Show pilot info
	pilot_info_label.text = "Position: %d | Status: %s" % [pilot.position, pilot.get_status_string()]

	# Show roll breakdown
	roll_container.visible = true

	# D20 result
	d20_result.text = "d20 Roll: %d" % roll_result.base_roll
	d20_result.add_theme_color_override("font_color", Color.WHITE)

	# Stat bonus
	stat_bonus.text = "%s Stat: +%d" % [roll_result.stat_name.capitalize(), roll_result.stat_value]
	stat_bonus.add_theme_color_override("font_color", Color.CYAN)

	# Clear previous modifiers
	for child in modifiers_container.get_children():
		child.queue_free()

	# Show all modifiers
	if roll_result.modifiers_applied.size() > 0:
		for mod_text in roll_result.modifiers_applied:
			var mod_label = Label.new()
			mod_label.text = "  • " + mod_text
			mod_label.add_theme_color_override("font_color", Color.YELLOW)
			mod_label.add_theme_font_size_override("font_size", 12)
			modifiers_container.add_child(mod_label)
	else:
		var no_mods = Label.new()
		no_mods.text = "  (No modifiers)"
		no_mods.add_theme_color_override("font_color", Color.DIM_GRAY)
		no_mods.add_theme_font_size_override("font_size", 12)
		modifiers_container.add_child(no_mods)

	# Calculation breakdown
	var calc_parts = [str(roll_result.base_roll), str(roll_result.stat_value)]
	if roll_result.flat_modifiers != 0:
		calc_parts.append(str(roll_result.flat_modifiers))
	calculation_label.text = " + ".join(calc_parts) + " = " + str(roll_result.final_total)
	calculation_label.add_theme_font_size_override("font_size", 14)
	calculation_label.add_theme_color_override("font_color", Color.AQUA)

	# Total result
	total_result.text = "Total: %d" % roll_result.final_total
	total_result.add_theme_font_size_override("font_size", 16)
	total_result.add_theme_color_override("font_color", Color.WHITE)

	# Tier result
	var tier_color = TIER_COLORS.get(roll_result.tier_name, Color.WHITE)
	tier_result.text = "Result: %s" % roll_result.tier_name
	tier_result.add_theme_font_size_override("font_size", 18)
	tier_result.add_theme_color_override("font_color", tier_color)

	# Movement outcome (with potential momentum info)
	movement_result.visible = true
	var momentum_text = _calculate_potential_momentum_text(pilot, sector, movement)
	movement_result.text = "Movement: %d gaps%s" % [movement, momentum_text]
	movement_result.add_theme_font_size_override("font_size", 16)
	movement_result.add_theme_color_override("font_color", Color.LAWN_GREEN)

	# Resolution text
	resolution_label.visible = true
	var resolution_text = _get_resolution_text(pilot.name, roll_result.tier_name, movement)
	resolution_label.text = resolution_text
	resolution_label.add_theme_font_size_override("font_size", 14)
	resolution_label.add_theme_color_override("font_color", TIER_COLORS.get(roll_result.tier_name, Color.WHITE))

func _calculate_potential_momentum_text(pilot: PilotState, sector, movement: int) -> String:
	# Calculate if this movement would complete the sector
	var new_gap = pilot.gap_in_sector + movement
	if new_gap >= sector.length_in_gap:
		var excess = new_gap - sector.length_in_gap
		var potential_momentum = min(excess, sector.carrythru)
		if potential_momentum > 0:
			return " (+%d momentum)" % potential_momentum
	return ""

func _get_resolution_text(pilot_name: String, tier: String, movement: int) -> String:
	match tier:
		"PURPLE":
			return "%s surges ahead!" % pilot_name
		"GREEN":
			return "%s pushes forward!" % pilot_name
		"GREY":
			return "%s maintains pace" % pilot_name
		"RED":
			return "%s struggles!" % pilot_name
		_:
			return "%s advances" % pilot_name
