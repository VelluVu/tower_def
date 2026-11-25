extends RefCounted

## The Egg Bomb (2026-11-25): a trap whose first ground enemy lights a fuse; then one blast on everything round it,
## flyers too, with falloff, and a slow rebuild before it can go off again.


func _route_cells(kit : TestKit) -> Array[Vector2i]:
	var route : PackedVector2Array = kit.level.get_routes()[0]
	var cells : Array[Vector2i] = []
	for point in kit.level.grid.find_path(route[0], route[1]):
		cells.append(kit.level.grid.world_position_to_grid(point))
	return cells


## An Egg Bomb on the first route, a few steps from its spawner.
func _place_egg(kit : TestKit) -> EggBomb:
	var cells : Array[Vector2i] = _route_cells(kit)
	for cell in cells.slice(4):
		if kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(cell)) and not kit.level.grid.has_building_in_cell_position(cell):
			return await kit.place("egg_bomb", cell)
	return null


func _enemy(kit : TestKit, scene_name : String, health : float, at : Vector2 = Vector2.INF) -> Enemy:
	var enemy : Enemy = kit.spawn_enemy(scene_name)
	if at != Vector2.INF:
		enemy.global_position = at
	await kit.frames(1)
	for stat_type in [Utils.StatType.MaxHealth, Utils.StatType.Health]:
		enemy.stats.get_stat(stat_type).value = health
	return enemy


func _lost(enemy : Enemy, health : float) -> float:
	return health - enemy.stats.get_stat_value(Utils.StatType.Health)


func test_egg_bomb_basics(kit : TestKit) -> void:
	await kit.load_level(1)
	var egg : EggBomb = await _place_egg(kit)
	kit.check(egg != null, "an Egg Bomb goes on the path")
	kit.check(egg is Trap and egg.astar_weight == 1.0, "a trap the enemies walk over")
	kit.check(egg.skill.skill_type == Utils.SkillType.Blast, "its skill is the blast")
	kit.check(TalentEffect.get_building_flag(egg) == TalentEffect.EGG_BOMB, "talents see it as an Egg Bomb, not a Leopard Trap")
	kit.check_near(egg.get_blast_radius(), EggBomb.BLAST_RADIUS_TILES * Utils.TILE_SIZE, "a blast of 1.25 tiles")
	var list : BuildingListElement = load("res://scenes/unit/building/buildings/egg_bomb.tres")
	kit.check(list.unlock_level == 49 and not list.is_unlocked(48) and list.is_unlocked(49), "it unlocks on level 49")


func test_blast_falloff_and_flyers(kit : TestKit) -> void:
	await kit.load_level(6)
	var egg : EggBomb = await _place_egg(kit)
	var health : float = 100000.0
	var centre : Enemy = await _enemy(kit, "weakling", health, egg.global_position)
	var edge : Enemy = await _enemy(kit, "weakling", health, egg.global_position + Vector2(Utils.TILE_SIZE * 1.1, 0.0))
	var far : Enemy = await _enemy(kit, "weakling", health, egg.global_position + Vector2(Utils.TILE_SIZE * 4.0, 0.0))
	var flyer : Enemy = await _enemy(kit, "batling", health, egg.global_position + Vector2(0.0, Utils.TILE_SIZE * 0.5))
	#where they stand when it goes off
	centre.global_position = egg.global_position
	edge.global_position = egg.global_position + Vector2(Utils.TILE_SIZE * 1.1, 0.0)
	far.global_position = egg.global_position + Vector2(Utils.TILE_SIZE * 4.0, 0.0)
	flyer.global_position = egg.global_position + Vector2(0.0, Utils.TILE_SIZE * 0.5)
	egg.skill.stats.get_stat(Utils.StatType.CriticalChance).value = 0.0
	egg.stats.get_stat(Utils.StatType.CriticalChance).value = 0.0
	egg.detonate()
	kit.check(_lost(centre, health) > 0.0, "the blast hits the enemy on it")
	kit.check(_lost(edge, health) > 0.0 and _lost(edge, health) < _lost(centre, health), "less toward the edge")
	kit.check(_lost(far, health) == 0.0, "nothing beyond its reach")
	kit.check(_lost(flyer, health) > 0.0, "and flyers above it")
	kit.check(egg.is_rebuilding, "then it rebuilds")
	for enemy in [centre, edge, far, flyer]:
		enemy.remove_without_reward()
	await kit.frames(2)


func test_fuse_and_rebuild(kit : TestKit) -> void:
	await kit.load_level(1)
	var egg : EggBomb = await _place_egg(kit)
	var health : float = 100000.0
	var walker : Enemy = await _enemy(kit, "weakling", health)
	await kit.run_until(func() -> bool: return not egg.skill.is_ready, 30.0)
	kit.check(not egg.skill.is_ready, "an enemy walking onto it lights the fuse")
	kit.check(_lost(walker, health) == 0.0, "the fuse burns before the blast")
	#the enemy that lit it is gone: the egg goes off anyway
	walker.remove_without_reward()
	await kit.run_until(func() -> bool: return egg.is_rebuilding, 2.0)
	kit.check(egg.is_rebuilding, "the blast comes when the fuse ends")
	await kit.run_until(func() -> bool: return egg.get_rebuild_progress() > 0.3, 10.0)
	kit.check(egg.get_rebuild_progress() > 0.3 and egg.get_rebuild_progress() < 1.0, "the rebuild takes its time")
	kit.check(not egg.skill.is_ready, "and it cannot go off meanwhile")
	await kit.run_until(func() -> bool: return egg.skill.is_ready, 25.0)
	kit.check(egg.skill.is_ready and not egg.is_rebuilding, "until the egg is whole again")
