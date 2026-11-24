extends RefCounted

## The Broodmother's phases and her egg sacs, the Bog Hydra's spit and dive.


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
	await kit.load_level(12)
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
	await kit.load_level(12)
	var egg : Enemy = kit.spawn_enemy("egg_sac")
	await kit.frames(2)
	var gold : float = kit.level.player_stats.gold
	_set_health_ratio(egg, 0.0)
	await kit.run_until(func() -> bool: return egg.is_deactivated, 1.0)
	await kit.run_until(func() -> bool: return false, 7.0)
	kit.check(_count(kit, "swarmling") == 0, "a popped sac hatches nothing")
	kit.check(kit.level.player_stats.gold > gold, "popping it gives its gold")


func test_broodmother_lays_eggs(kit : TestKit) -> void:
	await kit.load_level(12)
	var boss : Enemy = kit.spawn_enemy("broodmother")
	await kit.frames(2)
	var time : float = await kit.run_until(func() -> bool: return _count(kit, "egg_sac") > 0, 12.0)
	kit.check(_count(kit, "egg_sac") == 1, "she lays an egg sac (after %.1f s)" % time)
	kit.check(time > 4.0, "not right at the spawn (%.1f s)" % time)
	_set_health_ratio(boss, 0.6)
	_ability(boss, "LayEgg").cooldown_timer.stop()
	kit.check(not _ability(boss, "LayEgg").is_ready, "no eggs below 66% health")


func test_broodmother_digs_up_further_along(kit : TestKit) -> void:
	await kit.load_level(12)
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


## Dig Up comes up where the fewest towers reach, so one cluster of towers gets dug past (2026-11-20).
func test_broodmother_digs_past_a_tower_cluster(kit : TestKit) -> void:
	await kit.load_level(12)
	var boss : Enemy = kit.spawn_enemy("broodmother")
	await kit.run_until(func() -> bool: return boss.has_path and boss.current_waypoint_index > 1, 20.0)
	var dig : BurrowAbility = _ability(boss, "DigUp")
	kit.check(dig.seeks_weak_spot, "her Dig Up seeks the weak spot")
	#a Bolter beside the path a few cells ahead of her
	var grid : LevelGrid = kit.level.grid
	var guarded : Vector2 = boss.point_path[mini(boss.current_waypoint_index + dig.min_cells_ahead + 1, boss.point_path.size() - 1)]
	var tower_cell : Vector2i = Vector2i.MAX
	for neighbour in grid.get_surrounding_cells(grid.world_position_to_grid(guarded)):
		if grid.is_position_buildable(grid.grid_position_to_world(neighbour)) and not boss.point_path.has(grid.grid_position_to_world(neighbour)):
			tower_cell = neighbour
			break
	kit.check(tower_cell != Vector2i.MAX, "a buildable cell beside her path")
	await kit.place("puffe_bolter", tower_cell)
	await kit.frames(2)
	var towers : Array[Tower] = []
	for building in kit.level.all_buildings:
		if building is Tower:
			towers.append(building)
	var spot : Vector2 = dig._get_weak_spot()
	var at_spot : int = BurrowAbility.count_towers_reaching(towers, spot)
	kit.check(BurrowAbility.count_towers_reaching(towers, guarded) == 1, "the Bolter reaches the guarded cell")
	kit.check(at_spot == 0, "she comes up where no tower reaches (%d towers there)" % at_spot)


func test_bog_hydra_submerges_and_sends_leeches(kit : TestKit) -> void:
	await kit.load_level(24)
	var boss : Enemy = kit.spawn_enemy("bog_hydra")
	await kit.run_until(func() -> bool: return boss.has_path and boss.current_waypoint_index > 1, 20.0)
	var remaining : int = boss.get_remaining_path_waypoint_count()
	_set_health_ratio(boss, 0.5)
	await kit.run_until(func() -> bool: return boss.is_burrowed, 3.0)
	kit.check(boss.is_burrowed, "it sinks into the bog")
	await kit.run_until(func() -> bool: return not boss.is_burrowed, 5.0)
	kit.check(not boss.is_burrowed and boss.visible, "it comes up again")
	kit.check(boss.get_remaining_path_waypoint_count() < remaining, "closer to the castle")
	kit.check(_count(kit, "leechling") == 4, "four leeches come up with it (%d)" % _count(kit, "leechling"))


func test_bog_hydra_spits_at_the_farthest_tower(kit : TestKit) -> void:
	await kit.load_level(24)
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var far_cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		var world : Vector2 = kit.level.grid.grid_position_to_world(c)
		var tiles : float = world.distance_to(spawn) / Utils.TILE_SIZE
		return kit.level.grid.is_position_buildable(world) and tiles >= 3.5 and tiles <= 4.5)
	kit.check(far_cell != Vector2i.MAX, "a cell 4 tiles from the spawn")
	var tower : Building = await kit.place("puffe_beamer", far_cell)
	var boss : Enemy = kit.spawn_enemy("bog_hydra")
	var spit : EnemyAbility = _ability(boss, "BogSpit")
	await kit.run_until(func() -> bool: return spit.use_count > 0 and not spit.is_active, 12.0)
	await kit.run_until(func() -> bool: return not is_instance_valid(tower) or tower.stats.get_stat_value(Utils.StatType.Health) < 10.0, 4.0)
	kit.check(spit.use_count > 0, "it spits")
	kit.check(not is_instance_valid(tower) or tower.stats.get_stat_value(Utils.StatType.Health) < 10.0, "the acid hits a tower out of the heads' reach")


func test_bog_hydra_heads_frenzy_when_low(kit : TestKit) -> void:
	await kit.load_level(24)
	var boss : Enemy = kit.spawn_enemy("bog_hydra")
	_set_health_ratio(boss, 0.2)
	kit.check(not _ability(boss, "HeadStrike").is_ready and not _ability(boss, "BogSpit").is_ready, "no calm strikes or spit under a third")
	kit.check(_ability(boss, "FrenziedHeads").cooldown < _ability(boss, "HeadStrike").cooldown, "the frenzied heads strike faster")


func test_broodmother_frenzy_and_screech(kit : TestKit) -> void:
	await kit.load_level(12)
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


func _blood_splats(kit : TestKit) -> Array[BloodSplat]:
	var splats : Array[BloodSplat] = []
	for child in kit.level.get_children():
		if child is BloodSplat and child.is_draw:
			splats.append(child)
	return splats


func test_broodmother_dies_in_a_pool_of_blood(kit : TestKit) -> void:
	await kit.load_level(12)
	var boss : Enemy = kit.spawn_enemy("broodmother")
	await kit.frames(2)
	var bursts : int = boss.gore_emitter.death_bursts
	boss.die()
	await kit.run_until(func() -> bool: return _blood_splats(kit).size() >= bursts, 5.0)
	var splats : Array[BloodSplat] = _blood_splats(kit)
	kit.check(splats.size() >= bursts, "a splat per death burst: %d of %d" % [splats.size(), bursts])
	var spread : float = 0.0
	for splat in splats:
		spread = maxf(spread, absf(splat.global_position.x - boss.global_position.x))
	kit.check(spread > Utils.TILE_SIZE * 0.5, "the splats spread around her (%.0f px)" % spread)
	var corpse : WeakRef = weakref(boss)
	await kit.run_until(func() -> bool: return corpse.get_ref() == null, 10.0)
	kit.check(corpse.get_ref() == null, "the corpse still goes once the gore is done")
