class_name Level
extends Node2D

@onready var tile_map : TileMapLayer = $TileMapLayer
@onready var end_point : Marker2D = $EndPoint
var offset : Vector2
var cell_size : Vector2i
var astar_grid : AStarGrid2D
var all_buildings : Array[Building]


func _ready() -> void:
	create_astar_grid()
	GameStateSignals.level_loaded.emit(self)


func _exit_tree() -> void:
	GameStateSignals.game_stop.emit()


func create_astar_grid() -> void:
	astar_grid = AStarGrid2D.new()
	var tileMapRect : Rect2i = tile_map.get_used_rect()
	var grid_region : Rect2i = tileMapRect
	cell_size = tile_map.tile_set.tile_size
	offset = Vector2(cell_size.x * -0.5 + cell_size.x, cell_size.y * 0.5)
	astar_grid.region = grid_region
	astar_grid.cell_size = cell_size
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.offset = offset
	astar_grid.update()


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
	print("There is no building in cell position!")
	return null


func free_position(_pos : Vector2):
	astar_grid.set_point_solid(tile_map.local_to_map(_pos), false)
	GameSignals.astar_grid_updated.emit()


func grid_position_to_world(_grid_pos : Vector2i):
	return tile_map.map_to_local(_grid_pos)


func world_position_to_grid(_pos : Vector2):
	return tile_map.local_to_map(_pos)


func snap_position_to_grid(_pos : Vector2):
	return grid_position_to_world(world_position_to_grid(_pos))


func get_cell_data_from_tile_pos(_pos : Vector2) -> TileData:
	return tile_map.get_cell_tile_data(world_position_to_grid(_pos))


func _draw() -> void:
	var top_left_corner : Vector2 = Vector2(astar_grid.region.position.x, astar_grid.region.position.y) * Vector2(cell_size)
	var top_right_corner : Vector2 = Vector2(astar_grid.region.end.x, astar_grid.region.position.y) * Vector2(cell_size)
	var bottom_right_corner : Vector2 = Vector2(astar_grid.region.end.x, astar_grid.region.end.y) * Vector2(cell_size)
	var bottom_left_corner : Vector2 = Vector2(astar_grid.region.position.x, astar_grid.region.end.y) * Vector2(cell_size)
	draw_line(top_left_corner, top_right_corner, Color.CHOCOLATE)
	draw_line(top_right_corner, bottom_right_corner, Color.CHOCOLATE)
	draw_line(bottom_right_corner, bottom_left_corner, Color.CHOCOLATE)
	draw_line(bottom_left_corner, top_left_corner, Color.CHOCOLATE)
