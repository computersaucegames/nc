extends Control
class_name FocusModeOverlay

## Focus Mode UI overlay that displays roll breakdowns for wheel-to-wheel situations
## Shows floating panels near the pilots on the circuit display

@onready var backdrop: ColorRect = $Backdrop
@onready var roll_panel_container: Control = $RollPanelContainer
@onready var continue_prompt: Label = $ContinuePrompt

# Reference to FocusMode autoload
var focus_mode_manager: Node

# Reference to the circuit display (to get pilot positions)
var circuit_display: CircuitDisplay = null

# Current event being displayed
var current_event: FocusModeManager.FocusModeEvent = null

# Stage tracking
enum DisplayStage {
	SHOWING_ROLLS,
	SHOWING_OUTCOMES
}
var current_stage: DisplayStage = DisplayStage.SHOWING_ROLLS

# Panel scene to instantiate for each pilot
var pilot_roll_panel_scene = preload("res://scenes/ui/FocusModeRollPanel.tscn")

func _ready():
	# Get reference to FocusMode autoload
	focus_mode_manager = get_node("/root/FocusMode")

	# Start hidden
	visible = false

	# Connect to Focus Mode manager
	focus_mode_manager.focus_mode_activated.connect(_on_focus_mode_activated)
	focus_mode_manager.focus_mode_deactivated.connect(_on_focus_mode_deactivated)

	# Setup input handling
	set_process_input(true)

func _input(event):
	if not visible:
		return

	# Click or spacebar to continue
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_focus_mode()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_advance_focus_mode()
		get_viewport().set_input_as_handled()

func _advance_focus_mode():
	focus_mode_manager.advance()

func _on_focus_mode_activated(event: FocusModeManager.FocusModeEvent):
	current_event = event

	# Determine stage based on whether rolls have been made
	if event.roll_results.size() == 0:
		current_stage = DisplayStage.SHOWING_ROLLS
		continue_prompt.text = "Click or press SPACE to roll"
	else:
		current_stage = DisplayStage.SHOWING_OUTCOMES
		continue_prompt.text = "Click or press SPACE to continue race"

	# Clear previous panels
	_clear_panels()

	# Create panels for each pilot
	_create_pilot_panels(event)

	# Show the overlay
	visible = true

func _on_focus_mode_deactivated():
	visible = false
	_clear_panels()
	current_event = null

func _clear_panels():
	for child in roll_panel_container.get_children():
		child.queue_free()

func _create_pilot_panels(event: FocusModeManager.FocusModeEvent):
	if circuit_display == null:
		print("WARNING: No circuit display set for FocusModeOverlay")
		return

	# Track panel positions to prevent overlaps
	var placed_panels: Array[Rect2] = []
	const PANEL_SIZE = Vector2(280, 400)
	const PANEL_BUFFER = 20.0  # Pixels of spacing between panels

	# Get pilot positions on screen
	for pilot_idx in range(event.pilots.size()):
		var pilot = event.pilots[pilot_idx]
		var pilot_id = _get_pilot_id_from_state(pilot)

		if pilot_id == -1:
			continue

		# Get screen position of the pilot on the circuit
		var screen_pos = _get_pilot_screen_position(pilot_id)
		if screen_pos == null:
			continue

		# Create panel for this pilot
		var panel = pilot_roll_panel_scene.instantiate()
		roll_panel_container.add_child(panel)

		# Position panel near the pilot (offset to avoid covering them)
		var base_offset = Vector2(60 if pilot_idx == 0 else -260, -100)
		var final_position = screen_pos + base_offset

		# Check for overlaps with existing panels and adjust if needed
		var panel_rect = Rect2(final_position, PANEL_SIZE)
		var adjusted = false
		var max_attempts = 20  # Prevent infinite loops

		for attempt in range(max_attempts):
			var overlapping = false
			for existing_rect in placed_panels:
				# Check if panels overlap (with buffer zone)
				var buffered_rect = existing_rect.grow(PANEL_BUFFER)
				if buffered_rect.intersects(panel_rect):
					overlapping = true
					break

			if not overlapping:
				break

			# Move panel down to avoid overlap
			final_position.y += PANEL_SIZE.y / 4  # Move down by quarter panel height
			panel_rect.position = final_position
			adjusted = true

		# Store this panel's rect for future overlap checks
		placed_panels.append(panel_rect)

		panel.position = final_position

		# Setup panel data
		if event.roll_results.size() > pilot_idx:
			# Show roll results
			var roll_result = event.roll_results[pilot_idx]
			var movement = event.movement_outcomes[pilot_idx]
			panel.setup_roll_display(pilot, event.sector, roll_result, movement)
		else:
			# Waiting for rolls - show pilot and sector info
			panel.setup_pre_roll_display(pilot, event.sector)

func _get_pilot_screen_position(pilot_id: int) -> Variant:
	if circuit_display == null or not circuit_display.pilot_markers.has(pilot_id):
		return null

	var path_follow: PathFollow2D = circuit_display.pilot_markers[pilot_id]
	var icon = path_follow.get_child(0) if path_follow.get_child_count() > 0 else null

	if icon == null:
		return null

	# Get global position of the icon
	return icon.global_position

func _get_pilot_id_from_state(pilot_state: PilotState) -> int:
	# Simply return the pilot_id field from the PilotState
	return pilot_state.pilot_id

## Call this from the main scene to link the circuit display
func set_circuit_display(display: CircuitDisplay):
	circuit_display = display
