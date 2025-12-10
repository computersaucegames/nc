# Race Simulation Refactor - Milestone 2: Extract Focus Sequences

## Overview

**Milestone 2** focuses on extracting the multi-stage Focus Mode logic from RaceSimulator into dedicated sequence classes. This will reduce RaceSimulator's complexity and make it easier to add new Focus Mode types (pitting, user decisions, etc.).

**Status:** 📋 Ready to Begin
**Prerequisites:** ✅ Milestone 1 Complete
**Estimated Complexity:** 🔶 Medium Risk
**Expected LOC Change:** ~400 lines moved from RaceSimulator to sequences

---

## 🎯 Goals

1. **Extract Race Start sequence** - Grid formation → rolls → movement application
2. **Extract Red Result sequence** - Failure table → movement application
3. **Extract W2W Failure sequence** - Both pilots roll → failure table → avoidance → movement
4. **Refactor RaceSimulator** - Delegate to sequences instead of inline logic
5. **Maintain 100% compatibility** - All existing tests must still pass

---

## 📋 Tasks

### Task 1: Create RaceStartSequence

**File:** `scripts/systems/focus_sequences/RaceStartSequence.gd`

**Current Code Location:** `RaceSimulator.gd` lines 130-230
- `begin_race_start_focus_mode()` - Entry point
- `_on_race_start_focus_advance()` - Stage handler (2 stages)
- `_execute_race_start_rolls()` - Roll execution

**Stages:**
1. **Execute Rolls** - All pilots roll TWITCH, sort by result
2. **Apply Movement** - Move pilots based on roll results

**Implementation:**

```gdscript
class_name RaceStartSequence extends FocusSequence

## Multi-stage sequence for race start Focus Mode
##
## Stage 1: Execute race start rolls (all pilots, TWITCH)
## Stage 2: Apply movement from rolls

var race_sim: RaceSimulator  # Reference to race simulator
var start_sector: Sector
var all_pilots: Array[PilotState]
var roll_results: Array = []  # Store rolls for stage 2

func _init(event: FocusModeManager.FocusModeEvent, simulator: RaceSimulator):
	super._init(event)
	sequence_name = "RaceStart"
	race_sim = simulator
	start_sector = event.sector
	all_pilots = event.pilots.duplicate()

func get_stage_count() -> int:
	return 2

func get_stage_name(stage: int) -> String:
	match stage:
		0: return "Race Start Rolls"
		1: return "Apply Movement"
		_: return "Unknown"

func execute_stage(stage: int) -> StageResult:
	var result = StageResult.new()

	match stage:
		0:  # Execute race start rolls
			roll_results = _execute_race_start_rolls()
			result.emit_signal = "race_start_rolls"
			result.signal_data = {"results": roll_results}
			result.continue_sequence = true
			result.requires_user_input = true

		1:  # Apply movement
			_apply_race_start_movement()
			result.emit_signal = "race_start_complete"
			result.continue_sequence = false
			result.exit_focus_mode = true
			result.requires_user_input = false

	return result

func _execute_race_start_rolls() -> Array:
	var results = []

	for pilot in all_pilots:
		# Set race start status
		pilot.is_race_start = true

		# Get badges for race start context
		var context = {
			"roll_type": "race_start",
			"is_race_start": true,
			"sector": start_sector
		}

		var modifiers = BadgeSystem.get_active_modifiers(pilot, context)

		# Roll TWITCH (race start uses twitch stat)
		var roll_result = DiceSystem.roll_with_gates(
			pilot.pilot_data.TWITCH,
			modifiers,
			start_sector.grey_threshold,
			start_sector.green_threshold,
			start_sector.purple_threshold
		)

		results.append({
			"pilot": pilot,
			"roll": roll_result,
			"grid_position": pilot.grid_position
		})

		# Emit badge activated signals if any
		for badge_info in BadgeSystem.get_active_badges_info(pilot, context):
			race_sim.badge_activated.emit(pilot, badge_info.name, badge_info.description)

	# Sort by roll result (highest first), ties broken by grid position
	results.sort_custom(func(a, b):
		if a.roll.total_roll == b.roll.total_roll:
			return a.grid_position < b.grid_position
		return a.roll.total_roll > b.roll.total_roll
	)

	return results

func _apply_race_start_movement():
	for idx in range(roll_results.size()):
		var result_data = roll_results[idx]
		var pilot: PilotState = result_data.pilot
		var roll: Dice.DiceResult = result_data.roll

		# Calculate movement based on roll tier
		var movement = MovementProcessor.calculate_base_movement(roll.tier, start_sector)

		# Apply movement (no capacity blocking on race start)
		var move_result = MovementProcessor.apply_movement(
			pilot,
			movement,
			race_sim.circuit
		)

		# Clear race start status
		pilot.is_race_start = false

		# Emit movement signals
		race_sim.pilot_moved.emit(pilot, movement)
```

**Integration into RaceSimulator:**

```gdscript
# In RaceSimulator.gd, replace begin_race_start_focus_mode():

func begin_race_start_focus_mode():
	var event = FocusModeManager.create_race_start_event(pilots, circuit.sectors[0])

	# Create sequence
	var sequence = RaceStartSequence.new(event, self)
	current_focus_sequence = sequence

	# Enter focus mode
	race_mode = RaceMode.FOCUS_MODE
	FocusModeManager.activate(event)
	focus_mode_triggered.emit(pilots, "Race Start")

	# Execute first stage
	_advance_focus_sequence()

func _advance_focus_sequence():
	if not current_focus_sequence:
		push_error("No active focus sequence!")
		return

	var result = current_focus_sequence.advance()

	# Emit signal if requested
	if result.emit_signal != "":
		# Use get() to call signal dynamically
		if has_signal(result.emit_signal):
			emit_signal(result.emit_signal, result.signal_data)

	# Exit focus mode if done
	if result.exit_focus_mode:
		race_mode = RaceMode.RUNNING
		FocusModeManager.deactivate()
		current_focus_sequence = null
		process_round()  # Continue with race
```

**Testing:**
- Run existing `RaceTestScene.tscn`
- Verify race start still works
- Check that rolls and movement are identical to before

---

### Task 2: Create RedResultSequence

**File:** `scripts/systems/focus_sequences/RedResultSequence.gd`

**Current Code Location:** `RaceSimulator.gd` lines 988-1098
- `process_red_result_focus_mode()` - Entry point
- `_on_red_result_focus_advance()` - Stage handler (2 stages)
- `_execute_failure_table_roll()` - Failure table logic

**Stages:**
1. **Roll on Failure Table** - Determine consequence and apply badges
2. **Apply Movement** - Apply red movement minus penalties

**Implementation:**

```gdscript
class_name RedResultSequence extends FocusSequence

## Multi-stage sequence for red result (failure table) Focus Mode
##
## Stage 1: Roll on failure table, determine consequences
## Stage 2: Apply reduced movement

var race_sim: RaceSimulator
var pilot: PilotState
var sector: Sector
var initial_roll: Dice.DiceResult
var failure_result: Dictionary = {}

func _init(event: FocusModeManager.FocusModeEvent, simulator: RaceSimulator):
	super._init(event)
	sequence_name = "RedResult"
	race_sim = simulator
	pilot = get_pilot()
	sector = get_sector()
	initial_roll = event.metadata.get("initial_roll")

func get_stage_count() -> int:
	return 2

func get_stage_name(stage: int) -> String:
	match stage:
		0: return "Failure Table Roll"
		1: return "Apply Movement"
		_: return "Unknown"

func execute_stage(stage: int) -> StageResult:
	var result = StageResult.new()

	match stage:
		0:  # Roll on failure table
			failure_result = FailureTableResolver.resolve_failure(pilot, sector)

			# Check for crash (RED on failure save)
			if failure_result.crashed:
				pilot.crash()
				race_sim.pilot_crashed.emit(pilot, sector, "Failed stability check")
				result.exit_focus_mode = true
				return result

			# Apply negative badge if any
			if failure_result.badge:
				pilot.temporary_badges.append(failure_result.badge)
				race_sim.negative_badge_applied.emit(pilot, failure_result.badge)

			# Calculate movement and overflow
			var movement = sector.red_movement - failure_result.penalty
			set_context("movement", movement)
			set_context("overflow_penalty", failure_result.overflow_penalty)

			result.emit_signal = "failure_table_triggered"
			result.signal_data = {
				"pilot": pilot,
				"sector": sector,
				"consequence": failure_result.consequence_text,
				"roll_result": failure_result.roll_result
			}
			result.continue_sequence = true
			result.requires_user_input = true

		1:  # Apply movement
			var movement = get_context("movement", 0)
			var overflow = get_context("overflow_penalty", 0)

			if overflow > 0:
				pilot.penalty_next_turn = overflow
				race_sim.overflow_penalty_deferred.emit(pilot, overflow)

			# Apply movement
			var move_result = MovementProcessor.apply_movement(pilot, movement, race_sim.circuit)

			# Handle overtaking if needed
			race_sim.handle_overtaking(pilot, move_result.final_movement)

			# Emit signals
			race_sim.pilot_moved.emit(pilot, movement)
			race_sim.handle_movement_results(pilot, move_result)

			result.exit_focus_mode = true
			result.requires_user_input = false

	return result
```

**Integration:**
Replace `process_red_result_focus_mode()` with sequence creation similar to Task 1.

---

### Task 3: Create W2WFailureSequence

**File:** `scripts/systems/focus_sequences/W2WFailureSequence.gd`

**Current Code Location:** `RaceSimulator.gd` lines 591-939 (most complex!)
- `process_w2w_focus_mode()` - Entry point
- `_execute_w2w_rolls()` - Stage 1: Both pilots roll
- `_execute_w2w_failure_roll()` - Stage 2: Failure table for failing pilot
- `_execute_w2w_avoidance_save()` - Stage 3: Avoidance roll for other pilot
- `_apply_w2w_failure_movement()` - Stage 4: Apply movement for both

**Stages:**
1. **W2W Rolls** - Both pilots roll, check for RED results
2. **Failure Table** - Failing pilot rolls on W2W failure table
3. **Avoidance Save** - Other pilot attempts to avoid contact
4. **Apply Movement** - Both pilots move with adjusted movement

**Implementation:**

```gdscript
class_name W2WFailureSequence extends FocusSequence

## Multi-stage sequence for Wheel-to-Wheel failure Focus Mode
##
## This is the most complex sequence with up to 4 stages

var race_sim: RaceSimulator
var pilot1: PilotState
var pilot2: PilotState
var sector: Sector
var failing_pilot: PilotState
var avoiding_pilot: PilotState
var roll_results: Dictionary = {}
var w2w_failure_result: Dictionary = {}
var avoidance_result: Dice.DiceResult

func _init(event: FocusModeManager.FocusModeEvent, simulator: RaceSimulator):
	super._init(event)
	sequence_name = "W2WFailure"
	race_sim = simulator
	var pilots = get_pilots()
	pilot1 = pilots[0]
	pilot2 = pilots[1]
	sector = get_sector()

func get_stage_count() -> int:
	# Variable stages depending on what happens:
	# - Both RED: 1 stage (dual crash)
	# - One RED, no contact: 2 stages (rolls → apply movement)
	# - One RED, contact: 4 stages (rolls → failure → avoidance → apply)
	# We'll use max and skip stages dynamically
	return 4

func get_stage_name(stage: int) -> String:
	match stage:
		0: return "W2W Rolls"
		1: return "W2W Failure Table"
		2: return "Avoidance Save"
		3: return "Apply Movement"
		_: return "Unknown"

func execute_stage(stage: int) -> StageResult:
	var result = StageResult.new()

	match stage:
		0:  # W2W Rolls
			result = _execute_w2w_rolls()

		1:  # Failure table (only if one RED)
			result = _execute_failure_table()

		2:  # Avoidance save (only if contact triggered)
			result = _execute_avoidance_save()

		3:  # Apply movement
			result = _apply_movement()

	return result

func _execute_w2w_rolls() -> StageResult:
	var result = StageResult.new()

	# Apply any pending overflow penalties
	for pilot in [pilot1, pilot2]:
		if pilot.penalty_next_turn > 0:
			race_sim.overflow_penalty_applied.emit(pilot, pilot.penalty_next_turn)
			pilot.penalty_next_turn = 0

	# Roll for both pilots
	var context = {
		"roll_type": "w2w",
		"sector": sector,
		"is_wheel_to_wheel": true
	}

	for pilot in [pilot1, pilot2]:
		var modifiers = BadgeSystem.get_active_modifiers(pilot, context)
		var roll = DiceSystem.roll_with_gates(
			pilot.pilot_data.get(sector.get_stat_property_name()),
			modifiers,
			sector.grey_threshold,
			sector.green_threshold,
			sector.purple_threshold
		)
		roll_results[pilot] = roll

		# Emit signals
		race_sim.pilot_rolling.emit(pilot, sector)
		race_sim.pilot_rolled.emit(pilot, roll)

	# Check for dual RED
	if roll_results[pilot1].tier == Dice.Tier.RED and roll_results[pilot2].tier == Dice.Tier.RED:
		# DUAL CRASH
		pilot1.crash()
		pilot2.crash()
		race_sim.w2w_dual_crash.emit(pilot1, pilot2, sector)
		result.exit_focus_mode = true
		return result

	# Check for single RED
	if roll_results[pilot1].tier == Dice.Tier.RED:
		failing_pilot = pilot1
		avoiding_pilot = pilot2
		set_context("w2w_failure", true)
		result.continue_sequence = true
	elif roll_results[pilot2].tier == Dice.Tier.RED:
		failing_pilot = pilot2
		avoiding_pilot = pilot1
		set_context("w2w_failure", true)
		result.continue_sequence = true
	else:
		# No failure - calculate movement and skip to stage 3
		set_context("w2w_failure", false)
		_calculate_normal_movement()
		current_stage = 2  # Skip to apply movement
		result.continue_sequence = true

	result.emit_signal = "w2w_rolls_complete"
	result.requires_user_input = true
	return result

func _execute_failure_table() -> StageResult:
	var result = StageResult.new()

	if not get_context("w2w_failure", false):
		# Skip this stage
		result.continue_sequence = true
		result.requires_user_input = false
		return result

	race_sim.w2w_failure_triggered.emit(failing_pilot, avoiding_pilot, sector)

	# Roll on W2W failure table
	w2w_failure_result = FailureTableResolver.resolve_w2w_failure(failing_pilot, sector)

	race_sim.w2w_failure_roll_result.emit(
		failing_pilot,
		w2w_failure_result.consequence_text,
		w2w_failure_result.roll_result
	)

	# Check if contact was triggered
	if w2w_failure_result.contact_triggered:
		set_context("contact_triggered", true)
		race_sim.w2w_contact_triggered.emit(failing_pilot, avoiding_pilot, w2w_failure_result)
		result.continue_sequence = true  # Go to avoidance stage
	else:
		# No contact - apply movement directly
		_calculate_failure_movement()
		current_stage = 2  # Skip avoidance, go to apply
		result.continue_sequence = true

	result.requires_user_input = true
	return result

func _execute_avoidance_save() -> StageResult:
	var result = StageResult.new()

	if not get_context("contact_triggered", false):
		# Skip this stage
		result.continue_sequence = true
		result.requires_user_input = false
		return result

	# Avoiding pilot rolls TWITCH with modified gates
	var modified_gates = {
		"grey": sector.grey_threshold + 2,
		"green": sector.green_threshold + 2,
		"purple": sector.purple_threshold + 2
	}

	race_sim.w2w_avoidance_roll_required.emit(avoiding_pilot, modified_gates)

	var context = {
		"roll_type": "avoidance",
		"sector": sector
	}
	var modifiers = BadgeSystem.get_active_modifiers(avoiding_pilot, context)

	avoidance_result = DiceSystem.roll_with_gates(
		avoiding_pilot.pilot_data.TWITCH,
		modifiers,
		modified_gates.grey,
		modified_gates.green,
		modified_gates.purple
	)

	# Apply consequences based on tier
	var description = ""
	match avoidance_result.tier:
		Dice.Tier.PURPLE:
			description = "Clean avoidance!"
			set_context("avoiding_penalty", 0)
		Dice.Tier.GREEN:
			description = "Minor contact - lose 1 gap"
			set_context("avoiding_penalty", 1)
		Dice.Tier.GREY:
			description = "Heavy contact - lose 2 gaps, Rattled"
			set_context("avoiding_penalty", 2)
			var rattled_badge = load("res://resources/badges/rattled.tres")
			avoiding_pilot.temporary_badges.append(rattled_badge)
		Dice.Tier.RED:
			description = "COLLISION - both crash!"
			failing_pilot.crash()
			avoiding_pilot.crash()
			race_sim.w2w_dual_crash.emit(failing_pilot, avoiding_pilot, sector)
			result.exit_focus_mode = true
			return result

	race_sim.w2w_avoidance_roll_result.emit(avoiding_pilot, avoidance_result, description)

	result.continue_sequence = true
	result.requires_user_input = true
	return result

func _apply_movement() -> StageResult:
	var result = StageResult.new()

	# Apply movement for both pilots
	var failing_movement = get_context("failing_movement", 0)
	var avoiding_movement = get_context("avoiding_movement", 0)
	var avoiding_penalty = get_context("avoiding_penalty", 0)

	# Apply failing pilot movement
	var fail_move = MovementProcessor.apply_movement(failing_pilot, failing_movement, race_sim.circuit)
	race_sim.handle_overtaking(failing_pilot, fail_move.final_movement)
	race_sim.pilot_moved.emit(failing_pilot, failing_movement)

	# Apply avoiding pilot movement
	var avoid_move = MovementProcessor.apply_movement(
		avoiding_pilot,
		avoiding_movement - avoiding_penalty,
		race_sim.circuit
	)
	race_sim.handle_overtaking(avoiding_pilot, avoid_move.final_movement)
	race_sim.pilot_moved.emit(avoiding_pilot, avoiding_movement - avoiding_penalty)

	# Mark both as processed
	race_sim.pilots_processed_this_round.append(failing_pilot)
	race_sim.pilots_processed_this_round.append(avoiding_pilot)

	result.exit_focus_mode = true
	result.requires_user_input = false
	return result

func _calculate_normal_movement():
	# Both pilots rolled successfully
	for pilot in [pilot1, pilot2]:
		var movement = MovementProcessor.calculate_base_movement(
			roll_results[pilot].tier,
			sector
		)
		set_context("%s_movement" % pilot.name, movement)

func _calculate_failure_movement():
	# One pilot failed, no contact
	var failing_movement = sector.red_movement - w2w_failure_result.penalty
	var avoiding_movement = MovementProcessor.calculate_base_movement(
		roll_results[avoiding_pilot].tier,
		sector
	)

	set_context("failing_movement", failing_movement)
	set_context("avoiding_movement", avoiding_movement)
```

**Note:** This is the most complex sequence. Take care to preserve all the edge cases!

---

### Task 4: Refactor RaceSimulator

**Changes needed in `RaceSimulator.gd`:**

1. **Add sequence tracking:**
```gdscript
var current_focus_sequence: FocusSequence = null
```

2. **Replace inline Focus Mode logic with sequence creation:**
```gdscript
# OLD:
func begin_race_start_focus_mode():
	# 50+ lines of inline logic...

# NEW:
func begin_race_start_focus_mode():
	var event = FocusModeManager.create_race_start_event(pilots, circuit.sectors[0])
	current_focus_sequence = RaceStartSequence.new(event, self)
	race_mode = RaceMode.FOCUS_MODE
	FocusModeManager.activate(event)
	_advance_focus_sequence()
```

3. **Replace `_on_focus_mode_advance()` with generic handler:**
```gdscript
# OLD: Separate handlers for each sequence type
func _on_race_start_focus_advance(): ...
func _on_red_result_focus_advance(): ...
func _on_focus_mode_advance(): ...  # W2W

# NEW: Single generic handler
func _on_focus_mode_advance():
	_advance_focus_sequence()

func _advance_focus_sequence():
	if not current_focus_sequence:
		return

	var result = current_focus_sequence.advance()

	# Emit signal if requested
	if result.emit_signal != "":
		_emit_sequence_signal(result.emit_signal, result.signal_data)

	# Exit if done
	if result.exit_focus_mode:
		_exit_focus_mode()

func _exit_focus_mode():
	race_mode = RaceMode.RUNNING
	FocusModeManager.deactivate()
	current_focus_sequence = null
	resume_round()
```

4. **Delete old inline methods:**
- `_execute_race_start_rolls()`
- `_execute_failure_table_roll()`
- `_execute_w2w_rolls()`
- `_execute_w2w_failure_roll()`
- `_execute_w2w_avoidance_save()`
- `_apply_w2w_failure_movement()`

**Expected Line Count Reduction:**
- Before: 1134 lines
- After: ~750 lines (-384 lines moved to sequences)

---

### Task 5: Testing

**Test Plan:**

1. **Run existing tests:**
   - `RaceTestScene.tscn` - Full race simulation
   - `IntegrationTest.tscn` - Foundation tests
   - `BadgeSystemTest.tscn` - Badge tests

2. **Create sequence-specific tests:**

**File:** `scripts/tests/SequenceTestScene.gd`
```gdscript
extends Node

func _ready():
	print("\n=== FOCUS SEQUENCE TESTS ===\n")

	test_race_start_sequence()
	test_red_result_sequence()
	test_w2w_failure_sequence()

	print("\n=== ALL SEQUENCE TESTS COMPLETE ===\n")

func test_race_start_sequence():
	print("TEST 1: Race Start Sequence...")

	var circuit = create_test_circuit()
	var pilots = create_test_pilots()
	var event = FocusModeManager.create_race_start_event(pilots, circuit.sectors[0])
	var sim = RaceSimulator.new()

	var sequence = RaceStartSequence.new(event, sim)

	assert(sequence.get_stage_count() == 2, "Should have 2 stages")
	assert(sequence.current_stage == 0, "Should start at stage 0")

	# Execute stage 1 (rolls)
	var result = sequence.advance()
	assert(result.emit_signal == "race_start_rolls", "Should emit race_start_rolls")
	assert(not result.exit_focus_mode, "Should not exit yet")

	# Execute stage 2 (movement)
	result = sequence.advance()
	assert(result.exit_focus_mode, "Should exit after stage 2")
	assert(sequence.is_complete(), "Should be complete")

	print("  ✓ Race start sequence executes correctly")
	print("  PASSED\n")

func test_red_result_sequence():
	print("TEST 2: Red Result Sequence...")
	# Similar structure...
	print("  PASSED\n")

func test_w2w_failure_sequence():
	print("TEST 3: W2W Failure Sequence...")
	# Test all 4 stages and edge cases
	print("  PASSED\n")
```

3. **Manual testing checklist:**
   - [ ] Race starts correctly with grid formation
   - [ ] Red results trigger failure table
   - [ ] W2W situations trigger wheel-to-wheel sequence
   - [ ] Dual crashes work
   - [ ] Avoidance rolls work
   - [ ] All signals still emit correctly
   - [ ] UI updates properly

---

## 📊 Success Criteria

Milestone 2 is complete when:

- ✅ All three sequence classes created and working
- ✅ RaceSimulator refactored to use sequences
- ✅ RaceSimulator reduced by ~400 lines
- ✅ All existing tests pass (RaceTestScene, Integration, Badge)
- ✅ New sequence tests pass
- ✅ No regressions in race behavior
- ✅ Code is committed and pushed

---

## 🚧 Potential Risks

### Risk 1: Signal Timing Changes
**Issue:** Sequences might emit signals in different order
**Mitigation:** Compare signal order before/after with logging

### Risk 2: State Management
**Issue:** Sequences need access to RaceSimulator state
**Mitigation:** Pass RaceSimulator reference to sequences

### Risk 3: Complex W2W Logic
**Issue:** W2W sequence has many edge cases
**Mitigation:** Extract in small commits, test after each change

### Risk 4: Focus Mode Callbacks
**Issue:** Current callback system is tangled
**Mitigation:** Generic `_on_focus_mode_advance()` handler

---

## 📝 Implementation Order

**Recommended order (lowest to highest risk):**

1. **RaceStartSequence** (Easiest)
   - Only 2 stages
   - No complex conditionals
   - Good warm-up

2. **RedResultSequence** (Medium)
   - 2 stages with branching (crash vs continue)
   - Simpler than W2W

3. **W2WFailureSequence** (Hardest)
   - Up to 4 stages
   - Many edge cases
   - Most lines of code

4. **Refactor RaceSimulator**
   - Replace all three at once
   - Test thoroughly

---

## 🔍 Testing Strategy

### Before Starting
```bash
# Take a snapshot of current behavior
godot --headless scenes/tests/RaceTestScene.tscn > /tmp/race_before.log
```

### After Each Sequence
```bash
# Test the sequence in isolation
godot --headless scenes/tests/SequenceTest.tscn
```

### After Refactor
```bash
# Compare behavior
godot --headless scenes/tests/RaceTestScene.tscn > /tmp/race_after.log
diff /tmp/race_before.log /tmp/race_after.log
```

### Signal Verification
Add logging to RaceSimulator:
```gdscript
func _emit_any_signal(sig_name: String, args: Array):
	print("SIGNAL: %s with %d args" % [sig_name, args.size()])
	# Then emit actual signal
```

---

## 📚 Reference Materials

**Key RaceSimulator sections to study:**
- Lines 130-230: Race start logic
- Lines 591-939: W2W failure logic (largest)
- Lines 988-1098: Red result logic

**FocusSequence API:**
```gdscript
# Override these:
func get_stage_count() -> int
func get_stage_name(stage: int) -> String
func execute_stage(stage: int) -> StageResult

# Use these helpers:
func get_pilot() -> PilotState
func get_other_pilot() -> PilotState
func get_sector() -> Sector
func set_context(key, value)
func get_context(key, default)

# StageResult controls flow:
result.continue_sequence = true/false
result.exit_focus_mode = true/false
result.emit_signal = "signal_name"
result.signal_data = {...}
result.requires_user_input = true/false
```

---

## 🎯 Expected Outcome

After Milestone 2:

**File Structure:**
```
scripts/systems/focus_sequences/
├── FocusSequence.gd           (base class)
├── RaceStartSequence.gd       (NEW - ~150 lines)
├── RedResultSequence.gd       (NEW - ~120 lines)
└── W2WFailureSequence.gd      (NEW - ~250 lines)

scripts/systems/
└── RaceSimulator.gd           (750 lines, down from 1134)
```

**Benefits:**
- ✅ RaceSimulator is 34% smaller
- ✅ Focus Mode logic is isolated and testable
- ✅ Easy to add new sequence types (PitStopSequence, DecisionSequence)
- ✅ No more tangled callback logic
- ✅ Clear separation of concerns

**Ready for Milestone 3:** Break up RaceSimulator further (TurnProcessor, RaceOrchestrator, etc.)

---

## 🚀 Getting Started

When ready to begin Milestone 2:

```bash
# Make sure you're on the refactor branch
git checkout claude/refactor-race-sim-014H4irYMmcomq8RaCPcBCmE

# Pull latest changes
git pull origin claude/refactor-race-sim-014H4irYMmcomq8RaCPcBCmE

# Create a checkpoint
git tag milestone-1-complete

# Start with RaceStartSequence (easiest)
# Create scripts/systems/focus_sequences/RaceStartSequence.gd
# Follow the implementation guide above
```

**Good luck! Take it one sequence at a time, test frequently, and commit often!** 🎉
