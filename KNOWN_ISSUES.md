# Known Issues - Failure Table System

This document tracks known issues with the failure table implementation that need to be addressed.

## 1. Overflow Penalties Not Applied During W2W Focus Mode

**Priority:** Medium
**Component:** `scripts/systems/RaceSimulator.gd`
**Lines:** 568-586 (`_execute_w2w_rolls()`)

### Description
When pilots enter wheel-to-wheel (W2W) focus mode, they bypass the normal `process_pilot_turn()` flow and go directly to `_execute_w2w_rolls()`. This means any `penalty_next_turn` from a previous failure table is **not applied**.

### Example Scenario
- Round 1: Cowboy gets RED result, failure table penalty of 3 gaps, only 1 gap available → 2 gap overflow stored in `penalty_next_turn`
- Round 2: Cowboy enters W2W with Buoy
- **Bug**: The 2 gap penalty is never applied because W2W uses a different code path that skips the penalty application logic

### Expected Behavior
Overflow penalties should be applied at the start of a pilot's turn regardless of whether they're in normal mode or W2W focus mode.

### Affected Code
The penalty application code exists in `process_pilot_turn()` (lines 330-336) but is not present in `_execute_w2w_rolls()`.

---

## 2. RED Results During W2W Don't Trigger Failure Tables

**Priority:** Low (May Be Intentional)
**Component:** `scripts/systems/RaceSimulator.gd`
**Lines:** 568-586 (`_execute_w2w_rolls()`)

### Description
If a pilot rolls RED during a W2W focus mode, it doesn't trigger a failure table - they just get normal `red_movement`. This might be intentional to avoid nesting focus modes.

### Current Behavior
- Normal turn: RED → Triggers failure table focus mode
- W2W turn: RED → Just gets `red_movement`, no failure table

### Decision Needed
Determine if this is intentional design (to avoid nested focus modes) or if RED results during W2W should also trigger failure tables somehow (perhaps after W2W resolution).

---

## 3. Consecutive RED Results Lose First Overflow Penalty

**Priority:** High
**Component:** `scripts/systems/RaceSimulator.gd`
**Lines:** 323-325, 330-336, 697

### Description
If a pilot has an overflow penalty stored (`penalty_next_turn > 0`) and rolls RED again before it's applied, the first penalty is lost.

### Example Scenario
- Turn 1: Pilot rolls RED → Gets failure table with 2 gap penalty, only 1 gap available → `penalty_next_turn = 2`
- Turn 2: Pilot rolls RED again
  - The RED check happens at line 323-325 (before penalty application at 330-336)
  - `process_red_result_focus_mode()` is called immediately
  - Penalty application code (330-336) is skipped
  - A new overflow penalty is calculated and overwrites the old one (line 697)
- **Bug**: The first 2 gap penalty is never applied

### Expected Behavior
Either:
1. Apply pending penalties before checking for RED results, OR
2. Accumulate penalties rather than overwriting them

### Suggested Fix
Move the penalty application code (lines 330-336) to execute **before** the RED result check (line 323).
