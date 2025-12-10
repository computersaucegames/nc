class_name RaceEvent extends RefCounted

## Base class for all race events that flow through the event pipeline
##
## Events represent discrete moments in the race simulation that can be:
## - Observed by handlers (logging, UI updates, badge evaluation)
## - Modified by handlers (add penalties, change movement, cancel actions)
## - Cancelled to prevent default behavior

## Event types representing all significant moments in a race
enum Type {
	## Race lifecycle events
	RACE_STARTED,           # Race has begun
	RACE_FINISHED,          # Race has ended
	ROUND_STARTED,          # New round begins

	## Pilot turn events
	PILOT_TURN_START,       # Pilot's turn is beginning
	PILOT_TURN_END,         # Pilot's turn is complete

	## Rolling and calculation events
	ROLL_REQUESTED,         # About to roll dice (can modify roll)
	ROLL_COMPLETE,          # Dice roll finished (can modify result)
	BADGE_EVALUATED,        # Badges evaluated for modifiers

	## Movement events
	MOVEMENT_CALCULATED,    # Base movement determined (can modify)
	PENALTY_APPLIED,        # Penalty being applied to movement
	MOVEMENT_BLOCKED,       # Movement prevented (capacity/overtake)
	MOVEMENT_APPLIED,       # Movement has been applied

	## Position and status events
	POSITION_CHANGED,       # Pilot changed position
	STATUS_CHANGED,         # Pilot status flags updated
	SECTOR_COMPLETED,       # Pilot completed a sector
	LAP_COMPLETED,          # Pilot completed a lap

	## Combat and interaction events
	OVERTAKE_DETECTED,      # Potential overtake identified
	OVERTAKE_ATTEMPTED,     # Contested roll happening
	OVERTAKE_RESOLVED,      # Overtake completed or blocked
	W2W_DETECTED,           # Wheel-to-wheel situation found

	## Failure and damage events
	RED_RESULT,             # Red roll result (failure)
	FAILURE_TABLE_ROLL,     # Rolling on failure table
	CRASH,                  # Pilot crashed (DNF)
	NEGATIVE_BADGE_APPLIED, # Temporary negative badge added

	## Focus Mode events
	FOCUS_MODE_ENTERED,     # Entering Focus Mode
	FOCUS_MODE_STAGE,       # Focus Mode stage advanced
	FOCUS_MODE_EXITED,      # Exiting Focus Mode

	## Future expansion events (placeholders)
	PIT_ENTRY_REQUESTED,    # Pilot requesting pit stop
	PIT_EXIT_COMPLETE,      # Pilot leaving pit lane
	DECISION_REQUIRED,      # User decision needed
	TIRE_DEGRADED,          # Tire condition changed
	FUEL_CONSUMED,          # Fuel level changed
	TEAM_ORDER_ISSUED,      # Team giving driver orders
}

## The type of event
var type: Type

## Primary pilot involved in this event (if applicable)
var pilot: PilotState

## Secondary pilot (for W2W, overtakes, etc.)
var other_pilot: PilotState

## Additional event data (flexible dictionary for event-specific data)
var data: Dictionary = {}

## Whether this event has been cancelled
var cancelled: bool = false

## The round number when this event occurred
var round_number: int = 0

## Constructor
func _init(event_type: Type, primary_pilot: PilotState = null):
	type = event_type
	pilot = primary_pilot

## Cancel this event to prevent default behavior
func cancel() -> void:
	cancelled = true

## Check if event is cancelled
func is_cancelled() -> bool:
	return cancelled

## Set additional data for this event
func set_data(key: String, value) -> RaceEvent:
	data[key] = value
	return self  # Chain calls

## Get data from event (with optional default)
func get_data(key: String, default = null):
	return data.get(key, default)

## Check if event has specific data key
func has_data(key: String) -> bool:
	return key in data

## Get a human-readable description of this event (for logging/debugging)
func get_description() -> String:
	var desc = Type.keys()[type]
	if pilot:
		desc += " [%s]" % pilot.name
	if other_pilot:
		desc += " vs [%s]" % other_pilot.name
	return desc
