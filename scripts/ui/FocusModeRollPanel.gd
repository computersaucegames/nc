extends PanelContainer
class_name FocusModeRollPanel

## Individual pilot roll display panel for Focus Mode
## Shows full breakdown of roll, stat, modifiers, and result

@onready var vbox: VBoxContainer = $VBox
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

# Headshot display (created dynamically)
var headshot_texture: TextureRect = null

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

	# Create headshot texture rect and add it to the top of VBox
	headshot_texture = TextureRect.new()
	headshot_texture.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	headshot_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	headshot_texture.custom_minimum_size = Vector2(80, 80)
	headshot_texture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(headshot_texture)
	vbox.move_child(headshot_texture, 0)  # Move to top

## Setup display before roll is made
func setup_pre_roll_display(pilot: PilotState, sector, event_type: int = -1, tied_position: int = -1):
	# Load and display headshot
	if headshot_texture and pilot.headshot != "":
		headshot_texture.texture = load(pilot.headshot)
		headshot_texture.visible = true
	elif headshot_texture:
		headshot_texture.visible = false

	pilot_name_label.text = pilot.name

	# Add context to sector label based on event type
	# For failure tables, use the failure_table_check_type instead of normal check_type
	var check_type = sector.failure_table_check_type if event_type == 5 else sector.check_type
	var check_type_str = _get_check_type_string(check_type)
	var sector_text = "Sector: %s (%s)" % [sector.sector_name, check_type_str.to_upper()]

	# Add sector tags if present
	if not sector.sector_tags.is_empty():
		var tags_str = " [" + ", ".join(sector.sector_tags) + "]"
		sector_text += tags_str

	if event_type == 0:  # WHEEL_TO_WHEEL_ROLL
		sector_text = "W2W Focus Mode - " + sector_text
	elif event_type == 5:  # RED_RESULT (Failure Table)
		sector_text = "Failure Table - " + sector_text
	sector_label.text = sector_text

	# Show pilot current stats with tied position if in W2W mode
	var stat_value = pilot.get_stat(check_type)
	if tied_position > 0:
		pilot_info_label.text = _format_pilot_info("Tied for P%d" % tied_position, "%s: +%d" % [check_type_str.capitalize(), stat_value])
	else:
		pilot_info_label.text = _format_pilot_info("Position: %d" % pilot.position, "%s: +%d" % [check_type_str.capitalize(), stat_value])

	# Hide roll results until rolled
	roll_container.visible = false
	movement_result.visible = false
	resolution_label.visible = false

## Setup display with roll results
func setup_roll_display(pilot: PilotState, sector, roll_result: Dice.DiceResult, movement: int, event_type: int = -1, tied_position: int = -1, event_metadata: Dictionary = {}):
	print("DEBUG: Setting up roll display for %s - tier: %s, movement: %d" % [pilot.name, roll_result.tier_name, movement])

	# Load and display headshot
	if headshot_texture and pilot.headshot != "":
		headshot_texture.texture = load(pilot.headshot)
		headshot_texture.visible = true
	elif headshot_texture:
		headshot_texture.visible = false

	pilot_name_label.text = pilot.name

	# Add context to sector label based on event type
	# For failure tables, show the failure_table_check_type instead
	var check_type_for_display = sector.failure_table_check_type if event_type == 5 else sector.check_type
	var check_type_str = _get_check_type_string(check_type_for_display)
	var sector_text = "Sector: %s (%s)" % [sector.sector_name, check_type_str.to_upper()]

	# Add sector tags if present
	if not sector.sector_tags.is_empty():
		var tags_str = " [" + ", ".join(sector.sector_tags) + "]"
		sector_text += tags_str

	if event_type == 0:  # WHEEL_TO_WHEEL_ROLL
		sector_text = "W2W Focus Mode - " + sector_text
	elif event_type == 5:  # RED_RESULT (Failure Table)
		sector_text = "Failure Table - " + sector_text
	sector_label.text = sector_text

	# Show pilot info with tied position if in W2W mode
	if tied_position > 0:
		pilot_info_label.text = _format_pilot_info("Tied for P%d" % tied_position, "Status: %s" % pilot.get_status_string())
	else:
		pilot_info_label.text = _format_pilot_info("Position: %d" % pilot.position, "Status: %s" % pilot.get_status_string())

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
	var resolution_text = _get_resolution_text(pilot.name, roll_result.tier_name, movement, event_type, event_metadata)
	resolution_label.text = resolution_text
	resolution_label.add_theme_font_size_override("font_size", 14)
	resolution_label.add_theme_color_override("font_color", TIER_COLORS.get(roll_result.tier_name, Color.WHITE))

## Format pilot info text with line break if too long
func _format_pilot_info(part1: String, part2: String) -> String:
	const MAX_LENGTH = 30  # Character threshold before breaking to new line
	var combined = part1 + " | " + part2

	# If combined text is too long, use a line break instead of pipe separator
	if combined.length() > MAX_LENGTH:
		return part1 + "\n" + part2
	else:
		return combined

func _calculate_potential_momentum_text(pilot: PilotState, sector, movement: int) -> String:
	# Calculate if this movement would complete the sector
	var new_gap = pilot.gap_in_sector + movement
	if new_gap >= sector.length_in_gap:
		var excess = new_gap - sector.length_in_gap
		var potential_momentum = min(excess, sector.carrythru)
		if potential_momentum > 0:
			return " (+%d momentum)" % potential_momentum
	return ""

func _get_resolution_text(pilot_name: String, tier: String, movement: int, event_type: int = -1, event_metadata: Dictionary = {}) -> String:
	# If this is a failure table event, show the consequence
	if event_type == 5 and event_metadata.has("consequence"):  # RED_RESULT
		return "%s: %s" % [pilot_name, event_metadata["consequence"]]

	# Otherwise use standard resolution text
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

func _get_check_type_string(check_type: Sector.CheckType) -> String:
	match check_type:
		Sector.CheckType.TWITCH:
			return "twitch"
		Sector.CheckType.CRAFT:
			return "craft"
		Sector.CheckType.SYNC:
			return "sync"
		Sector.CheckType.EDGE:
			return "edge"
		_:
			return "unknown"
