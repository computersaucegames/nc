extends Control
class_name CircuitDisplay

## Visual circuit display with Path2D-based pilot tracking
## Maps pilot positions (sector + gap) to visual positions along a racing line
##
## SETUP INSTRUCTIONS:
## 1. Open CircuitDisplay.tscn in the Godot editor
## 2. Select the TrackPath (Path2D) node
## 3. Use the Path2D editing tools to draw the racing line over your track sprite
## 4. Make sure the path forms a complete loop (last point near first point)
## 5. Adjust the TrackSprite position/scale to match your circuit layout
##
## The pilot icons will automatically follow this path based on their race position.

@onready var track_path: Path2D = $TrackPath
@onready var pilot_container: Node2D = $PilotContainer

var circuit: Circuit
var pilot_markers: Dictionary = {}  # pilot_id -> PathFollow2D
var total_circuit_length: int = 0

# Pilot icon scene to instantiate (can be customized)
const PILOT_ICON_SIZE = 16
const PILOT_COLORS = [
	Color.GOLD,           # 1st place
	Color.SILVER,         # 2nd place
	Color.ORANGE,         # 3rd place
	Color.CORNFLOWER_BLUE, # 4th place
	Color.HOT_PINK,       # 5th place
	Color.LAWN_GREEN,     # 6th place
	Color.PURPLE,         # 7th place
	Color.CYAN            # 8th place
]

func _ready():
	pass

## Initialize the circuit display with a circuit configuration
func setup_circuit(p_circuit: Circuit):
	circuit = p_circuit
	total_circuit_length = circuit.get_total_length()
	print("DEBUG: Circuit setup - %s, Total length: %d" % [circuit.circuit_name, total_circuit_length])

	# Note: The Path2D curve should be set up in the editor
	# or you can generate it programmatically here if needed
	if track_path.curve == null:
		print("DEBUG: No curve found, generating default path")
		track_path.curve = Curve2D.new()
		_generate_default_path()
	else:
		print("DEBUG: Curve exists, length: %.2f" % track_path.curve.get_baked_length())

## Generate a default circular path (fallback if not set in editor)
func _generate_default_path():
	var curve = track_path.curve
	curve.clear_points()

	# Create a simple oval track as default
	var center = Vector2(256, 256)
	var radius_x = 180
	var radius_y = 120
	var points = 32

	for i in range(points + 1):
		var angle = (float(i) / points) * TAU
		var point = center + Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		)
		curve.add_point(point)

## Setup pilots on the track
func setup_pilots(pilot_data: Array):
	print("DEBUG: Setting up %d pilots" % pilot_data.size())

	# Clear existing markers
	for marker in pilot_markers.values():
		marker.queue_free()
	pilot_markers.clear()

	# Create a PathFollow2D for each pilot
	for i in range(pilot_data.size()):
		var pilot = pilot_data[i]
		var path_follow = PathFollow2D.new()
		path_follow.rotates = false  # Keep icons upright
		path_follow.loop = true

		# Create visual marker (colored circle)
		var icon = _create_pilot_icon(i, pilot.get("name", "Pilot %d" % i))
		path_follow.add_child(icon)

		track_path.add_child(path_follow)
		pilot_markers[i] = path_follow
		print("DEBUG: Created marker for pilot %d (%s)" % [i, pilot.get("name", "Unknown")])

## Create a simple colored circle icon for a pilot using draw calls
func _create_pilot_icon(pilot_index: int, pilot_name: String) -> Control:
	var icon = Control.new()
	icon.custom_minimum_size = Vector2(PILOT_ICON_SIZE * 2, PILOT_ICON_SIZE * 2)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.position = Vector2(-PILOT_ICON_SIZE, -PILOT_ICON_SIZE)

	# Use a simple colored panel
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(PILOT_ICON_SIZE, PILOT_ICON_SIZE)
	panel.size = Vector2(PILOT_ICON_SIZE, PILOT_ICON_SIZE)
	panel.position = Vector2(0, 0)

	# Create a StyleBox for colored background
	var style = StyleBoxFlat.new()
	style.bg_color = PILOT_COLORS[pilot_index % PILOT_COLORS.size()]
	style.border_color = Color.WHITE
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = PILOT_ICON_SIZE / 2
	style.corner_radius_top_right = PILOT_ICON_SIZE / 2
	style.corner_radius_bottom_left = PILOT_ICON_SIZE / 2
	style.corner_radius_bottom_right = PILOT_ICON_SIZE / 2
	panel.add_theme_stylebox_override("panel", style)

	# Label with position number
	var label = Label.new()
	label.text = str(pilot_index + 1)
	label.position = Vector2(PILOT_ICON_SIZE + 4, 0)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)

	icon.add_child(panel)
	icon.add_child(label)

	return icon

## Update a single pilot's position on the track
## Parameters:
##   pilot_id: Index of the pilot (0-based)
##   current_lap: Current lap number (1-based)
##   current_sector: Current sector index (0-based)
##   gap_in_sector: Progress within the current sector (0 to sector.length_in_gap)
func update_pilot_position(pilot_id: int, current_lap: int, current_sector: int, gap_in_sector: int):
	if not pilot_markers.has(pilot_id):
		print("WARNING: Pilot %d not found in pilot_markers" % pilot_id)
		return

	if total_circuit_length == 0:
		print("WARNING: total_circuit_length is 0!")
		return

	# Calculate total progress along the circuit
	var progress_gap = _calculate_total_gap_position(current_sector, gap_in_sector)

	# Convert to normalized progress (0.0 to 1.0)
	var progress_ratio = float(progress_gap) / float(total_circuit_length)

	# Clamp to valid range
	progress_ratio = clamp(progress_ratio, 0.0, 1.0)

	# Update the PathFollow2D position
	var path_follow: PathFollow2D = pilot_markers[pilot_id]
	path_follow.progress_ratio = progress_ratio

	print("DEBUG: Pilot %d - Sector: %d, Gap: %d, Progress: %.2f (Total gap: %d/%d)" %
		[pilot_id, current_sector, gap_in_sector, progress_ratio, progress_gap, total_circuit_length])

## Update all pilots from an array of PilotState objects
func update_all_pilots(pilots: Array):
	for i in range(pilots.size()):
		var pilot = pilots[i]
		update_pilot_position(
			i,
			pilot.current_lap,
			pilot.current_sector,
			pilot.gap_in_sector
		)

## Calculate the total gap position from start of circuit
func _calculate_total_gap_position(sector_index: int, gap_in_sector: int) -> int:
	var total_gap = 0

	# Add up all previous sectors
	for i in range(sector_index):
		if i < circuit.sectors.size():
			total_gap += circuit.sectors[i].length_in_gap

	# Add current position in sector
	total_gap += gap_in_sector

	return total_gap

## Helper: Get sector start ratio (for debugging/sector markers)
func get_sector_start_ratio(sector_index: int) -> float:
	var gap_position = _calculate_total_gap_position(sector_index, 0)
	return float(gap_position) / float(total_circuit_length)
