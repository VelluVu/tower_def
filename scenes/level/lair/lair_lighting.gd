class_name LairLighting
extends Node

## A boss lair's darkness (2026-11-24): placed in the level scene, it gives every tile layer (ground, walls, castle,
## set pieces) and every node in LIT_GROUP (the castle's camouflage) one lair_lit.gdshader material, so they sink into
## the dark while the units, towers and bars stay bright. Light comes from LairLight nodes anywhere in the level and
## from glowing tiles (tile_lights: crystals, glowcaps, egg sacs). Only looks.

const LIT_SHADER : Shader = preload("res://assets/shaders/lair_lit.gdshader")
## Canvas items in this group take the lair's light too.
const LIT_GROUP : StringName = &"lair_lit"
const MAX_LIGHTS : int = 64
const TILES_NODE : String = "Tiles"
const SPAWN_ART_NODE : String = "Art"
const AMBIENT_PARAMETER : StringName = &"ambient"
const LIGHTS_PARAMETER : StringName = &"lights"
const COLORS_PARAMETER : StringName = &"light_colors"
const COUNT_PARAMETER : StringName = &"light_count"
const TOO_MANY_LIGHTS_WARNING : String = "LairLighting: more than %d lights, the rest stay dark"
const FOG_COLOR_PARAMETER : StringName = &"fog_color"
const FOG_DEPTH_PARAMETER : StringName = &"fog_depth"
const FOG_GREY_DIM_PARAMETER : StringName = &"grey_dim"

@export var ambient : Color = Color(0.56, 0.54, 0.6)
@export var tile_lights : Array[LairTileLight] = []
@export_group("Edge fog")
## The lair's own fog past the map's edge (Hydra's Mire: a teal mist the drowned trees show through); off keeps the
## level's usual fog.
@export var overrides_fog : bool = false
@export var fog_color : Color = Color8(31, 20, 25)
## How far past the edge the fog thickens to full, in world pixels.
@export var fog_depth : float = 64.0
## How dark what lies past the edge turns before the fog (0 keeps its colours).
@export_range(0.0, 1.0) var fog_grey_dim : float = 0.45

var level : Level = null
var lit_material : ShaderMaterial = null
#the glowing tiles' lights, found once: position, radius, strength; and their colours
var tile_light_values : PackedVector4Array = PackedVector4Array()
var tile_light_colors : PackedVector4Array = PackedVector4Array()
var light_values : PackedVector4Array = PackedVector4Array()
var light_colors : PackedVector4Array = PackedVector4Array()
var is_over_warned : bool = false


func _ready() -> void:
	level = get_parent() as Level
	lit_material = ShaderMaterial.new()
	lit_material.shader = LIT_SHADER
	lit_material.set_shader_parameter(AMBIENT_PARAMETER, ambient)
	if level == null:
		return
	var tiles : Node = level.get_node_or_null(TILES_NODE)
	if tiles != null:
		for child in tiles.get_children():
			var layer : TileMapLayer = child as TileMapLayer
			if layer != null:
				layer.use_parent_material = false
				layer.material = lit_material
	#the spawn caves' art sits in the rock, so it takes the rock's light
	for spawner in level.get_spawners():
		var art : CanvasItem = spawner.get_node_or_null(SPAWN_ART_NODE) as CanvasItem
		if art != null:
			art.material = lit_material
	for node in get_tree().get_nodes_in_group(LIT_GROUP):
		var item : CanvasItem = node as CanvasItem
		if item != null and level.is_ancestor_of(item):
			item.material = lit_material
	_find_tile_lights(tiles)
	if overrides_fog:
		#the level adds its fog after its children are ready
		_apply_fog.call_deferred()


func _apply_fog() -> void:
	var fog : LevelEdgeFog = level.get_node_or_null(Level.EDGE_FOG_NAME) as LevelEdgeFog
	if fog == null:
		return
	var fog_material : ShaderMaterial = fog.material as ShaderMaterial
	if fog_material == null:
		return
	fog_material.set_shader_parameter(FOG_COLOR_PARAMETER, fog_color)
	fog_material.set_shader_parameter(FOG_DEPTH_PARAMETER, fog_depth)
	fog_material.set_shader_parameter(FOG_GREY_DIM_PARAMETER, fog_grey_dim)


func _find_tile_lights(tiles : Node) -> void:
	tile_light_values.clear()
	tile_light_colors.clear()
	if tiles == null:
		return
	for tile_light in tile_lights:
		var layer : TileMapLayer = tiles.get_node_or_null(NodePath(tile_light.layer)) as TileMapLayer
		if layer == null:
			continue
		for cell in layer.get_used_cells_by_id(tile_light.source_id, tile_light.atlas_coords):
			var at : Vector2 = layer.to_global(layer.map_to_local(cell)) - Vector2.ONE * Utils.TILE_SIZE * 0.5 + tile_light.offset
			tile_light_values.append(Vector4(at.x, at.y, tile_light.radius_tiles * Utils.TILE_SIZE, tile_light.strength))
			tile_light_colors.append(Vector4(tile_light.color.r, tile_light.color.g, tile_light.color.b, 0.0))


func _process(_delta : float) -> void:
	if lit_material == null:
		return
	light_values = tile_light_values.duplicate()
	light_colors = tile_light_colors.duplicate()
	for node in get_tree().get_nodes_in_group(LairLight.GROUP):
		var light : LairLight = node as LairLight
		if light == null or not light.is_visible_in_tree():
			continue
		light_values.append(Vector4(light.global_position.x, light.global_position.y, light.radius_tiles * Utils.TILE_SIZE, light.current_strength))
		light_colors.append(Vector4(light.color.r, light.color.g, light.color.b, 0.0))
	var count : int = mini(light_values.size(), MAX_LIGHTS)
	if light_values.size() > MAX_LIGHTS and not is_over_warned:
		is_over_warned = true
		push_warning(TOO_MANY_LIGHTS_WARNING % MAX_LIGHTS)
	#the shader's arrays are fixed at MAX_LIGHTS
	light_values.resize(MAX_LIGHTS)
	light_colors.resize(MAX_LIGHTS)
	lit_material.set_shader_parameter(LIGHTS_PARAMETER, light_values)
	lit_material.set_shader_parameter(COLORS_PARAMETER, light_colors)
	lit_material.set_shader_parameter(COUNT_PARAMETER, count)
