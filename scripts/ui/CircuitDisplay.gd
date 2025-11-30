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
var pilot_tweens: Dictionary = {}   # pilot_id -> Tween (for smooth animation)
var total_circuit_length: int = 0

# Pilot icon scene to instantiate (can be customized)
const PILOT_ICON_SIZE = 16
const MOVEMENT_ANIMATION_DURATION = 0.3  # Seconds for smooth pod movement
const OVERLAP_THRESHOLD = 0.02  # How close pilots need to be to count as overlapping (2% of track)
const LATERAL_OFFSET_DISTANCE = 10.0  # Pixels to offset sideways when overlapping

# Pod racer sprites for pilot icons
const POD_SPRITES = [
	"res://resources/art/classic-Recovered.png",
	"res://resources/art/bigblue-Recovered.png",
	"res://resources/art/3 wide-Recovered.png",
	"res://resources/art/pod-Recovered.png",
]

# Colors to modulate pods (for pilots beyond 4)
const PILOT_COLORS = [
	Color.WHITE,          # 1st - classic (red)
	Color.WHITE,          # 2nd - bigblue (blue)
	Color.WHITE,          # 3rd - 3 wide (red/orange)
	Color.CORAL,          # 4th - pod (yellow) with coral tint to stand out
	Color.HOT_PINK,       # 5th - classic + pink tint
	Color.LAWN_GREEN,     # 6th - bigblue + green tint
	Color.PURPLE,         # 7th - 3 wide + purple tint
	Color.CYAN            # 8th - pod + cyan tint
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

	for pt_idx in range(points + 1):
		var angle = (float(pt_idx) / points) * TAU
		var point = center + Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		)
		curve.add_point(point)

## Setup pilots on the track
func setup_pilots(pilot_data: Array):
	print("DEBUG: Setting up %d pilots" % pilot_data.size())

	# Clear existing markers and tweens
	for marker in pilot_markers.values():
		marker.queue_free()
	pilot_markers.clear()
	pilot_tweens.clear()

	# Create a PathFollow2D for each pilot
	for p_idx in range(pilot_data.size()):
		var pilot = pilot_data[p_idx]
		var path_follow = PathFollow2D.new()
		path_follow.rotates = true  # Rotate to face heading direction
		path_follow.loop = true

		# Create visual marker (pod racer sprite)
		var icon = _create_pilot_icon(p_idx, pilot.get("name", "Pilot %d" % p_idx))
		path_follow.add_child(icon)

		track_path.add_child(path_follow)
		pilot_markers[p_idx] = path_follow
		print("DEBUG: Created marker for pilot %d (%s)" % [p_idx, pilot.get("name", "Unknown")])

## Create a pod racer sprite icon for a pilot
func _create_pilot_icon(pilot_index: int, pilot_name: String) -> Node2D:
	var container = Node2D.new()

	# Load the pod sprite
	var sprite = Sprite2D.new()
	var pod_index = pilot_index % POD_SPRITES.size()
	sprite.texture = load(POD_SPRITES[pod_index])
	sprite.modulate = PILOT_COLORS[pilot_index % PILOT_COLORS.size()]

	# Scale up the sprite (adjust as needed for visibility)
	sprite.scale = Vector2(2.0, 2.0)

	container.add_child(sprite)

	# Label with position number
	var label = Label.new()
	label.text = str(pilot_index + 1)
	label.position = Vector2(12, -8)  # Position next to sprite
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)

	container.add_child(label)

	return container

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

	# Update the PathFollow2D position with smooth animation
	var path_follow: PathFollow2D = pilot_markers[pilot_id]

	# Kill existing tween if running to avoid conflicts
	if pilot_tweens.has(pilot_id) and pilot_tweens[pilot_id]:
		pilot_tweens[pilot_id].kill()

	# Create smooth tween animation to new position
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(path_follow, "progress_ratio", progress_ratio, MOVEMENT_ANIMATION_DURATION)
	pilot_tweens[pilot_id] = tween

	print("DEBUG: Pilot %d - Sector: %d, Gap: %d, Progress: %.2f (Total gap: %d/%d)" %
		[pilot_id, current_sector, gap_in_sector, progress_ratio, progress_gap, total_circuit_length])

## Update all pilots from an array of PilotState objects
func update_all_pilots(pilots: Array):
	# First, update all pilot positions
	for pilot_idx in range(pilots.size()):
		var pilot = pilots[pilot_idx]
		update_pilot_position(
			pilot_idx,
			pilot.current_lap,
			pilot.current_sector,
			pilot.gap_in_sector
		)

	# Then, apply lateral offsets for overlapping pilots
	_apply_overlap_offsets()

## Calculate the total gap position from start of circuit
func _calculate_total_gap_position(sector_index: int, gap_in_sector: int) -> int:
	var total_gap = 0

	# Add up all previous sectors
	for sect_idx in range(sector_index):
		if sect_idx < circuit.sectors.size():
			total_gap += circuit.sectors[sect_idx].length_in_gap

	# Add current position in sector
	total_gap += gap_in_sector

	return total_gap

## Helper: Get sector start ratio (for debugging/sector markers)
func get_sector_start_ratio(sector_index: int) -> float:
	var gap_position = _calculate_total_gap_position(sector_index, 0)
	return float(gap_position) / float(total_circuit_length)

## Detect overlapping pilots and apply lateral offsets
func _apply_overlap_offsets():
	var pilot_positions = []

	# Collect all pilot positions
	for pilot_id in pilot_markers.keys():
		var path_follow = pilot_markers[pilot_id]
		pilot_positions.append({
			"id": pilot_id,
			"progress": path_follow.progress_ratio,
			"marker": path_follow
		})

	# Sort by progress
	pilot_positions.sort_custom(func(a, b): return a.progress < b.progress)

	# Detect groups of overlapping pilots
	var groups = []
	var current_group = []

	for pos_idx in range(pilot_positions.size()):
		if current_group.is_empty():
			current_group.append(pilot_positions[pos_idx])
		else:
			var last_pilot = current_group[-1]
			if abs(pilot_positions[pos_idx].progress - last_pilot.progress) < OVERLAP_THRESHOLD:
				# Overlapping - add to current group
				current_group.append(pilot_positions[pos_idx])
			else:
				# Not overlapping - finish current group and start new one
				if current_group.size() > 1:
					groups.append(current_group)
				current_group = [pilot_positions[pos_idx]]

	# Don't forget the last group
	if current_group.size() > 1:
		groups.append(current_group)

	# Reset all offsets first
	for pilot_id in pilot_markers.keys():
		var icon = pilot_markers[pilot_id].get_child(0)
		if icon:
			icon.position = Vector2.ZERO

	# Apply offsets to overlapping groups
	for group in groups:
		var num_pilots = group.size()
		for group_idx in range(num_pilots):
			var offset_distance = _calculate_lateral_offset(group_idx, num_pilots)
			var path_follow: PathFollow2D = group[group_idx].marker
			var icon = path_follow.get_child(0)
			if icon:
				# Calculate perpendicular direction to the track
				# PathFollow2D.rotation gives us the tangent angle
				# Add 90 degrees (PI/2) to get the perpendicular
				var perpendicular_angle = path_follow.rotation + PI / 2
				var perpendicular_dir = Vector2(cos(perpendicular_angle), sin(perpendicular_angle))

				# Apply offset along the perpendicular direction
				icon.position = perpendicular_dir * offset_distance

## Calculate lateral offset distance for pilot in overlapping group
## Returns a signed distance value applied perpendicular to the track
func _calculate_lateral_offset(index: int, total: int) -> float:
	# Center the group around 0
	# For 2 pilots: -5, +5 (pixels perpendicular to track)
	# For 3 pilots: -10, 0, +10
	# For 4 pilots: -15, -5, +5, +15
	var half_width = (total - 1) * LATERAL_OFFSET_DISTANCE / 2.0
	return (index * LATERAL_OFFSET_DISTANCE) - half_width
