extends RefCounted

## Finds where 32x32 landmarks (2x2 blocking cells) can stand in existing levels without getting in the way: open ground
## (walkable and buildable, a free ring around it), off every spawner's path to its castle (and a cell either side), away
## from castles and spawners, apart from each other, and only where every route stays open with it in place. Prints one
## line per spot, "SPOT <level> <cell x> <cell y>", for tools/level_dressing.py to write into the level.
##     python tools/gd.py run tools/reports/landmark_spots.gd 13 14 ... [count=3] [spacing=8]

const ROAD_MARGIN : int = 1
const KEEP_AWAY : int = 3


func run(kit : TestKit, args : PackedStringArray) -> void:
	var count : int = 3
	var spacing : int = 8
	var levels : Array[int] = []
	for arg in args:
		if arg.begins_with("count="):
			count = int(arg.get_slice("=", 1))
		elif arg.begins_with("spacing="):
			spacing = int(arg.get_slice("=", 1))
		elif arg.is_valid_int():
			levels.append(int(arg))
	for number in levels:
		await kit.load_level(number)
		for spot in _spots(kit.level, number, count, spacing):
			print("SPOT %d %d %d" % [number, spot.x, spot.y])


func _spots(level : Level, number : int, count : int, spacing : int) -> Array[Vector2i]:
	var grid : LevelGrid = level.grid
	var roads : Dictionary[Vector2i, bool] = {}
	var keep_away : Array[Vector2i] = []
	for spawner in level.get_spawners():
		keep_away.append(grid.world_position_to_grid(spawner.global_position))
		if spawner.end_point == null:
			continue
		keep_away.append(grid.world_position_to_grid(spawner.end_point.global_position))
		for point in grid.find_path(spawner.global_position, spawner.end_point.global_position):
			var cell : Vector2i = grid.world_position_to_grid(point)
			for dx in range(-ROAD_MARGIN, ROAD_MARGIN + 1):
				for dy in range(-ROAD_MARGIN, ROAD_MARGIN + 1):
					roads[cell + Vector2i(dx, dy)] = true

	var candidates : Array[Vector2i] = []
	for cell in grid.tiles.ground_layer.get_used_cells():
		if _is_open_block(grid, cell, roads, keep_away):
			candidates.append(cell)
	#a fixed order per level, so a rerun picks the same spots
	candidates.sort_custom(func(a : Vector2i, b : Vector2i) -> bool:
		return str(number, a).hash() < str(number, b).hash())

	var picked : Array[Vector2i] = []
	for cell in candidates:
		if picked.size() >= count:
			break
		if picked.any(func(p : Vector2i) -> bool: return absi(p.x - cell.x) + absi(p.y - cell.y) < spacing):
			continue
		var block : Array[Vector2i] = [cell, cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)]
		for c in block:
			grid.set_cell_override(c, Utils.TileType.Blocking)
		if _routes_open(level):
			picked.append(cell)
		else:
			for c in block:
				grid.clear_cell_override(c)
	return picked


#the 2x2 block from cell and the ring around it: open ground, no road, nothing reserved
func _is_open_block(grid : LevelGrid, cell : Vector2i, roads : Dictionary[Vector2i, bool], keep_away : Array[Vector2i]) -> bool:
	for c in keep_away:
		if absi(c.x - cell.x) <= KEEP_AWAY and absi(c.y - cell.y) <= KEEP_AWAY:
			return false
	for dx in range(-1, 3):
		for dy in range(-1, 3):
			var c : Vector2i = cell + Vector2i(dx, dy)
			if not grid.is_cell_walkable(c) or not grid.is_position_buildable(grid.grid_position_to_world(c)):
				return false
			var inner : bool = dx in [0, 1] and dy in [0, 1]
			if inner and roads.has(c):
				return false
	return true


func _routes_open(level : Level) -> bool:
	for spawner in level.get_spawners():
		if spawner.end_point != null and level.grid.find_path(spawner.global_position, spawner.end_point.global_position).is_empty():
			return false
	return true
