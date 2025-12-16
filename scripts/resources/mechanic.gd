# Mechanic.gd
extends Resource
class_name Mechanic

@export var mechanic_name: String = "Crew Chief"
@export var mechanic_id: String = "default_crew"
@export var portrait: String = ""  # Path to portrait image

# Mechanic-specific stats
@export var BUILD: int = 7    # Repair/construction work (pit box service)
@export var RIG: int = 6      # Equipment setup/handling (pit box operations)
@export var COOL: int = 5     # Staying calm under pressure (pit exit merge)

# Optional flavor text
@export_multiline var bio: String = ""
