# Running Tests

This project has several test suites to verify functionality.

## Test Suites

### 1. Integration Tests (Milestone 1 Foundation)
**Location**: `scenes/tests/IntegrationTest.tscn`
**Tests**:
- Event system (RaceEvent, RaceEventHandler, RaceEventPipeline)
- Focus sequence system (FocusSequence)
- Race simulation signals
- Race lifecycle

### 2. Badge System Tests
**Location**: `scenes/tests/BadgeSystemTest.tscn`
**Tests**:
- Badge loading
- Badge activation conditions
- Badge state tracking
- Badge modifiers

### 3. Race Test Scene (Manual Testing)
**Location**: `scenes/tests/RaceTestScene.tscn`
**Purpose**: Interactive race simulation testing with full UI

## How to Run Tests

### Option 1: Run in Godot Editor (Recommended)

1. Open the project in Godot
2. In the FileSystem panel, navigate to `scenes/tests/`
3. Double-click on a test scene (e.g., `IntegrationTest.tscn`)
4. Click the "Play Scene" button (F6) or press F6
5. Check the Output panel for test results

### Option 2: Run from Command Line

```bash
# Run integration tests
godot --headless scenes/tests/IntegrationTest.tscn

# Run badge system tests
godot --headless scenes/tests/BadgeSystemTest.tscn
```

### Option 3: Set as Main Scene and Run

1. In Godot, go to Project > Project Settings > Application > Run
2. Set "Main Scene" to the test you want to run
3. Press F5 to run the project

## Expected Output

Tests will print results to the Output panel in this format:

```
=== TEST NAME ===

TEST 1: Description...
  ✓ Assertion passed
  ✓ Another assertion passed
  PASSED

TEST 2: Another test...
  ✓ All checks passed
  PASSED

=== ALL TESTS COMPLETE ===
```

## Test Failures

If a test fails, you'll see an assertion error in red:
```
ERROR: Assertion failed: <description>
```

Check the stack trace for the failing line and investigate.

## Adding New Tests

To add a new test:

1. Create a test script in `scripts/tests/` (extends Node)
2. Implement tests in `_ready()` function
3. Use `assert()` for validation
4. Create a corresponding `.tscn` file in `scenes/tests/`
5. Add documentation here

## CI/CD Integration

For automated testing, tests can be run headless:
```bash
godot --headless --quit-after 5 scenes/tests/IntegrationTest.tscn
```

The `--quit-after` flag exits after N seconds (adjust as needed).
