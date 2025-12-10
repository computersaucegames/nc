extends Node

## Integration tests for race simulation system
##
## These tests capture the current behavior of the race simulation
## to ensure refactoring doesn't break existing functionality.
##
## Run this in Godot to verify the race system works correctly.

var race_sim: RaceSimulator
var test_circuit: Circuit
var test_pilots: Array = []

# Signal tracking for verification
var signals_received: Dictionary = {}

func _ready():
	print("\n=== RACE SIMULATION INTEGRATION TESTS ===\n")

	test_event_system_basics()
	test_focus_sequence_basics()
	test_race_simulation_signals()
	test_race_lifecycle()

	print("\n=== ALL INTEGRATION TESTS COMPLETE ===\n")
	# Auto-quit after tests (for CI)
	# get_tree().quit()

## Test 1: Event System Basics
func test_event_system_basics():
	print("TEST 1: Event System Basics...")

	# Create event
	var pilot = PilotState.new()
	pilot.name = "Test Pilot"
	var event = RaceEvent.new(RaceEvent.Type.ROLL_COMPLETE, pilot)
	event.set_data("roll_value", 15)

	assert(event.type == RaceEvent.Type.ROLL_COMPLETE, "Event type should be set")
	assert(event.pilot == pilot, "Pilot should be set")
	assert(event.get_data("roll_value") == 15, "Event data should be accessible")
	assert(not event.is_cancelled(), "Event should not be cancelled initially")

	# Test cancellation
	event.cancel()
	assert(event.is_cancelled(), "Event should be cancelled after cancel()")

	print("  ✓ RaceEvent creation and data access")
	print("  ✓ Event cancellation")

	# Create pipeline
	var pipeline = RaceEventPipeline.new()
	assert(pipeline != null, "Pipeline should be created")

	# Create a test handler
	var handler = TestEventHandler.new()
	handler.handler_name = "TestHandler"
	handler.priority = 100

	pipeline.add_handler(handler)
	assert(pipeline.handlers.size() == 1, "Handler should be added")

	# Process event through pipeline
	var test_event = RaceEvent.new(RaceEvent.Type.PILOT_TURN_START, pilot)
	pipeline.process_event(test_event)

	assert(handler.handled_count == 1, "Handler should process event")
	print("  ✓ RaceEventPipeline creation and handler registration")
	print("  ✓ Event processing through pipeline")

	# Test handler priority
	var handler2 = TestEventHandler.new()
	handler2.handler_name = "HighPriorityHandler"
	handler2.priority = 50  # Lower priority = earlier execution

	pipeline.add_handler(handler2)
	assert(pipeline.handlers[0].priority == 50, "Handlers should be sorted by priority")
	assert(pipeline.handlers[1].priority == 100, "Lower priority handlers come first")

	print("  ✓ Handler priority sorting")
	print("  PASSED\n")

## Test 2: Focus Sequence Basics
func test_focus_sequence_basics():
	print("TEST 2: Focus Sequence Basics...")

	# Create a test sequence
	var sequence = TestFocusSequence.new()
	sequence.sequence_name = "TestSequence"

	assert(sequence.get_stage_count() == 3, "Test sequence should have 3 stages")
	assert(sequence.current_stage == 0, "Should start at stage 0")
	assert(sequence.can_advance(), "Should be able to advance initially")

	# Advance through stages
	var result = sequence.advance()
	assert(result != null, "Stage result should be returned")
	assert(sequence.current_stage == 1, "Should advance to stage 1")
	assert(not sequence.is_complete(), "Should not be complete after stage 1")

	print("  ✓ FocusSequence stage advancement")

	# Continue advancing
	sequence.advance()
	assert(sequence.current_stage == 2, "Should advance to stage 2")

	sequence.advance()
	assert(sequence.is_complete(), "Should be complete after all stages")
	assert(not sequence.can_advance(), "Cannot advance when complete")

	print("  ✓ FocusSequence completion detection")

	# Test reset
	sequence.reset()
	assert(sequence.current_stage == 0, "Should reset to stage 0")
	assert(not sequence.is_complete(), "Should not be complete after reset")
	assert(sequence.can_advance(), "Should be able to advance after reset")

	print("  ✓ FocusSequence reset")

	# Test context management
	sequence.set_context("test_key", "test_value")
	assert(sequence.has_context("test_key"), "Should have context key")
	assert(sequence.get_context("test_key") == "test_value", "Should retrieve context value")
	assert(sequence.get_context("missing_key", "default") == "default", "Should return default for missing key")

	print("  ✓ FocusSequence context management")
	print("  PASSED\n")

## Test 3: Race Simulation Signal Tracking
func test_race_simulation_signals():
	print("TEST 3: Race Simulation Signals...")

	# Setup race simulator
	setup_test_race()

	# Track key signals
	var key_signals = [
		"race_started",
		"round_started",
		"pilot_rolling",
		"pilot_rolled",
		"pilot_moved",
	]

	for sig in key_signals:
		assert(race_sim.has_signal(sig), "RaceSimulator should have signal: %s" % sig)

	print("  ✓ All key signals exist on RaceSimulator")
	print("  PASSED\n")

	cleanup_test_race()

## Test 4: Race Lifecycle
func test_race_lifecycle():
	print("TEST 4: Race Lifecycle...")

	setup_test_race()

	# Connect signals for tracking
	signals_received.clear()
	race_sim.race_started.connect(_on_race_started)
	race_sim.pilot_rolling.connect(_on_pilot_rolling)

	# Start race
	var pilots = create_test_pilots_array()
	race_sim.start_race(test_circuit, pilots)

	assert("race_started" in signals_received, "race_started signal should fire")
	assert(race_sim.race_mode == RaceSimulator.RaceMode.STOPPED, "Should be STOPPED waiting for race start")
	assert(race_sim.pilots.size() == 3, "Should have 3 pilots")

	print("  ✓ Race initialization")
	print("  ✓ Pilot setup (3 pilots)")

	# Verify pilot states
	for pilot in race_sim.pilots:
		assert(pilot is PilotState, "Pilot should be PilotState")
		assert(pilot.current_lap == 1, "Should start at lap 1")
		assert(pilot.current_sector == 0, "Should start at sector 0")

	print("  ✓ PilotState initialization")
	print("  PASSED\n")

	cleanup_test_race()

# Helper: Setup test race
func setup_test_race():
	race_sim = RaceSimulator.new()
	add_child(race_sim)
	test_circuit = create_test_circuit()

# Helper: Cleanup test race
func cleanup_test_race():
	if race_sim:
		race_sim.queue_free()
		race_sim = null

# Helper: Create test circuit
func create_test_circuit() -> Circuit:
	var circuit = Circuit.new()
	circuit.circuit_name = "Test Circuit"
	circuit.total_laps = 1

	# Create 2 simple sectors
	var sector1 = Sector.new()
	sector1.sector_name = "Sector 1"
	sector1.length_in_gap = 5
	sector1.check_type = Sector.CheckType.TWITCH
	sector1.is_start_sector = true
	sector1.carrythru = 2

	var sector2 = Sector.new()
	sector2.sector_name = "Sector 2"
	sector2.length_in_gap = 5
	sector2.check_type = Sector.CheckType.CRAFT
	sector2.carrythru = 0

	# Use append for typed arrays in Godot 4
	circuit.sectors.append(sector1)
	circuit.sectors.append(sector2)
	return circuit

# Helper: Create test pilots
func create_test_pilots_array() -> Array:
	var pilot1_resource = Pilot.new()
	pilot1_resource.pilot_name = "Pilot A"
	pilot1_resource.twitch = 7
	pilot1_resource.craft = 6
	pilot1_resource.sync = 5
	pilot1_resource.edge = 8

	var pilot2_resource = Pilot.new()
	pilot2_resource.pilot_name = "Pilot B"
	pilot2_resource.twitch = 6
	pilot2_resource.craft = 7
	pilot2_resource.sync = 8
	pilot2_resource.edge = 5

	var pilot3_resource = Pilot.new()
	pilot3_resource.pilot_name = "Pilot C"
	pilot3_resource.twitch = 8
	pilot3_resource.craft = 5
	pilot3_resource.sync = 6
	pilot3_resource.edge = 7

	return [
		{"pilot": pilot1_resource, "headshot": ""},
		{"pilot": pilot2_resource, "headshot": ""},
		{"pilot": pilot3_resource, "headshot": ""},
	]

# Signal handlers for tracking
func _on_race_started(circuit, pilots):
	signals_received["race_started"] = true

func _on_pilot_rolling(pilot, sector):
	signals_received["pilot_rolling"] = true

# Test Event Handler
class TestEventHandler extends RaceEventHandler:
	var handled_count: int = 0

	func handle(event: RaceEvent) -> void:
		handled_count += 1

# Test Focus Sequence
class TestFocusSequence extends FocusSequence:
	func _init():
		super._init()
		sequence_name = "TestSequence"

	func get_stage_count() -> int:
		return 3

	func get_stage_name(stage: int) -> String:
		return "Test Stage %d" % (stage + 1)

	func execute_stage(stage: int) -> StageResult:
		var result = StageResult.new()
		result.continue_sequence = true
		result.requires_user_input = false
		return result
