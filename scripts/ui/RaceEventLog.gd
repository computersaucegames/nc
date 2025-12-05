# RaceEventLog.gd
# Reusable race event logging component
extends VBoxContainer
class_name RaceEventLog

@onready var output_log: RichTextLabel
var export_button: Button

func _ready():
	setup_ui()

func setup_ui():
	# Header with title and export button
	var header = HBoxContainer.new()
	add_child(header)

	# Title
	var log_title = Label.new()
	log_title.text = "RACE LOG"
	log_title.add_theme_font_size_override("font_size", 18)
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(log_title)

	# Export button
	export_button = Button.new()
	export_button.text = "Copy Log"
	export_button.pressed.connect(_on_export_pressed)
	header.add_child(export_button)

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
	output_log.append_text("[b]Grid forms up... LIGHTS OUT AND AWAY WE GO![/b]\n")

func log_start_rolls(start_results: Array):
	output_log.append_text("\n[b][color=cyan]🚦 RACE START - LAUNCH ROLLS![/color][/b]\n")

	for result in start_results:
		var pilot = result["pilot"]
		var roll = result["roll"]
		var color = get_tier_color_name(roll.tier)
		var effect = get_start_roll_effect(roll.tier)

		output_log.append_text("  [b]%s[/b]: Twitch roll %d = [color=%s]%s[/color]%s\n" % [
			pilot.name, roll.final_total, color, roll.tier_name, effect
		])

	output_log.append_text("\n")

func log_round_started(round_num: int):
	output_log.append_text("\n[b]Round %d[/b]\n" % round_num)

func log_pilot_rolling(pilot_name: String, sector_name: String, total_gap: int = -1, max_gap: int = -1, status: String = "", sector_progress: String = "", gap_ahead: String = ""):
	var info_parts = []

	# Build info string with provided details
	if total_gap >= 0 and max_gap > 0:
		info_parts.append("Gap %d/%d" % [total_gap, max_gap])
	if status != "":
		info_parts.append(status)
	if sector_progress != "":
		info_parts.append(sector_progress)
	if gap_ahead != "":
		info_parts.append(gap_ahead)

	var info_string = ""
	if info_parts.size() > 0:
		info_string = " [" + ", ".join(info_parts) + "]"

	output_log.append_text("  [b]%s[/b]%s approaching %s...\n" % [pilot_name, info_string, sector_name])

func log_pilot_rolled(pilot_name: String, result: Dice.DiceResult):
	var color = get_tier_color_name(result.tier)
	output_log.append_text("    Roll: %d = [color=%s]%s[/color]\n" % [
		result.final_total, color, result.tier_name
	])

func log_badge_activated(pilot_name: String, badge_name: String, effect_description: String):
	output_log.append_text("    [color=magenta]⭐ [b]%s[/b] BADGE: %s - %s[/color]\n" % [
		pilot_name, badge_name, effect_description
	])

func log_overtake_detected(overtaking_name: String, overtaken_name: String):
	output_log.append_text("[b][color=yellow]⚡ OVERTAKE ATTEMPT! [b]%s[/b] trying to pass [b]%s[/b]![/color][/b]\n" % [
		overtaking_name, overtaken_name
	])

func log_overtake_attempt(attacker_name: String, defender_name: String, attacker_roll: Dice.DiceResult, defender_roll: Dice.DiceResult):
	output_log.append_text("  → [b]%s[/b] rolls %d (Attack)\n" % [attacker_name, attacker_roll.final_total])
	output_log.append_text("  ← [b]%s[/b] rolls %d (Defend)\n" % [defender_name, defender_roll.final_total])

func log_overtake_completed(overtaking_name: String, overtaken_name: String):
	output_log.append_text("[color=green]  ✓ OVERTAKE SUCCESS! [b]%s[/b] passes [b]%s[/b]![/color]\n" % [
		overtaking_name, overtaken_name
	])

func log_overtake_blocked(attacker_name: String, defender_name: String):
	output_log.append_text("[color=red]  ✗ OVERTAKE BLOCKED! [b]%s[/b] defends position from [b]%s[/b]![/color]\n" % [
		defender_name, attacker_name
	])

func log_capacity_blocked(pilot_name: String, blocking_pilots: Array, intended_movement: int, actual_movement: int):
	var blocker_names = []
	for blocker in blocking_pilots:
		blocker_names.append(blocker.name)
	var blockers_text = " & ".join(blocker_names)

	output_log.append_text("[color=orange]  🚧 BLOCKED BY BATTLE! [b]%s[/b] can't pass the wheel-to-wheel battle between %s! (Movement: %d → %d)[/color]\n" % [
		pilot_name, blockers_text, intended_movement, actual_movement
	])

func log_movement_details(pilot_name: String, start_gap: int, start_distance: int, movement: int, end_gap: int, end_distance: int, sector_completed: bool = false, momentum: int = 0):
	var details = "  📍 [b]%s[/b]: Gap %d→%d (Distance %d→%d, moved %d)" % [
		pilot_name, start_gap, end_gap, start_distance, end_distance, movement
	]
	if sector_completed:
		details += " [Sector complete"
		if momentum > 0:
			details += ", +%d momentum" % momentum
		details += "]"
	output_log.append_text(details + "\n\n")

func log_sector_completed(pilot_name: String, sector_name: String, momentum: int = 0):
	var momentum_text = ""
	if momentum > 0:
		momentum_text = " (+%d momentum)" % momentum
	output_log.append_text("  ✓ [b]%s[/b] completes %s%s\n\n" % [pilot_name, sector_name, momentum_text])

func log_lap_completed(pilot_name: String, lap_num: int):
	output_log.append_text("[b][color=cyan]🏁 [b]%s[/b] completes Lap %d![/color][/b]\n\n" % [
		pilot_name, lap_num - 1
	])

func log_pilot_finished(pilot_name: String, finish_position: int):
	var position_text = ["🥇", "🥈", "🥉", "🏁"]
	var medal = position_text[min(finish_position - 1, 3)]
	output_log.append_text("[b][color=gold]%s [b]%s[/b] FINISHES in position %d! Taking victory lap![/color][/b]\n\n" % [
		medal, pilot_name, finish_position
	])

func log_wheel_to_wheel(pilot1_name: String, pilot2_name: String):
	output_log.append_text("[b][color=orange]⚠️ WHEEL-TO-WHEEL! [b]%s[/b] vs [b]%s[/b]![/color][/b]\n" % [
		pilot1_name, pilot2_name
	])

func log_duel_started(pilot1_name: String, pilot2_name: String, round_number: int):
	output_log.append_text("[b][color=red]⚔️ DUEL! [b]%s[/b] vs [b]%s[/b] - Round %d of their battle![/color][/b]\n" % [
		pilot1_name, pilot2_name, round_number
	])

func log_focus_mode(reason: String):
	output_log.append_text("[b][color=red]🎯 FOCUS MODE: %s[/color][/b]\n" % reason)

func log_failure_table(pilot_name: String, sector_name: String, consequence: String):
	output_log.append_text("[b][color=red]💥 FAILURE TABLE! [b]%s[/b] at %s: %s[/color][/b]\n\n" % [
		pilot_name, sector_name, consequence
	])

func log_overflow_penalty_deferred(pilot_name: String, penalty_gaps: int):
	output_log.append_text("[b][color=orange]⚠️ PENALTY OVERFLOW! [b]%s[/b] will lose %d Gap on next turn[/color][/b]\n\n" % [
		pilot_name, penalty_gaps
	])

func log_overflow_penalty_applied(pilot_name: String, penalty_gaps: int):
	output_log.append_text("[b][color=orange]⚠️ PENALTY APPLIED! [b]%s[/b] loses %d Gap from previous failure[/color][/b]\n\n" % [
		pilot_name, penalty_gaps
	])

func log_race_finished(final_positions: Array):
	output_log.append_text("\n[b][color=gold]🏆 RACE FINISHED![/color][/b]\n")
	output_log.append_text("Final Results:\n")
	for i in range(final_positions.size()):
		var pilot = final_positions[i]
		output_log.append_text("  %d. [b]%s[/b] - Finished Round %d\n" % [
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

# === Export methods ===

func _on_export_pressed():
	var plain_text = get_plain_text()
	DisplayServer.clipboard_set(plain_text)
	export_button.text = "Copied!"
	await get_tree().create_timer(1.5).timeout
	export_button.text = "Copy Log"

func get_plain_text() -> String:
	# Get text and strip BBCode tags
	var text = output_log.get_parsed_text()
	return text

func export_to_file(filepath: String) -> bool:
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: " + filepath)
		return false

	file.store_string(get_plain_text())
	file.close()
	return true
