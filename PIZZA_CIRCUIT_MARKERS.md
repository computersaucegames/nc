# Pizza Circuit - Pilot Position Marker System

## Circuit Overview

**Pizza Circuit** is a 3-sector triangular racing circuit themed around pizza slices.

### Circuit Specifications
- **Total Length**: 18 gap units (6 + 6 + 6)
- **Laps**: 3
- **Country**: Italy
- **Shape**: Equilateral triangle

### Sectors

1. **Crust Corner** (Sector 1 - Start)
   - Length: 6 gap units
   - Check Type: TWITCH
   - Carrythru: 2
   - Starting sector with grid positions

2. **Cheese Chase** (Sector 2)
   - Length: 6 gap units
   - Check Type: CRAFT
   - Carrythru: 2
   - Technical precision sector

3. **Sauce Straight** (Sector 3)
   - Length: 6 gap units
   - Check Type: EDGE
   - Carrythru: 2
   - Aggressive driving sector

## Marker System Implementation

### Current System (Already Implemented)

The marker system is **already fully functional** in the existing codebase. No new code is needed!

#### How Position Tracking Works

1. **Gap-Based Position Calculation**
   - Each pilot has `current_sector` (0-2) and `gap_in_sector` (0-6)
   - Total distance = sum of completed sector gaps + current gap in sector
   - Example: Pilot in Sector 2 with gap 3 = (6) + 3 = 9 total gap

2. **Visual Markers (CircuitDisplay.gd)**
   - Uses `PathFollow2D` nodes for each pilot
   - Pilots represented as colored circles (16px)
   - Position calculated as: `progress_ratio = total_distance / circuit_length`
   - PathFollow2D automatically positions pilots along the triangular racing line

3. **Sector Start Markers**
   - Three `Marker2D` nodes mark sector boundaries:
     - **Sector1Start**: Position (256, 100) - Top of triangle
     - **Sector2Start**: Position (400, 350) - Bottom-right corner
     - **Sector3Start**: Position (112, 350) - Bottom-left corner

4. **Racing Line (Path2D)**
   - Triangular Curve2D with 4 points (closes the loop):
     - Point 1: (256, 100) - Top
     - Point 2: (400, 350) - Bottom-right
     - Point 3: (112, 350) - Bottom-left
     - Point 4: (256, 100) - Back to top

### Pilot Colors & Position Indicators

| Position | Color | Hex Code |
|----------|-------|----------|
| P1 | Gold | #FFD700 |
| P2 | Silver | #C0C0C0 |
| P3 | Orange | #FFA500 |
| P4 | Cornflower Blue | #6495ED |
| P5 | Hot Pink | #FF69B4 |
| P6 | Lawn Green | #7CFC00 |
| P7 | Purple | #800080 |
| P8 | Cyan | #00FFFF |

### Real-Time Position Updates

The system automatically updates pilot positions through these signals:
- `pilot_moved` - Updates PathFollow2D.progress_ratio
- `sector_completed` - Advances to next sector
- `lap_completed` - Increments lap counter

## Using the Pizza Circuit

### 1. Load the Circuit Resource
```gdscript
var pizza_circuit = load("res://resources/circuits/pizza_circuit.tres")
```

### 2. Use with CircuitDisplay Scene
```gdscript
# Load the pizza circuit display
var circuit_display = load("res://scenes/ui/PizzaCircuitDisplay.tscn").instantiate()
# The CircuitDisplay.gd script will handle all marker positioning automatically
```

### 3. Replace Placeholder Asset
When the triangle circuit asset is ready:
1. Save the PNG file as `/home/user/nc/resources/art/pizza_triangle_placeholder.png`
2. Godot will automatically re-import the texture
3. The CircuitDisplay will update to show the new artwork

## Example Position Scenario

```
Race State at Lap 2, Mid-Race:
- P1 (Gold): Sector 3, Gap 4 → Total: 6+6+4 = 16 gap + 18 (lap 1) = 34 total
- P2 (Silver): Sector 3, Gap 2 → Total: 6+6+2 = 14 gap + 18 (lap 1) = 32 total
  └─ Gap to leader: 2 units (ATTACKING)
- P3 (Orange): Sector 2, Gap 5 → Total: 6+5 = 11 gap + 18 (lap 1) = 29 total
  └─ Gap to P2: 3 units (ATTACKING)
```

On the triangular track display:
- All pilots appear as colored dots on the racing line
- Progress smoothly animates around the triangle
- Sector markers show where each sector begins
- PilotStatusPanel shows detailed gap and status info

## Files Created

1. `/home/user/nc/resources/circuits/pizza_circuit.tres` - Circuit resource definition
2. `/home/user/nc/scenes/ui/PizzaCircuitDisplay.tscn` - Visual display scene
3. `/home/user/nc/resources/art/pizza_triangle_placeholder.png.import` - Asset import config
4. This documentation file

## Next Steps

- [ ] Add actual triangle circuit artwork to replace placeholder
- [ ] Test the circuit in RaceTestScene
- [ ] Adjust sector marker positions if needed based on artwork
- [ ] Fine-tune racing line curve to match triangle shape
- [ ] Consider adding visual effects for sector transitions
