class_name RaceEventHandler extends RefCounted

## Base class for all race event handlers
##
## Handlers process events as they flow through the pipeline.
## They can:
## - Observe events (logging, UI updates)
## - Modify events (change data, add effects)
## - Cancel events (prevent default behavior)
##
## Handlers are executed in priority order (lower priority = earlier execution)

## Priority for handler execution (lower = earlier)
## Common priorities:
##   0-99: Pre-processing (validation, setup)
##   100-199: Core game logic (badge evaluation, movement calculation)
##   200-299: Post-processing (UI updates, logging)
var priority: int = 100

## Name of this handler (for debugging)
var handler_name: String = "BaseHandler"

## Whether this handler is currently enabled
var enabled: bool = true

## Constructor
func _init():
	pass

## Check if this handler should process the given event
## Override this to filter events by type
func can_handle(event: RaceEvent) -> bool:
	# Base implementation: handle all events
	# Subclasses should override to filter by event type
	return enabled

## Handle the event
## Override this to implement handler behavior
func handle(event: RaceEvent) -> void:
	# Base implementation does nothing
	# Subclasses MUST override this
	push_warning("RaceEventHandler.handle() called on base class - did you forget to override?")

## Called when handler is added to pipeline
func on_registered(pipeline) -> void:
	pass

## Called when handler is removed from pipeline
func on_unregistered(pipeline) -> void:
	pass

## Helper: Check if event is of specific type
func is_event_type(event: RaceEvent, type: RaceEvent.Type) -> bool:
	return event.type == type

## Helper: Check if event is one of multiple types
func is_event_type_in(event: RaceEvent, types: Array) -> bool:
	return event.type in types
