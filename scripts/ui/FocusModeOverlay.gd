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
	print("DEBUG [FocusOverlay]: _on_focus_mode_activated called, event_type: %d" % event.event_type)
	current_event = event

	# Determine stage based on whether rolls have been made
	if event.roll_results.size() == 0:
		current_stage = DisplayStage.SHOWING_ROLLS
		continue_prompt.text = "Click or press SPACE to roll"
		print("DEBUG [FocusOverlay]: Stage = SHOWING_ROLLS")
	else:
		current_stage = DisplayStage.SHOWING_OUTCOMES
		continue_prompt.text = "Click or press SPACE to continue race"
		print("DEBUG [FocusOverlay]: Stage = SHOWING_OUTCOMES, rolls: %d" % event.roll_results.size())

	# Clear previous panels
	_clear_panels()

	# Create panels for each pilot
	print("DEBUG [FocusOverlay]: Creating pilot panels for %d pilots" % event.pilots.size())
	_create_pilot_panels(event)

	# Show the overlay
	visible = true
	print("DEBUG [FocusOverlay]: Overlay now visible")

func _on_focus_mode_deactivated():
	visible = false
	_clear_panels()
	current_event = null

func _clear_panels():
	for child in roll_panel_container.get_children():
		child.queue_free()

func _create_pilot_panels(event: FocusModeManager.FocusModeEvent):
	const PANEL_SIZE = Vector2(280, 450)  # Increased height to accommodate headshot
	const PANEL_SPACING = 40.0  # Horizontal spacing between panels
	const BOTTOM_MARGIN = 80.0  # Space from bottom of screen (to leave room for continue prompt)
	const SIDE_MARGIN = 20.0  # Space from sides of screen

	# Get viewport size
	var viewport_size = get_viewport_rect().size

	# Special handling for PIT_STOP events
	if event.event_type == FocusModeManager.EventType.PIT_STOP:
		_create_pit_stop_panel(event, viewport_size, PANEL_SIZE, BOTTOM_MARGIN)
		return

	# Calculate tied position for W2W events
	var tied_position = -1
	if event.event_type == FocusModeManager.EventType.WHEEL_TO_WHEEL_ROLL and event.pilots.size() > 0:
		# Find the higher position between the two pilots (lower number = better position)
		var pos1 = event.pilots[0].position
		var pos2 = event.pilots[1].position if event.pilots.size() > 1 else pos1
		tied_position = min(pos1, pos2)

	# Calculate total width needed for all panels
	var num_panels = event.pilots.size()
	var total_width = (num_panels * PANEL_SIZE.x) + ((num_panels - 1) * PANEL_SPACING)

	# Calculate starting X position to center the panels
	var start_x = (viewport_size.x - total_width) / 2.0

	# Clamp to ensure panels don't go off screen
	start_x = max(start_x, SIDE_MARGIN)

	# Calculate Y position (bottom of screen, with margin)
	var panel_y = viewport_size.y - PANEL_SIZE.y - BOTTOM_MARGIN

	# Create panels for each pilot, arranged horizontally at the bottom
	for pilot_idx in range(event.pilots.size()):
		var pilot = event.pilots[pilot_idx]
		var pilot_id = _get_pilot_id_from_state(pilot)

		# Create panel for this pilot
		var panel = pilot_roll_panel_scene.instantiate()
		roll_panel_container.add_child(panel)

		# Calculate position for this panel
		var panel_x = start_x + (pilot_idx * (PANEL_SIZE.x + PANEL_SPACING))

		# Ensure panel doesn't go off the right edge
		if panel_x + PANEL_SIZE.x > viewport_size.x - SIDE_MARGIN:
			panel_x = viewport_size.x - PANEL_SIZE.x - SIDE_MARGIN

		panel.position = Vector2(panel_x, panel_y)

		# Setup panel data
		if event.roll_results.size() > pilot_idx:
			# Show roll results
			var roll_result = event.roll_results[pilot_idx]
			var movement = event.movement_outcomes[pilot_idx]
			panel.setup_roll_display(pilot, event.sector, roll_result, movement, event.event_type, tied_position, event.metadata)
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

## Create a centered panel for pit stop events
func _create_pit_stop_panel(event: FocusModeManager.FocusModeEvent, viewport_size: Vector2, panel_size: Vector2, bottom_margin: float):
	print("DEBUG [FocusOverlay]: _create_pit_stop_panel called")
	if event.pilots.size() == 0:
		print("DEBUG [FocusOverlay]: ERROR - No pilots in event!")
		return

	var pilot = event.pilots[0]
	print("DEBUG [FocusOverlay]: Pilot: %s, Sector: %s" % [pilot.name, event.sector.sector_name if event.sector else "NULL"])

	# Create panel for pit stop
	var panel = pilot_roll_panel_scene.instantiate()
	roll_panel_container.add_child(panel)
	print("DEBUG [FocusOverlay]: Panel instantiated and added to container")

	# Center the panel
	var panel_x = (viewport_size.x - panel_size.x) / 2.0
	var panel_y = viewport_size.y - panel_size.y - bottom_margin

	panel.position = Vector2(panel_x, panel_y)
	print("DEBUG [FocusOverlay]: Panel positioned at (%f, %f)" % [panel_x, panel_y])

	# Setup panel data
	if event.roll_results.size() > 0:
		# Show roll results
		print("DEBUG [FocusOverlay]: Setting up roll display (has results)")
		var roll_result = event.roll_results[0]
		var movement = 0  # Pit stops don't have normal movement
		panel.setup_roll_display(pilot, event.sector, roll_result, movement, event.event_type, -1, event.metadata)
	else:
		# Waiting for rolls - show pilot and sector info
		print("DEBUG [FocusOverlay]: Setting up pre-roll display (no results yet)")
		panel.setup_pre_roll_display(pilot, event.sector, event.event_type, -1)

	print("DEBUG [FocusOverlay]: Panel setup complete")

## Call this from the main scene to link the circuit display
func set_circuit_display(display: CircuitDisplay):
	circuit_display = display
