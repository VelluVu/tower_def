class_name Level
extends Node2D


const NO_BUILDING_IN_CELL_POSITION_MESSAGE : String = " There is no building in cell position!"
const PATH_TO_UNIT_SELECTION_SCENE : String = "res://scenes/unit/unit_selection/unit_selection.tscn"
const WALKABLE_CUSTOM_DATA_NAME : String = "Walkable"
const BUILDABLE_CUSTOM_DATA_NAME : String = "Buildable"
const TILE_TYPE_CUSTOM_DATA_NAME : String = "TileType"

@onready var tiles : Tiles = $Tiles
@onready var end_point : Marker2D = $EndPoint
@onready var player_stats : PlayerStats = $PlayerStats

var total_spawns : int = 0
var cell_size : Vector2i = Vector2i.ZERO
var offset : Vector2 = Vector2.ZERO
var astar_grid : AStarGrid2D = null
var unit_selection : UnitSelection
var all_buildings : Array[Building]
var all_enemies : Array[Enemy]
var existing_enemies : Array[Enemy]

var tile_test_flags : int = 0


func find_path(from : Vector2, to : Vector2) -> PackedVector2Array:
	return astar_grid.get_point_path(world_position_to_grid(from), world_position_to_grid(to), true)


func find_path_cell(from : Vector2i, to : Vector2i) -> PackedVector2Array:
	return astar_grid.get_point_path(grid_position_to_world(from), grid_position_to_world(to), true)


func block_position(_pos : Vector2) -> void:
	var grid_pos : Vector2i = world_position_to_grid(_pos)
	astar_grid.set_point_solid(grid_pos, true)
	GameSignals.astar_grid_updated.emit()


func is_position_blocked(_pos : Vector2) -> bool:
	var to_map_coords : Vector2i = world_position_to_grid(_pos)
	if not astar_grid.is_in_bounds(to_map_coords.x, to_map_coords.y):
		return true
	return astar_grid.is_point_solid(to_map_coords)


func is_position_in_bounds(_pos : Vector2) -> bool:
	return astar_grid.is_in_boundsv(world_position_to_grid(_pos))


func is_position_buildable(_pos : Vector2) -> bool:
	var tile_data : TileData = null
	var cell : Vector2i = world_position_to_grid(_pos)
	var buildable_ground : bool = false
	tile_test_flags = 0
	
	for tile_map_layer in tiles.tile_map_layers:
		tile_data = tile_map_layer.get_cell_tile_data(cell)
		
		if tile_data == null:
			continue
		
		var tile_type_data = tile_data.get_custom_data(TILE_TYPE_CUSTOM_DATA_NAME)
		
		if tile_type_data:
			tile_test_flags |= tile_type_data
	
	if has_flag(tile_test_flags, Utils.TileType.OnlyBuildable):
		buildable_ground = true
		return buildable_ground
	
	buildable_ground = has_flag(tile_test_flags, Utils.TileType.Normal)
	var non_buildable_tile_types : int = Utils.TileType.Blocking | Utils.TileType.OnlyWalkable
	
	if has_flag(tile_test_flags, non_buildable_tile_types):
		buildable_ground = false
	
	return buildable_ground


func has_flag(a : int, b : int) -> bool:
	return a & b != 0


func is_cell_walkable(cell : Vector2i) -> bool:
	#get data from tiles class, and iterate through all layers
	var tile_data : TileData = null
	var is_walkable : bool = true
	tile_test_flags = 0
	
	for tile_map_layer in tiles.tile_map_layers:
		tile_data = tile_map_layer.get_cell_tile_data(cell)
		
		if tile_data == null:
			continue
		
		var tile_type_data = tile_data.get_custom_data(TILE_TYPE_CUSTOM_DATA_NAME)
		
		if tile_type_data:
			tile_test_flags |= tile_type_data
		
	if has_flag(tile_test_flags, Utils.TileType.OnlyWalkable):
		is_walkable = true
		return is_walkable
	
	is_walkable = has_flag(tile_test_flags, Utils.TileType.Normal)
	
	var non_walkable_tile_types : int = Utils.TileType.Blocking | Utils.TileType.OnlyBuildable
	
	if has_flag(tile_test_flags, non_walkable_tile_types):
		is_walkable = false
	
	return is_walkable


func handle_walkable_cells() -> void:
	for cell in tiles.ground_layer.get_used_cells():
		var is_walkable : bool = is_cell_walkable(cell)
			
		if not is_walkable:
			astar_grid.set_point_solid(cell, true)

	GameSignals.astar_grid_updated.emit()


func get_neighbour_buildings_from_world_position(_position : Vector2) -> Array[Building]:
	var neighbour_building_grid_positions : Array[Building]
	var grid_position = world_position_to_grid(_position)
	
	var building : Building = get_building_from_cell_position(grid_position - Vector2i(1,0))
	
	if building != null:
		neighbour_building_grid_positions.append(building)
	
	building = get_building_from_cell_position(grid_position + Vector2i(1,0))
	
	if building != null:
		neighbour_building_grid_positions.append(building)
	
	building = get_building_from_cell_position(grid_position + Vector2i(0,1))
	
	if building != null:
		neighbour_building_grid_positions.append(building)
	
	building = get_building_from_cell_position(grid_position - Vector2i(0,1))
	
	if building != null:
		neighbour_building_grid_positions.append(building)
	
	return neighbour_building_grid_positions


func has_building_in_cell_position(_grid_pos : Vector2i) -> bool:
	for building in all_buildings:
		if world_position_to_grid(building.global_position) == _grid_pos:
			return true
	return false


func has_building_in_world_position(pos : Vector2) -> bool:
	for building in all_buildings:
		if building.global_position == pos:
			return true
	return false


func get_building_from_cell_position(_grid_pos : Vector2i) -> Building:
	for building in all_buildings:
		if world_position_to_grid(building.global_position) == _grid_pos:
			return building
	print(name, NO_BUILDING_IN_CELL_POSITION_MESSAGE)
	return null


func get_building_from_world_position(_pos : Vector2) -> Building:
	for building in all_buildings:
		if _pos == building.global_position:
			return building
	return null


func free_position(_pos : Vector2) -> void:
	#is position truly walkable after freeing, or only buildable? know this before using this function.
	astar_grid.set_point_solid(tiles.ground_layer.local_to_map(_pos), false)
	GameSignals.astar_grid_updated.emit()


func grid_position_to_world(_grid_pos : Vector2i) -> Vector2:
	return tiles.ground_layer.map_to_local(_grid_pos)


func world_position_to_grid(_pos : Vector2) -> Vector2i:
	return tiles.ground_layer.local_to_map(_pos)


func snap_position_to_grid(_pos : Vector2) -> Vector2:
	return grid_position_to_world(world_position_to_grid(_pos))


func get_cell_data_from_position(_pos : Vector2) -> TileData:
	return tiles.ground_layer.get_cell_tile_data(world_position_to_grid(_pos))


func _ready() -> void:
	_create_astar_grid()
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.building_destroyed.connect(_on_building_erase)
	GameSignals.sell_building.connect(_on_building_erase)
	GameSignals.enemy_spawned.connect(_on_enemy_spawned)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	GameSignals.enemy_reached_end_point.connect(_on_enemy_reached_end)
	_get_unit_selection()
	GameSignals.level_loaded.emit(self)


func _exit_tree() -> void:
	GameSignals.game_stop.emit()


#func _draw() -> void:
	#var top_left_corner : Vector2 = Vector2(astar_grid.region.position.x, astar_grid.region.position.y) * Vector2(cell_size)
	#var top_right_corner : Vector2 = Vector2(astar_grid.region.end.x, astar_grid.region.position.y) * Vector2(cell_size)
	#var bottom_right_corner : Vector2 = Vector2(astar_grid.region.end.x, astar_grid.region.end.y) * Vector2(cell_size)
	#var bottom_left_corner : Vector2 = Vector2(astar_grid.region.position.x, astar_grid.region.end.y) * Vector2(cell_size)
	#draw_line(top_left_corner, top_right_corner, Color.CHOCOLATE)
	#draw_line(top_right_corner, bottom_right_corner, Color.CHOCOLATE)
	#draw_line(bottom_right_corner, bottom_left_corner, Color.CHOCOLATE)
	#draw_line(bottom_left_corner, top_left_corner, Color.CHOCOLATE)


func _on_enemy_spawned(enemy : Enemy) -> void:
	all_enemies.append(enemy)
	existing_enemies.append(enemy)


func _on_enemy_destroyed(enemy : Enemy) -> void:
	existing_enemies.erase(enemy)
	_check_level_end_conditions()


func _on_enemy_reached_end(enemy : Enemy) -> void:
	existing_enemies.erase(enemy)
	_check_level_end_conditions()


func _on_building_placed(building : Building) -> void:
	all_buildings.append(building)
	GameSignals.astar_grid_updated.emit()


func _on_building_erase(building : Building) -> void:
	all_buildings.erase(building)
	GameSignals.astar_grid_updated.emit()


func _check_level_end_conditions() -> void:
	if existing_enemies.is_empty() and total_spawns >= all_enemies.size() and player_stats.is_alive:
		GameSignals.level_completed.emit(self)


func _create_astar_grid() -> void:
	astar_grid = AStarGrid2D.new()
	var tileMapRect : Rect2i = tiles.ground_layer.get_used_rect()
	var grid_region : Rect2i = tileMapRect
	cell_size = tiles.ground_layer.tile_set.tile_size
	offset = Vector2(cell_size.x * -0.5 + cell_size.x, cell_size.y * 0.5)
	astar_grid.region = grid_region
	astar_grid.cell_size = cell_size
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.offset = offset
	astar_grid.update()
	handle_walkable_cells()


func _get_unit_selection() -> void:
	if unit_selection == null:
		if has_node("UnitSelection"):
			unit_selection = get_node("UnitSelection")
		else:
			unit_selection = ResourceLoader.load(PATH_TO_UNIT_SELECTION_SCENE).instantiate()
