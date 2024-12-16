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

	
var cell_size : Vector2i = Vector2i.ZERO
var offset : Vector2 = Vector2.ZERO
var astar_grid : AStarGrid2D = null
var unit_selection : UnitSelection
var all_buildings : Array[Building]
var all_enemies : Array[Enemy]
var existing_enemies : Array[Enemy]

var tile_test_flags : int = 0

var total_spawns : int = 0 : 
	get = _get_total_spawns

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


func is_position_walkable(_position : Vector2) -> bool:
	return is_cell_walkable(world_position_to_grid(_position))


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


func get_walkable_surrounding_cells(cell : Vector2i) -> Array[Vector2i]:
	#just quick way to get cell coordinates around the cell
	var surrounding_cells : Array[Vector2i] = tiles.ground_layer.get_surrounding_cells(cell).filter(filter_walkable_cells)
	return surrounding_cells.filter(filter_out_buildings)
 

func filter_out_buildings(cell : Vector2i) -> bool:
	if has_building_in_cell_position(cell):
		if get_building_from_cell_position(cell) is Trap:
			return true
		return false
	return true


func filter_walkable_cells(cell : Vector2i) -> bool:
	return is_cell_walkable(cell)


func handle_walkable_cells() -> void:
	for cell in tiles.ground_layer.get_used_cells():
		var is_walkable : bool = is_cell_walkable(cell)
			
		if not is_walkable:
			astar_grid.set_point_solid(cell, true)

	GameSignals.astar_grid_updated.emit()


func get_neighbour_buildings_from_world_position(_position : Vector2) -> Array[Building]:
	var grid_position = world_position_to_grid(_position)
	var neighbour_buildings : Array[Building]
	var surrounding_cells : Array[Vector2i] = tiles.ground_layer.get_surrounding_cells(grid_position).filter(filter_cells_with_buildings)
	
	for building_cell in surrounding_cells:
		neighbour_buildings.append(get_building_from_cell_position(building_cell))
	
	return neighbour_buildings


func filter_cells_with_buildings(cell : Vector2i) -> bool:
	return has_building_in_cell_position(cell)


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
	if existing_enemies.is_empty() and player_stats.is_alive and all_enemies.size() >= total_spawns:
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


func _get_total_spawns() -> int:
	if total_spawns > 0:
		return total_spawns
	
	var spawners : Array[Node] = get_tree().get_nodes_in_group(GroupNames.SPAWNER)
	for spawner in spawners:
		total_spawns += spawner.max_spawns
	return total_spawns
