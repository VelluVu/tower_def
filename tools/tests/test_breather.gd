extends RefCounted

## The Breather (2026-11-24): gusts that hit every enemy in a cone 4 times; only an enemy's first hit of a gust is a
## direct hit; the ConeWidth stat widens the cone; a patch gust leaves one patch in the cone.


func _place_breather(kit : TestKit) -> Tower:
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))
	return await kit.place("puffe_breather", cell)


func _tough(kit : TestKit, enemy_name : String, at : Vector2) -> Enemy:
	var enemy : Enemy = kit.spawn_enemy(enemy_name)
	await kit.frames(1)
	for stat_type in [Utils.StatType.MaxHealth, Utils.StatType.Health]:
		enemy.stats.get_stat(stat_type).value = 1000.0
	enemy.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	enemy.freeze = true
	enemy.global_position = at
	return enemy


func _lost(enemy : Enemy) -> float:
	return 1000.0 - enemy.stats.get_stat_value(Utils.StatType.Health)


func test_breather_basics(kit : TestKit) -> void:
	await kit.load_level(1)
	var breather : Tower = await _place_breather(kit)
	kit.check(breather.skill is Breath and breather.skill.skill_type == Utils.SkillType.Breath, "the Breather breathes")
	kit.check(breather.can_choose_target, "it aims by tactic")
	kit.check(breather.hits_air, "its breath reaches flyers")
	kit.check(TalentEffect.get_building_flag(breather) == TalentEffect.BREATHER, "talents see it as a Breather")
	kit.check(breather.stats.get_stat(Utils.StatType.ConeWidth) != null, "it has the cone width stat")
	kit.check(breather.evolve_tree.upgrade_data != null, "it has its upgrade data")
	kit.check(breather.skill.projectile_scene != null, "it has its puffs")
	var list : BuildingListElement = load("res://scenes/unit/building/buildings/puffe_breather.tres")
	kit.check(list.unlock_level == 19 and not list.is_unlocked(18) and list.is_unlocked(19), "it unlocks on level 19")


func test_cone_hits_what_is_in_front(kit : TestKit) -> void:
	await kit.load_level(1)
	var breather : Tower = await _place_breather(kit)
	var breath : Breath = breather.skill
	var origin : Vector2 = breather.global_position
	var reach : float = breath.get_reach()
	breath.direction = Vector2.RIGHT
	var front : Enemy = await _tough(kit, "weakling", origin + Vector2(reach * 0.6, 0.0))
	var edge : Enemy = await _tough(kit, "weakling", origin + Vector2.RIGHT.rotated(deg_to_rad(25.0)) * reach * 0.7)
	var side : Enemy = await _tough(kit, "weakling", origin + Vector2.RIGHT.rotated(deg_to_rad(50.0)) * reach * 0.7)
	var behind : Enemy = await _tough(kit, "weakling", origin + Vector2(-reach * 0.6, 0.0))
	var far : Enemy = await _tough(kit, "weakling", origin + Vector2(reach * 1.5, 0.0))

	breath.ticks_left = Breath.GUST_TICKS
	breath._tick()
	kit.check(_lost(front) > 0.0 and _lost(edge) > 0.0, "the enemies in the cone are hit")
	kit.check(_lost(side) == 0.0 and _lost(behind) == 0.0 and _lost(far) == 0.0, "outside the cone nothing is hit")

	breather.stats.get_stat(Utils.StatType.ConeWidth).value = 60.0
	kit.check(breath.is_in_cone(side), "a wider cone takes the enemy at 50 degrees in")
	kit.check(not breath.is_in_cone(behind), "but not the one behind")
	breath._end_gust()


func test_one_direct_hit_per_gust(kit : TestKit) -> void:
	await kit.load_level(1)
	var breather : Tower = await _place_breather(kit)
	var breath : Breath = breather.skill
	breath.direction = Vector2.RIGHT
	var enemy : Enemy = await _tough(kit, "weakling", breather.global_position + Vector2(breath.get_reach() * 0.5, 0.0))
	var splashes : Array[bool] = []
	var record : Callable = func(hit_enemy : Enemy, damage_data : DamageData) -> void:
		if hit_enemy == enemy:
			splashes.append(damage_data.is_splash)
	GameSignals.enemy_hit.connect(record)
	breath.ticks_left = Breath.GUST_TICKS
	for i in Breath.GUST_TICKS:
		breath._tick()
	GameSignals.enemy_hit.disconnect(record)
	kit.check(splashes.size() == Breath.GUST_TICKS, "every tick hits it (%d)" % splashes.size())
	kit.check(not splashes.is_empty() and not splashes[0] and not splashes.slice(1).has(false), "only the first hit is direct")
	breath._end_gust()


func test_patch_gust_leaves_one_patch(kit : TestKit) -> void:
	await kit.load_level(1)
	var breather : Tower = await _place_breather(kit)
	var breath : Breath = breather.skill
	breath.direction = Vector2.RIGHT
	for i in 3:
		await _tough(kit, "weakling", breather.global_position + Vector2(breath.get_reach() * 0.5, i * 3.0))
	breather.stats.get_stat(Utils.StatType.PatchDuration).value = 2.0
	breather.stats.get_stat(Utils.StatType.PatchShare).value = 0.2
	var before : int = kit.level.get_children().filter(func(node) -> bool: return node is GroundPatch).size()
	breath._drop_patch()
	breath.ticks_left = Breath.GUST_TICKS
	breath._tick()
	var after : int = kit.level.get_children().filter(func(node) -> bool: return node is GroundPatch).size()
	kit.check(after - before == 1, "one patch for the gust, not one per enemy (%d)" % (after - before))
	breath._end_gust()


func test_gust_runs_and_ends(kit : TestKit) -> void:
	await kit.load_level(1)
	var breather : Tower = await _place_breather(kit)
	var breath : Breath = breather.skill
	var enemy : Enemy = await _tough(kit, "weakling", breather.global_position + Vector2(breath.get_reach() * 0.5, 0.0))
	breather.targets.append(enemy)
	breath.target = enemy
	breath.activate()
	kit.check(breath.is_breathing, "the gust starts")
	await kit.run_until(func() -> bool: return not breath.is_breathing, 3.0)
	kit.check(not breath.is_breathing, "the gust ends by itself")
	kit.check_near(_lost(enemy), breath.stats.get_stat_value(Utils.StatType.Damage) * Breath.GUST_TICKS, "four hits a gust", 0.5 * Breath.GUST_TICKS * breath.stats.get_stat_value(Utils.StatType.Damage))
