class_name Level
extends Node2D

@onready var tile_map : TileMapLayer = $TileMapLayer
@onready var end_point : Marker2D = $EndPoint
var offset : Vector2
var cell_size : Vector2i
var astar_grid : AStarGrid2D


func _ready() -> void:
	create_astar_grid()
	GameStateSignals.level_loaded.emit(self)


func _exit_tree() -> void:
	GameStateSignals.game_stop.emit()

#align grid position with tilemap
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
	return astar_grid.get_point_path(tile_map.local_to_map(from), tile_map.local_to_map(to), true)


func block_position(_pos : Vector2):
	var to_map_pos : Vector2i = tile_map.local_to_map(_pos)
	astar_grid.set_point_solid(tile_map.local_to_map(_pos), true)
	GameSignals.astar_grid_updated.emit()


func is_position_blocked(_pos : Vector2):
	var to_map_coords : Vector2i = tile_map.local_to_map(_pos)
	if not astar_grid.is_in_bounds(to_map_coords.x, to_map_coords.y):
		return true
	return astar_grid.is_point_solid(to_map_coords)


func free_position(_pos : Vector2):
	astar_grid.set_point_solid(tile_map.local_to_map(_pos), false)
	GameSignals.astar_grid_updated.emit()


func snap_position_to_grid(_pos : Vector2):
	return tile_map.map_to_local(tile_map.local_to_map(_pos))


func get_cell_data_from_tile_pos(_pos : Vector2) -> TileData:
	return tile_map.get_cell_tile_data(tile_map.local_to_map(_pos))


func _draw() -> void:
	var top_left_corner : Vector2 = Vector2(astar_grid.region.position.x, astar_grid.region.position.y) * Vector2(cell_size)
	var top_right_corner : Vector2 = Vector2(astar_grid.region.end.x, astar_grid.region.position.y) * Vector2(cell_size)
	var bottom_right_corner : Vector2 = Vector2(astar_grid.region.end.x, astar_grid.region.end.y) * Vector2(cell_size)
	var bottom_left_corner : Vector2 = Vector2(astar_grid.region.position.x, astar_grid.region.end.y) * Vector2(cell_size)
	draw_line(top_left_corner, top_right_corner, Color.CHOCOLATE)
	draw_line(top_right_corner, bottom_right_corner, Color.CHOCOLATE)
	draw_line(bottom_right_corner, bottom_left_corner, Color.CHOCOLATE)
	draw_line(bottom_left_corner, top_left_corner, Color.CHOCOLATE)
