# FocusModeConfig.gd
# Resource for configuring Focus Mode triggers and behavior
extends Resource
class_name FocusModeConfig

# Trigger toggles
@export var enable_wheel_to_wheel: bool = true
@export var enable_overtakes: bool = false
@export var enable_race_start: bool = true
@export var enable_final_lap: bool = false
@export var enable_photo_finish: bool = false
@export var enable_red_result: bool = true  # Trigger failure table on red rolls

# Position filtering (0 = all positions)
@export var only_top_n_positions: int = 0  # e.g., 3 = only trigger for positions 1-3

# Overtake thresholds (for future use)
@export var overtake_minimum_gap: int = 2  # Only trigger if gap difference >= this

# Auto-advance settings (for future use)
@export var auto_advance_delay: float = 0.0  # 0 = requires click, >0 = auto-advance after delay
