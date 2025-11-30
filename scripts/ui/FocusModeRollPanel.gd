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
@onready var total_result: Label = $VBox/RollContainer/TotalResult
@onready var tier_result: Label = $VBox/RollContainer/TierResult
@onready var movement_result: Label = $VBox/MovementResult

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

## Setup display with roll results
func setup_roll_display(pilot: PilotState, sector, roll_result: Dice.DiceResult, movement: int):
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

	# Total result
	total_result.text = "Total: %d" % roll_result.final_total
	total_result.add_theme_font_size_override("font_size", 16)
	total_result.add_theme_color_override("font_color", Color.WHITE)

	# Tier result
	var tier_color = TIER_COLORS.get(roll_result.tier_name, Color.WHITE)
	tier_result.text = "Result: %s" % roll_result.tier_name
	tier_result.add_theme_font_size_override("font_size", 18)
	tier_result.add_theme_color_override("font_color", tier_color)

	# Movement outcome
	movement_result.visible = true
	movement_result.text = "Movement: %d gaps" % movement
	movement_result.add_theme_font_size_override("font_size", 16)
	movement_result.add_theme_color_override("font_color", Color.LAWN_GREEN)
