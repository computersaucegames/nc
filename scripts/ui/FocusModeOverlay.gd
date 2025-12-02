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
	const PANEL_SIZE = Vector2(280, 450)  # Increased height to accommodate headshot
	const PANEL_BUFFER = 30.0  # Increased spacing between panels

	# Get viewport size to keep panels on screen
	var viewport_size = get_viewport_rect().size

	# Calculate tied position for W2W events
	var tied_position = -1
	if event.event_type == FocusModeManager.EventType.WHEEL_TO_WHEEL_ROLL and event.pilots.size() > 0:
		# Find the higher position between the two pilots (lower number = better position)
		var pos1 = event.pilots[0].position
		var pos2 = event.pilots[1].position if event.pilots.size() > 1 else pos1
		tied_position = min(pos1, pos2)

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

		# Try different placement positions around the pilot
		var placement_offsets = [
			Vector2(60, -150),   # Right of pilot
			Vector2(-340, -150), # Left of pilot
			Vector2(60, -300),   # Right-high
			Vector2(-340, -300), # Left-high
			Vector2(60, 0),      # Right-low
			Vector2(-340, 0),    # Left-low
		]

		var final_position = screen_pos + placement_offsets[0]
		var panel_rect = Rect2(final_position, PANEL_SIZE)
		var found_valid_position = false

		# Try each placement offset
		for offset in placement_offsets:
			final_position = screen_pos + offset
			panel_rect = Rect2(final_position, PANEL_SIZE)

			# Clamp to viewport bounds
			final_position.x = clamp(final_position.x, PANEL_BUFFER, viewport_size.x - PANEL_SIZE.x - PANEL_BUFFER)
			final_position.y = clamp(final_position.y, PANEL_BUFFER, viewport_size.y - PANEL_SIZE.y - PANEL_BUFFER)
			panel_rect.position = final_position

			# Check for overlaps
			var overlapping = false
			for existing_rect in placed_panels:
				var buffered_rect = existing_rect.grow(PANEL_BUFFER)
				if buffered_rect.intersects(panel_rect):
					overlapping = true
					break

			if not overlapping:
				found_valid_position = true
				break

		# If still overlapping, try stacking vertically with more spacing
		if not found_valid_position:
			# Stack below the last placed panel
			if placed_panels.size() > 0:
				var last_rect = placed_panels[placed_panels.size() - 1]
				final_position = Vector2(last_rect.position.x, last_rect.position.y + last_rect.size.y + PANEL_BUFFER)

				# If that goes off screen, try stacking to the side
				if final_position.y + PANEL_SIZE.y > viewport_size.y - PANEL_BUFFER:
					final_position.x = last_rect.position.x + last_rect.size.x + PANEL_BUFFER
					final_position.y = PANEL_BUFFER

					# If still off screen, wrap back to left side
					if final_position.x + PANEL_SIZE.x > viewport_size.x - PANEL_BUFFER:
						final_position.x = PANEL_BUFFER

				panel_rect.position = final_position

		# Store this panel's rect for future overlap checks
		placed_panels.append(panel_rect)

		panel.position = final_position

		# Setup panel data
		if event.roll_results.size() > pilot_idx:
			# Show roll results
			var roll_result = event.roll_results[pilot_idx]
			var movement = event.movement_outcomes[pilot_idx]
			panel.setup_roll_display(pilot, event.sector, roll_result, movement, event.event_type, tied_position)
		else:
			# Waiting for rolls - show pilot and sector info
			panel.setup_pre_roll_display(pilot, event.sector, event.event_type, tied_position)

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
