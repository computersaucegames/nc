class_name FocusSequence extends RefCounted

## Base class for multi-stage Focus Mode sequences
##
## A Focus Mode sequence represents a multi-step interactive flow that pauses
## the race and requires user input to advance through stages.
##
## Examples:
## - Race start: Show grid → Execute rolls → Apply movement
## - W2W failure: Roll both → Failure table → Avoidance save → Apply movement
## - Red result: Failure table → Apply movement
## - Pit stop (future): Enter pit → Choose tires → Choose fuel → Exit pit
##
## Each sequence manages its own state and defines the stages to execute.

## Result of executing a stage
class StageResult extends RefCounted:
	## Whether the sequence should continue to the next stage
	var continue_sequence: bool = true

	## Whether to exit Focus Mode immediately (overrides continue_sequence)
	var exit_focus_mode: bool = false

	## Signal name to emit (optional)
	var emit_signal: String = ""

	## Data to include with the signal
	var signal_data: Dictionary = {}

	## Whether this stage requires user input to advance
	var requires_user_input: bool = true

	## Error message if stage failed
	var error: String = ""

## Sequence metadata and state
var sequence_name: String = "BaseSequence"
var current_stage: int = 0
var context: Dictionary = {}  # Sequence-specific state
var completed: bool = false
var failed: bool = false

## The FocusModeEvent that triggered this sequence (for compatibility)
var focus_event: FocusModeManager.FocusModeEvent

## Constructor
func _init(event: FocusModeManager.FocusModeEvent = null):
	focus_event = event
	if event:
		_initialize_from_event(event)

## Initialize sequence state from the triggering event
## Override this to extract data from the event into context
func _initialize_from_event(event: FocusModeManager.FocusModeEvent) -> void:
	# Base implementation: store event metadata
	context = event.metadata.duplicate()

## Get the total number of stages in this sequence
## Override this to define your sequence length
func get_stage_count() -> int:
	return 1  # Base implementation

## Get a human-readable name for the current stage
## Override this to provide stage descriptions
func get_stage_name(stage: int) -> String:
	return "Stage %d" % (stage + 1)

## Execute a specific stage
## Override this to implement stage behavior
func execute_stage(stage: int) -> StageResult:
	var result = StageResult.new()
	result.error = "execute_stage() not implemented for %s" % sequence_name
	result.continue_sequence = false
	result.exit_focus_mode = true
	push_warning("FocusSequence.execute_stage() called on base class - did you forget to override?")
	return result

## Check if sequence can advance to the next stage
func can_advance() -> bool:
	return not completed and not failed and current_stage < get_stage_count()

## Advance to the next stage and execute it
func advance() -> StageResult:
	if not can_advance():
		var result = StageResult.new()
		result.continue_sequence = false
		result.exit_focus_mode = true
		result.error = "Cannot advance - sequence is complete or failed"
		return result

	var result = execute_stage(current_stage)

	if result.error != "":
		failed = true
		result.continue_sequence = false
		result.exit_focus_mode = true
		push_error("FocusSequence error in %s stage %d: %s" % [sequence_name, current_stage, result.error])
		return result

	# Move to next stage if continuing
	if result.continue_sequence and not result.exit_focus_mode:
		current_stage += 1

		# Check if we've reached the end
		if current_stage >= get_stage_count():
			completed = true
			result.continue_sequence = false
			result.exit_focus_mode = true

	return result

## Reset the sequence to the beginning
func reset() -> void:
	current_stage = 0
	completed = false
	failed = false
	context.clear()

## Get sequence progress (0.0 to 1.0)
func get_progress() -> float:
	var total = get_stage_count()
	if total == 0:
		return 1.0
	return float(current_stage) / float(total)

## Check if sequence is complete
func is_complete() -> bool:
	return completed

## Check if sequence has failed
func has_failed() -> bool:
	return failed

## Get context data (with optional default)
func get_context(key: String, default = null):
	return context.get(key, default)

## Set context data
func set_context(key: String, value) -> void:
	context[key] = value

## Check if context has a key
func has_context(key: String) -> bool:
	return key in context

## Helper: Get pilots from the focus event
func get_pilots() -> Array:
	if focus_event:
		return focus_event.pilots
	return []

## Helper: Get primary pilot (first pilot in the event)
func get_pilot():
	var pilots = get_pilots()
	return pilots[0] if pilots.size() > 0 else null

## Helper: Get secondary pilot (second pilot in the event)
func get_other_pilot():
	var pilots = get_pilots()
	return pilots[1] if pilots.size() > 1 else null

## Helper: Get sector from the focus event
func get_sector():
	if focus_event:
		return focus_event.sector
	return null

## Debug: Print sequence state
func print_state() -> void:
	print("=== FocusSequence: %s ===" % sequence_name)
	print("  Stage: %d / %d (%s)" % [current_stage, get_stage_count(), get_stage_name(current_stage)])
	print("  Progress: %.1f%%" % (get_progress() * 100))
	print("  Status: %s" % ("COMPLETE" if completed else ("FAILED" if failed else "IN PROGRESS")))
	print("  Context keys: %s" % str(context.keys()))
	print("========================")
