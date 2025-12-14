# Fin.gd
extends Resource
class_name Fin

# Define fin stat types as an enum for better type safety
enum StatType {
	THRUST,
	FORM,
	RESPONSE,
	SYNC
}

@export var fin_name: String = "Unnamed Fin"
@export var fin_model: String = "Unknown Model"
@export var fin_bio: String = "A racing craft with unknown specifications."

@export_group("Stats")
@export var THRUST: int = 1  # Power & acceleration
@export var FORM: int = 1     # Durability, stability, aero
@export var RESPONSE: int = 1 # Handling & reaction
@export var SYNC: int = 1     # Neural sync compatibility (future use)

@export_group("Badges")
@export var equipped_badges: Array[Badge] = []


# Helper function to get the stat type as a string (for display/logging)
func get_stat_type_string(stat: StatType) -> String:
	match stat:
		StatType.THRUST:
			return "thrust"
		StatType.FORM:
			return "form"
		StatType.RESPONSE:
			return "response"
		StatType.SYNC:
			return "sync"
		_:
			return "unknown"

# Helper to get a descriptive name for the stat type
func get_stat_type_display_name(stat: StatType) -> String:
	match stat:
		StatType.THRUST:
			return "Thrust"
		StatType.FORM:
			return "Form"
		StatType.RESPONSE:
			return "Response"
		StatType.SYNC:
			return "Sync"
		_:
			return "Unknown Stat"
