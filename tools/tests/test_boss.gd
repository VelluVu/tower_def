extends RefCounted

## The Broodmother's phases and her egg sacs.


func _count(kit : TestKit, scene_name : String) -> int:
	var count : int = 0
	for enemy in kit.level.existing_enemies:
		if is_instance_valid(enemy) and enemy.scene_file_path.get_file().get_basename() == scene_name:
			count += 1
	return count


func _set_health_ratio(enemy : Enemy, ratio : float) -> void:
	enemy.stats.get_stat(Utils.StatType.Health).value = enemy.stats.get_stat_value(Utils.StatType.MaxHealth) * ratio


func _ability(enemy : Enemy, ability_name : String) -> EnemyAbility:
	return enemy.abilities.get_node(ability_name)


func test_egg_sac_hatches_without_reward(kit : TestKit) -> void:
	await kit.load_level(8)
	var egg : Enemy = kit.spawn_enemy("egg_sac")
	await kit.frames(2)
	var gold : float = kit.level.player_stats.gold
	var xp : float = kit.level.upgrades.xp
	var start : Vector2 = egg.global_position
	var time : float = await kit.run_until(func() -> bool: return egg.is_deactivated, 12.0)
	kit.check(egg.is_deactivated, "the egg sac hatches (took %.1f s)" % time)
	kit.check(time > 5.0, "not before its countdown (%.1f s)" % time)
	kit.check(egg.global_position == start, "the egg sac never moves")
	kit.check(_count(kit, "swarmling") == 6, "six swarmlings hatch (%d)" % _count(kit, "swarmling"))
	kit.check_near(kit.level.player_stats.gold, gold, "a hatched sac gives no gold")
	kit.check_near(kit.level.upgrades.xp, xp, "a hatched sac gives no XP")


func test_popped_egg_sac_hatches_nothing(kit : TestKit) -> void:
	await kit.load_level(8)
	var egg : Enemy = kit.spawn_enemy("egg_sac")
	await kit.frames(2)
	var gold : float = kit.level.player_stats.gold
	_set_health_ratio(egg, 0.0)
	await kit.run_until(func() -> bool: return egg.is_deactivated, 1.0)
	await kit.run_until(func() -> bool: return false, 7.0)
	kit.check(_count(kit, "swarmling") == 0, "a popped sac hatches nothing")
	kit.check(kit.level.player_stats.gold > gold, "popping it gives its gold")


func test_broodmother_lays_eggs(kit : TestKit) -> void:
	await kit.load_level(8)
	var boss : Enemy = kit.spawn_enemy("broodmother")
	await kit.frames(2)
	var time : float = await kit.run_until(func() -> bool: return _count(kit, "egg_sac") > 0, 12.0)
	kit.check(_count(kit, "egg_sac") == 1, "she lays an egg sac (after %.1f s)" % time)
	kit.check(time > 4.0, "not right at the spawn (%.1f s)" % time)
	_set_health_ratio(boss, 0.6)
	_ability(boss, "LayEgg").cooldown_timer.stop()
	kit.check(not _ability(boss, "LayEgg").is_ready, "no eggs below 66% health")


func test_broodmother_digs_up_further_along(kit : TestKit) -> void:
	await kit.load_level(8)
	var boss : Enemy = kit.spawn_enemy("broodmother")
	await kit.run_until(func() -> bool: return boss.has_path and boss.current_waypoint_index > 1, 20.0)
	var remaining : int = boss.get_remaining_path_waypoint_count()
	_set_health_ratio(boss, 0.5)
	await kit.run_until(func() -> bool: return boss.is_burrowed, 3.0)
	kit.check(boss.is_burrowed and not boss.visible, "she burrows and hides")
	kit.check(boss.collider.disabled, "underground nothing touches her")
	await kit.run_until(func() -> bool: return not boss.is_burrowed, 5.0)
	kit.check(not boss.is_burrowed and boss.visible, "she comes up again")
	var after : int = boss.get_remaining_path_waypoint_count()
	kit.check(after < remaining, "closer to the castle (%d -> %d path cells)" % [remaining, after])
	kit.check(_count(kit, "beefling") == 2, "her tunnel sends two beeflings (%d)" % _count(kit, "beefling"))


func test_broodmother_frenzy_and_screech(kit : TestKit) -> void:
	await kit.load_level(8)
	var boss : Enemy = kit.spawn_enemy("broodmother")
	await kit.frames(2)
	var tower_cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)) \
			and kit.level.grid.grid_position_to_world(c).distance_to(boss.global_position) < 48.0)
	var tower : Tower = null
	if tower_cell != Vector2i.MAX:
		tower = await kit.place("puffe_nova", tower_cell)
	var speed : float = boss.stats.get_stat_value(Utils.StatType.Speed)
	_set_health_ratio(boss, 0.3)
	await kit.run_until(func() -> bool: return _count(kit, "batling") > 0, 3.0)
	kit.check(_count(kit, "batling") == 6, "a batling swarm leaves her back (%d)" % _count(kit, "batling"))
	kit.check(boss.stats.get_stat_value(Utils.StatType.Speed) > speed * 1.4, "she speeds up")
	kit.check(tower != null, "a buildable cell near her spawn for the screech test")
	if tower != null:
		kit.check(tower.is_silenced and not tower.has_target, "the screech silences a nearby tower")
		await kit.run_until(func() -> bool: return not tower.is_silenced, 4.0)
		kit.check(not tower.is_silenced, "the silence wears off")
	kit.check(not _ability(boss, "BroodFrenzy").is_ready, "the frenzy comes only once")
