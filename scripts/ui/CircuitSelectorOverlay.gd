# CircuitSelectorOverlay.gd
# Displays available circuits for selection before a race
extends ColorRect
class_name CircuitSelectorOverlay

signal circuit_selected(circuit: Circuit)

# UI references
var circuit_list_container: VBoxContainer
var title_label: Label
var selected_circuit: Circuit = null

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
	main_container.custom_minimum_size = Vector2(600, 500)
	add_child(main_container)

	# Title
	title_label = Label.new()
	title_label.text = "SELECT CIRCUIT"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	main_container.add_child(title_label)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 30
	main_container.add_child(spacer1)

	# Circuit list container
	circuit_list_container = VBoxContainer.new()
	circuit_list_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_child(circuit_list_container)

# Display available circuits
func show_circuits():
	# Clear existing circuit display
	for child in circuit_list_container.get_children():
		child.queue_free()

	# Load all available circuits
	var circuits: Array[Circuit] = []

	# Add pizza circuit
	var pizza_circuit = load("res://resources/circuits/pizza_circuit.tres") as Circuit
	if pizza_circuit:
		circuits.append(pizza_circuit)

	# Add test circuits from CircuitLoader
	var test_circuits = CircuitLoader.get_test_circuits()
	circuits.append_array(test_circuits)

	# Display each circuit
	for circuit in circuits:
		var circuit_button = create_circuit_button(circuit)
		circuit_list_container.add_child(circuit_button)

		# Add spacing between buttons
		if circuit != circuits[-1]:
			var spacer = Control.new()
			spacer.custom_minimum_size.y = 15
			circuit_list_container.add_child(spacer)

	show()

# Create a button for a circuit
func create_circuit_button(circuit: Circuit) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 100)

	# Add a StyleBox for visual appeal
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 1.0)
	style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(hbox)

	# Circuit info (left side)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Circuit name
	var name_label = Label.new()
	name_label.text = circuit.circuit_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)

	# Circuit details
	var details_text = ""
	if circuit.country != "":
		details_text += circuit.country + " • "
	details_text += "%d Laps • %d Sectors" % [circuit.total_laps, circuit.sectors.size()]

	var details_label = Label.new()
	details_label.text = details_text
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	details_label.add_theme_font_size_override("font_size", 16)
	details_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1.0))
	vbox.add_child(details_label)

	hbox.add_child(vbox)

	# Select button (right side)
	var select_button = Button.new()
	select_button.text = "SELECT"
	select_button.custom_minimum_size = Vector2(120, 50)
	select_button.pressed.connect(_on_circuit_selected.bind(circuit))
	hbox.add_child(select_button)

	return panel

# Handle circuit selection
func _on_circuit_selected(circuit: Circuit):
	selected_circuit = circuit
	hide()
	circuit_selected.emit(circuit)
