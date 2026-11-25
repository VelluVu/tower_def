extends RefCounted

## The Mortar (2026-11-24): an artillery tower whose shell bursts on every ground enemy around where it lands, with
## falloff, a minimum range, no flyers.


func _place_mortar(kit : TestKit) -> Tower:
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))
	return await kit.place("puffe_mortar", cell)


func _tough(kit : TestKit, enemy_name : String) -> Enemy:
	var enemy : Enemy = kit.spawn_enemy(enemy_name)
	await kit.frames(1)
	for stat_type in [Utils.StatType.MaxHealth, Utils.StatType.Health]:
		enemy.stats.get_stat(stat_type).value = 1000.0
	return enemy


func _lost(enemy : Enemy) -> float:
	return 1000.0 - enemy.stats.get_stat_value(Utils.StatType.Health)


func test_mortar_is_artillery(kit : TestKit) -> void:
	await kit.load_level(1)
	var mortar : Tower = await _place_mortar(kit)
	kit.check(mortar.skill.skill_type == Utils.SkillType.Artillery, "the Mortar's skill is artillery")
	kit.check(mortar.can_choose_target, "the Mortar picks its target by tactic")
	kit.check(not mortar.hits_air, "the Mortar never hits flyers")
	kit.check(mortar.min_range_tiles > 0.0, "the Mortar has a minimum range")
	kit.check(TalentEffect.get_building_flag(mortar) == TalentEffect.MORTAR, "talents see it as a Mortar")
	kit.check(mortar.evolve_tree.upgrade_data != null, "it has its upgrade data")
	var list : BuildingListElement = load("res://scenes/unit/building/buildings/puffe_mortar.tres")
	kit.check(list.unlock_level == 13 and not list.is_unlocked(12) and list.is_unlocked(13), "it unlocks on level 13")


func test_falloff(kit : TestKit) -> void:
	kit.check_near(MortarShell.get_falloff_share(0.0, 16.0), 1.0, "the full hit at the centre")
	kit.check_near(MortarShell.get_falloff_share(16.0, 16.0), MortarShell.MIN_EDGE_SHARE, "the edge share at the edge")
	kit.check_near(MortarShell.get_falloff_share(8.0, 16.0), lerpf(1.0, MortarShell.MIN_EDGE_SHARE, 0.5), "halfway between")
	kit.check_near(MortarShell.get_falloff_share(40.0, 16.0), MortarShell.MIN_EDGE_SHARE, "never less than the edge share")


func test_blast_hits_ground_enemies_around_it(kit : TestKit) -> void:
	await kit.load_level(1)
	var mortar : Tower = await _place_mortar(kit)
	var centre : Enemy = await _tough(kit, "weakling")
	var edge : Enemy = await _tough(kit, "weakling")
	var outside : Enemy = await _tough(kit, "weakling")
	var flyer : Enemy = await _tough(kit, "batling")
	var at : Vector2 = kit.level.grid.grid_position_to_world(kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_walkable(kit.level.grid.grid_position_to_world(c))))
	var radius : float = MortarShell.get_blast_radius(mortar)
	centre.global_position = at
	edge.global_position = at + Vector2(radius * 0.9, 0.0)
	outside.global_position = at + Vector2(radius * 2.0, 0.0)
	flyer.global_position = at + Vector2(0.0, 2.0)

	var hit : DamageData = mortar.skill.damage_data
	hit.is_critical = false
	hit.damage = 20.0
	var victims : Array[Enemy] = MortarShell.blast(hit, at, radius)
	hit.free()

	kit.check(victims.size() == 2 and victims[0] == centre and victims[1] == edge, "the centre and edge enemies, nearest first (%d)" % victims.size())
	kit.check(_lost(centre) > 0.0 and _lost(edge) > 0.0, "both took damage")
	kit.check(_lost(edge) < _lost(centre), "the edge takes less than the centre (%.1f < %.1f)" % [_lost(edge), _lost(centre)])
	kit.check_near(_lost(edge) / _lost(centre), MortarShell.get_falloff_share(radius * 0.9, radius), "the falloff share", 0.05)
	kit.check(_lost(outside) == 0.0, "an enemy outside the blast is untouched")
	kit.check(_lost(flyer) == 0.0, "a flyer over the blast is untouched")


func test_splash_radius_widens_the_blast(kit : TestKit) -> void:
	await kit.load_level(1)
	var mortar : Tower = await _place_mortar(kit)
	var before : float = MortarShell.get_blast_radius(mortar)
	mortar.stats.get_stat(Utils.StatType.SplashRadius).value = 0.5
	kit.check_near(MortarShell.get_blast_radius(mortar), before + 0.5 * Utils.TILE_SIZE, "SplashRadius adds to the blast")


func test_minimum_range(kit : TestKit) -> void:
	await kit.load_level(1)
	var mortar : Tower = await _place_mortar(kit)
	var near : Enemy = await _tough(kit, "weakling")
	var far : Enemy = await _tough(kit, "weakling")
	near.global_position = mortar.global_position + Vector2(mortar.min_range_tiles * Utils.TILE_SIZE * 0.5, 0.0)
	far.global_position = mortar.global_position + Vector2(mortar.min_range_tiles * Utils.TILE_SIZE + 8.0, 0.0)
	mortar.targets.clear()
	mortar.targets.append(near)
	kit.check(mortar.get_tactic_target() == null, "an enemy at its feet is out of reach")
	mortar.targets.append(far)
	mortar.target_tactic = Utils.TargetTactic.Closest
	kit.check(mortar.get_tactic_target() == far, "it fires at the one beyond its minimum range")


func test_shell_leads_its_target(kit : TestKit) -> void:
	await kit.load_level(1)
	var enemy : Enemy = await _tough(kit, "weakling")
	enemy.linear_velocity = Vector2(10.0, 0.0) * Utils.game_control.time_scale
	var aim : Vector2 = MortarShell.get_landing_position(enemy, Vector2.ZERO)
	kit.check_near(aim.x - enemy.global_position.x, 10.0 * MortarShell.FLIGHT_SECONDS, "it aims where the enemy walks to", 0.1)
	enemy.linear_velocity = Vector2(1000.0, 0.0) * Utils.game_control.time_scale
	aim = MortarShell.get_landing_position(enemy, Vector2.ZERO)
	kit.check(aim.distance_to(enemy.global_position) <= MortarShell.MAX_LEAD_TILES * Utils.TILE_SIZE + 0.01, "the lead is capped")
	enemy.freeze_for(1.0)
	kit.check(MortarShell.get_landing_position(enemy, Vector2.ZERO) == enemy.global_position, "a frozen enemy is not led")
