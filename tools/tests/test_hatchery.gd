extends RefCounted

## The Hatchery (2026-11-25): guard drakelings stand on a rally cell in its range, each holds one ground enemy and
## claws it while that enemy hits back; a fallen guard hatches again; bosses are only slowed, flyers pass over.


## A Hatchery beside the first spawner's route, a few steps in, so enemies reach its guards soon.
func _place_hatchery(kit : TestKit) -> Hatchery:
	var route : PackedVector2Array = kit.level.get_routes()[0]
	var path : PackedVector2Array = kit.level.grid.find_path(route[0], route[1])
	var path_cells : Array[Vector2i] = []
	for point in path:
		path_cells.append(kit.level.grid.world_position_to_grid(point))
	var near : Array[Vector2i] = path_cells.slice(3, 8)
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		if path_cells.has(c) or not kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)):
			return false
		for p in near:
			if Vector2(c - p).length() <= 1.5:
				return true
		return false)
	return await kit.place("puffe_hatchery", cell)


func _enemy(kit : TestKit, scene_name : String, health : float) -> Enemy:
	var enemy : Enemy = kit.spawn_enemy(scene_name)
	await kit.frames(1)
	for stat_type in [Utils.StatType.MaxHealth, Utils.StatType.Health]:
		enemy.stats.get_stat(stat_type).value = health
	return enemy


func _ready_guards(hatchery : Hatchery) -> int:
	return hatchery.guards.filter(func(g : HatcheryGuard) -> bool: return g.state == HatcheryGuard.State.ACTIVE).size()


func test_hatchery_basics(kit : TestKit) -> void:
	await kit.load_level(1)
	var hatchery : Hatchery = await _place_hatchery(kit)
	kit.check(hatchery.skill.skill_type == Utils.SkillType.Guard, "its skill is the guards' claws")
	kit.check(TalentEffect.get_building_flag(hatchery) == TalentEffect.HATCHERY, "talents see it as a Hatchery")
	kit.check(hatchery.guard_count == Hatchery.BASE_GUARDS, "three guards")
	kit.check_near(hatchery.guard_health, 24.0, "of 24 health")
	kit.check(hatchery.guards.size() == Hatchery.BASE_GUARDS, "they are hatched when it is placed")
	var list : BuildingListElement = load("res://scenes/unit/building/buildings/puffe_hatchery.tres")
	kit.check(list.unlock_level == 11 and not list.is_unlocked(10) and list.is_unlocked(11), "it unlocks on level 11")
	await kit.run_until(func() -> bool: return _ready_guards(hatchery) == Hatchery.BASE_GUARDS, 4.0)
	kit.check(_ready_guards(hatchery) == Hatchery.BASE_GUARDS, "all three hatch")
	hatchery.remove()
	await kit.frames(1)


func test_rally_cell(kit : TestKit) -> void:
	await kit.load_level(1)
	var hatchery : Hatchery = await _place_hatchery(kit)
	kit.check(hatchery.rally_cell != Utils.BAD_CELL, "it finds a rally cell")
	kit.check(hatchery.is_valid_rally_cell(hatchery.rally_cell), "a walkable one in range")
	var route : PackedVector2Array = kit.level.get_routes()[0]
	var on_route : bool = false
	for point in kit.level.grid.find_path(route[0], route[1]):
		on_route = on_route or kit.level.grid.world_position_to_grid(point) == hatchery.rally_cell
	kit.check(on_route, "on the enemies' route")
	kit.check(not hatchery.set_manual_rally(hatchery.grid_position + Vector2i(20, 0)), "a cell out of range is refused")
	var other : Vector2i = Utils.BAD_CELL
	for y in range(-2, 3):
		for x in range(-2, 3):
			var cell : Vector2i = hatchery.grid_position + Vector2i(x, y)
			if cell != hatchery.rally_cell and hatchery.is_valid_rally_cell(cell):
				other = cell
	kit.check(other != Utils.BAD_CELL and hatchery.set_manual_rally(other), "another cell in range is taken")
	hatchery.update_rally()
	kit.check(hatchery.rally_cell == other and hatchery.is_rally_manual, "the player's pick stays after the maze changes")


func test_guards_hold_and_fight(kit : TestKit) -> void:
	await kit.load_level(1)
	var hatchery : Hatchery = await _place_hatchery(kit)
	await kit.run_until(func() -> bool: return _ready_guards(hatchery) == Hatchery.BASE_GUARDS, 4.0)
	await kit.run_until(func() -> bool: return false, 2.0)
	var enemy : Enemy = await _enemy(kit, "weakling", 10000.0)
	await kit.run_until(func() -> bool: return is_instance_valid(enemy.held_by), 20.0)
	kit.check(is_instance_valid(enemy.held_by), "a guard holds the enemy")
	var held_at : Vector2 = enemy.global_position
	await kit.run_until(func() -> bool: return false, 3.0)
	kit.check(enemy.global_position.distance_to(held_at) < 4.0, "the held enemy stays put")
	kit.check(enemy.stats.get_stat_value(Utils.StatType.Health) < 10000.0, "the guard claws it")
	var guard : HatcheryGuard = enemy.held_by
	kit.check(guard.health < guard.max_health, "and it hits back")
	#a guard that falls lets go and hatches again later
	var hit : DamageData = DamageData.new()
	hit.damage = 1000.0
	guard.take_damage(hit)
	hit.free()
	kit.check(guard.state == HatcheryGuard.State.DYING, "a guard can fall")
	kit.check(enemy.held_by != guard, "and lets go")
	await kit.run_until(func() -> bool: return guard.state == HatcheryGuard.State.ACTIVE, Hatchery.RESPAWN_SECONDS + 3.0)
	kit.check(guard.state == HatcheryGuard.State.ACTIVE, "it hatches again")
	enemy.remove_without_reward()
	await kit.frames(2)


func test_bosses_and_flyers(kit : TestKit) -> void:
	await kit.load_level(6)
	var hatchery : Hatchery = await _place_hatchery(kit)
	await kit.run_until(func() -> bool: return _ready_guards(hatchery) == Hatchery.BASE_GUARDS, 4.0)
	var guard : HatcheryGuard = hatchery.guards[0]
	var flyer : Enemy = await _enemy(kit, "batling", 1000.0)
	flyer.global_position = guard.get_post()
	kit.check(guard._find_enemy() != flyer, "flyers pass over the guards")
	#a boss from its first frame: the guards stand near the spawner and would take a plain enemy at once
	var boss : Enemy = kit.spawn_enemy("weakling")
	boss.is_boss = true
	boss.global_position = guard.get_post()
	await kit.frames(1)
	for other in hatchery.guards:
		other._release()
	var speed : float = boss.stats.get_stat_value(Utils.StatType.Speed)
	guard._engage(guard._find_enemy())
	kit.check(guard.enemy == boss, "a guard claws at a boss")
	kit.check(not is_instance_valid(boss.held_by), "but never holds it")
	kit.check_near(boss.stats.get_stat_value(Utils.StatType.Speed), speed * (1.0 - HatcheryGuard.BOSS_SLOW), "only slows it")
	guard._release()
	kit.check_near(boss.stats.get_stat_value(Utils.StatType.Speed), speed, "and the slow goes when it lets go")
	for enemy in [flyer, boss]:
		enemy.remove_without_reward()
	await kit.frames(2)
