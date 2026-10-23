class_name LevelGrid
extends RefCounted

## The level's cell grid: world/cell conversion, walkable and buildable tiles from the
## TileType custom data, AStarGrid2D paths, and which building stands in which cell.


const TILE_TYPE_CUSTOM_DATA_NAME : String = "TileType"

var tiles : Tiles = null
var astar_grid : AStarGrid2D = null
#the level's own list, shared by reference: Level adds and removes buildings
var buildings : Array[Building] = []


func _init(level_tiles : Tiles, level_buildings : Array[Building]) -> void:
	tiles = level_tiles
	buildings = level_buildings
	_create_astar_grid()


func find_path(from : Vector2, to : Vector2) -> PackedVector2Array:
	return astar_grid.get_point_path(world_position_to_grid(from), world_position_to_grid(to), true)


func set_cell_weight(cell : Vector2i, weight : float) -> void:
	astar_grid.set_point_weight_scale(cell, weight)


func is_position_in_bounds(_pos : Vector2) -> bool:
	return astar_grid.is_in_boundsv(world_position_to_grid(_pos))


func is_position_buildable(_pos : Vector2) -> bool:
	var flags : int = _get_cell_flags(world_position_to_grid(_pos))

	if has_flag(flags, Utils.TileType.OnlyBuildable):
		return true

	return has_flag(flags, Utils.TileType.Normal) and not has_flag(flags, Utils.TileType.Blocking | Utils.TileType.OnlyWalkable)


func is_position_walkable(_position : Vector2) -> bool:
	return is_cell_walkable(world_position_to_grid(_position))


func is_cell_walkable(cell : Vector2i) -> bool:
	var flags : int = _get_cell_flags(cell)

	if has_flag(flags, Utils.TileType.OnlyWalkable):
		return true

	return has_flag(flags, Utils.TileType.Normal) and not has_flag(flags, Utils.TileType.Blocking | Utils.TileType.OnlyBuildable)


func has_flag(a : int, b : int) -> bool:
	return a & b != 0


func get_surrounding_cells(cell : Vector2i) -> Array[Vector2i]:
	return tiles.ground_layer.get_surrounding_cells(cell)


## Walkable neighbour cells without a building in them (traps don't count).
func get_walkable_surrounding_cells(cell : Vector2i) -> Array[Vector2i]:
	return get_surrounding_cells(cell).filter(_is_cell_free_to_walk)


func get_neighbour_buildings_from_world_position(_position : Vector2) -> Array[Building]:
	var neighbour_buildings : Array[Building] = []

	for cell in get_surrounding_cells(world_position_to_grid(_position)):
		var building : Building = get_building_from_cell_position(cell)
		if building != null:
			neighbour_buildings.append(building)

	return neighbour_buildings


func has_building_in_cell_position(_grid_pos : Vector2i) -> bool:
	return get_building_from_cell_position(_grid_pos) != null


func get_building_from_cell_position(_grid_pos : Vector2i) -> Building:
	for building in buildings:
		if world_position_to_grid(building.global_position) == _grid_pos:
			return building
	return null


#exact match: callers pass a cell centre (snap_position_to_grid) to find the building there
func get_building_from_world_position(_pos : Vector2) -> Building:
	for building in buildings:
		if _pos == building.global_position:
			return building
	return null


func grid_position_to_world(_grid_pos : Vector2i) -> Vector2:
	return tiles.ground_layer.map_to_local(_grid_pos)


func world_position_to_grid(_pos : Vector2) -> Vector2i:
	return tiles.ground_layer.local_to_map(_pos)


func snap_position_to_grid(_pos : Vector2) -> Vector2:
	return grid_position_to_world(world_position_to_grid(_pos))


#the TileType flags of every tile map layer on this cell, combined
func _get_cell_flags(cell : Vector2i) -> int:
	var flags : int = 0

	for tile_map_layer in tiles.tile_map_layers:
		var tile_data : TileData = tile_map_layer.get_cell_tile_data(cell)

		if tile_data == null:
			continue

		var tile_type_data = tile_data.get_custom_data(TILE_TYPE_CUSTOM_DATA_NAME)

		if tile_type_data:
			flags |= tile_type_data

	return flags


func _is_cell_free_to_walk(cell : Vector2i) -> bool:
	if not is_cell_walkable(cell):
		return false
	var building : Building = get_building_from_cell_position(cell)
	return building == null or building is Trap


func _create_astar_grid() -> void:
	astar_grid = AStarGrid2D.new()
	var cell_size : Vector2i = tiles.ground_layer.tile_set.tile_size
	astar_grid.region = tiles.ground_layer.get_used_rect()
	astar_grid.cell_size = cell_size
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.offset = Vector2(cell_size.x * -0.5 + cell_size.x, cell_size.y * 0.5)
	astar_grid.update()

	for cell in tiles.ground_layer.get_used_cells():
		if not is_cell_walkable(cell):
			astar_grid.set_point_solid(cell, true)
