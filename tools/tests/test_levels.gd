extends RefCounted

## Every level loads, has waves, a route from each spawner, and spawn groups that use existing spawners.

const LEVEL_COUNT : int = 6


func test_levels_load_and_route(kit : TestKit) -> void:
	for number in range(1, LEVEL_COUNT + 1):
		await kit.load_level(number)
		var data : LevelData = kit.level_data(number)
		kit.check(not data.waves.is_empty(), "level %d has waves" % number)

		var spawner_ids : Array[int] = []
		for spawner in kit.level.get_spawners():
			spawner_ids.append(spawner.id)
			var path : PackedVector2Array = kit.level.grid.find_path(spawner.global_position, spawner.end_point.global_position)
			kit.check(path.size() > 1, "level %d spawner %d has a route" % [number, spawner.id])

		for wave_index in data.waves.size():
			for group in data.waves[wave_index].spawn_groups:
				kit.check(group.enemy_scene != null, "level %d wave %d has an enemy" % [number, wave_index + 1])
				kit.check(spawner_ids.has(group.spawner_id), "level %d wave %d uses spawner %d" % [number, wave_index + 1, group.spawner_id])
