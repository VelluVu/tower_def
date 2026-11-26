extends RefCounted

## Crowds (2026-11-26): a clearly faster enemy passes a slower one in front instead of queueing,
## and spacing looks only at the enemies in the cells round it (EnemyNeighbours).


func test_slower_neighbour_in_front_is_passed(kit : TestKit) -> void:
	var ahead : Array[Vector2] = [Vector2(4.0, 0.0)]
	var queued : float = EnemySpacing.get_speed_factor(Vector2.ZERO, Vector2.RIGHT, ahead, [20.0], 20.0)
	kit.check(queued < 1.0, "same speed: queues behind (%s)" % queued)
	var passing : float = EnemySpacing.get_speed_factor(Vector2.ZERO, Vector2.RIGHT, ahead, [18.0], 34.0)
	kit.check_near(passing, 1.0, "a scout behind a soldier walks on")
	var no_speeds : float = EnemySpacing.get_speed_factor(Vector2.ZERO, Vector2.RIGHT, ahead)
	kit.check(no_speeds < 1.0, "without speeds it queues as before")


func test_neighbours_come_from_nearby_cells_only(kit : TestKit) -> void:
	await kit.load_level(1)
	var asker : Enemy = kit.spawn_enemy("weakling")
	var near : Enemy = kit.spawn_enemy("weakling")
	var far : Enemy = kit.spawn_enemy("weakling")
	await kit.frames()
	near.global_position = asker.global_position + Vector2(6.0, 0.0)
	far.global_position = asker.global_position + Vector2(80.0, 0.0)
	await kit.frames()
	var positions : Array[Vector2] = []
	var speeds : Array[float] = []
	kit.level.enemy_neighbours.collect(kit.level.existing_enemies, asker, positions, speeds)
	kit.check(positions.size() == 1 and speeds.size() == 1, "only the near one, never itself (%d)" % positions.size())
