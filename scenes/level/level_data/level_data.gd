class_name LevelData
extends Resource

#everything about a level that is not the map, the map stays in the level .tscn

@export var starting_gold : float = 6.0
@export var starting_life : float = 10.0
@export var waves : Array[WaveData] = []
