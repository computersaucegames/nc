# Known Issues - Failure Table System

This document tracks known issues with the failure table implementation.

## RESOLVED ISSUES

### ✅ 1. Overflow Penalties Not Applied During W2W Focus Mode [RESOLVED]

**Status:** FIXED
**Component:** `scripts/systems/RaceSimulator.gd`
**Fixed in:** Current commit

**Solution Implemented:**
- Added penalty tracking at start of `_execute_w2w_rolls()` (lines 639-645)
- Applied penalties to movement calculations (lines 663-669)
- Penalties now correctly reduce W2W movement and are cleared after application

---

### ✅ 2. Consecutive RED Results Lose First Overflow Penalty [RESOLVED]

**Status:** FIXED
**Component:** `scripts/systems/RaceSimulator.gd`
**Fixed in:** Current commit

**Solution Implemented:**
- Modified `_execute_failure_table_roll()` to accumulate penalties (lines 801-818)
- Existing `penalty_next_turn` is now added to new failure penalties
- Total penalty is calculated and applied, preventing penalty loss
- Proper overflow penalty emission for both old and new penalties

---

### ✅ 3. Position Update Includes DNF Pilots [RESOLVED]

**Status:** FIXED
**Component:** `scripts/systems/MovementProcessor.gd`
**Fixed in:** Current commit

**Solution Implemented:**
- Updated `update_all_positions()` to check both `finished` and `did_not_finish` (line 155)
- DNF pilots no longer receive position updates

---

## OPEN ISSUES

### 4. RED Results During W2W - Design Enhancement

**Priority:** Enhancement
**Component:** `scripts/systems/RaceSimulator.gd`

### Description
Currently, RED results during W2W don't trigger failure tables. This is being enhanced with a new W2W failure system.

### Planned Enhancement
- W2W-specific failure tables with contact mechanics
- Non-RED pilot makes Twitch avoidance save
- Both pilots crash if both roll RED
- See implementation in progress
