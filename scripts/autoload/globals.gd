extends Node
# Persistent game data

var current_season: int = 1
var current_race: int = 1
var player_team: Resource  # Will be Team resource later
var all_circuits: Array[Circuit] = []
var all_fins: Array[Resource] = []

# Global W2W failure table - used when pilots roll RED during wheel-to-wheel
# Sectors can override with their own w2w_failure_table_override
var w2w_failure_table: Array[Dictionary] = [
	{
		"text": "Lose control in close quarters",
		"penalty_gaps": 2,
		"triggers_contact": true,
		"badge_id": "rattled"
	},
	{
		"text": "Clip wings while battling",
		"penalty_gaps": 2,
		"triggers_contact": true,
		"badge_id": "shaky_brakes"
	},
	{
		"text": "Lock brakes under pressure",
		"penalty_gaps": 1,
		"triggers_contact": true,
		"badge_id": "shaky_brakes"
	},
	{
		"text": "Wobble in traffic",
		"penalty_gaps": 1,
		"triggers_contact": false,
		"badge_id": "lost_focus"
	},
	{
		"text": "Defensive mistake",
		"penalty_gaps": 2,
		"triggers_contact": true,
		"badge_id": "sloppy_technique"
	},
	{
		"text": "Overcorrect while defending",
		"penalty_gaps": 1,
		"triggers_contact": false,
		"badge_id": "rattled"
	},
	{
		"text": "Miss apex in wheel-to-wheel",
		"penalty_gaps": 1,
		"triggers_contact": true,
		"badge_id": "lost_focus"
	},
	{
		"text": "Squeeze too hard",
		"penalty_gaps": 2,
		"triggers_contact": true,
		"badge_id": "sloppy_technique"
	}
]
