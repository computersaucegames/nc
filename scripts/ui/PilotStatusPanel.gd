# PilotStatusPanel.gd
# Reusable pilot status display component
extends VBoxContainer
class_name PilotStatusPanel

var pilot_labels: Dictionary = {}
var circuit: Circuit  # Reference to track sector names

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
		if child is RichTextLabel:
			child.queue_free()
	pilot_labels.clear()
	
	# Create pilot status labels
	for data in pilot_data:
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.custom_minimum_size.y = 60
		label.fit_content = true
		add_child(label)
		pilot_labels[data.name] = label

# Set the circuit reference for sector names
func set_circuit(race_circuit: Circuit):
	circuit = race_circuit

# Update all pilot displays from a list of pilot states
func update_all_pilots(pilots: Array):
	for pilot in pilots:
		update_pilot_display(pilot)

# Update a single pilot's display
func update_pilot_display(pilot):
	if not pilot.name in pilot_labels:
		return
	
	var label = pilot_labels[pilot.name]
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
