class_name Badge
extends Resource

## Badge System Resource
## Represents a badge that can be equipped by pilots, fins, etc. to provide bonuses
## Badges can have trigger conditions and modify rolls in various ways

# ===== IDENTITY =====
@export var badge_id: String = ""  # Unique identifier (e.g., "intimidator", "start_expert")
@export var badge_name: String = ""  # Display name (e.g., "Intimidator")
@export var description: String = ""  # Flavor text explaining what the badge does

# ===== PERMANENCE (for future use) =====
enum Permanence {
	PERMANENT,        # Never lost
	SEASONAL,         # Lasts entire season
	WEAR_AND_TEAR,    # Can be lost during races, cleared by pit stops
	RACE_TEMPORARY    # Earned during race, cleared at race end
}
@export var permanence: Permanence = Permanence.PERMANENT

# ===== TRIGGER CONDITIONS =====
# When should this badge activate?
@export_group("Trigger Conditions")

# Race phase conditions
@export var trigger_on_race_start: bool = false  # Only active on initial race start roll
@export var trigger_on_race_end: bool = false    # Final lap/sector (future use)

# Status-based conditions
@export var trigger_on_attacking: bool = false    # When pilot is attacking (within 3 gaps of pilot ahead)
@export var trigger_on_defending: bool = false    # When pilot is defending (someone within 3 gaps behind)
@export var trigger_on_clear_air: bool = false    # When pilot has no one within 3 gaps
@export var trigger_on_wheel_to_wheel: bool = false  # When pilot is W2W with another
@export var trigger_on_dueling: bool = false      # When W2W for multiple consecutive rounds
@export var trigger_on_in_train: bool = false     # When both attacking and defending

# Position-based conditions (future use)
@export var trigger_on_leading: bool = false      # When in 1st place
@export var trigger_on_last_place: bool = false   # When in last place
@export var trigger_on_top_3: bool = false        # When in top 3 positions

# Sector type conditions (future use)
@export var trigger_on_twitch_sectors: bool = false
@export var trigger_on_craft_sectors: bool = false
@export var trigger_on_sync_sectors: bool = false
@export var trigger_on_edge_sectors: bool = false

# State-based conditions
@export var requires_consecutive_rounds: int = 0  # 0 = no requirement, N = must be in condition for N rounds
@export var state_property: String = ""  # Which state to track (e.g., "consecutive_attacking_rounds")

# ===== EFFECT =====
# What does this badge do when active?
@export_group("Effect")
@export var modifier_type: Dice.ModType = Dice.ModType.FLAT_BONUS
@export var modifier_value: int = 1  # Meaning depends on modifier_type

# ===== APPLICABILITY =====
# Which types of rolls does this badge affect?
@export_group("Applies To")
@export var affects_movement_rolls: bool = true   # Normal sector movement rolls
@export var affects_overtaking_rolls: bool = true # Overtake attempt rolls
@export var affects_defending_rolls: bool = true  # Defense rolls when being overtaken
@export var affects_w2w_rolls: bool = true        # Wheel-to-wheel contest rolls
@export var affects_start_rolls: bool = true      # Race start rolls

# Future: specific stat rolls, specific sector types, etc.

# ===== METHODS =====

## Check if this badge should be active given the current context
func should_activate(pilot_state, context: Dictionary) -> bool:
	# Check race phase conditions
	if trigger_on_race_start:
		if not context.get("is_race_start", false):
			return false

	# Check status-based conditions
	if trigger_on_attacking and not pilot_state.is_attacking:
		return false
	if trigger_on_defending and not pilot_state.is_defending:
		return false
	if trigger_on_clear_air and not pilot_state.is_clear_air:
		return false
	if trigger_on_wheel_to_wheel and not pilot_state.is_wheel_to_wheel:
		return false
	if trigger_on_dueling and not pilot_state.is_dueling:
		return false
	if trigger_on_in_train and not pilot_state.is_in_train:
		return false

	# Check sector type conditions
	var sector = context.get("sector", null)
	if sector:
		var has_sector_trigger = trigger_on_twitch_sectors or trigger_on_craft_sectors or trigger_on_sync_sectors or trigger_on_edge_sectors
		if has_sector_trigger:
			var sector_matches = false
			match sector.check_type:
				Sector.CheckType.TWITCH:
					sector_matches = trigger_on_twitch_sectors
				Sector.CheckType.CRAFT:
					sector_matches = trigger_on_craft_sectors
				Sector.CheckType.SYNC:
					sector_matches = trigger_on_sync_sectors
				Sector.CheckType.EDGE:
					sector_matches = trigger_on_edge_sectors
			if not sector_matches:
				return false

	# Check consecutive rounds requirement
	if requires_consecutive_rounds > 0 and state_property != "":
		var badge_state = pilot_state.badge_states.get(badge_id, {})
		var current_count = badge_state.get(state_property, 0)
		if current_count < requires_consecutive_rounds:
			return false

	# Check roll type applicability
	var roll_type = context.get("roll_type", "movement")
	match roll_type:
		"movement":
			if not affects_movement_rolls:
				return false
		"overtaking":
			if not affects_overtaking_rolls:
				return false
		"defending":
			if not affects_defending_rolls:
				return false
		"wheel_to_wheel":
			if not affects_w2w_rolls:
				return false
		"race_start":
			if not affects_start_rolls:
				return false

	# All conditions met!
	return true

## Create a RollModifier for this badge's effect
func create_modifier() -> Dice.RollModifier:
	var mod = Dice.RollModifier.new(modifier_type, modifier_value, badge_name)
	mod.description = description
	return mod

## Update this badge's state tracking (if applicable)
func update_state(pilot_state) -> void:
	if state_property == "":
		return

	# Ensure badge state dictionary exists
	if not pilot_state.badge_states.has(badge_id):
		pilot_state.badge_states[badge_id] = {}

	var badge_state = pilot_state.badge_states[badge_id]

	# Update consecutive round tracking
	if state_property == "consecutive_attacking_rounds":
		if pilot_state.is_attacking:
			badge_state[state_property] = badge_state.get(state_property, 0) + 1
		else:
			badge_state[state_property] = 0
	elif state_property == "consecutive_defending_rounds":
		if pilot_state.is_defending:
			badge_state[state_property] = badge_state.get(state_property, 0) + 1
		else:
			badge_state[state_property] = 0
	elif state_property == "consecutive_clear_air_rounds":
		if pilot_state.is_clear_air:
			badge_state[state_property] = badge_state.get(state_property, 0) + 1
		else:
			badge_state[state_property] = 0
	# Add more state tracking types as needed
