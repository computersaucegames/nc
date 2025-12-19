extends FocusSequence
class_name PitStopSequence

## Multi-stage sequence for Pit Stop Focus Mode
##
## This sequence handles the full pit stop process:
## Stage 0: Pit Entry - Roll for entry positioning (pilot CRAFT stat)
## Stage 1: Pit Box - Roll for service work (mechanic RIG stat), clear badges
## Stage 2: Pit Exit - Roll for exit merge (mechanic COOL stat)
## Stage 3: Apply movement and rejoin track
##
## The pilot progresses through 3 pit lane sectors, each with its own check
## and potential penalties. Badges can be cleared during the pit box stage.

var race_sim: RaceSimulator
var pilot: PilotState
var circuit: Circuit
var pit_entry_sector: Sector
var pit_box_sector: Sector
var pit_exit_sector: Sector

func _init(event: FocusModeManager.FocusModeEvent, simulator: RaceSimulator):
	super._init(event)
	sequence_name = "PitStop"
	race_sim = simulator
	pilot = focus_event.pilots[0]
	circuit = focus_event.metadata.get("circuit")

	# Get pit lane sectors from circuit
	if circuit and circuit.has_pit_lane and circuit.pit_lane_sectors.size() == 3:
		pit_entry_sector = circuit.pit_lane_sectors[0]
		pit_box_sector = circuit.pit_lane_sectors[1]
		pit_exit_sector = circuit.pit_lane_sectors[2]
	else:
		push_error("PitStopSequence: Circuit does not have valid pit lane configuration")

func get_stage_count() -> int:
	return 4

func get_stage_name(stage: int) -> String:
	match stage:
		0: return "Pit Entry"
		1: return "Pit Box"
		2: return "Pit Exit"
		3: return "Rejoin Track"
		_: return "Unknown"

func execute_stage(stage: int) -> StageResult:
	var result = StageResult.new()

	match stage:
		0:  # Pit Entry
			_execute_pit_entry(result)

		1:  # Pit Box
			_execute_pit_box(result)

		2:  # Pit Exit
			_execute_pit_exit(result)

		3:  # Rejoin Track
			_execute_rejoin(result)

	return result

## Stage 0: Pit Entry
## Pilot rolls CRAFT to navigate pit lane entry
func _execute_pit_entry(result: StageResult):
	if not pit_entry_sector:
		result.error = "Pit entry sector not found"
		return

	# Mark pilot as entering pit lane
	var entry_sector_index = pilot.current_sector
	pilot.enter_pit_lane(entry_sector_index)

	# Emit signal
	race_sim.pit_entry_started.emit(pilot, pit_entry_sector)

	# Roll for pit entry (uses pilot CRAFT stat)
	race_sim.pilot_rolling.emit(pilot, pit_entry_sector)
	var roll = race_sim.make_pilot_roll(pilot, pit_entry_sector)
	race_sim.pilot_rolled.emit(pilot, roll)

	# Store roll result
	context["entry_roll"] = roll

	# Calculate time penalty from roll
	var time_penalty = _calculate_pit_penalty(roll, pit_entry_sector)
	context["entry_penalty"] = time_penalty

	# Apply penalty if any
	if time_penalty > 0:
		race_sim.pit_entry_penalty.emit(pilot, time_penalty)

	# Update focus event with roll result
	focus_event.roll_results = [roll]
	focus_event.metadata["entry_penalty"] = time_penalty
	FocusMode.focus_mode_activated.emit(focus_event)

	# Advance to pit box
	pilot.advance_pit_stage()
	result.continue_sequence = true
	result.requires_user_input = true

## Stage 1: Pit Box
## Mechanic rolls RIG for service work, clear badges from fin
func _execute_pit_box(result: StageResult):
	if not pit_box_sector:
		result.error = "Pit box sector not found"
		return

	# Emit signal
	race_sim.pit_box_started.emit(pilot, pit_box_sector)

	# Roll for pit box service (uses mechanic RIG stat)
	race_sim.pilot_rolling.emit(pilot, pit_box_sector)
	var roll = _make_mechanic_roll(pilot, pit_box_sector, "rig")
	race_sim.pilot_rolled.emit(pilot, roll)

	# Store roll result
	context["box_roll"] = roll

	# Calculate time penalty from roll
	var time_penalty = _calculate_pit_penalty(roll, pit_box_sector)
	context["box_penalty"] = time_penalty

	# Apply penalty if any
	if time_penalty > 0:
		race_sim.pit_box_penalty.emit(pilot, time_penalty)

	# Clear badges from BOTH pilot AND fin (this is the main purpose of pit stops!)
	var badges_cleared = _clear_pilot_and_fin_badges(pilot, roll)
	context["badges_cleared"] = badges_cleared

	if badges_cleared.size() > 0:
		race_sim.pit_badges_cleared.emit(pilot, badges_cleared)

	# Update focus event with roll result
	focus_event.roll_results = [roll]
	focus_event.metadata["box_penalty"] = time_penalty
	focus_event.metadata["badges_cleared"] = badges_cleared
	FocusMode.focus_mode_activated.emit(focus_event)

	# Advance to pit exit
	pilot.advance_pit_stage()
	result.continue_sequence = true
	result.requires_user_input = true

## Stage 2: Pit Exit
## Mechanic rolls COOL for exit merge under pressure
func _execute_pit_exit(result: StageResult):
	if not pit_exit_sector:
		result.error = "Pit exit sector not found"
		return

	# Emit signal
	race_sim.pit_exit_started.emit(pilot, pit_exit_sector)

	# Roll for pit exit (uses mechanic COOL stat)
	race_sim.pilot_rolling.emit(pilot, pit_exit_sector)
	var roll = _make_mechanic_roll(pilot, pit_exit_sector, "cool")
	race_sim.pilot_rolled.emit(pilot, roll)

	# Store roll result
	context["exit_roll"] = roll

	# Calculate time penalty from roll
	var time_penalty = _calculate_pit_penalty(roll, pit_exit_sector)
	context["exit_penalty"] = time_penalty

	# Apply penalty if any
	if time_penalty > 0:
		race_sim.pit_exit_penalty.emit(pilot, time_penalty)

	# Update focus event with roll result
	focus_event.roll_results = [roll]
	focus_event.metadata["exit_penalty"] = time_penalty
	FocusMode.focus_mode_activated.emit(focus_event)

	# Continue to rejoin
	result.continue_sequence = true
	result.requires_user_input = true

## Stage 3: Rejoin Track
## Calculate total time cost and update pilot position
func _execute_rejoin(result: StageResult):
	# Calculate total pit stop cost
	var total_penalty = 0
	total_penalty += pit_entry_sector.length_in_gap
	total_penalty += pit_box_sector.length_in_gap
	total_penalty += pit_exit_sector.length_in_gap
	total_penalty += context.get("entry_penalty", 0)
	total_penalty += context.get("box_penalty", 0)
	total_penalty += context.get("exit_penalty", 0)

	context["total_cost"] = total_penalty

	# Exit pit lane and rejoin track
	var rejoin_sector = circuit.pit_exit_rejoin_sector
	pilot.exit_pit_lane(rejoin_sector)

	# Update pilot's total distance (this affects position)
	pilot.total_distance += total_penalty

	# Emit completion signal
	race_sim.pit_stop_completed.emit(pilot, total_penalty, context.get("badges_cleared", []))

	# Update focus event
	focus_event.metadata["total_cost"] = total_penalty
	focus_event.metadata["rejoin_sector"] = rejoin_sector
	FocusMode.focus_mode_activated.emit(focus_event)

	# Mark pilot as processed for this round
	_mark_pilot_processed()

	# Exit focus mode
	result.exit_focus_mode = true
	result.requires_user_input = false

## Make a roll using mechanic stats instead of pilot stats
func _make_mechanic_roll(pilot_state: PilotState, sector: Sector, mechanic_stat: String) -> Dice.DiceResult:
	# Get mechanic stat value
	var stat_value = 5  # Default
	if pilot_state.mechanic_state:
		stat_value = pilot_state.mechanic_state.get_stat(mechanic_stat)

	# Get roll context
	var check_name = "%s - %s" % [sector.sector_name, mechanic_stat.to_upper()]
	var gates = sector.gates

	# Get modifiers (mechanic badges if any)
	var modifiers = []
	if pilot_state.mechanic_state:
		var badge_context = {
			"pilot": pilot_state,
			"sector": sector,
			"check_type": sector.check_type,
			"race_sim": race_sim
		}
		var badge_mods = BadgeSystem.get_active_modifiers_for_mechanic(pilot_state.mechanic_state, badge_context)
		modifiers.append_array(badge_mods)

	# Roll d20
	return Dice.roll_d20(stat_value, check_name, modifiers, gates)

## Calculate time penalty from pit sector roll
## Uses failure table to determine penalty (GREEN=no penalty, GREY=1 gap, RED=2 gaps)
func _calculate_pit_penalty(roll: Dice.DiceResult, sector: Sector) -> int:
	match roll.tier:
		Dice.Tier.PURPLE:
			return 0  # Perfect execution
		Dice.Tier.GREEN:
			return 0  # Clean execution
		Dice.Tier.GREY:
			return 1  # Minor mistake, lose 1 gap
		Dice.Tier.RED:
			return 2  # Major mistake, lose 2 gaps
		_:
			return 0

## Clear badges from BOTH pilot and fin based on pit stop quality
## GREEN/PURPLE: Clear normal badges (base badges)
## PURPLE: Can also clear severe badges
func _clear_pilot_and_fin_badges(pilot_state: PilotState, box_roll: Dice.DiceResult) -> Array:
	var cleared_badges = []

	# Determine what can be cleared based on roll quality
	var can_clear_severe = false
	if box_roll.tier == Dice.Tier.PURPLE:
		can_clear_severe = true  # Perfect service clears everything

	# Clear badges from PILOT
	var pilot_badges_to_remove = []
	for badge in pilot_state.temporary_badges:
		var is_severe = badge.badge_id.ends_with("_severe")

		# Can always clear normal badges, severe only on PURPLE
		if not is_severe or can_clear_severe:
			pilot_badges_to_remove.append(badge)
			cleared_badges.append(badge.badge_id)

	# Remove cleared badges from pilot
	for badge in pilot_badges_to_remove:
		pilot_state.temporary_badges.erase(badge)

	# Clear badges from FIN
	if pilot_state.fin_state:
		var fin_badges_to_remove = []
		for badge in pilot_state.fin_state.temporary_badges:
			var is_severe = badge.badge_id.ends_with("_severe")

			# Can always clear normal badges, severe only on PURPLE
			if not is_severe or can_clear_severe:
				fin_badges_to_remove.append(badge)
				cleared_badges.append(badge.badge_id)

		# Remove cleared badges from fin
		for badge in fin_badges_to_remove:
			pilot_state.fin_state.temporary_badges.erase(badge)

	return cleared_badges

## Mark pilot as processed for this round
func _mark_pilot_processed():
	if race_sim and race_sim.has_signal("pilot_turn_complete"):
		race_sim.pilot_turn_complete.emit(pilot)
