class_name LevelBackdrop
extends Node2D

## Fills the space around the level with the map's dark border colour, so a level that is lower
## (or narrower) than the view shows a frame instead of the grey clear colour.

#under the ground tile layers, which are at -1
const BACKDROP_Z_INDEX : int = -2
const BACKDROP_RECT : Rect2 = Rect2(-4096, -4096, 8192, 8192)

@export var color : Color = Color8(31, 20, 25)


func _ready() -> void:
	z_index = BACKDROP_Z_INDEX


func _draw() -> void:
	draw_rect(BACKDROP_RECT, color)
