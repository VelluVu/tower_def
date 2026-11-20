class_name BuildingListElement
extends Resource


@export var scene : PackedScene = null
@export var id : int = 0
@export var icon : Texture2D = null
## The level that introduces it; from then on it is in the build tray of every level, replays included.
@export var unlock_level : int = 1
## The build tray's tooltip: what it does, in a line or two.
@export_multiline var description : String = ""


func is_unlocked(furthest_level : int) -> bool:
	return unlock_level <= furthest_level
