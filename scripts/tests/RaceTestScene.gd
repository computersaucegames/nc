extends Control

# Reference UI components from scene tree
@onready var race_controls: RaceControls = $MarginContainer/VBoxContainer/RaceControls
@onready var pilot_status_panel: PilotStatusPanel = $MarginContainer/VBoxContainer/ContentSplit/PilotStatusPanel
@onready var circuit_display: CircuitDisplay = $MarginContainer/VBoxContainer/ContentSplit/RightSplit/CircuitDisplay
@onready var race_log: RaceEventLog = $MarginContainer/VBoxContainer/ContentSplit/RightSplit/RaceEventLog

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
	race_sim.sector_completed.connect(_on_sector_completed)
	race_sim.lap_completed.connect(_on_lap_completed)
	race_sim.pilot_finished.connect(_on_pilot_finished)
	race_sim.wheel_to_wheel_detected.connect(_on_wheel_to_wheel)
	race_sim.focus_mode_triggered.connect(_on_focus_mode)
	race_sim.race_finished.connect(_on_race_finished)

func create_test_circuit():
	# Load the Pizza Circuit resource
	test_circuit = load("res://resources/circuits/pizza_circuit.tres")

func setup_test_pilots():
	var test_pilots = [
		{"name": "Nova", "twitch": 7, "craft": 5, "sync": 6, "edge": 8},
		{"name": "Blaze", "twitch": 6, "craft": 7, "sync": 5, "edge": 6},
		{"name": "Frost", "twitch": 8, "craft": 6, "sync": 7, "edge": 5},
		{"name": "Shadow", "twitch": 5, "craft": 8, "sync": 6, "edge": 7}
	]

	# CHANGED: Use PilotStatusPanel to setup pilots
	pilot_status_panel.setup_pilots(test_pilots)
	pilot_status_panel.set_circuit(test_circuit)

	# CHANGED: Setup circuit display with circuit and pilots
	circuit_display.setup_circuit(test_circuit)
	circuit_display.setup_pilots(test_pilots)

func _on_start_pressed():
	# CHANGED: Use race_log method instead of direct output_log calls
	race_log.log_race_start(test_circuit.circuit_name, test_circuit.total_laps)
	
	var pilots = [
		{"name": "Nova", "twitch": 7, "craft": 5, "sync": 6, "edge": 8},
		{"name": "Blaze", "twitch": 6, "craft": 7, "sync": 5, "edge": 6},
		{"name": "Frost", "twitch": 8, "craft": 6, "sync": 7, "edge": 5},
		{"name": "Shadow", "twitch": 5, "craft": 8, "sync": 6, "edge": 7}
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
	race_log.log_pilot_rolling(pilot.name, sector.sector_name)

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

func _on_sector_completed(pilot, sector):
	race_log.log_sector_completed(pilot.name, sector.sector_name)

func _on_lap_completed(pilot, lap_num: int):
	race_log.log_lap_completed(pilot.name, lap_num)

func _on_pilot_finished(pilot, finish_position: int):
	race_log.log_pilot_finished(pilot.name, finish_position)

func _on_wheel_to_wheel(pilot1, pilot2):
	race_log.log_wheel_to_wheel(pilot1.name, pilot2.name)

func _on_focus_mode(pilots: Array, reason: String):
	race_log.log_focus_mode(reason)

func _on_race_finished(final_positions: Array):
	race_log.log_race_finished(final_positions)
	race_controls.set_pause_enabled(false)
