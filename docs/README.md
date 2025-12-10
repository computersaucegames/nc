# Race Simulation Refactor Documentation

This directory contains documentation for the race simulation refactor project.

## 📚 Documents

### Current Status
- **[REFACTOR_MILESTONE_1_COMPLETE.md](REFACTOR_MILESTONE_1_COMPLETE.md)** - ✅ Milestone 1 completion report
  - Foundation classes (events, sequences)
  - Integration tests
  - What we built and why
  - All tests passing

### Next Steps
- **[REFACTOR_MILESTONE_2_PLAN.md](REFACTOR_MILESTONE_2_PLAN.md)** - 📋 Milestone 2 implementation guide
  - Extract Focus Mode sequences from RaceSimulator
  - Detailed task breakdown
  - Code examples and integration steps
  - Testing strategy

## 🎯 Refactor Overview

The race simulation system is being refactored to:
1. **Reduce complexity** - Break up the 1134-line RaceSimulator monolith
2. **Improve extensibility** - Make it easy to add features (pitting, user decisions, team racing)
3. **Enhance testability** - Isolated components with clear responsibilities
4. **Event-driven architecture** - Decouple race logic from orchestration

## 📋 Milestone Roadmap

| Milestone | Status | Description | LOC Impact |
|-----------|--------|-------------|------------|
| **1. Foundation** | ✅ **COMPLETE** | Event system, FocusSequence base, tests | +770 new |
| **2. Extract Sequences** | 📋 Ready | RaceStartSequence, RedResultSequence, W2WFailureSequence | -384 from RaceSimulator |
| **3. Break Up RaceSimulator** | ⏳ Planned | RaceOrchestrator, TurnProcessor, FocusModeCoordinator | -400 from RaceSimulator |
| **4. Event Pipeline** | ⏳ Planned | Integrate RaceEventPipeline into race loop | Refactor existing |
| **5. Badge Enhancement** | ⏳ Planned | Event-driven badges, typed contexts | Refactor existing |
| **6. Feature Prep** | ⏳ Planned | DecisionPoint, pit stop structure, team state | +300 new |

## 🏗️ Architecture Evolution

### Before Refactor
```
RaceSimulator (1134 lines)
├─ Race lifecycle
├─ Pilot turns
├─ Focus Mode sequences (inline)
├─ W2W handling
├─ Red result handling
├─ Movement
├─ Overtaking
└─ Badge evaluation
```

### After Milestone 1 ✅
```
RaceSimulator (1134 lines) ← unchanged
+ Event System
  ├─ RaceEvent
  ├─ RaceEventHandler
  └─ RaceEventPipeline
+ FocusSequence (base)
+ Integration Tests
```

### After Milestone 2 (Target)
```
RaceSimulator (750 lines)
├─ Race lifecycle
├─ Pilot turns
├─ Focus Mode coordination → delegates to:
│   ├─ RaceStartSequence
│   ├─ RedResultSequence
│   └─ W2WFailureSequence
├─ Movement
├─ Overtaking
└─ Badge evaluation
```

### Final Vision (Milestone 6)
```
RaceOrchestrator (300 lines)
├─ TurnProcessor (200 lines)
│  └─ RaceEventPipeline
│     ├─ BadgeHandler
│     ├─ PenaltyHandler
│     ├─ DecisionHandler
│     └─ PitStopHandler
├─ FocusModeCoordinator (150 lines)
│  ├─ RaceStartSequence
│  ├─ W2WFailureSequence
│  ├─ RedResultSequence
│  ├─ PitStopSequence
│  └─ DecisionSequence
├─ RaceStateManager (100 lines)
├─ MovementProcessor (existing)
├─ StatusCalculator (existing)
└─ OvertakeResolver (existing)
```

## 🧪 Testing

All tests are located in:
- `tests/` - Test scripts
- `scripts/tests/` - Test scenes
- `scenes/tests/` - Test scene files

See [tests/README.md](../tests/README.md) for how to run tests.

### Current Test Coverage

| Test Suite | Status | Tests | Coverage |
|------------|--------|-------|----------|
| Integration Tests | ✅ PASS | 4 | Event system, Focus sequences, Race signals, Lifecycle |
| Badge System Tests | ✅ PASS | 4 | Loading, Activation, State tracking, Modifiers |
| Race Test Scene | ✅ PASS | Manual | Full race simulation with UI |

## 🚀 Quick Start

### View Current Progress
```bash
cd /home/user/nc
cat docs/REFACTOR_MILESTONE_1_COMPLETE.md
```

### Run Tests
```bash
# In Godot:
# 1. Open scenes/tests/IntegrationTest.tscn
# 2. Press F6

# Or command line:
godot --headless scenes/tests/IntegrationTest.tscn
```

### Start Milestone 2
```bash
# Read the plan
cat docs/REFACTOR_MILESTONE_2_PLAN.md

# Create a checkpoint
git tag milestone-1-complete

# Start implementing RaceStartSequence
# See REFACTOR_MILESTONE_2_PLAN.md for detailed instructions
```

## 📖 Additional Resources

- **Branch:** `claude/refactor-race-sim-014H4irYMmcomq8RaCPcBCmE`
- **Original Issue:** Race sim refactor for extensibility
- **Related PRs:** #67 (previous refactor work)

## 🤝 Contributing

When working on this refactor:
1. Read the relevant milestone document first
2. Make small, focused commits
3. Test after each change
4. Update tests if behavior changes
5. Document any new patterns or decisions

## 📝 Change Log

### 2024-12-10 - Milestone 1 Complete
- ✅ Event system foundation (RaceEvent, RaceEventHandler, RaceEventPipeline)
- ✅ FocusSequence base class
- ✅ Integration tests (100% passing)
- ✅ Badge system tests (100% passing)
- ✅ Documentation (this folder!)

### Coming Soon - Milestone 2
- Extract RaceStartSequence
- Extract RedResultSequence
- Extract W2WFailureSequence
- Refactor RaceSimulator to use sequences

---

**Questions?** Check the milestone documents or review the test code for examples.

**Ready to proceed?** Start with [REFACTOR_MILESTONE_2_PLAN.md](REFACTOR_MILESTONE_2_PLAN.md)! 🚀
