extends RefCounted

## Tower hit effects from the tier steps: splash and freeze (TowerHitEffects).


func _tower(kit : TestKit, tower_name : String) -> Building:
	return await kit.place(tower_name, kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c))))


func _hit(target : Enemy, source : Building, damage : float) -> void:
	var hit : DamageData = DamageData.new()
	hit.damage = damage
	hit.source = source
	target.take_damage(hit)
	hit.free()


func test_splash_hits_the_neighbours_for_half(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await _tower(kit, "puffe_bolter")
	bolter.stats.get_stat(Utils.StatType.SplashRadius).value = 1.0
	var target : Enemy = kit.spawn_enemy("weakling")
	var near : Enemy = kit.spawn_enemy("weakling")
	var far : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	near.global_position = target.global_position + Vector2(8, 0)
	far.global_position = target.global_position + Vector2(64, 0)
	var health : Callable = func(e : Enemy) -> float: return e.stats.get_stat_value(Utils.StatType.Health)
	var near_before : float = health.call(near)
	var far_before : float = health.call(far)
	_hit(target, bolter, 4.0)
	kit.check_near(near_before - health.call(near), 2.0, "the neighbour takes half")
	kit.check_near(far_before - health.call(far), 0.0, "an enemy four tiles off takes nothing")


func test_splash_reaches_flyers_only_from_air_towers(kit : TestKit) -> void:
	await kit.load_level(1)
	var nova : Building = await _tower(kit, "puffe_nova")
	var bolter : Building = await _tower(kit, "puffe_bolter")
	kit.check(not nova.hits_air and bolter.hits_air, "a T1 Nova cannot hit flyers, a Bolter can")
	for tower in [nova, bolter]:
		tower.stats.get_stat(Utils.StatType.SplashRadius).value = 1.0
	var target : Enemy = kit.spawn_enemy("weakling")
	var flyer : Enemy = kit.spawn_enemy("batling")
	await kit.frames(1)
	flyer.global_position = target.global_position + Vector2(8, 0)
	var before : float = flyer.stats.get_stat_value(Utils.StatType.Health)
	_hit(target, nova, 0.2)
	kit.check_near(flyer.stats.get_stat_value(Utils.StatType.Health), before, "the Nova's splash passes under the flyer")
	_hit(target, bolter, 0.2)
	kit.check_near(flyer.stats.get_stat_value(Utils.StatType.Health), before - 0.1, "the Bolter's splash hits it")


func test_freeze_stops_and_bosses_never_freeze(kit : TestKit) -> void:
	await kit.load_level(12)
	var nova : Building = await _tower(kit, "puffe_nova")
	nova.stats.get_stat(Utils.StatType.FreezeChance).value = 1.0
	nova.stats.get_stat(Utils.StatType.FreezeDuration).value = 1.0
	var enemy : Enemy = kit.spawn_enemy("weakling")
	var boss : Enemy = kit.spawn_enemy("broodmother")
	await kit.frames(2)
	_hit(enemy, nova, 1.0)
	_hit(boss, nova, 1.0)
	kit.check(enemy.is_frozen, "the hit freezes it")
	kit.check(not boss.is_frozen, "the Broodmother shrugs it off")
	var at : Vector2 = enemy.global_position
	await kit.run_until(func() -> bool: return false, 0.5)
	kit.check(enemy.global_position.distance_to(at) < 1.0, "a frozen enemy does not move")
	await kit.run_until(func() -> bool: return not enemy.is_frozen, 2.0)
	kit.check(not enemy.is_frozen, "and thaws")


func test_knockback_pushes_back_along_the_path(kit : TestKit) -> void:
	await kit.load_level(1)
	var nova : Building = await _tower(kit, "puffe_nova")
	nova.stats.get_stat(Utils.StatType.Knockback).value = 2.0
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.run_until(func() -> bool: return enemy.current_waypoint_index >= 4, 20.0)
	var index : int = enemy.current_waypoint_index
	_hit(enemy, nova, 1.0)
	kit.check(enemy.current_waypoint_index == index - 2, "two cells back (%d -> %d)" % [index, enemy.current_waypoint_index])


func test_ground_patch_hurts_those_inside(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await _tower(kit, "puffe_bolter")
	bolter.stats.get_stat(Utils.StatType.PatchDuration).value = 2.0
	bolter.stats.get_stat(Utils.StatType.PatchShare).value = 0.5
	var target : Enemy = kit.spawn_enemy("beefling")
	var inside : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	for enemy in [target, inside]:
		enemy.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		enemy.freeze = true
		enemy.resistances = null
	inside.global_position = target.global_position + Vector2(4, 0)
	_hit(target, bolter, 10.0)
	var health : float = inside.stats.get_stat_value(Utils.StatType.Health)
	await kit.run_until(func() -> bool: return false, 1.2)
	kit.check(inside.stats.get_stat_value(Utils.StatType.Health) < health, "an enemy on the patch takes damage over time")


func test_split_shards_hit_the_nearest(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await _tower(kit, "puffe_bolter")
	bolter.stats.get_stat(Utils.StatType.SplitCount).value = 1.0
	bolter.stats.get_stat(Utils.StatType.SplitShare).value = 0.5
	var target : Enemy = kit.spawn_enemy("beefling")
	var near : Enemy = kit.spawn_enemy("beefling")
	var farther : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	for enemy in [target, near, farther]:
		enemy.resistances = null
	near.global_position = target.global_position + Vector2(8, 0)
	farther.global_position = target.global_position + Vector2(20, 0)
	var health : Callable = func(e : Enemy) -> float: return e.stats.get_stat_value(Utils.StatType.Health)
	var near_before : float = health.call(near)
	var farther_before : float = health.call(farther)
	_hit(target, bolter, 10.0)
	kit.check_near(near_before - health.call(near), 5.0, "one shard: the nearest takes half")
	kit.check_near(farther_before - health.call(farther), 0.0, "the next one takes nothing")


func test_beam_line_hits(kit : TestKit) -> void:
	await kit.load_level(1)
	var beamer : Building = await _tower(kit, "puffe_beamer")
	beamer.stats.get_stat(Utils.StatType.LineHits).value = 1.0
	var target : Enemy = kit.spawn_enemy("beefling")
	var between : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	for enemy in [target, between]:
		enemy.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		enemy.freeze = true
	target.global_position = beamer.global_position + Vector2(40, 0)
	between.global_position = beamer.global_position + Vector2(20, 0) - (between.body_center - between.global_position)
	beamer.skill.target = target
	var before : float = between.stats.get_stat_value(Utils.StatType.Health)
	beamer.skill._hit_target()
	kit.check(between.stats.get_stat_value(Utils.StatType.Health) < before, "the enemy on the beam's line is hit too")


func test_poison_spreads_on_death(kit : TestKit) -> void:
	await kit.load_level(1)
	var beamer : Building = await _tower(kit, "puffe_beamer")
	var leaf : ElementEvolveLeaf = beamer.evolve_tree.get_node_or_null(^"EvolveBranch4/PoisonElementEvolveLeaf")
	if leaf == null:
		for node in beamer.evolve_tree.find_children("*", "", true):
			if node is ElementEvolveLeaf and node.name.begins_with("Poison"):
				leaf = node
	leaf.evolve(beamer)
	beamer.stats.get_stat(Utils.StatType.PoisonSpread).value = 1.0
	var target : Enemy = kit.spawn_enemy("weakling")
	var near : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	near.global_position = target.global_position + Vector2(8, 0)
	var poisoned_hit : DamageData = beamer.skill.damage_data
	target.take_damage(poisoned_hit)
	poisoned_hit.queue_free()
	kit.check(not target.overtime_effect_handler.get_active_stacks(Utils.DamageType.Poison).is_empty(), "the target is poisoned")
	_hit(target, beamer, 9999.0)
	kit.check(not near.overtime_effect_handler.get_active_stacks(Utils.DamageType.Poison).is_empty(), "its death poisons the enemy next to it")


func test_a_direct_hit_flinches_a_pixel_and_ticks_do_not(kit : TestKit) -> void:
	await kit.load_level(1)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	var sprite : AnimationControl = enemy.animation_control
	var tick : DamageData = DamageData.new()
	tick.damage = 0.1
	tick.is_overtime = true
	enemy.take_damage(tick)
	tick.free()
	kit.check(sprite.flinch_left <= 0.0, "a burn or poison tick does not flinch")
	_hit(enemy, null, 0.1)
	kit.check(sprite.flinch_left > 0.0, "a direct hit flinches")
	await kit.frames(1)
	#the pixel snap alone moves the sprite less than half a pixel; the flinch adds a whole one
	kit.check(absf(sprite.position.x - sprite.pixel_snap_position.x) > 0.5, "the sprite sits a pixel back")
	sprite.flinch_left = 0.0
	_hit(enemy, null, 0.1)
	kit.check(sprite.flinch_left <= 0.0, "a second hit inside the cooldown does not flinch again (beams would shake it)")
	await kit.run_until(func() -> bool: return false, sprite.flinch_cooldown + 0.1)
	kit.check(absf(sprite.position.x - sprite.pixel_snap_position.x) <= 0.51, "and it is back in place")
