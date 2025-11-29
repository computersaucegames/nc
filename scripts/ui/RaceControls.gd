# RaceControls.gd
# Reusable race control panel component
extends HBoxContainer
class_name RaceControls

signal start_pressed
signal pause_pressed
signal speed_changed(value: float)

var start_button: Button
var pause_button: Button
var speed_slider: HSlider
var speed_label: Label

func _ready():
	setup_ui()

func setup_ui():
	# Start button
	start_button = Button.new()
	start_button.text = "Start Race"
	start_button.pressed.connect(_on_start_pressed)
	add_child(start_button)
	
	# Pause button
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(_on_pause_pressed)
	pause_button.disabled = true
	add_child(pause_button)
	
	# Separator
	add_child(VSeparator.new())
	
	# Speed controls container
	var speed_container = HBoxContainer.new()
	add_child(speed_container)
	
	# Speed label
	var speed_text = Label.new()
	speed_text.text = "Speed: "
	speed_container.add_child(speed_text)
	
	# Speed slider
	speed_slider = HSlider.new()
	speed_slider.min_value = 0.5
	speed_slider.max_value = 3.0
	speed_slider.value = 1.5
	speed_slider.step = 0.1
	speed_slider.custom_minimum_size.x = 150
	speed_slider.value_changed.connect(_on_speed_changed)
	speed_container.add_child(speed_slider)
	
	# Speed value label
	speed_label = Label.new()
	speed_label.text = "1.5s"
	speed_container.add_child(speed_label)

# Enable/disable pause button (called when race starts/ends)
func set_pause_enabled(enabled: bool):
	pause_button.disabled = not enabled

# Update pause button text based on state
func set_pause_text(paused: bool):
	pause_button.text = "Resume" if paused else "Pause"

# Get current speed value
func get_speed_value() -> float:
	return speed_slider.value

# Set speed value programmatically
func set_speed_value(value: float):
	speed_slider.value = value
	speed_label.text = "%.1fs" % value

# Signal handlers
func _on_start_pressed():
	start_pressed.emit()

func _on_pause_pressed():
	pause_pressed.emit()

func _on_speed_changed(value: float):
	speed_label.text = "%.1fs" % value
	speed_changed.emit(value)
