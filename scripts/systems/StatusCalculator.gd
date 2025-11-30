# StatusCalculator.gd
extends RefCounted
class_name StatusCalculator

# Status calculation for racing pilots
# This class is responsible ONLY for determining pilot statuses based on positions

const ATTACK_RANGE = 3  # Gap range for attacking
const DEFEND_RANGE = 3  # Gap range for defending

# Calculate all statuses for a group of pilots
static func calculate_all_statuses(pilots: Array) -> void:
	# First, clear all statuses
	_clear_all_statuses(pilots)

	# Calculate basic statuses for each pilot
	for i in range(pilots.size()):
		var pilot = pilots[i]
		if pilot.finished:
			continue

		_calculate_pilot_status(pilot, pilots)

	# Check for trains
	_detect_trains(pilots)

	# Check for duels (multi-round W2W)
	_detect_duels(pilots)

# Clear all status flags for pilots
static func _clear_all_statuses(pilots: Array) -> void:
	for pilot in pilots:
		pilot.is_clear_air = true
		pilot.is_attacking = false
		pilot.is_defending = false
		pilot.is_wheel_to_wheel = false
		pilot.is_in_train = false
		pilot.attacking_targets.clear()
		pilot.defending_from.clear()
		pilot.wheel_to_wheel_with.clear()

# Calculate status for a single pilot relative to others
static func _calculate_pilot_status(pilot, all_pilots: Array) -> void:
	var has_close_fin = false
	
	for other in all_pilots:
		if other == pilot or other.finished:
			continue
		
		var gap_diff = calculate_gap_between(pilot, other)
		
		if gap_diff == 0:
			# Wheel-to-wheel
			pilot.is_wheel_to_wheel = true
			pilot.wheel_to_wheel_with.append(other)
			has_close_fin = true
			
		elif gap_diff > 0 and gap_diff <= ATTACK_RANGE:
			# Other is ahead - we're attacking
			pilot.is_attacking = true
			pilot.attacking_targets.append(other)
			has_close_fin = true
			
		elif gap_diff < 0 and gap_diff >= -DEFEND_RANGE:
			# Other is behind - we're defending
			pilot.is_defending = true
			pilot.defending_from.append(other)
			has_close_fin = true
	
	# Set clear air if no close fins
	pilot.is_clear_air = not has_close_fin

# Detect train formations
static func _detect_trains(pilots: Array) -> void:
	var pilots_in_trains = {}
	
	# Find all pilots that are both attacking AND defending
	for pilot in pilots:
		if pilot.is_attacking and pilot.is_defending:
			# This pilot is sandwiched - mark entire connected group
			var train_group = _get_connected_group(pilot)
			for member in train_group:
				pilots_in_trains[member] = true
	
	# Apply train status
	for pilot in pilots_in_trains.keys():
		pilot.is_in_train = true

# Get all pilots connected to this pilot through attack/defend relationships
static func _get_connected_group(pilot) -> Array:
	var group = []
	group.append(pilot)
	group.append_array(pilot.attacking_targets)
	group.append_array(pilot.defending_from)
	return group

# Detect duels (pilots who have been W2W for 2+ consecutive rounds)
static func _detect_duels(pilots: Array) -> void:
	for pilot in pilots:
		if pilot.finished:
			continue

		# Check if pilot is currently W2W
		if pilot.is_wheel_to_wheel and pilot.wheel_to_wheel_with.size() == 1:
			# Get the current W2W partner
			var current_partner = pilot.wheel_to_wheel_with[0]

			# Check if this is the same partner as last round
			if current_partner.name == pilot.last_w2w_partner_name:
				# Same partner - increment consecutive rounds
				pilot.consecutive_w2w_rounds += 1

				# If 2+ rounds, mark as dueling
				if pilot.consecutive_w2w_rounds >= 2:
					pilot.is_dueling = true
			else:
				# Different partner - reset and start counting
				pilot.consecutive_w2w_rounds = 1
				pilot.last_w2w_partner_name = current_partner.name
		else:
			# Not W2W or multiple W2W partners - reset duel tracking
			pilot.consecutive_w2w_rounds = 0
			pilot.last_w2w_partner_name = ""

# Calculate gap between two pilots
static func calculate_gap_between(pilot1, pilot2) -> int:
	# Returns positive if pilot2 is ahead, negative if behind, 0 if equal
	# First check if they're in the same sector
	if pilot1.current_sector == pilot2.current_sector:
		return pilot2.gap_in_sector - pilot1.gap_in_sector
	else:
		# Use total distance for pilots in different sectors
		return pilot2.total_distance - pilot1.total_distance

# Get wheel-to-wheel pairs from current statuses
static func get_wheel_to_wheel_pairs(pilots: Array) -> Array:
	var pairs = []
	var already_paired = {}
	
	for pilot in pilots:
		if pilot.is_wheel_to_wheel:
			for other in pilot.wheel_to_wheel_with:
				# Create a unique key for this pair
				var pair_key = [pilot.name, other.name]
				pair_key.sort()
				var key_string = pair_key[0] + "_" + pair_key[1]
				
				if not already_paired.has(key_string):
					pairs.append([pilot, other])
					already_paired[key_string] = true
	
	return pairs

# Utility function to get status summary
static func get_status_summary(pilots: Array) -> Dictionary:
	var summary = {
		"clear_air": [],
		"attacking": [],
		"defending": [],
		"wheel_to_wheel": [],
		"trains": []
	}
	
	for pilot in pilots:
		if pilot.finished:
			continue
			
		if pilot.is_clear_air:
			summary["clear_air"].append(pilot.name)
		if pilot.is_attacking:
			summary["attacking"].append(pilot.name)
		if pilot.is_defending:
			summary["defending"].append(pilot.name)
		if pilot.is_wheel_to_wheel:
			summary["wheel_to_wheel"].append(pilot.name)
		if pilot.is_in_train:
			summary["trains"].append(pilot.name)
	
	return summary
