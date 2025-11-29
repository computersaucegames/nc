extends Node
# Persistent game data

var current_season: int = 1
var current_race: int = 1
var player_team: Resource  # Will be Team resource later
var all_circuits: Array[Circuit] = []
var all_fins: Array[Resource] = []
