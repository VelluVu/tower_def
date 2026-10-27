class_name WallLinePreview
extends Node2D

## Ghost walls of a line the player is dragging, built only when the button is released.
## A ghost with an enemy on it is drawn red: that wall is skipped if the enemy is still there.

const GHOST_COLOR : Color = Color(0.7, 1.0, 0.7, 0.6)
const BLOCKED_COLOR : Color = Color(1.0, 0.35, 0.3, 0.6)

var ghost_positions : PackedVector2Array = []
var ghost_textures : Array[Texture2D] = []
var ghost_blocked : Array[bool] = []


func _ready() -> void:
	z_index = 1


func set_ghosts(positions : PackedVector2Array, textures : Array[Texture2D], blocked : Array[bool]) -> void:
	ghost_positions = positions
	ghost_textures = textures
	ghost_blocked = blocked
	queue_redraw()


func clear() -> void:
	set_ghosts(PackedVector2Array(), [], [])


func _draw() -> void:
	for i in ghost_positions.size():
		var texture : Texture2D = ghost_textures[i]
		if texture == null:
			continue

		var color : Color = BLOCKED_COLOR if ghost_blocked[i] else GHOST_COLOR
		draw_texture(texture, to_local(ghost_positions[i]) - texture.get_size() * 0.5, color)
