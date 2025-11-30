# PilotStatusPanel.gd
# Reusable pilot status display component
extends VBoxContainer
class_name PilotStatusPanel

var pilot_labels: Dictionary = {}
var circuit: Circuit  # Reference to track sector names

# Pod racer sprites for pilot icons (matching CircuitDisplay)
const POD_SPRITES = [
	"res://resources/art/classic-Recovered.png",
	"res://resources/art/bigblue-Recovered.png",
	"res://resources/art/3 wide-Recovered.png",
	"res://resources/art/pod-Recovered.png",
]

# Colors to modulate pods (matching CircuitDisplay)
const PILOT_COLORS = [
	Color.WHITE,          # 1st - classic (red)
	Color.WHITE,          # 2nd - bigblue (blue)
	Color.WHITE,          # 3rd - 3 wide (red/orange)
	Color.CORAL,          # 4th - pod (yellow) with coral tint
	Color.HOT_PINK,       # 5th - classic + pink tint
	Color.LAWN_GREEN,     # 6th - bigblue + green tint
	Color.PURPLE,         # 7th - 3 wide + purple tint
	Color.CYAN            # 8th - pod + cyan tint
]

func _ready():
	setup_ui()

func setup_ui():
	# Set minimum width for better visibility
	custom_minimum_size.x = 450
	# Title
	var status_title = Label.new()
	status_title.text = "RACE POSITIONS"
	status_title.add_theme_font_size_override("font_size", 18)
	add_child(status_title)

# Initialize pilot labels for a list of pilots
func setup_pilots(pilot_data: Array):
	# Clear existing labels
	for child in get_children():
		if child is HBoxContainer:
			child.queue_free()
	pilot_labels.clear()

	# Create pilot status labels with sprites
	for p_idx in range(pilot_data.size()):
		var data = pilot_data[p_idx]

		# Create horizontal container for sprite + text
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size.y = 60

		# Add sprite
		var sprite = TextureRect.new()
		sprite.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.custom_minimum_size = Vector2(24, 24)
		sprite.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pod_index = p_idx % POD_SPRITES.size()
		sprite.texture = load(POD_SPRITES[pod_index])
		sprite.modulate = PILOT_COLORS[p_idx % PILOT_COLORS.size()]
		hbox.add_child(sprite)

		# Add label
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.custom_minimum_size.y = 60
		label.fit_content = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)

		add_child(hbox)
		pilot_labels[data.name] = {"container": hbox, "label": label, "sprite": sprite}

# Set the circuit reference for sector names
func set_circuit(race_circuit: Circuit):
	circuit = race_circuit

# Update all pilot displays from a list of pilot states
func update_all_pilots(pilots: Array):
	# Sort pilots by position (ascending - 1st place at top)
	var sorted_pilots = pilots.duplicate()
	sorted_pilots.sort_custom(func(a, b): return a.position < b.position)

	# Reorder labels to match sorted order with animation
	for i in range(sorted_pilots.size()):
		var pilot = sorted_pilots[i]
		if pilot.name in pilot_labels:
			var container = pilot_labels[pilot.name]["container"]
			var current_index = container.get_index()
			var target_index = i + 1  # +1 to account for title label

			# If position changed, animate the movement
			if current_index != target_index:
				animate_position_change(container)
				move_child(container, target_index)

	# Update display content for all pilots
	for pilot in sorted_pilots:
		update_pilot_display(pilot)

# Update a single pilot's display
func update_pilot_display(pilot):
	if not pilot.name in pilot_labels:
		return

	var label = pilot_labels[pilot.name]["label"]
	var color = get_position_color(pilot.position)
	
	var sector_name = ""
	if circuit and pilot.current_sector < circuit.sectors.size():
		sector_name = circuit.sectors[pilot.current_sector].sector_name
	
	label.clear()
	label.append_text("[b][color=%s]P%d - %s[/color][/b]\n" % [color, pilot.position, pilot.name])
	
	if pilot.finished:
		label.append_text("[color=green]FINISHED - Victory Lap![/color]\n")
	else:
		label.append_text("Lap %d/%d | Sector: %s\n" % [
			pilot.current_lap, circuit.total_laps, sector_name
		])
		label.append_text("Progress: %d Gap | Status: %s" % [
			pilot.gap_in_sector, pilot.get_status_string()
		])
		
		# Add color coding for status
		if pilot.is_in_train:
			label.append_text(" [color=red]⚠[/color]")
		elif pilot.is_wheel_to_wheel:
			label.append_text(" [color=orange]⚔[/color]")
		elif pilot.is_attacking:
			label.append_text(" [color=yellow]→[/color]")
		elif pilot.is_defending:
			label.append_text(" [color=cyan]←[/color]")

# Get color based on position
func get_position_color(position: int) -> String:
	match position:
		1: return "gold"
		2: return "silver"
		3: return "orange"
	return "white"

# Animate a pilot label when its position changes
func animate_position_change(container: HBoxContainer):
	# Get the label from the container (not the sprite, to avoid modulate conflicts)
	var label = container.get_child(1) if container.get_child_count() > 1 else null
	if label == null:
		return

	# Create a brief highlight animation to show movement
	var tween = create_tween()
	tween.set_parallel(true)

	# Flash effect with a bright highlight (only on the label, not the sprite)
	label.modulate = Color(1.5, 1.5, 1.0)  # Bright yellow
	tween.tween_property(label, "modulate", Color.WHITE, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Scale pulse effect on the whole container
	var original_scale = container.scale
	container.scale = Vector2(1.02, 1.02)  # Reduced from 1.05 to prevent overflow
	tween.tween_property(container, "scale", original_scale, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
