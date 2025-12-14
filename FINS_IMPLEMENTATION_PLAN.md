# Fins Module Implementation Plan

## Overview
Separate craft from pilots - pilots control "fins" (racing craft) that have their own stats, badges, and characteristics.

---

## Phase 1: Core Data Structures

### 1.1 Create Fin Resource (`scripts/resources/fin.gd`)
**New resource class similar to Pilot**

```gdscript
extends Resource
class_name Fin

@export var fin_name: String
@export var fin_model: String  # e.g., "Mk-VII Interceptor"
@export var fin_bio: String    # Description of craft design/history

# Core Stats (1-8 range, like pilots)
@export var THRUST: int  # Power & acceleration
@export var FORM: int    # Durability, stability, aero
@export var RESPONSE: int # Handling & reaction
@export var SYNC: int    # (Future use - track but not used in sectors yet)

# Badge system
@export var equipped_badges: Array[Badge] = []
```

**Sample Fins to Create:**
- Create 5+ different fin models with varied stat distributions
- Similar diversity to pilot roster (specialist vs generalist)

---

### 1.2 Create FinState Runtime Object (`scripts/systems/finstate.gd`)
**Runtime state during races - mirrors PilotState structure**

```gdscript
extends RefCounted
class_name FinState

var fin: Fin  # Reference to base Fin resource
var temporary_badges: Array[Badge] = []  # Earned during race

# Badge tracking
var consecutive_rounds_in_condition: Dictionary = {}

func get_stat(stat_name: String) -> int:
    match stat_name:
        "THRUST": return fin.THRUST
        "FORM": return fin.FORM
        "RESPONSE": return fin.RESPONSE
        "SYNC": return fin.SYNC
    return 0

func get_all_badges() -> Array[Badge]:
    return fin.equipped_badges + temporary_badges
```

---

### 1.3 Update PilotState to Reference Fin
**Modify `scripts/systems/pilotstate.gd`**

Add field:
```gdscript
var fin_state: FinState  # The craft this pilot is controlling
```

---

## Phase 2: Badge System Integration

### 2.1 Create Fin-Specific Badges
**New badge resources focusing on craft characteristics**

Examples:
- **Reinforced Hull** (WEAR_AND_TEAR)
  - Trigger: When defending
  - Effect: +1 to defending rolls
  - Applies to: defending_rolls

- **Aerodynamic Shell** (PERMANENT)
  - Trigger: In clear air
  - Effect: +1 to movement rolls
  - Applies to: movement_rolls

- **Overtuned Thrusters** (WEAR_AND_TEAR)
  - Trigger: When attacking
  - Effect: +1 to overtaking rolls
  - Applies to: overtaking_rolls
  - Note: Can be lost during hard racing (wear & tear)

- **Battle Scarred** (RACE_TEMPORARY, earned during race)
  - Trigger: After completing 3+ defensive actions
  - Effect: +1 to all rolls
  - Earned by: Successfully defending 3+ times

---

### 2.2 Extend BadgeSystem for Fins
**Modify `scripts/systems/BadgeSystem.gd`**

Current functions take `pilot: PilotState`, need to also handle fins:

```gdscript
# New/Modified functions:
static func get_active_modifiers_combined(
    pilot: PilotState,
    fin: FinState,
    context: Dictionary
) -> Array:
    var mods = []
    mods.append_array(get_active_modifiers(pilot, context))
    mods.append_array(get_active_modifiers_for_fin(fin, context))
    return mods

static func get_active_modifiers_for_fin(
    fin: FinState,
    context: Dictionary
) -> Array:
    # Same logic as pilot version, but checks fin badges
    pass
```

---

## Phase 3: Stat Calculation Infrastructure

### 3.1 Keep Existing Sector System Working (Backward Compatibility)
**No changes to current TWITCH/CRAFT/SYNC/EDGE sectors**

Current sectors continue to use pilot stats only:
- TWITCH sectors → pilot.TWITCH
- CRAFT sectors → pilot.CRAFT
- SYNC sectors → pilot.SYNC
- EDGE sectors → pilot.EDGE

---

### 3.2 Document Future Sector Types (Not Implemented Yet)
**Add to `scripts/resources/sector.gd` as comments**

```gdscript
# FUTURE: New combined pilot+fin sector types (Phase 4)
# These will use: d20 + pilot_stat + fin_stat + modifiers
#
# Twitch-based:
#   - BURST_ZONE (Twitch × Thrust)
#   - IMPACT_POINTS (Twitch × Form)
#   - REFLEX_SECTION (Twitch × Response)
#
# Craft-based:
#   - TACTICAL_STRAIGHT (Craft × Thrust)
#   - TECHNICAL_COMPLEX (Craft × Form)
#   - PRECISION_PASSAGE (Craft × Response)
#
# Edge-based:
#   - POWER_THRESHOLDS (Edge × Thrust)
#   - ENDURANCE_TEST (Edge × Form)
#   - COMMITMENT_CORNER (Edge × Response)
#
# Sync-based (Future - Relationship system):
#   - HARMONY_STRAIGHT (Relationship × Thrust)
#   - FLOW_COMPLEX (Relationship × Form)
#   - RESONANCE_ZONE (Relationship × Response)
```

---

### 3.3 Add Helper for Combined Stats (Dormant for Now)
**Add to `scripts/systems/pilotstate.gd`**

```gdscript
# Future: Get combined pilot+fin stat for new sector types
func get_combined_stat(sector_check_type: String) -> int:
    # For now, just return pilot stat (backward compatible)
    # In Phase 4, this will add fin contribution
    return get_stat(sector_check_type)
```

---

## Phase 4: Race Integration

### 4.1 Fin Selection Before Race
**Modify race setup/initialization**

- Add fin selection to race configuration
- Each pilot must have a fin assigned before race starts
- Store fin assignment in race state

**Where to implement:**
- Race setup UI (wherever pilots are selected)
- RaceState initialization (assign fin to each pilot)

---

### 4.2 Update TurnProcessor for Fin Badges
**Modify `scripts/systems/TurnProcessor.gd`**

When collecting modifiers for rolls:
```gdscript
func make_roll(pilot: PilotState, sector: Sector, current_round: int) -> Dice.DiceResult:
    var stat_value = pilot.get_stat(sector.check_type)
    var modifiers = []

    var context = {
        "roll_type": "movement",
        "sector": sector,
        "round": current_round
    }

    # Apply BOTH pilot and fin badge modifiers
    var pilot_mods = BadgeSystem.get_active_modifiers(pilot, context)
    var fin_mods = BadgeSystem.get_active_modifiers_for_fin(pilot.fin_state, context)
    modifiers.append_array(pilot_mods)
    modifiers.append_array(fin_mods)

    return Dice.roll_d20(stat_value, check_name, modifiers, gates, context)
```

---

### 4.3 Update OvertakeResolver for Fin Badges
**Modify `scripts/systems/OvertakeResolver.gd`**

Similar changes - collect modifiers from both pilot and fin for contested rolls.

---

### 4.4 Fin Badge Earning During Race
**Add badge earning logic**

Similar to pilot badge earning:
- Track fin performance in sectors
- Award temporary badges based on criteria
- Apply wear & tear badge loss

Example:
- Fin completes 2+ GREEN results in technical sectors → earns "Tuned Suspension" badge
- Fin takes damage from collision → loses "Pristine Aero" badge

---

## Phase 5: UI Integration

### 5.1 Fin Selection Screen
**New or modified UI**

- Display available fins with stats
- Show fin badges
- Allow pilot-to-fin assignment

---

### 5.2 Race HUD Updates
**Show fin information during race**

- Display fin name/model
- Show active fin badges
- Indicate fin condition (via badges)

---

### 5.3 Post-Race Summary
**Include fin performance**

- Fins badges earned/lost
- Fin wear & tear status

---

## Phase 6: Sample Data & Testing

### 6.1 Create Sample Fins
**Create 5+ fin resources in `scripts/resources/fins/`**

Example distributions:
- **Interceptor-class** (THRUST:7, FORM:5, RESPONSE:7, SYNC:6) - Fast & agile
- **Tank-class** (THRUST:5, FORM:8, RESPONSE:5, SYNC:6) - Durable
- **Balanced-class** (THRUST:6, FORM:6, RESPONSE:6, SYNC:7) - Jack of all trades
- **Technical-class** (THRUST:5, FORM:6, RESPONSE:8, SYNC:7) - Precision handling
- **Power-class** (THRUST:8, FORM:6, RESPONSE:5, SYNC:6) - Raw acceleration

---

### 6.2 Create Sample Fin Badges
**Create 10+ fin badge resources**

Mix of:
- PERMANENT badges (built-in design features)
- WEAR_AND_TEAR badges (can be lost)
- RACE_TEMPORARY badges (earned during race)

---

### 6.3 Testing Scenarios
**Verify:**
1. Existing races work unchanged (backward compatibility)
2. Fins can be assigned to pilots
3. Fin badges activate correctly based on triggers
4. Fin badges apply modifiers to rolls
5. Fin badges can be earned during race
6. Fin badges can be lost (wear & tear)

---

## Implementation Order

1. **Create Fin & FinState classes** (Phase 1.1, 1.2)
2. **Link FinState to PilotState** (Phase 1.3)
3. **Create sample fins** (Phase 6.1)
4. **Extend BadgeSystem for fins** (Phase 2.2)
5. **Create sample fin badges** (Phase 2.1, 6.2)
6. **Update TurnProcessor for fin badge modifiers** (Phase 4.2)
7. **Update OvertakeResolver for fin badge modifiers** (Phase 4.3)
8. **Add fin selection to race setup** (Phase 4.1)
9. **Implement fin badge earning** (Phase 4.4)
10. **Add UI for fin selection/display** (Phase 5)
11. **Test & verify** (Phase 6.3)

---

## Notes

- **Backward Compatibility**: Existing sector system (TWITCH/CRAFT/SYNC/EDGE) remains unchanged
- **Future Expansion**: Infrastructure ready for 12 new sector types (pilot×fin combos)
- **Relationship System**: Sync stat tracked but not used yet; Relationship system deferred
- **Badge Philosophy**: Fin badges focus on craft design & physical wear; pilot badges focus on mentality & experience

---

## Open Questions for Future Phases

1. **Fin Customization**: Can players upgrade/modify fins between races?
2. **Fin Damage**: Beyond badges, any HP/condition tracking?
3. **Fin Unlocking**: Are fins unlocked through progression, or all available from start?
4. **Pilot-Fin Synergy**: Special bonuses for specific pilot+fin combinations?
