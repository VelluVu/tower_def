extends RefCounted

## `python tools/gd.py levels [--map] [level numbers]`: per level the waves (enemies, total health),
## the XP, cards and kill gold over the level, and per spawner the route length, turns and slow cells.
## --map draws each level: # blocked, . walkable, s slow ground, * route, T tower-only, 0-9 spawner id.

const TURN_DOT_LIMIT : float = 0.5
const MAP_ARG : String = "--map"


func run(kit : TestKit, args : PackedStringArray) -> void:
	var show_map : bool = args.has(MAP_ARG)
	var numbers : Array[int] = []
	for arg in args:
		if arg.is_valid_int():
			numbers.append(arg.to_int())
	if numbers.is_empty():
		numbers.assign(range(1, _count_levels() + 1))

	for number in numbers:
		await kit.load_level(number)
		_print_level(kit, number, show_map)


func _print_level(kit : TestKit, number : int, show_map : bool) -> void:
	var data : LevelData = kit.level_data(number)
	var total_xp : float = 0.0
	var total_gold : float = 0.0
	var total_enemies : int = 0
	var wave_lines : PackedStringArray = []

	for wave_index in data.waves.size():
		var health : float = 0.0
		var parts : PackedStringArray = []
		for group in data.waves[wave_index].spawn_groups:
			var enemy : Enemy = group.enemy_scene.instantiate()
			var xp_multiplier : float = enemy.xp_multiplier
			var enemy_stats : Dictionary = _base_stats(enemy)
			health += enemy_stats.get(Utils.StatType.MaxHealth, 0.0) * group.count
			total_xp += UpgradeRules.kill_xp(enemy_stats.get(Utils.StatType.MaxHealth, 0.0), xp_multiplier) * group.count
			total_gold += enemy_stats.get(Utils.StatType.Price, 0.0) * group.count
			total_enemies += group.count
			parts.append("%d %s /%ss sp%d" % [group.count, group.enemy_scene.resource_path.get_file().get_basename(), group.interval, group.spawner_id])
		wave_lines.append("  w%d: %s  (health %d, early bonus %s)" % [wave_index + 1, ", ".join(parts), health, data.waves[wave_index].early_start_bonus])

	print("LEVEL %d  start gold %s, life %s, %d waves, %d enemies, kill gold %d, xp %d -> %d cards" % [number, data.starting_gold, data.starting_life, data.waves.size(), total_enemies, total_gold, total_xp, _cards_for_xp(total_xp)])
	for line in wave_lines:
		print(line)

	var grid : LevelGrid = kit.level.grid
	var route_cells : Dictionary = {}
	for spawner in kit.level.get_spawners():
		var path : PackedVector2Array = grid.find_path(spawner.global_position, spawner.end_point.global_position)
		var turns : int = 0
		var slow : int = 0
		for i in path.size():
			var cell : Vector2i = grid.world_position_to_grid(path[i])
			route_cells[cell] = true
			if grid.get_move_speed_factor(cell) < 1.0:
				slow += 1
			if i > 0 and i < path.size() - 1 and (path[i] - path[i - 1]).normalized().dot((path[i + 1] - path[i]).normalized()) < TURN_DOT_LIMIT:
				turns += 1
		print("  route sp%d: %d cells, %d turns, %d on slow ground" % [spawner.id, path.size(), turns, slow])

	if show_map:
		_print_map(kit, route_cells)


func _print_map(kit : TestKit, route_cells : Dictionary) -> void:
	var grid : LevelGrid = kit.level.grid
	var region : Rect2i = grid.astar_grid.region
	var spawner_cells : Dictionary[Vector2i, int] = {}
	for spawner in kit.level.get_spawners():
		spawner_cells[grid.world_position_to_grid(spawner.global_position)] = spawner.id
	print("  map cells x %d..%d, y %d..%d" % [region.position.x, region.end.x - 1, region.position.y, region.end.y - 1])
	for y in range(region.position.y, region.end.y):
		var row : String = "  "
		for x in range(region.position.x, region.end.x):
			var cell : Vector2i = Vector2i(x, y)
			var walkable : bool = grid.is_cell_walkable(cell)
			if spawner_cells.has(cell):
				row += str(spawner_cells[cell])
			elif route_cells.has(cell):
				row += "*"
			elif walkable:
				row += "s" if grid.get_move_speed_factor(cell) < 1.0 else "."
			elif grid.is_position_buildable(grid.grid_position_to_world(cell)):
				row += "T"
			else:
				row += "#"
		print(row)


#the base value of every Stat under the unit's Stats node
func _base_stats(unit : Node) -> Dictionary:
	var values : Dictionary = {}
	for stat in unit.get_node("Stats").get_children():
		if stat is Stat:
			values[stat.type] = stat.base_value
	unit.free()
	return values


func _cards_for_xp(xp : float) -> int:
	var cards : int = 0
	var needed : float = 0.0
	while needed + UpgradeRules.xp_required(cards + 1) <= xp:
		needed += UpgradeRules.xp_required(cards + 1)
		cards += 1
	return cards


func _count_levels() -> int:
	return DirAccess.get_files_at(TestKit.LEVEL_PATH.get_base_dir()).size()
