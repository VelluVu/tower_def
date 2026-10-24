extends RefCounted

## Enemy movement: slow ground, the maze slow and the turn pause.

const SAND_ATLAS_ROWS : Array[int] = [2, 3]


func test_speed_factors(kit : TestKit) -> void:
	await kit.load_level(3)
	var grid : LevelGrid = kit.level.grid
	var ground : TileMapLayer = kit.level.tiles.ground_layer
	var grass : Vector2i = kit.find_cell(func(cell : Vector2i) -> bool: return grid.get_move_speed_factor(cell) == 1.0 and grid.is_cell_walkable(cell + Vector2i.RIGHT))
	var sand : Vector2i = kit.find_cell(func(cell : Vector2i) -> bool: return ground.get_cell_atlas_coords(cell).y in SAND_ATLAS_ROWS and grid.is_cell_walkable(cell + Vector2i.RIGHT))
	kit.check(grass != Vector2i.MAX and sand != Vector2i.MAX, "found a grass and a sand cell")
	kit.check_near(grid.get_move_speed_factor(sand), LevelGrid.SLOWING_GROUND_SPEED_FACTOR, "sand slows")

	await kit.place("wall", grass + Vector2i.RIGHT)
	await kit.place("wall", sand + Vector2i.RIGHT)
	kit.check_near(grid.get_move_speed_factor(grass), LevelGrid.MAZE_SPEED_FACTOR, "next to a wall slows")
	kit.check_near(grid.get_move_speed_factor(sand), LevelGrid.MAZE_SPEED_FACTOR * LevelGrid.SLOWING_GROUND_SPEED_FACTOR, "both slows multiply")


func test_trap_does_not_slow(kit : TestKit) -> void:
	await kit.load_level(3)
	var grid : LevelGrid = kit.level.grid
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool: return grid.get_move_speed_factor(c) == 1.0 and grid.is_cell_walkable(c + Vector2i.RIGHT))
	await kit.place("leopard_trap", cell + Vector2i.RIGHT)
	kit.check_near(grid.get_move_speed_factor(cell), 1.0, "traps are not part of the maze")


func test_turn_pause_on_route(kit : TestKit) -> void:
	await kit.load_level(1)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	var reached : Array[bool] = [false]
	var on_reached : Callable = func(_enemy : Enemy) -> void: reached[0] = true
	GameSignals.enemy_reached_end_point.connect(on_reached)
	var pauses : Array[int] = [0]
	var was_paused : Array[bool] = [false]
	#an array, because a lambda that captured the enemy itself complains once the enemy is freed at the castle
	var walker : Array[Enemy] = [enemy]
	var walk_done : Callable = func() -> bool:
		if not is_instance_valid(walker[0]):
			return true
		var paused : bool = not walker[0].turn_pause_timer.is_stopped()
		if paused and not was_paused[0]:
			pauses[0] += 1
		was_paused[0] = paused
		return reached[0]
	var time : float = await kit.run_until(walk_done, 120.0)
	GameSignals.enemy_reached_end_point.disconnect(on_reached)
	kit.check(reached[0], "the weakling reaches the castle (took %.1f s)" % time)
	kit.check(pauses[0] >= 10, "it pauses at the turns (%d pauses)" % pauses[0])
