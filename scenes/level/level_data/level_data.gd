class_name LevelData
extends Resource

#everything about a level that is not the map, the map stays in the level .tscn

## Shown on the world map; empty shows "Level N".
@export var level_name : String = ""
@export var starting_gold : float = 6.0
@export var starting_life : float = 10.0
@export var waves : Array[WaveData] = []
