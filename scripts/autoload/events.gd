extends Node
# Central signal hub to prevent tight coupling

signal race_started(circuit: Circuit)
signal sector_completed(fin: Resource, sector: Sector, result: String)
signal race_finished(results: Array)
signal fin_rolled_check(fin: Resource, roll: int, result: String)
