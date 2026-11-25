extends RefCounted

## A player's session in one Main (bug search 2026-11-25): level after level from the world map, each built on,
## played a few seconds, retried, then left for the map. The bots load one level per process, so only this sees
## what piles up between levels: signal connections on the buses, nodes left behind, script errors on the way.

#the areas, their bosses and lairs, a Hard and a Survival run
const STOPS : Array[Array] = [[1, Utils.LevelMode.Normal], [12, Utils.LevelMode.Normal], [13, Utils.LevelMode.Hard], [24, Utils.LevelMode.Normal],
	[30, Utils.LevelMode.Survival], [36, Utils.LevelMode.Normal], [44, Utils.LevelMode.Hard], [57, Utils.LevelMode.Normal], [60, Utils.LevelMode.Normal]]
const BUILT : Array[String] = ["puffe_bolter", "puffe_nova", "puffe_hatchery"]
const PLAY_SECONDS : float = 4.0
#a few connections or nodes either way are timers and puffs still running
const CONNECTION_SLACK : int = 8
const NODE_SLACK : int = 60


func test_levels_in_a_row(kit : TestKit) -> void:
	var main : Main = load("res://scenes/main.tscn").instantiate()
	kit.root.add_child(main)
	await kit.frames(2)
	var connections : Array[int] = []
	var nodes : Array[int] = []
	for stop in STOPS:
		var level : Level = await _start(kit, main, func() -> void: UISignals.start_level_button_pressed.emit(stop[0], stop[1]))
		kit.check(level != null and level.mode == stop[1], "level %d loads" % stop[0])
		if level == null:
			break
		await _play(kit, level)
		level = await _start(kit, main, func() -> void: UISignals.retry_level_pressed.emit(), level)
		kit.check(level != null, "level %d restarts" % stop[0])
		if level == null:
			break
		await _play(kit, level)
		UISignals.continue_next_level_pressed.emit()
		await kit.run_until(func() -> bool: return main.scene_manager.current_level == null, 5.0)
		await kit.frames(3)
		kit.check(main.scene_manager.current_level == null, "level %d left for the map" % stop[0])
		connections.append(_bus_connections())
		nodes.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	if connections.size() == STOPS.size():
		kit.check(connections[-1] - connections[0] <= CONNECTION_SLACK, "bus connections do not pile up: %s" % [connections])
		kit.check(nodes[-1] - nodes[0] <= NODE_SLACK, "nodes do not pile up: %s" % [nodes])
	#a level-up offer or a lost level pauses the tree: later tests need it running, at normal speed
	main.reset_time_scale()
	kit.root.get_tree().paused = false
	main.queue_free()
	await kit.frames(2)


## Does what starts a level (from the map, a retry) and waits for the new level.
func _start(kit : TestKit, main : Main, action : Callable, old_level : Level = null) -> Level:
	action.call()
	var level : Level = null
	for i in 900:
		await kit.frames()
		level = main.scene_manager.current_level as Level
		if level != null and level != old_level and is_instance_valid(level) and level.is_node_ready():
			break
		level = null
	if level != null:
		kit.level = level
		await kit.frames(2)
	return level


## A few towers by the route, the first wave for a few seconds, one sold mid-wave.
func _play(kit : TestKit, level : Level) -> void:
	level.player_stats.gold = 999.0
	level.player_stats.life = 999.0
	var route : PackedVector2Array = level.grid.find_path(level.get_routes()[0][0], level.get_routes()[0][1])
	var on_route : Dictionary[Vector2i, bool] = {}
	for point in route:
		on_route[level.grid.world_position_to_grid(point)] = true
	var near : Vector2i = level.grid.world_position_to_grid(route[mini(10, route.size() - 1)])
	var placed : Array[Building] = []
	for building_name in BUILT:
		var cell : Vector2i = kit.find_cell(func(cell : Vector2i) -> bool:
			return not on_route.has(cell) and Vector2(cell - near).length() <= 4.0 \
				and level.grid.is_position_buildable(level.grid.grid_position_to_world(cell)) and not level.grid.has_building_in_cell_position(cell))
		if cell != Vector2i.MAX:
			placed.append(await kit.place(building_name, cell))
	UISignals.start_wave_pressed.emit()
	await kit.run_until(func() -> bool: return false, PLAY_SECONDS * 0.5)
	if not placed.is_empty() and is_instance_valid(placed[0]):
		GameSignals.forced_selection.emit(placed[0])
		await kit.frames(1)
		UISignals.on_sell_selected_building_pressed.emit()
	await kit.run_until(func() -> bool: return false, PLAY_SECONDS * 0.5)


func _bus_connections() -> int:
	var count : int = 0
	for bus in [GameSignals, UISignals]:
		for item in bus.get_signal_list():
			count += bus.get_signal_connection_list(item.name).size()
	return count
