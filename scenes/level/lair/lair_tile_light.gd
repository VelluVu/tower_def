class_name LairTileLight
extends Resource

## A tile that glows in a boss lair (LairLighting): every cell of `layer` showing atlas tile `atlas_coords` of
## `source_id` gets a light, `offset` pixels from the cell's top-left (a 2x2 landmark's middle is 16, 16).

@export var layer : StringName = &"FrontTileMapLayer"
@export var source_id : int = 0
@export var atlas_coords : Vector2i = Vector2i.ZERO
@export var offset : Vector2 = Vector2(8.0, 8.0)
@export var color : Color = Color(0.17, 0.91, 0.96)
@export var radius_tiles : float = 2.0
@export_range(0.0, 2.0) var strength : float = 0.5
