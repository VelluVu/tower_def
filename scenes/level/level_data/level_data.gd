class_name LevelData
extends Resource

#everything about a level that is not the map, the map stays in the level .tscn

## Shown on the world map; empty shows "Level N".
@export var level_name : String = ""
## Shown on the world map above the waves and starting resources.
@export_multiline var story_text : String = ""
@export var starting_gold : float = 6.0
@export var starting_life : float = 10.0
@export var waves : Array[WaveData] = []
## Puffe's lines in this level, in order (the first level's lines are the tutorial).
@export var puffe_lines : Array[PuffeLine] = []
