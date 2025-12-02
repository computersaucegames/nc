extends Control

# Reference UI components from scene tree
@onready var race_controls: RaceControls = $MarginContainer/VBoxContainer/RaceControls
@onready var pilot_status_panel: PilotStatusPanel = $MarginContainer/VBoxContainer/ContentSplit/PilotStatusPanel
@onready var circuit_display: CircuitDisplay = $MarginContainer/VBoxContainer/ContentSplit/RightSplit/CircuitDisplay
@onready var race_log: RaceEventLog = $MarginContainer/VBoxContainer/ContentSplit/RightSplit/RaceEventLog
@onready var focus_mode_overlay: FocusModeOverlay = $FocusModeOverlay

# Race simulator (created programmatically)
var race_sim: RaceSimulator

# Test circuit
var test_circuit: Circuit

func _ready():
	setup_ui_connections()
	setup_race_simulator()
	create_test_circuit()
	setup_test_pilots()

func setup_ui_connections():
	# Connect signals from UI components
	race_controls.start_pressed.connect(_on_start_pressed)
	race_controls.pause_pressed.connect(_on_pause_pressed)
	race_controls.speed_changed.connect(_on_speed_changed)

func setup_race_simulator():
	race_sim = RaceSimulator.new()
	add_child(race_sim)
	
	# Connect all the signals
	race_sim.race_started.connect(_on_race_started)
	race_sim.race_start_rolls.connect(_on_race_start_rolls)
	race_sim.round_started.connect(_on_round_started)
	race_sim.pilot_rolling.connect(_on_pilot_rolling)
	race_sim.pilot_rolled.connect(_on_pilot_rolled)
	race_sim.pilot_moved.connect(_on_pilot_moved)
	race_sim.overtake_detected.connect(_on_overtake_detected)
	race_sim.overtake_attempt.connect(_on_overtake_attempt)
	race_sim.overtake_completed.connect(_on_overtake_completed)
	race_sim.overtake_blocked.connect(_on_overtake_blocked)
	race_sim.capacity_blocked.connect(_on_capacity_blocked)
	race_sim.sector_completed.connect(_on_sector_completed)
	race_sim.lap_completed.connect(_on_lap_completed)
	race_sim.pilot_finished.connect(_on_pilot_finished)
	race_sim.wheel_to_wheel_detected.connect(_on_wheel_to_wheel)
	race_sim.duel_started.connect(_on_duel_started)
	race_sim.focus_mode_triggered.connect(_on_focus_mode)
	race_sim.race_finished.connect(_on_race_finished)

func create_test_circuit():
	# Load the Pizza Circuit resource
	test_circuit = load("res://resources/circuits/pizza_circuit.tres")

func setup_test_pilots():
	var test_pilots = [
		{"name": "Buoy", "twitch": 7, "craft": 5, "sync": 6, "edge": 8, "headshot": "res://resources/art/buoy.png"},
		{"name": "Cowboy", "twitch": 6, "craft": 7, "sync": 5, "edge": 6, "headshot": "res://resources/art/cowboy.png"},
		{"name": "Redman", "twitch": 8, "craft": 6, "sync": 7, "edge": 5, "headshot": "res://resources/art/redman.png"},
		{"name": "Stubble", "twitch": 5, "craft": 8, "sync": 6, "edge": 7, "headshot": "res://resources/art/stubble.png"},
		{"name": "Poshpaul", "twitch": 6, "craft": 6, "sync": 8, "edge": 6, "headshot": "res://resources/art/poshpaul.png"}
	]

	# CHANGED: Use PilotStatusPanel to setup pilots
	pilot_status_panel.setup_pilots(test_pilots)
	pilot_status_panel.set_circuit(test_circuit)

	# CHANGED: Setup circuit display with circuit and pilots
	circuit_display.setup_circuit(test_circuit)
	circuit_display.setup_pilots(test_pilots)

	# Setup Focus Mode overlay with circuit display reference
	focus_mode_overlay.set_circuit_display(circuit_display)

func _on_start_pressed():
	# CHANGED: Use race_log method instead of direct output_log calls
	race_log.log_race_start(test_circuit.circuit_name, test_circuit.total_laps)

	var pilots = [
		{"name": "Buoy", "twitch": 7, "craft": 5, "sync": 6, "edge": 8, "headshot": "res://resources/art/buoy.png"},
		{"name": "Cowboy", "twitch": 6, "craft": 7, "sync": 5, "edge": 6, "headshot": "res://resources/art/cowboy.png"},
		{"name": "Redman", "twitch": 8, "craft": 6, "sync": 7, "edge": 5, "headshot": "res://resources/art/redman.png"},
		{"name": "Stubble", "twitch": 5, "craft": 8, "sync": 6, "edge": 7, "headshot": "res://resources/art/stubble.png"},
		{"name": "Poshpaul", "twitch": 6, "craft": 6, "sync": 8, "edge": 6, "headshot": "res://resources/art/poshpaul.png"}
	]
	
	# CHANGED: Use race_controls to enable pause button
	race_controls.set_pause_enabled(true)
	race_sim.start_race(test_circuit, pilots)

func _on_pause_pressed():
	if race_sim.race_mode == RaceSimulator.RaceMode.PAUSED:
		race_sim.resume_race()
		race_controls.set_pause_text(false)
	else:
		race_sim.pause_race()
		race_controls.set_pause_text(true)

func _on_speed_changed(value: float):
	race_sim.auto_advance_delay = value

func update_pilot_displays():
	# CHANGED: Update both status panel and circuit display
	pilot_status_panel.update_all_pilots(race_sim.pilots)
	circuit_display.update_all_pilots(race_sim.pilots)

# Signal handlers - ALL CHANGED to use race_log methods
func _on_race_started(circuit: Circuit, pilots: Array):
	update_pilot_displays()

func _on_race_start_rolls(start_results: Array):
	race_log.log_start_rolls(start_results)
	update_pilot_displays()

func _on_round_started(round_num: int):
	race_log.log_round_started(round_num)
	update_pilot_displays()

func _on_pilot_rolling(pilot, sector):
	# Calculate total gaps in circuit
	var total_gaps = 0
	for s in test_circuit.sectors:
		total_gaps += s.length_in_gap

	# Get status string
	var status = ""
	if pilot.is_dueling:
		status = "DUEL"
	elif pilot.is_wheel_to_wheel:
		status = "W2W"
	elif pilot.is_clear_air:
		status = "Clear Air"
	elif pilot.is_in_train:
		status = "In Train"
	elif pilot.is_attacking and pilot.is_defending:
		status = "Attacking & Defending"
	elif pilot.is_attacking:
		status = "Attacking"
	elif pilot.is_defending:
		status = "Defending"

	# Sector progress
	var sector_progress = "Sector %d: %d/%d" % [pilot.current_sector + 1, pilot.gap_in_sector, sector.length_in_gap]

	# Gap to position ahead
	var gap_ahead = ""
	var pilot_ahead = null
	var smallest_gap = 999999
	for other in race_sim.pilots:
		if other == pilot or other.finished:
			continue
		var gap_diff = other.total_distance - pilot.total_distance
		if gap_diff > 0 and gap_diff < smallest_gap:
			smallest_gap = gap_diff
			pilot_ahead = other

	if pilot_ahead != null:
		if smallest_gap == 0:
			gap_ahead = "W2W with %s" % pilot_ahead.name
		else:
			gap_ahead = "+%d gap" % smallest_gap
	else:
		gap_ahead = "Leading"

	# Calculate gap within current lap (resets each lap)
	var current_lap_gap = pilot.total_distance % total_gaps if total_gaps > 0 else 0

	race_log.log_pilot_rolling(pilot.name, sector.sector_name, current_lap_gap, total_gaps, status, sector_progress, gap_ahead)

func _on_pilot_rolled(pilot, result: Dice.DiceResult):
	race_log.log_pilot_rolled(pilot.name, result)

func _on_pilot_moved(pilot, movement: int):
	update_pilot_displays()

func _on_overtake_detected(overtaking, overtaken):
	race_log.log_overtake_detected(overtaking.name, overtaken.name)

func _on_overtake_attempt(attacker, defender, attacker_roll: Dice.DiceResult, defender_roll: Dice.DiceResult):
	race_log.log_overtake_attempt(attacker.name, defender.name, attacker_roll, defender_roll)

func _on_overtake_completed(overtaking, overtaken):
	race_log.log_overtake_completed(overtaking.name, overtaken.name)

func _on_overtake_blocked(attacker, defender):
	race_log.log_overtake_blocked(attacker.name, defender.name)

func _on_capacity_blocked(pilot, blocking_pilots: Array, intended_movement: int, actual_movement: int):
	race_log.log_capacity_blocked(pilot.name, blocking_pilots, intended_movement, actual_movement)

func _on_sector_completed(pilot, sector, momentum: int):
	race_log.log_sector_completed(pilot.name, sector.sector_name, momentum)

func _on_lap_completed(pilot, lap_num: int):
	race_log.log_lap_completed(pilot.name, lap_num)

func _on_pilot_finished(pilot, finish_position: int):
	race_log.log_pilot_finished(pilot.name, finish_position)

func _on_wheel_to_wheel(pilot1, pilot2):
	race_log.log_wheel_to_wheel(pilot1.name, pilot2.name)

func _on_duel_started(pilot1, pilot2, round_number: int):
	race_log.log_duel_started(pilot1.name, pilot2.name, round_number)

func _on_focus_mode(pilots: Array, reason: String):
	race_log.log_focus_mode(reason)

func _on_race_finished(final_positions: Array):
	race_log.log_race_finished(final_positions)
	race_controls.set_pause_enabled(false)
