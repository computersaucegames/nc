# Combined Pilot + Fin Stat Sectors

## Overview

Sectors now support **combined pilot + fin stats** for more complex racing challenges. Each sector can specify both:
1. **Pilot stat** (check_type): TWITCH, CRAFT, SYNC, or EDGE
2. **Fin stat** (fin_stat_type): THRUST, FORM, RESPONSE, SYNC, or NONE

When both are specified, the roll uses: `d20 + pilot_stat + fin_stat + modifiers`

## Stat Pairings

Recommended pilot → fin stat combinations:

| Pilot Stat | Fin Stat | Description |
|------------|----------|-------------|
| **TWITCH** | RESPONSE | Quick reflexes + responsive handling = reaction speed |
| **CRAFT** | FORM | Technical skill + stable aero = precision handling |
| **SYNC** | SYNC | Neural sync + fin compatibility = harmonious control |
| **EDGE** | THRUST | Aggressive driving + raw power = overtaking ability |

## Gate Adjustments

With combined stats, the roll range increases from **2-28** to **3-36**.

### Old Gates (Pilot Only)
- Grey: 5 (failure threshold)
- Green: 10 (success threshold)
- Purple: 15 (critical threshold)

### New Gates (Pilot + Fin)
- Grey: **9** (failure threshold)
- Green: **18** (success threshold)
- Purple: **27** (critical threshold)

### Why These Numbers?

**Average roll calculation:**
- Pilot stat average: 5
- Fin stat average: 5
- d20 average: 10.5
- **Total average: 20.5**

With gates at 9/18/27:
- Grey (9): Easy to avoid failure (need 4+ total from stats)
- Green (18): Balanced challenge (need average roll)
- Purple (27): Difficult critical (need 16+ from stats+roll)

## Updating Existing Tracks

### Option 1: Run the Update Script (Recommended)

1. Open Godot
2. Create a new scene with a Node
3. Attach `scripts/tools/update_circuits_for_fins.gd`
4. Run the scene (F6)
5. Check Output panel for results

This will automatically:
- Add fin stats to all sectors in Mountain and Pizza circuits
- Update gates from 5/10/15 → 9/18/27
- Save the updated circuit files

### Option 2: Manual Update

For each sector in the .tres file:

**Before:**
```
check_type = 0
grey_threshold = 5
green_threshold = 10
purple_threshold = 15
```

**After:**
```
check_type = 0
fin_stat_type = 3  # Add this line! (RESPONSE for TWITCH sectors)
grey_threshold = 9
green_threshold = 18
purple_threshold = 27
```

**Fin Stat Type Values:**
- 0 = NONE (legacy, pilot stat only)
- 1 = THRUST
- 2 = FORM
- 3 = RESPONSE
- 4 = SYNC

**Mapping Table:**
- check_type 0 (TWITCH) → fin_stat_type 3 (RESPONSE)
- check_type 1 (CRAFT) → fin_stat_type 2 (FORM)
- check_type 2 (SYNC) → fin_stat_type 4 (SYNC)
- check_type 3 (EDGE) → fin_stat_type 1 (THRUST)

## Backward Compatibility

Sectors with `fin_stat_type = 0` (NONE) work exactly as before:
- Only pilot stat is used
- Old gates (5/10/15) still work
- No fin required

## Testing

After updating tracks:

1. **Assign fins to pilots** in your race setup:
```gdscript
var pilot_list = [
	{
		"pilot": pilot_resource,
		"fin": fin_resource  # Must have fin for combined checks!
	}
]
```

2. **Run a race** and verify:
   - Rolls are higher (stat values combined)
   - Gates work correctly (harder to fail, harder to crit)
   - Badges still apply from both pilot and fin

## Example: Before & After

### Before (Pilot Only)
```
Sector: "Narrow Pass" (CRAFT check)
Pilot Craft: 7
Roll: d20(12) + 7 = 19
Gates: 5/10/15
Result: PURPLE (19 ≥ 15)
```

### After (Pilot + Fin)
```
Sector: "Narrow Pass" (CRAFT + FORM check)
Pilot Craft: 7
Fin Form: 6
Roll: d20(12) + 7 + 6 = 25
Gates: 9/18/27
Result: GREEN (25 ≥ 18, but < 27)
```

Notice: Same d20 roll, but result tier changed due to adjusted difficulty!

## Future Enhancements

Currently, fin stat pairing is **manual** (set per sector). In the future, we could implement the 12 new combined sector types from the implementation plan:

- Burst Zone (TWITCH × THRUST)
- Impact Points (TWITCH × FORM)
- Reflex Section (TWITCH × RESPONSE)
- Tactical Straight (CRAFT × THRUST)
- Technical Complex (CRAFT × FORM)
- Precision Passage (CRAFT × RESPONSE)
- Power Thresholds (EDGE × THRUST)
- Endurance Test (EDGE × FORM)
- Commitment Corner (EDGE × RESPONSE)
- Harmony Straight (SYNC × THRUST)
- Flow Complex (SYNC × FORM)
- Resonance Zone (SYNC × RESPONSE)

These would be new CheckType enum values that automatically determine the fin stat.

## Troubleshooting

### "Sectors feel too easy now"
- Increase gates: try 10/20/30 instead of 9/18/27
- Adjust per-sector based on difficulty intent

### "Pilots without fins failing constantly"
- Either assign fins to all pilots, OR
- Keep some sectors with fin_stat_type = NONE for legacy support

### "Rolls seem wrong"
- Check that both pilot AND fin stats are being added
- Verify fin_stat_type is not NONE (0)
- Ensure pilot has a fin assigned

## Code Integration

The changes are in:
- `scripts/resources/sector.gd` - Added FinStatType enum
- `scripts/systems/TurnProcessor.gd` - Adds fin stat to movement rolls
- `scripts/systems/OvertakeResolver.gd` - Adds fin stat to overtake rolls
- `scripts/tools/update_circuits_for_fins.gd` - Batch update script
