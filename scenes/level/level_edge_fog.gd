class_name LevelEdgeFog
extends Node2D

## Dithered fog over everything outside the playfield (edge_fog.gdshader), so spawns, waterfalls and rock that
## reach past the map's edge fade into the dark border instead of being cut off.

#above the tiles, spawns and units, under the UI layers
const FOG_Z_INDEX : int = 20
const FOG_RECT : Rect2 = Rect2(-4096, -4096, 8192, 8192)
const FOG_SHADER : Shader = preload("res://assets/shaders/edge_fog.gdshader")
const FOG_COLOR_PARAMETER : StringName = &"fog_color"
const PLAYFIELD_PARAMETER : StringName = &"playfield"

@export var color : Color = Color8(31, 20, 25)

#world pixels
var playfield : Rect2 = Rect2()


func _ready() -> void:
	z_index = FOG_Z_INDEX
	var fog_material : ShaderMaterial = ShaderMaterial.new()
	fog_material.shader = FOG_SHADER
	fog_material.set_shader_parameter(FOG_COLOR_PARAMETER, color)
	fog_material.set_shader_parameter(PLAYFIELD_PARAMETER, Vector4(playfield.position.x, playfield.position.y, playfield.size.x, playfield.size.y))
	material = fog_material


func _draw() -> void:
	draw_rect(FOG_RECT, Color.WHITE)
