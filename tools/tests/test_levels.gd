extends RefCounted

## Every level loads, has waves, a route from each spawner all the way to its castle, and spawn groups that use
## existing spawners.

const LEVELS_FOLDER : String = "res://scenes/level/levels/"


func _level_numbers() -> Array[int]:
	var numbers : Array[int] = []
	for file in DirAccess.get_files_at(LEVELS_FOLDER):
		if file.ends_with(".tscn"):
			numbers.append(file.get_basename().get_slice("_", 1).to_int())
	numbers.sort()
	return numbers


func test_levels_load_and_route(kit : TestKit) -> void:
	var numbers : Array[int] = _level_numbers()
	kit.check(numbers.size() >= 36 and numbers[-1] == numbers.size(), "the levels are numbered 1 to %d without gaps" % numbers.size())
	for number in numbers:
		await kit.load_level(number)
		var data : LevelData = kit.level_data(number)
		kit.check(not data.waves.is_empty(), "level %d has waves" % number)

		var spawner_ids : Array[int] = []
		for spawner in kit.level.get_spawners():
			spawner_ids.append(spawner.id)
			var path : PackedVector2Array = kit.level.grid.find_path(spawner.global_position, spawner.end_point.global_position)
			var grid : LevelGrid = kit.level.grid
			var reaches : bool = path.size() > 1 and grid.world_position_to_grid(path[-1]) == grid.world_position_to_grid(spawner.end_point.global_position)
			kit.check(reaches, "level %d spawner %d has a route to the castle" % [number, spawner.id])

		for wave_index in data.waves.size():
			for group in data.waves[wave_index].spawn_groups:
				kit.check(group.enemy_scene != null, "level %d wave %d has an enemy" % [number, wave_index + 1])
				kit.check(spawner_ids.has(group.spawner_id), "level %d wave %d uses spawner %d" % [number, wave_index + 1, group.spawner_id])


## Nothing is built in a spawn's mouth or on the ground right in front of it; enemies still walk out (2026-11-27).
func test_no_building_in_spawn_mouths(kit : TestKit) -> void:
	await kit.load_level(1)
	var grid : LevelGrid = kit.level.grid
	for spawner in kit.level.get_spawners():
		var mouth : Vector2i = grid.world_position_to_grid(spawner.global_position)
		var in_front : Vector2i = mouth + Vector2i.DOWN
		kit.check(not grid.is_position_buildable(grid.grid_position_to_world(mouth)), "no building in spawn %s's mouth" % spawner.id)
		kit.check(not grid.is_position_buildable(grid.grid_position_to_world(in_front)), "no building in front of spawn %s" % spawner.id)
		kit.check(not grid.is_position_trappable(grid.grid_position_to_world(in_front)), "no trap in front of spawn %s" % spawner.id)
		kit.check(grid.is_cell_walkable(mouth), "spawn %s's mouth is still walkable" % spawner.id)
