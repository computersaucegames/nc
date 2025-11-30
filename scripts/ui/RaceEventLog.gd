# RaceEventLog.gd
# Reusable race event logging component
extends VBoxContainer
class_name RaceEventLog

@onready var output_log: RichTextLabel

func _ready():
	setup_ui()

func setup_ui():
	# Title
	var log_title = Label.new()
	log_title.text = "RACE LOG"
	log_title.add_theme_font_size_override("font_size", 18)
	add_child(log_title)
	
	# Rich text log
	output_log = RichTextLabel.new()
	output_log.bbcode_enabled = true
	output_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_log.custom_minimum_size = Vector2(500, 400)
	output_log.scroll_following = true
	add_child(output_log)

# === Core logging methods ===

func clear():
	output_log.clear()

func append_text(text: String):
	output_log.append_text(text)

# === Specialized logging methods ===

func log_race_start(circuit_name: String, total_laps: int):
	output_log.clear()
	output_log.append_text("[b][color=green]RACE STARTING![/color][/b]\n")
	output_log.append_text("Circuit: %s - %d Laps\n\n" % [circuit_name, total_laps])

func log_start_rolls(start_results: Array):
	output_log.append_text("\n[b][color=cyan]🚦 RACE START - LAUNCH ROLLS![/color][/b]\n")
	
	for result in start_results:
		var pilot = result["pilot"]
		var roll = result["roll"]
		var color = get_tier_color_name(roll.tier)
		var effect = get_start_roll_effect(roll.tier)
		
		output_log.append_text("  %s: Twitch roll %d = [color=%s]%s[/color]%s\n" % [
			pilot.name, roll.final_total, color, roll.tier_name, effect
		])
	
	output_log.append_text("[b]Grid forms up... LIGHTS OUT AND AWAY WE GO![/b]\n")

func log_round_started(round_num: int):
	output_log.append_text("\n[b]Round %d[/b]\n" % round_num)

func log_pilot_rolling(pilot_name: String, sector_name: String):
	output_log.append_text("  %s approaching %s...\n" % [pilot_name, sector_name])

func log_pilot_rolled(pilot_name: String, result: Dice.DiceResult):
	var color = get_tier_color_name(result.tier)
	output_log.append_text("    Roll: %d = [color=%s]%s[/color]\n" % [
		result.final_total, color, result.tier_name
	])

func log_overtake_detected(overtaking_name: String, overtaken_name: String):
	output_log.append_text("[b][color=yellow]⚡ OVERTAKE ATTEMPT! %s trying to pass %s![/color][/b]\n" % [
		overtaking_name, overtaken_name
	])

func log_overtake_attempt(attacker_name: String, defender_name: String, attacker_roll: Dice.DiceResult, defender_roll: Dice.DiceResult):
	output_log.append_text("  → %s rolls %d (Attack)\n" % [attacker_name, attacker_roll.final_total])
	output_log.append_text("  ← %s rolls %d (Defend)\n" % [defender_name, defender_roll.final_total])

func log_overtake_completed(overtaking_name: String, overtaken_name: String):
	output_log.append_text("[color=green]  ✓ OVERTAKE SUCCESS! %s passes %s![/color]\n" % [
		overtaking_name, overtaken_name
	])

func log_overtake_blocked(attacker_name: String, defender_name: String):
	output_log.append_text("[color=red]  ✗ OVERTAKE BLOCKED! %s defends position from %s![/color]\n" % [
		defender_name, attacker_name
	])

func log_capacity_blocked(pilot_name: String, blocking_pilots: Array, intended_movement: int, actual_movement: int):
	var blocker_names = []
	for blocker in blocking_pilots:
		blocker_names.append(blocker.name)
	var blockers_text = " & ".join(blocker_names)

	output_log.append_text("[color=orange]  🚧 BLOCKED BY BATTLE! %s can't pass the wheel-to-wheel battle between %s! (Movement: %d → %d)[/color]\n" % [
		pilot_name, blockers_text, intended_movement, actual_movement
	])

func log_sector_completed(pilot_name: String, sector_name: String):
	output_log.append_text("  ✓ %s completes %s\n" % [pilot_name, sector_name])

func log_lap_completed(pilot_name: String, lap_num: int):
	output_log.append_text("[b][color=cyan]🏁 %s completes Lap %d![/color][/b]\n" % [
		pilot_name, lap_num - 1
	])

func log_pilot_finished(pilot_name: String, finish_position: int):
	var position_text = ["🥇", "🥈", "🥉", "🏁"]
	var medal = position_text[min(finish_position - 1, 3)]
	output_log.append_text("[b][color=gold]%s %s FINISHES in position %d! Taking victory lap![/color][/b]\n" % [
		medal, pilot_name, finish_position
	])

func log_wheel_to_wheel(pilot1_name: String, pilot2_name: String):
	output_log.append_text("[b][color=orange]⚠️ WHEEL-TO-WHEEL! %s vs %s![/color][/b]\n" % [
		pilot1_name, pilot2_name
	])

func log_focus_mode(reason: String):
	output_log.append_text("[b][color=red]🎯 FOCUS MODE: %s[/color][/b]\n" % reason)

func log_race_finished(final_positions: Array):
	output_log.append_text("\n[b][color=gold]🏆 RACE FINISHED![/color][/b]\n")
	output_log.append_text("Final Results:\n")
	for i in range(final_positions.size()):
		var pilot = final_positions[i]
		output_log.append_text("  %d. %s - Finished Round %d\n" % [
			i + 1, pilot.name, pilot.finish_round
		])

# === Helper methods ===

func get_tier_color_name(tier: Dice.Tier) -> String:
	match tier:
		Dice.Tier.RED: return "red"
		Dice.Tier.GREY: return "gray"
		Dice.Tier.GREEN: return "green"
		Dice.Tier.PURPLE: return "purple"
	return "white"

func get_start_roll_effect(tier: Dice.Tier) -> String:
	match tier:
		Dice.Tier.PURPLE:
			return " - PERFECT LAUNCH! (+1 Gap)"
		Dice.Tier.GREEN:
			return " - Good start"
		Dice.Tier.GREY:
			return " - Average start"
		Dice.Tier.RED:
			return " - POOR START! (Disadvantage next roll)"
	return ""
