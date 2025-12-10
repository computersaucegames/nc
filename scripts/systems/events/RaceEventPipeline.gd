class_name RaceEventPipeline extends RefCounted

## Event pipeline that processes race events through registered handlers
##
## The pipeline:
## 1. Receives events from the race orchestrator
## 2. Routes them to registered handlers in priority order
## 3. Allows handlers to modify or cancel events
## 4. Returns the processed event
##
## Usage:
##   var pipeline = RaceEventPipeline.new()
##   pipeline.add_handler(BadgeHandler.new())
##   pipeline.add_handler(LoggingHandler.new())
##   var event = RaceEvent.new(RaceEvent.Type.ROLL_COMPLETE, pilot)
##   pipeline.process_event(event)

## All registered handlers, sorted by priority
var handlers: Array[RaceEventHandler] = []

## Whether the pipeline is currently processing an event (prevents recursion)
var _is_processing: bool = false

## Event processing statistics (for debugging/profiling)
var stats: Dictionary = {
	"events_processed": 0,
	"events_cancelled": 0,
	"handlers_executed": 0,
}

## Constructor
func _init():
	pass

## Add a handler to the pipeline
func add_handler(handler: RaceEventHandler) -> void:
	if handler in handlers:
		push_warning("RaceEventPipeline: Handler '%s' already registered" % handler.handler_name)
		return

	handlers.append(handler)
	_sort_handlers()
	handler.on_registered(self)

## Remove a handler from the pipeline
func remove_handler(handler: RaceEventHandler) -> void:
	if handler not in handlers:
		push_warning("RaceEventPipeline: Handler '%s' not found" % handler.handler_name)
		return

	handlers.erase(handler)
	handler.on_unregistered(self)

## Remove all handlers
func clear_handlers() -> void:
	for handler in handlers:
		handler.on_unregistered(self)
	handlers.clear()

## Process an event through all handlers
func process_event(event: RaceEvent) -> RaceEvent:
	if _is_processing:
		push_error("RaceEventPipeline: Recursive event processing detected! Event: %s" % event.get_description())
		return event

	_is_processing = true
	stats["events_processed"] += 1

	# Process through each handler in priority order
	for handler in handlers:
		# Skip disabled handlers
		if not handler.enabled:
			continue

		# Check if handler wants to process this event
		if not handler.can_handle(event):
			continue

		# Execute handler
		stats["handlers_executed"] += 1
		handler.handle(event)

		# If event was cancelled, stop processing
		if event.is_cancelled():
			stats["events_cancelled"] += 1
			break

	_is_processing = false
	return event

## Get all handlers that can handle a specific event type
func get_handlers_for_type(event_type: RaceEvent.Type) -> Array[RaceEventHandler]:
	var matching_handlers: Array[RaceEventHandler] = []
	var test_event = RaceEvent.new(event_type)

	for handler in handlers:
		if handler.can_handle(test_event):
			matching_handlers.append(handler)

	return matching_handlers

## Enable/disable a specific handler by name
func set_handler_enabled(handler_name: String, enabled: bool) -> void:
	for handler in handlers:
		if handler.handler_name == handler_name:
			handler.enabled = enabled
			return

	push_warning("RaceEventPipeline: Handler '%s' not found" % handler_name)

## Get handler by name
func get_handler(handler_name: String) -> RaceEventHandler:
	for handler in handlers:
		if handler.handler_name == handler_name:
			return handler
	return null

## Get statistics about pipeline usage
func get_stats() -> Dictionary:
	return stats.duplicate()

## Reset statistics
func reset_stats() -> void:
	stats = {
		"events_processed": 0,
		"events_cancelled": 0,
		"handlers_executed": 0,
	}

## Sort handlers by priority (lower priority first)
func _sort_handlers() -> void:
	handlers.sort_custom(func(a, b): return a.priority < b.priority)

## Debug: Print all registered handlers
func print_handlers() -> void:
	print("=== RaceEventPipeline Handlers ===")
	for i in range(handlers.size()):
		var h = handlers[i]
		var status = "ENABLED" if h.enabled else "DISABLED"
		print("  [%d] %s (priority: %d) - %s" % [i, h.handler_name, h.priority, status])
	print("===================================")
