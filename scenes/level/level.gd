class_name Level
extends Node2D


const NO_BUILDING_IN_CELL_POSITION_MESSAGE : String = " There is no building in cell position!"
const PATH_TO_UNIT_SELECTION_SCENE : String = "res://scenes/unit/unit_selection/unit_selection.tscn"
const WALKABLE_CUSTOM_DATA_NAME : String = "Walkable"
const BUILDABLE_CUSTOM_DATA_NAME : String = "Buildable"

@onready var tile_map_main_layer : TileMapLayer = $MainTileMapLayer
@onready var end_point : Marker2D = $EndPoint
@onready var player_stats : PlayerStats = $PlayerStats

var unit_selection : UnitSelection
var offset : Vector2 = Vector2.ZERO
var cell_size : Vector2i = Vector2i.ZERO
var astar_grid : AStarGrid2D = null
var all_buildings : Array[Building]


func find_path(from : Vector2, to : Vector2) -> PackedVector2Array:
	return astar_grid.get_point_path(world_position_to_grid(from), world_position_to_grid(to), true)


func block_position(_pos : Vector2):
	var grid_pos : Vector2i = world_position_to_grid(_pos)
	astar_grid.set_point_solid(grid_pos, true)
	GameSignals.astar_grid_updated.emit()


func is_position_blocked(_pos : Vector2):
	var to_map_coords : Vector2i = world_position_to_grid(_pos)
	if not astar_grid.is_in_bounds(to_map_coords.x, to_map_coords.y):
		return true
	return astar_grid.is_point_solid(to_map_coords)


func has_building_in_cell_position(_grid_pos : Vector2i):
	for building in all_buildings:
		if world_position_to_grid(building.global_position) == _grid_pos:
			return true
	return false


func get_building_from_cell_position(_grid_pos : Vector2i):
	for building in all_buildings:
		if world_position_to_grid(building.global_position) == _grid_pos:
			return building
	print(name, NO_BUILDING_IN_CELL_POSITION_MESSAGE)
	return null


func free_position(_pos : Vector2):
	astar_grid.set_point_solid(tile_map_main_layer.local_to_map(_pos), false)
	GameSignals.astar_grid_updated.emit()


func grid_position_to_world(_grid_pos : Vector2i):
	return tile_map_main_layer.map_to_local(_grid_pos)


func world_position_to_grid(_pos : Vector2):
	return tile_map_main_layer.local_to_map(_pos)


func snap_position_to_grid(_pos : Vector2):
	return grid_position_to_world(world_position_to_grid(_pos))


func get_cell_data_from_position(_pos : Vector2) -> TileData:
	return tile_map_main_layer.get_cell_tile_data(world_position_to_grid(_pos))


func _ready() -> void:
	_create_astar_grid()
	GameStateSignals.level_loaded.emit(self)
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.building_destroyed.connect(_on_building_destroyed)
	_get_unit_selection()


func _exit_tree() -> void:
	GameStateSignals.game_stop.emit()


func _draw() -> void:
	var top_left_corner : Vector2 = Vector2(astar_grid.region.position.x, astar_grid.region.position.y) * Vector2(cell_size)
	var top_right_corner : Vector2 = Vector2(astar_grid.region.end.x, astar_grid.region.position.y) * Vector2(cell_size)
	var bottom_right_corner : Vector2 = Vector2(astar_grid.region.end.x, astar_grid.region.end.y) * Vector2(cell_size)
	var bottom_left_corner : Vector2 = Vector2(astar_grid.region.position.x, astar_grid.region.end.y) * Vector2(cell_size)
	draw_line(top_left_corner, top_right_corner, Color.CHOCOLATE)
	draw_line(top_right_corner, bottom_right_corner, Color.CHOCOLATE)
	draw_line(bottom_right_corner, bottom_left_corner, Color.CHOCOLATE)
	draw_line(bottom_left_corner, top_left_corner, Color.CHOCOLATE)


func _on_building_placed(building : Building) -> void:
	all_buildings.append(building)


func _on_building_destroyed(building : Building) -> void:
	all_buildings.erase(building)


func _create_astar_grid() -> void:
	astar_grid = AStarGrid2D.new()
	var tileMapRect : Rect2i = tile_map_main_layer.get_used_rect()
	var grid_region : Rect2i = tileMapRect
	cell_size = tile_map_main_layer.tile_set.tile_size
	offset = Vector2(cell_size.x * -0.5 + cell_size.x, cell_size.y * 0.5)
	astar_grid.region = grid_region
	astar_grid.cell_size = cell_size
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.offset = offset
	astar_grid.update()
	handle_walkable_cells()


func handle_walkable_cells() -> void:
	for cell in tile_map_main_layer.get_used_cells():
		var tile_data : TileData = tile_map_main_layer.get_cell_tile_data(cell)
		var is_walkable : bool = tile_data.get_custom_data(WALKABLE_CUSTOM_DATA_NAME)
		if not is_walkable:
			astar_grid.set_point_solid(cell, true)
		else:
			astar_grid.set_point_solid(cell, false)
	GameSignals.astar_grid_updated.emit()


func _get_unit_selection() -> void:
	if unit_selection == null:
		if has_node("UnitSelection"):
			unit_selection = get_node("UnitSelection")
		else:
			unit_selection = ResourceLoader.load(PATH_TO_UNIT_SELECTION_SCENE).instantiate()
