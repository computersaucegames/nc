# StartingGridOverlay.gd
# Displays the starting grid before the race begins
extends ColorRect
class_name StartingGridOverlay

signal begin_race_start_requested

# UI references
var grid_container: VBoxContainer
var title_label: Label
var begin_button: Button

# Data
var pilots: Array = []
var circuit: Circuit = null

func _ready():
	setup_ui()
	hide()  # Hidden by default

func setup_ui():
	# Dark semi-transparent background
	color = Color(0, 0, 0, 0.85)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Main container (centered)
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(600, 400)
	add_child(main_container)

	# Title
	title_label = Label.new()
	title_label.text = "STARTING GRID"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	main_container.add_child(title_label)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 20
	main_container.add_child(spacer1)

	# Grid display container
	grid_container = VBoxContainer.new()
	grid_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_child(grid_container)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 30
	main_container.add_child(spacer2)

	# Begin button
	begin_button = Button.new()
	begin_button.text = "BEGIN RACE START"
	begin_button.custom_minimum_size = Vector2(200, 50)
	begin_button.pressed.connect(_on_begin_pressed)

	# Center the button
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_child(begin_button)
	main_container.add_child(button_container)

# Display the grid with pilots
func show_grid(pilot_list: Array, race_circuit: Circuit):
	pilots = pilot_list
	circuit = race_circuit

	# Clear existing grid display
	for child in grid_container.get_children():
		child.queue_free()

	# Get layout data from StartHandler
	var StartHandler = preload("res://scripts/systems/RaceStartHandler.gd")
	var layout = StartHandler.get_grid_layout_data(pilots)

	# Display each row
	for row_data in layout:
		var row_container = HBoxContainer.new()
		row_container.alignment = BoxContainer.ALIGNMENT_CENTER

		# Gap label
		var gap_label = Label.new()
		gap_label.text = "Gap %d:" % row_data.gap
		gap_label.custom_minimum_size.x = 80
		gap_label.add_theme_font_size_override("font_size", 18)
		row_container.add_child(gap_label)

		# Pilot boxes in this row
		for pilot_entry in row_data.pilots:
			var pilot_box = create_pilot_box(pilot_entry.pilot, pilot_entry.grid_position)
			row_container.add_child(pilot_box)

		grid_container.add_child(row_container)

		# Add spacing between rows
		if row_data != layout[-1]:
			var spacer = Control.new()
			spacer.custom_minimum_size.y = 15
			grid_container.add_child(spacer)

	show()

# Create a visual box for a pilot
func create_pilot_box(pilot: PilotState, grid_pos: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 80)

	# Add a StyleBox for visual appeal
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 1.0)
	style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	style.border_width_all = 2
	style.corner_radius_all = 5
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Position label
	var pos_label = Label.new()
	pos_label.text = "P%d" % grid_pos
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_label.add_theme_font_size_override("font_size", 16)
	pos_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	vbox.add_child(pos_label)

	# Pilot name
	var name_label = Label.new()
	name_label.text = pilot.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)

	# Stats label
	var stats_label = Label.new()
	stats_label.text = "Twitch: %d" % pilot.twitch
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1.0))
	vbox.add_child(stats_label)

	return panel

# Handle begin button press
func _on_begin_pressed():
	hide()
	begin_race_start_requested.emit()
