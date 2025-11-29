# DiceTestScene.gd
# Attach this to a Control node to test the dice system
extends Control

# UI References - we'll assign these in setup_ui()
var output_label: RichTextLabel
var roll_button: Button
var sector_name_label: Label
var gates_label: Label
var pilot_stats_label: Label
var modifiers_option: OptionButton

# Test data
var test_pilot = {
	"name": "Alex Nova",
	"twitch": 7,
	"craft": 5,
	"sync": 6,
	"edge": 8
}

var test_sectors = [
	{
		"name": "Harbor Chicane",
		"check_stat": "twitch",
		"gates": {"grey": 10, "green": 15, "purple": 20},
		"description": "Tight corners requiring quick reflexes"
	},
	{
		"name": "The Straight",
		"check_stat": "edge",
		"gates": {"grey": 8, "green": 14, "purple": 19},
		"description": "Full throttle section - how far do you push?"
	},
	{
		"name": "Technical Complex",
		"check_stat": "craft",
		"gates": {"grey": 12, "green": 17, "purple": 21},
		"description": "Demanding series of corners"
	},
	{
		"name": "Rain-Soaked Hairpin",
		"check_stat": "twitch",
		"gates": {"grey": 13, "green": 18, "purple": 23},
		"description": "Treacherous wet conditions"
	}
]

var current_sector_index = 0
var roll_history = []

func _ready():
	# Create UI first
	setup_ui()
	
	# Connect signals
	roll_button.pressed.connect(_on_roll_pressed)
	modifiers_option.item_selected.connect(_on_modifier_changed)
	
	# Setup initial display
	display_sector_info()
	display_pilot_info()
	setup_modifier_options()
	
	output_label.text = "[b]Welcome to Dice System Test![/b]\n"
	output_label.text += "Press 'Roll for Sector' to simulate a pilot navigating through sectors.\n\n"

func setup_ui():
	# Create the UI programmatically
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "NEBULA CIRCUIT - Dice Test"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	# Sector Info Container
	var sector_container = VBoxContainer.new()
	sector_container.name = "SectorInfo"
	vbox.add_child(sector_container)
	
	sector_name_label = Label.new()
	sector_name_label.name = "SectorNameLabel"
	sector_container.add_child(sector_name_label)
	
	gates_label = Label.new()
	gates_label.name = "GatesLabel"
	sector_container.add_child(gates_label)
	
	vbox.add_child(HSeparator.new())
	
	# Pilot Info Container
	var pilot_container = VBoxContainer.new()
	pilot_container.name = "PilotInfo"
	vbox.add_child(pilot_container)
	
	pilot_stats_label = Label.new()
	pilot_stats_label.name = "StatsLabel"
	pilot_container.add_child(pilot_stats_label)
	
	vbox.add_child(HSeparator.new())
	
	# Modifiers Container
	var mod_container = HBoxContainer.new()
	mod_container.name = "ModifiersContainer"
	vbox.add_child(mod_container)
	
	var mod_label = Label.new()
	mod_label.text = "Test Modifiers: "
	mod_container.add_child(mod_label)
	
	modifiers_option = OptionButton.new()
	modifiers_option.name = "ModifiersOption"
	mod_container.add_child(modifiers_option)
	
	# Roll Button
	roll_button = Button.new()
	roll_button.name = "RollButton"
	roll_button.text = "Roll for Sector"
	roll_button.custom_minimum_size = Vector2(200, 40)
	vbox.add_child(roll_button)
	
	vbox.add_child(HSeparator.new())
	
	# Output Label
	output_label = RichTextLabel.new()
	output_label.name = "OutputLabel"
	output_label.bbcode_enabled = true
	output_label.custom_minimum_size = Vector2(600, 400)
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(output_label)

func setup_modifier_options():
	modifiers_option.clear()
	modifiers_option.add_item("No Modifiers")
	modifiers_option.add_item("Advantage (Badge: Perfect Line)")
	modifiers_option.add_item("Disadvantage (Damaged Wing)")
	modifiers_option.add_item("+3 Bonus (Team Sync)")
	modifiers_option.add_item("Use Craft instead of Twitch")
	modifiers_option.add_item("Complex (Advantage + Sync Bonus)")
	modifiers_option.add_item("Terrible (Disadvantage + -2)")
	modifiers_option.selected = 0

func display_sector_info():
	var sector = test_sectors[current_sector_index]
	sector_name_label.text = "SECTOR %d: %s" % [current_sector_index + 1, sector.name]
	sector_name_label.add_theme_font_size_override("font_size", 18)
	
	gates_label.text = "%s | Gates: Grey %d+ | Green %d+ | Purple %d+" % [
		sector.description,
		sector.gates.grey,
		sector.gates.green,
		sector.gates.purple
	]

func display_pilot_info():
	pilot_stats_label.text = "PILOT: %s | Twitch: %d | Craft: %d | Sync: %d | Edge: %d" % [
		test_pilot.name,
		test_pilot.twitch,
		test_pilot.craft,
		test_pilot.sync,
		test_pilot.edge
	]

func _on_modifier_changed(_index: int):
	# Just for display feedback
	output_label.append_text("[color=gray]Modifier changed: %s[/color]\n" % modifiers_option.get_item_text(modifiers_option.selected))

func _on_roll_pressed():
	var sector = test_sectors[current_sector_index]
	var stat_name = sector.check_stat
	var stat_value = test_pilot[stat_name]
	
	# Build modifiers based on selection
	var modifiers = []
	match modifiers_option.selected:
		1: # Advantage
			modifiers.append(Dice.create_advantage("Perfect Line Badge"))
		2: # Disadvantage
			modifiers.append(Dice.create_disadvantage("Damaged Wing"))
		3: # +3 Bonus
			modifiers.append(Dice.create_bonus(3, "Team Sync"))
		4: # Stat replacement
			modifiers.append(Dice.create_stat_replacement("craft", test_pilot.craft, "Methodical Approach Badge"))
		5: # Complex - Advantage + Bonus
			modifiers.append(Dice.create_advantage("Perfect Line Badge"))
			modifiers.append(Dice.create_bonus(2, "Team Sync"))
		6: # Terrible - Disadvantage + Penalty
			modifiers.append(Dice.create_disadvantage("Damaged Wing"))
			modifiers.append(Dice.create_bonus(-2, "Low Morale"))
	
	# Make the roll
	var result = Dice.roll_d20(stat_value, stat_name, modifiers, sector.gates, {"sector": sector.name})
	
	# Display the results
	display_roll_result(result, sector)
	
	# Move to next sector or loop back
	current_sector_index = (current_sector_index + 1) % test_sectors.size()
	if current_sector_index == 0:
		output_label.append_text("\n[b][color=yellow]--- LAP COMPLETE ---[/color][/b]\n\n")
	display_sector_info()

func display_roll_result(result: Dice.DiceResult, sector: Dictionary):
	output_label.append_text("\n[b]%s - %s Check[/b]\n" % [sector.name, result.stat_name.to_upper()])
	
	# Show the roll breakdown
	output_label.append_text("Roll: d20(%d) + %s(%d)" % [result.base_roll, result.stat_name, result.stat_value])
	
	if result.flat_modifiers != 0:
		var sign = "+" if result.flat_modifiers > 0 else ""
		output_label.append_text(" %s%d" % [sign, result.flat_modifiers])
	
	output_label.append_text(" = %d\n" % result.final_total)
	
	# Show modifiers applied
	if result.modifiers_applied.size() > 0:
		output_label.append_text("[color=gray]Modifiers: ")
		for mod in result.modifiers_applied:
			output_label.append_text("%s | " % mod)
		output_label.append_text("[/color]\n")
	
	# Show the tier result with color
	var color_name = get_tier_color_name(result.tier)
	output_label.append_text("Result: [b][color=%s]%s[/color][/b]\n" % [color_name, result.tier_name])
	
	# Narrative result based on tier
	match result.tier:
		Dice.Tier.PURPLE:
			output_label.append_text("[color=purple]★ PERFECT EXECUTION! Gained major advantage![/color]\n")
		Dice.Tier.GREEN:
			output_label.append_text("[color=green]✓ Clean sector, maintaining position.[/color]\n")
		Dice.Tier.GREY:
			output_label.append_text("[color=gray]⚠ Struggled through sector, lost some time.[/color]\n")
		Dice.Tier.RED:
			output_label.append_text("[color=red]✗ CRITICAL ERROR! Major incident occurred![/color]\n")
			# In full game, would roll on failure table here

func get_tier_color_name(tier: Dice.Tier) -> String:
	match tier:
		Dice.Tier.RED: return "red"
		Dice.Tier.GREY: return "gray"
		Dice.Tier.GREEN: return "green"  
		Dice.Tier.PURPLE: return "purple"
	return "white"
