class_name LevelGrid
extends RefCounted

## The level's cell grid: world/cell conversion, walkable and buildable tiles from the
## TileType custom data, AStarGrid2D paths, and which building stands in which cell.


const TILE_TYPE_CUSTOM_DATA_NAME : String = "TileType"
const TILE_EFFECT_CUSTOM_DATA_NAME : String = "TileEffect"
#enemy speed on ground with the Slowing tile effect (sand, mud)
const SLOWING_GROUND_SPEED_FACTOR : float = 0.85
#enemy speed on a cell next to a player building: squeezing through the maze
const MAZE_SPEED_FACTOR : float = 0.85
#on top of the maze slow next to an element wall: Frost about 75% speed in all, Fortress about 80%
const WALL_ELEMENT_SPEED_FACTORS : Dictionary[Utils.Element, float] = {Utils.Element.Frost: 0.88, Utils.Element.Physical: 0.94}
const FROST_T2_SPEED_FACTOR : float = 0.78
#an element wall's maze effect spreads to the cells around a tower touching it from this tier on (T2 needs the
#element tree's wall node and the shared wall line at Up 4: wall talents and improved walls)
const MAZE_TOWER_MIN_TIER : int = 2
#from this tier the effect runs on along a row of touching towers, up to this many towers from the cell
const MAZE_CHAIN_MIN_TIER : int = 3
const MAZE_CHAIN_TOWERS : int = 8
#how far (cells) find_path looks for open ground when the start cell is solid (lava poured over an enemy)
const OFF_SOLID_SEARCH_CELLS : int = 4

var tiles : Tiles = null
var astar_grid : AStarGrid2D = null
#the level's own list, shared by reference: Level adds and removes buildings
var buildings : Array[Building] = []
#cells taken by level objects drawn over the ground (spawn point caves): no walking, no building
var reserved_cells : Dictionary[Vector2i, bool] = {}
#walkable cells nothing may be built on (a bog crossing's far shore: a wader on the stones cannot reach a wall there)
var unbuildable_cells : Dictionary[Vector2i, bool] = {}
#MAZE_SPEED_FACTOR, lowered by the maze slow card (LevelUpgrades)
var maze_speed_factor : float = MAZE_SPEED_FACTOR
#maze slow points from the talents (Narrow Ways, Dragon's Maze), on top of maze_speed_factor
var talent_maze_slow : float = 0.0
#the level's BogCrossings, for the enemies that can wade
var bog_crossings : Array[BogCrossing] = []
#cells whose tile flags something in the level replaced (lava cooled into rock, an eruption over a road)
var cell_overrides : Dictionary[Vector2i, int] = {}
#buildings by cell, rebuilt on the next lookup after mark_buildings_changed: the maze checks ask for
#up to twenty cells per enemy step and per tower hit, too many for a scan of every building each time
var buildings_by_cell : Dictionary[Vector2i, Building] = {}
var is_cell_index_dirty : bool = true


func _init(level_tiles : Tiles, level_buildings : Array[Building]) -> void:
	tiles = level_tiles
	buildings = level_buildings
	_create_astar_grid()


func find_path(from : Vector2, to : Vector2) -> PackedVector2Array:
	var from_cell : Vector2i = world_position_to_grid(from)
	var to_cell : Vector2i = world_position_to_grid(to)

	#AStarGrid2D finds nothing from a solid cell: an enemy that an eruption caught on its road would never move again
	if astar_grid.is_in_boundsv(from_cell) and astar_grid.is_point_solid(from_cell):
		return _find_path_off_solid(from_cell, to_cell)

	return astar_grid.get_point_path(from_cell, to_cell, true)


## find_path with every wall's cell weighing wall_weight instead of its building weight (the battering ram, the
## wall crawler); the weights are put back before it returns.
func find_path_with_wall_weight(from : Vector2, to : Vector2, wall_weight : float) -> PackedVector2Array:
	var old_weights : Dictionary[Vector2i, float] = {}
	for building in buildings:
		if is_instance_valid(building) and building is Wall and building.is_placed:
			var cell : Vector2i = world_position_to_grid(building.global_position)
			if astar_grid.is_in_boundsv(cell) and not old_weights.has(cell):
				old_weights[cell] = astar_grid.get_point_weight_scale(cell)
				astar_grid.set_point_weight_scale(cell, wall_weight)
	var path : PackedVector2Array = find_path(from, to)
	for cell in old_weights:
		astar_grid.set_point_weight_scale(cell, old_weights[cell])
	return path


#the shortest path from the nearest ring of open cells around a solid one that has a path reaching `to`
func _find_path_off_solid(from_cell : Vector2i, to_cell : Vector2i) -> PackedVector2Array:
	for radius in range(1, OFF_SOLID_SEARCH_CELLS + 1):
		var best : PackedVector2Array = PackedVector2Array()
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell : Vector2i = from_cell + Vector2i(dx, dy)
				if not astar_grid.is_in_boundsv(cell) or astar_grid.is_point_solid(cell):
					continue
				var path : PackedVector2Array = astar_grid.get_point_path(cell, to_cell, true)
				if path.is_empty() or world_position_to_grid(path[path.size() - 1]) != to_cell:
					continue
				if best.is_empty() or path.size() < best.size():
					best = path
		if not best.is_empty():
			return best

	return PackedVector2Array()


## The cheapest way for a wading enemy: the road, or a bog crossing when the road to it, the
## stones and the road from its far shore cost less (buildings count with their weight).
func find_wading_route(from : Vector2, to : Vector2) -> WadingRoute:
	var best : WadingRoute = WadingRoute.new()
	best.path = find_path(from, to)
	var best_cost : float = get_path_cost(best.path, to)

	for crossing in bog_crossings:
		var to_entry : PackedVector2Array = find_path(from, crossing.entry_position)
		var from_exit : PackedVector2Array = find_path(crossing.exit_position, to)
		var cost : float = get_path_cost(to_entry, crossing.entry_position) + crossing.get_cost() + get_path_cost(from_exit, to)
		if cost < best_cost:
			best_cost = cost
			best = WadingRoute.new()
			best.path = to_entry + from_exit
			best.exit_index = to_entry.size()
			best.crossing = crossing

	return best


## What AStarGrid2D counts for a path: each step costs the weight of the cell it enters. INF when the
## path does not reach `to` (a partial path).
func get_path_cost(path : PackedVector2Array, to : Vector2) -> float:
	if path.is_empty() or world_position_to_grid(path[path.size() - 1]) != world_position_to_grid(to):
		return INF

	var cost : float = 0.0
	for i in range(1, path.size()):
		cost += astar_grid.get_point_weight_scale(world_position_to_grid(path[i]))
	return cost


func set_cell_weight(cell : Vector2i, weight : float) -> void:
	astar_grid.set_point_weight_scale(cell, weight)


## Replaces the cell's tile flags (Utils.TileType) until cleared, and keeps the A* grid in step.
## Emit GameSignals.astar_grid_updated afterwards when enemies are already walking.
func set_cell_override(cell : Vector2i, flags : int) -> void:
	cell_overrides[cell] = flags
	_update_solid(cell)


func clear_cell_override(cell : Vector2i) -> void:
	if cell_overrides.erase(cell):
		_update_solid(cell)


func _update_solid(cell : Vector2i) -> void:
	if astar_grid.is_in_boundsv(cell):
		astar_grid.set_point_solid(cell, not is_cell_walkable(cell))


#emit GameSignals.astar_grid_updated afterwards when enemies are already walking
func reserve_cells(cells : Array[Vector2i]) -> void:
	for cell in cells:
		reserved_cells[cell] = true
		if astar_grid.is_in_boundsv(cell):
			astar_grid.set_point_solid(cell, true)


#whether a walk from `from` gets to `to` at all, through buildings or not (find_path allows partial paths, so an
#empty check is not enough: a cut-off route still returns the way to the nearest cell)
func reaches(from : Vector2, to : Vector2) -> bool:
	var path : PackedVector2Array = find_path(from, to)
	return not path.is_empty() and world_position_to_grid(path[path.size() - 1]) == world_position_to_grid(to)


#open = the cheapest path walks around every building; a closed route goes through one
func is_route_open(from : Vector2, to : Vector2) -> bool:
	var path : PackedVector2Array = find_path(from, to)

	if path.is_empty() or world_position_to_grid(path[path.size() - 1]) != world_position_to_grid(to):
		return false

	for point in path:
		if astar_grid.get_point_weight_scale(world_position_to_grid(point)) > 1.0:
			return false

	return true


#whether a building of this weight in the cell would close a route that is open now, with the
#planned cells (a dragged wall line not built yet) counted as built; the grid is left as it was
func would_close_route(cell : Vector2i, weight : float, routes : Array[PackedVector2Array], planned_cells : Array[Vector2i] = []) -> bool:
	var old_weights : Dictionary[Vector2i, float] = {}

	for planned_cell in planned_cells + [cell]:
		old_weights[planned_cell] = astar_grid.get_point_weight_scale(planned_cell)

	for planned_cell in planned_cells:
		astar_grid.set_point_weight_scale(planned_cell, weight)

	var open_routes : Array[PackedVector2Array] = routes.filter(func(route : PackedVector2Array) -> bool: return is_route_open(route[0], route[1]))
	var closes : bool = false

	if not open_routes.is_empty():
		astar_grid.set_point_weight_scale(cell, weight)
		closes = open_routes.any(func(route : PackedVector2Array) -> bool: return not is_route_open(route[0], route[1]))

	for changed_cell in old_weights:
		astar_grid.set_point_weight_scale(changed_cell, old_weights[changed_cell])

	return closes


## The grid's area in world pixels.
func get_playfield_rect() -> Rect2:
	var region : Rect2 = Rect2(astar_grid.region)
	var cell_size : Vector2 = Vector2(tiles.ground_layer.tile_set.tile_size)
	var origin : Vector2 = tiles.ground_layer.to_global(Vector2.ZERO)
	return Rect2(origin + region.position * cell_size, region.size * cell_size)


func is_position_in_bounds(_pos : Vector2) -> bool:
	return astar_grid.is_in_boundsv(world_position_to_grid(_pos))


func is_position_buildable(_pos : Vector2) -> bool:
	var cell : Vector2i = world_position_to_grid(_pos)
	if reserved_cells.has(cell) or unbuildable_cells.has(cell):
		return false

	var flags : int = _get_cell_flags(cell)

	if has_flag(flags, Utils.TileType.OnlyBuildable):
		return true

	return has_flag(flags, Utils.TileType.Normal) and not has_flag(flags, Utils.TileType.Blocking | Utils.TileType.OnlyWalkable)


func is_position_walkable(_position : Vector2) -> bool:
	return is_cell_walkable(world_position_to_grid(_position))


func is_cell_walkable(cell : Vector2i) -> bool:
	if reserved_cells.has(cell):
		return false

	var flags : int = _get_cell_flags(cell)

	if has_flag(flags, Utils.TileType.OnlyWalkable):
		return true

	return has_flag(flags, Utils.TileType.Normal) and not has_flag(flags, Utils.TileType.Blocking | Utils.TileType.OnlyBuildable)


func has_flag(a : int, b : int) -> bool:
	return a & b != 0


## How fast a walker moves on this cell: slower on slowing ground and next to a building (traps don't count).
func get_move_speed_factor(cell : Vector2i) -> float:
	var factor : float = 1.0

	if has_flag(_get_cell_flags(cell, TILE_EFFECT_CUSTOM_DATA_NAME), Utils.TileEffect.Slowing):
		factor *= SLOWING_GROUND_SPEED_FACTOR

	if is_maze_cell(cell):
		factor *= maxf(maze_speed_factor - talent_maze_slow, 0.4)
		#element walls: freezing ground next to Frost, hard going next to Fortress (strongest wall nearby counts)
		var wall_factor : float = 1.0
		for wall in get_maze_walls(cell):
			var wall_slow : float = WALL_ELEMENT_SPEED_FACTORS.get(wall.element, 1.0)
			#Frost T2: freezing ground, colder still
			if wall.element == Utils.Element.Frost and wall.get_element_tier() >= 2:
				wall_slow = FROST_T2_SPEED_FACTOR
			wall_factor = minf(wall_factor, wall_slow)
		factor *= wall_factor

	return factor


## The element walls whose maze-area effect reaches this cell: the element walls beside it, and through a tower
## beside it the element walls at MAZE_TOWER_MIN_TIER or higher that touch that tower (the tower extends the maze;
## the user, 2026-11-20). From MAZE_CHAIN_MIN_TIER the effect also runs along a row of touching towers (up to
## MAZE_CHAIN_TOWERS of them). Only the ground side: attackers of the tower get nothing from the wall.
func get_maze_walls(cell : Vector2i) -> Array[Wall]:
	var walls : Array[Wall] = []
	var towers : Array[Vector2i] = []
	for neighbour in get_surrounding_cells(cell):
		var building : Building = get_building_from_cell_position(neighbour)
		if building is Wall:
			if building.element != Utils.Element.None and not walls.has(building):
				walls.append(building)
		elif building is Tower and not towers.has(neighbour):
			towers.append(neighbour)
	if towers.is_empty():
		return walls

	#the towers beside the cell first (T2 walls touching them count), then the towers chained to them (T3 walls)
	var first_count : int = towers.size()
	var index : int = 0
	while index < towers.size():
		var tower_cell : Vector2i = towers[index]
		var min_tier : int = MAZE_TOWER_MIN_TIER if index < first_count else MAZE_CHAIN_MIN_TIER
		for touching in get_surrounding_cells(tower_cell):
			var building : Building = get_building_from_cell_position(touching)
			if building is Wall:
				if building.element != Utils.Element.None and building.get_element_tier() >= min_tier and not walls.has(building):
					walls.append(building)
			elif building is Tower and not towers.has(touching) and towers.size() < MAZE_CHAIN_TOWERS:
				towers.append(touching)
		index += 1
	return walls


## The maze: a cell next to a wall, or next to a building (not a trap) that touches a wall (the user, 2026-11-26:
## towers alone bend the route but do not slow it, so walls have a job only they can do).
func is_maze_cell(cell : Vector2i) -> bool:
	for neighbour in get_surrounding_cells(cell):
		var building : Building = get_building_from_cell_position(neighbour)
		if building == null or building is Trap:
			continue
		if building is Wall or _touches_wall(neighbour):
			return true

	return false


## A tight corridor (the Breather's niche, 2026-11-26): blocked on both sides, left and right or above and below, by
## ground no one walks or a building (not a trap).
func is_corridor_cell(cell : Vector2i) -> bool:
	return (_is_side_blocked(cell + Vector2i.LEFT) and _is_side_blocked(cell + Vector2i.RIGHT)) 		or (_is_side_blocked(cell + Vector2i.UP) and _is_side_blocked(cell + Vector2i.DOWN))


## An inside corner of the maze (the Nova's niche, 2026-11-26): blocked on one side and above or below it, so the
## route turns here.
func is_corner_cell(cell : Vector2i) -> bool:
	var horizontal : bool = _is_side_blocked(cell + Vector2i.LEFT) or _is_side_blocked(cell + Vector2i.RIGHT)
	var vertical : bool = _is_side_blocked(cell + Vector2i.UP) or _is_side_blocked(cell + Vector2i.DOWN)
	return horizontal and vertical and not is_corridor_cell(cell)


func _is_side_blocked(cell : Vector2i) -> bool:
	if not is_cell_walkable(cell):
		return true
	var building : Building = get_building_from_cell_position(cell)
	return building != null and building is not Trap


func _touches_wall(building_cell : Vector2i) -> bool:
	for touching in get_surrounding_cells(building_cell):
		if get_building_from_cell_position(touching) is Wall:
			return true
	return false


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
	if is_cell_index_dirty:
		_rebuild_cell_index()
	return buildings_by_cell.get(_grid_pos, null)


## Call after a building is added to or removed from `buildings` (Level does it).
func mark_buildings_changed() -> void:
	is_cell_index_dirty = true


#the first building in the list wins a cell, as the old scan did
func _rebuild_cell_index() -> void:
	buildings_by_cell.clear()
	for building in buildings:
		if not is_instance_valid(building):
			continue
		var cell : Vector2i = world_position_to_grid(building.global_position)
		if not buildings_by_cell.has(cell):
			buildings_by_cell[cell] = building
	is_cell_index_dirty = false


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


#the flags of one custom data layer (TileType or TileEffect) of every tile map layer on this cell, combined
func _get_cell_flags(cell : Vector2i, data_name : String = TILE_TYPE_CUSTOM_DATA_NAME) -> int:
	if data_name == TILE_TYPE_CUSTOM_DATA_NAME and cell_overrides.has(cell):
		return cell_overrides[cell]
	var flags : int = 0

	for tile_map_layer in tiles.tile_map_layers:
		var tile_data : TileData = tile_map_layer.get_cell_tile_data(cell)

		#a tile set without the layer would print an error for every lookup
		if tile_data == null or tile_map_layer.tile_set.get_custom_data_layer_by_name(data_name) < 0:
			continue

		var tile_type_data = tile_data.get_custom_data(data_name)

		if tile_type_data:
			flags |= tile_type_data

	return flags


## Walkable ground with no building on it (a trap is walked over).
func is_cell_free_to_walk(cell : Vector2i) -> bool:
	return _is_cell_free_to_walk(cell)


## A walk from cell reaches to without going through a building (a pocket the maze walls in has none).
func has_clear_route(cell : Vector2i, to : Vector2) -> bool:
	var path : PackedVector2Array = find_path(grid_position_to_world(cell), to)
	if path.is_empty() or world_position_to_grid(path[path.size() - 1]) != world_position_to_grid(to):
		return false
	for point in path:
		if not _is_cell_free_to_walk(world_position_to_grid(point)):
			return false
	return true


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
