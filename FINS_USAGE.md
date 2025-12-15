# Fins System - Usage Guide

## Overview

The **Fins** system separates pilots from their racing craft. Each pilot can be assigned a "fin" (racing craft) with its own stats and badges that work alongside the pilot's abilities.

## Quick Start

### 1. Loading Fin Resources

```gdscript
# Load a fin from resources
var interceptor = load("res://resources/fins/interceptor_mk7.tres")
var bulwark = load("res://resources/fins/bulwark.tres")
```

### 2. Assigning Fins to Pilots in Races

When starting a race, use the extended pilot data format:

```gdscript
var pilot_list = [
	{
		"pilot": load("res://resources/pilots/buoy.tres"),
		"headshot": "res://path/to/headshot.png",
		"fin": load("res://resources/fins/interceptor_mk7.tres")  # NEW!
	},
	{
		"pilot": load("res://resources/pilots/redman.tres"),
		"headshot": "",
		"fin": load("res://resources/fins/bulwark.tres")
	}
]

race_simulator.start_race(circuit, pilot_list)
```

### 3. Assigning Fins Manually

```gdscript
var pilot_state = PilotState.new()
pilot_state.setup_from_pilot_resource(pilot_resource)

# Assign a fin
var fin_resource = load("res://resources/fins/thunderbolt.tres")
pilot_state.setup_fin(fin_resource)

# Now pilot has pilot_state.fin_state with fin data
```

## Available Fins

| Fin Name | Model | Profile | Stats (THRUST/FORM/RESPONSE/SYNC) |
|----------|-------|---------|-----------------------------------|
| **Interceptor MK-VII** | MK-VII | Speed & Agility | 7/5/7/6 |
| **Bulwark** | BW-440 | Durable Tank | 5/8/5/6 |
| **Equilibrium** | EQ-600 | Balanced | 6/6/6/7 |
| **Scalpel** | SC-850 | Precision | 5/6/8/7 |
| **Thunderbolt** | TB-900 | Raw Power | 8/6/5/6 |

### Fin Stats

- **THRUST** (1-8): Power & acceleration
- **FORM** (1-8): Durability, stability, aerodynamics
- **RESPONSE** (1-8): Handling & reaction time
- **SYNC** (1-8): Neural sync compatibility *(currently tracked but not used in sectors)*

## Fin Badges

Fins have their own badge system separate from pilots. Fin badges focus on **craft design and physical wear**.

### Permanent Badges

| Badge | Effect | Trigger |
|-------|--------|---------|
| **Aerodynamic Shell** | +1 movement | In clear air |
| **Precision Calibration** | +1 all rolls | In CRAFT sectors |
| **Launch Systems** | +1 race start | Race start only |

### Wear & Tear Badges (Can be lost)

| Badge | Effect | Trigger |
|-------|--------|---------|
| **Reinforced Hull** | +1 defending | When defending |
| **Overtuned Thrusters** | +1 overtaking | When attacking |
| **Lightweight Frame** | +1 movement | Always (movement rolls) |

### Negative Badges (Damage)

| Badge | Effect | Permanence |
|-------|--------|-----------|
| **Damaged Aero** | -1 movement | Race temporary |

## How Fin Badges Work

### During Races

1. **Badge evaluation**: Both pilot AND fin badges are checked every roll
2. **Modifiers combine**: Pilot badge bonuses + fin badge bonuses stack
3. **Badge triggers**: Fin badges use pilot status (attacking, defending, clear air, etc.)

### Example: Combined Bonuses

```
Pilot: Redman with "Clear Air Specialist" (+1 in clear air)
Fin: Interceptor with "Aerodynamic Shell" (+1 movement in clear air)

When in clear air during movement roll:
  Pilot bonus: +1 (Clear Air Specialist)
  Fin bonus: +1 (Aerodynamic Shell)
  Total: +2 to the roll
```

### Badge Earning

Fins can **earn temporary badges** during races based on performance:

```gdscript
# Example: Earning a badge for good performance in technical sectors
# After completing sectors with "technical" tag with GREEN+ results
# Fin may earn a "Tuned Suspension" badge
```

Badge earning works the same as pilot badges:
- Track sector completions with `BadgeSystem.track_fin_sector_completion()`
- Award badges with `BadgeSystem.check_and_award_fin_sector_badges()`

## Testing

### Run Basic Tests

```gdscript
# Load and run the test scene
var test_scene = load("res://tests/test_fin_system.gd")
# Run in Godot to see console output
```

### Run Race Simulation Tests

```gdscript
# Load and run the race simulation tests
var race_test = load("res://tests/test_fin_badges_in_race.gd")
# Tests fin badges applying to actual rolls
```

## Code Integration Points

### Where Fin Badges Apply

1. **Movement Rolls** (`TurnProcessor.gd:126-167`)
   - Pilot badges checked
   - **Fin badges checked** ✓

2. **Overtaking Rolls** (`OvertakeResolver.gd:102-146`)
   - Attacker pilot badges checked
   - **Attacker fin badges checked** ✓
   - Defender pilot badges checked
   - **Defender fin badges checked** ✓

3. **Badge State Updates** (`RoundProcessor.gd:80-86`)
   - Pilot badge states updated each round
   - **Fin badge states updated each round** ✓

## Backward Compatibility

- **Fins are optional**: Pilots without fins work normally
- **Existing code unchanged**: Old sector system (TWITCH/CRAFT/SYNC/EDGE) still works
- **Legacy support**: Dictionary-based pilot setup still works (no fin assignment)

## Future Enhancements

### 12 New Sector Types (Planned, not implemented)

In the future, sectors will use **combined pilot × fin stats**:

**Twitch-based:**
- Burst Zone (Twitch × Thrust)
- Impact Points (Twitch × Form)
- Reflex Section (Twitch × Response)

**Craft-based:**
- Tactical Straight (Craft × Thrust)
- Technical Complex (Craft × Form)
- Precision Passage (Craft × Response)

**Edge-based:**
- Power Thresholds (Edge × Thrust)
- Endurance Test (Edge × Form)
- Commitment Corner (Edge × Response)

**Relationship-based** *(future system)*:
- Harmony Straight (Relationship × Thrust)
- Flow Complex (Relationship × Form)
- Resonance Zone (Relationship × Response)

## Troubleshooting

### Fin badges not applying?

Check:
1. Is `pilot_state.fin_state` not null?
2. Does the fin have badges equipped?
3. Are badge trigger conditions met? (e.g., clear air, attacking)

### Fin not assigned?

```gdscript
# Check if fin was assigned
if pilot_state.fin_state == null:
	print("No fin assigned!")
else:
	print("Fin: %s" % pilot_state.fin_state.fin_data.fin_name)
```

### Badges not stacking?

Both pilot and fin badges should stack. Check context includes `"pilot": pilot_state`:

```gdscript
var context = {
	"roll_type": "movement",
	"sector": sector,
	"pilot": pilot_state  # Required for fin badges!
}
```

## Creating Custom Fins

1. Create a new `.tres` file in `resources/fins/`
2. Set the script to `res://scripts/resources/fin.gd`
3. Configure stats (1-8 range)
4. Add equipped badges (optional)

Example:
```
[gd_resource type="Resource" script_class="Fin" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/fin.gd" id="1"]

[resource]
script = ExtResource("1")
fin_name = "Custom Racer"
fin_model = "CR-1000"
fin_bio = "A custom racing craft."
THRUST = 7
FORM = 6
RESPONSE = 7
SYNC = 6
equipped_badges = Array[Resource]([])
```

## Creating Custom Fin Badges

Same process as pilot badges, just save in `resources/badges/fins/`:

- Focus on **craft characteristics**: durability, aerodynamics, power systems
- Use **wear & tear** permanence for badges that can be lost
- Tie triggers to **racing status** (attacking, defending, clear air)

See `resources/badges/fins/` for examples.
