# FocusModeManager.gd
# Autoload singleton to manage Focus Mode state and events
extends Node
class_name FocusModeManager

# Focus Mode signals
signal focus_mode_activated(event_data: FocusModeEvent)
signal focus_mode_deactivated()
signal focus_mode_advance_requested()  # Player clicked to continue

# Focus Mode state
var is_active: bool = false
var current_event: FocusModeEvent = null
var config: FocusModeConfig = null

# Event types
enum EventType {
	WHEEL_TO_WHEEL_ROLL,
	OVERTAKE_ATTEMPT,
	RACE_START,
	FINAL_LAP,
	PHOTO_FINISH
}

# Focus Mode Event data structure
class FocusModeEvent:
	var event_type: EventType
	var pilots: Array = []  # Array of PilotState
	var roll_results: Array = []  # Array of Dice.DiceResult
	var sector = null  # Current sector being rolled
	var movement_outcomes: Array = []  # Movement results after rolls
	var metadata: Dictionary = {}  # Additional context

	func _init(type: EventType):
		event_type = type

# Initialize with default config
func _ready():
	if config == null:
		config = FocusModeConfig.new()

# Activate Focus Mode with event data
func activate(event: FocusModeEvent) -> void:
	if not should_trigger(event):
		return

	is_active = true
	current_event = event
	focus_mode_activated.emit(event)

# Deactivate Focus Mode
func deactivate() -> void:
	is_active = false
	current_event = null
	focus_mode_deactivated.emit()

# Player advanced through Focus Mode (clicked continue)
func advance() -> void:
	focus_mode_advance_requested.emit()

# Check if this event should trigger Focus Mode based on config
func should_trigger(event: FocusModeEvent) -> bool:
	if config == null:
		return false

	match event.event_type:
		EventType.WHEEL_TO_WHEEL_ROLL:
			return config.enable_wheel_to_wheel
		EventType.OVERTAKE_ATTEMPT:
			return config.enable_overtakes
		EventType.RACE_START:
			return config.enable_race_start
		EventType.FINAL_LAP:
			return config.enable_final_lap
		EventType.PHOTO_FINISH:
			return config.enable_photo_finish

	return false

# Helper to create W2W event
func create_wheel_to_wheel_event(pilot1, pilot2, sector) -> FocusModeEvent:
	var event = FocusModeEvent.new(EventType.WHEEL_TO_WHEEL_ROLL)
	event.pilots = [pilot1, pilot2]
	event.sector = sector
	event.metadata["position_context"] = "Wheel-to-wheel"
	return event

# Helper to create overtake event
func create_overtake_event(attacker, defender, sector) -> FocusModeEvent:
	var event = FocusModeEvent.new(EventType.OVERTAKE_ATTEMPT)
	event.pilots = [attacker, defender]
	event.sector = sector
	event.metadata["position_context"] = "Overtake attempt"
	return event
