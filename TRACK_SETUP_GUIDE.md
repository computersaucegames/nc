# Track Setup Guide - Mountain Circuit

This guide will walk you through setting up the racing line (Path2D) and sector markers for your mountain track sprite in Godot.

## Prerequisites
- Mountain track sprite placed at: `resources/art/mountain track.png`
- Mountain track circuit resource: `resources/circuits/mountain_track.tres`
- Mountain display scene: `scenes/ui/MountainCircuitDisplay.tscn`

## Step-by-Step: Setting Up the Racing Line

### 1. Open the Mountain Display Scene
1. In Godot, navigate to `res://scenes/ui/MountainCircuitDisplay.tscn`
2. Double-click to open it in the editor

### 2. Locate the Key Nodes
You'll see these important nodes in the Scene tree:
- **TrackSprite** - Your mountain track image
- **TrackPath** (Path2D node) - The racing line that pilots follow
- **SectorMarkers** (Node2D parent) - Contains sector start positions
  - Sector1Start (Marker2D)
  - Sector2Start (Marker2D)
  - Sector3Start (Marker2D)

### 3. Adjust Track Sprite Position (If Needed)
1. Select the **TrackSprite** node
2. In the Inspector, adjust the **Position** property to center your track in the viewport
3. Adjust the **Scale** property if your track needs to be bigger/smaller
4. Default scale is (3, 3) - you may need to adjust based on your sprite size

### 4. Draw the Racing Line (Path2D)
This is the most important step - the racing line determines where pilots appear on the track!

1. Select the **TrackPath** node in the Scene tree
2. Look at the top toolbar - you should see Path2D editing buttons appear:
   - ➕ Add Point
   - ✏️ Edit Point
   - 🗑️ Delete Point
   - ↔️ Edit Tangents (for smooth curves)
   - ❌ Close Path

3. **Clear the existing placeholder path:**
   - Select all points (Ctrl+A or click each while holding Shift)
   - Delete them (Delete key or Delete Point button)

4. **Draw your new racing line:**
   - Click the **Add Point** button (➕)
   - Click on your track sprite where the racing line should START
   - Continue clicking to add points along the ideal racing line
   - Space points evenly around the track (every major turn/straight)
   - **IMPORTANT:** End near where you started to complete the loop

5. **Close the loop:**
   - Click the **Close Path** button (❌) to connect the last point to the first
   - The path should now form a complete circuit

6. **Smooth the curves (Optional but recommended):**
   - Select the **Edit Point** button (✏️)
   - Click on a point to select it
   - Click the **Edit Tangents** button (↔️)
   - Drag the tangent handles to create smooth curves
   - Repeat for each corner to match your track's flow

### 5. Position the Sector Markers
Sector markers indicate where each sector begins on the track.

1. **Sector 1 Start Marker:**
   - Select **SectorMarkers > Sector1Start** in the Scene tree
   - In the viewport, drag this marker to where Sector 1 begins (usually the start/finish line)
   - Or manually set Position in the Inspector (X, Y coordinates)

2. **Sector 2 Start Marker:**
   - Select **SectorMarkers > Sector2Start**
   - Drag to where Sector 2 begins on your track
   - Position this roughly 1/3 of the way around the circuit

3. **Sector 3 Start Marker:**
   - Select **SectorMarkers > Sector3Start**
   - Drag to where Sector 3 begins
   - Position this roughly 2/3 of the way around the circuit

**Tip:** Match the sector positions to significant features on your track (e.g., after a major corner, start of a straight, etc.)

### 6. Test the Positioning
1. Save the scene (Ctrl+S)
2. Run the RaceTestScene
3. Select "Mountain Circuit" from the circuit selector
4. Start a race and observe:
   - Do the pilot icons follow the racing line correctly?
   - Do they match the visual track?
   - Are sector transitions happening at the right places?

### 7. Adjust and Iterate
If pilots don't follow the track correctly:
- **Off the track entirely:** Adjust TrackSprite position/scale
- **Wrong path:** Edit the Path2D curve points
- **Weird sectors:** Reposition the sector markers

## Visual Reference

Your racing line should:
- Follow the center/ideal line of your track
- Have enough points to accurately represent corners (3-5 points per major turn)
- Form a smooth, continuous loop
- Match the visual flow of your track sprite

Sector markers should:
- Be positioned ON the racing line path
- Mark logical divisions of the track (e.g., turns, straights)
- Be evenly spaced if possible (unless your track has natural divisions)

## Path2D Tips

### Number of Points
- **Minimum:** 4 points (simple oval/triangle)
- **Recommended:** 8-15 points (typical circuit)
- **Complex track:** 15-25 points (lots of corners)

### Point Placement
- Add points at: Corner entry, apex, corner exit, mid-straight
- DON'T add too many points on straights (2 is enough)
- DO add more points in complex corner sequences

### Tangent Handles
- Longer handles = gentler curves
- Shorter handles = tighter corners
- Adjust handles to match the track's corner radius

## Sector Configuration

If you need to adjust sector properties (length, thresholds, etc.):
1. Open `resources/circuits/mountain_track.tres` in Godot
2. Expand the **Sectors** array
3. Edit each sector's properties:
   - **sector_name**: Display name (e.g., "Summit Approach")
   - **length_in_gap**: How many gap units long (affects race duration)
   - **check_type**: Type of skill check (0=TWITCH, 1=CRAFT, 2=SYNC, 3=EDGE)
   - **thresholds**: Grey/Green/Purple roll thresholds
   - **movement**: How far pilots move on each result
   - **failure_table**: What happens on red rolls

## Troubleshooting

**Pilots don't appear on track:**
- Check that TrackPath has a valid closed curve
- Verify the curve has point_count > 0
- Check TrackSprite is visible

**Pilots jump around weirdly:**
- Path might not be closed - use Close Path button
- Path might cross itself - redraw problematic sections

**Sector markers invisible:**
- This is normal - they're editor-only visualization
- The sectors still work, pilots just don't see the markers

**Track looks wrong after selection:**
- Make sure mountain_track.tres has display_scene set to MountainCircuitDisplay.tscn
- Clear and re-save the resource if needed

## Done!

Once you're happy with the racing line and sector positions, your mountain track is ready to race! The circuit selector will now properly show both the Pizza Circuit and your Mountain Circuit with their correct visuals.

---

**Need to add more sectors?** Edit mountain_track.tres and add more Sector resources to the array. Then add corresponding SectorNStart markers in the scene.

**Want different sprite scaling?** Adjust TrackSprite scale - you may need to redraw the Path2D if you change scale significantly.
