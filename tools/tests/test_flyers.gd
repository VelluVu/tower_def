extends RefCounted

## Flyers: their own wavy route to the castle, no maze, no traps.


func test_flight_path(kit : TestKit) -> void:
	var from : Vector2 = Vector2(0.0, 0.0)
	var to : Vector2 = Vector2(320.0, 0.0)
	var points : PackedVector2Array = FlightPath.get_points(from, to, 0.25)
	kit.check(points.size() == 20, "one waypoint per tile (%d)" % points.size())
	kit.check(points[points.size() - 1].distance_to(to) < 0.01, "the last waypoint is the castle")
	var widest : float = 0.0
	for point in points:
		widest = maxf(widest, absf(point.y))
	kit.check(widest > 1.0 and widest <= FlightPath.WAVE_AMPLITUDE, "the route waves across the line (%.1f px)" % widest)


func test_batling_flies_to_the_castle(kit : TestKit) -> void:
	await kit.load_level(1)
	var spawner : Spawner = kit.level.get_spawners()[0]
	var enemy : Enemy = kit.spawn_enemy("batling")
	await kit.frames(2)
	var waypoints : int = enemy.point_path.size()
	var straight : int = ceili(spawner.global_position.distance_to(spawner.end_point.global_position) / FlightPath.STEP)
	kit.check(waypoints == straight, "the batling flies straight, not along the ground path (%d waypoints)" % waypoints)

	#a building changes every walker's path, never a flyer's
	var cell : Vector2i = kit.level.grid.world_position_to_grid(enemy.point_path[int(waypoints * 0.5)])
	await kit.place("wall", cell)
	kit.check(enemy.point_path.size() == waypoints, "a new wall does not reroute it")

	var reached : Array[bool] = [false]
	var on_reached : Callable = func(_enemy : Enemy) -> void: reached[0] = true
	GameSignals.enemy_reached_end_point.connect(on_reached)
	var time : float = await kit.run_until(func() -> bool: return reached[0], 120.0)
	GameSignals.enemy_reached_end_point.disconnect(on_reached)
	kit.check(reached[0], "the batling reaches the castle (took %.1f s)" % time)


func test_traps_skip_flyers(kit : TestKit) -> void:
	await kit.load_level(1)
	var trap : Trap = await kit.place("leopard_trap", kit.find_cell(func(c : Vector2i) -> bool: return kit.level.grid.is_cell_walkable(c)))
	var batling : Enemy = kit.spawn_enemy("batling")
	var weakling : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	trap._on_range_area_body_entered(batling)
	kit.check(not trap.targets.has(batling), "the trap ignores a flyer")
	trap.can_hit_air = true
	trap._on_range_area_body_entered(batling)
	kit.check(trap.targets.has(batling), "with can_hit_air it takes it")
	trap._on_range_area_body_entered(weakling)
	kit.check(trap.targets.has(weakling), "walkers are still taken")
