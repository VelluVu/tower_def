extends RefCounted

## The Harpooner (2026-11-24): every harpoon tethers its target (HarpoonTether: slowed for a while, the chain drawn to
## the tower), drags a flyer down to walk the maze (a boss flyer is only held for a moment), and aims at flyers first.


func _place_harpooner(kit : TestKit) -> Tower:
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))
	return await kit.place("puffe_harpooner", cell)


func _enemy(kit : TestKit, scene_name : String, health : float) -> Enemy:
	var enemy : Enemy = kit.spawn_enemy(scene_name)
	await kit.frames(1)
	for stat_type in [Utils.StatType.MaxHealth, Utils.StatType.Health]:
		enemy.stats.get_stat(stat_type).value = health
	return enemy


func _harpoon(harpooner : Tower, enemy : Enemy, damage_type : Utils.DamageType = Utils.DamageType.Physical) -> void:
	var hit : DamageData = DamageData.new()
	hit.source = harpooner
	hit.damage_type = damage_type
	hit.damage = 1.0
	enemy.take_damage(hit)
	hit.free()


func test_harpooner_basics(kit : TestKit) -> void:
	await kit.load_level(1)
	var harpooner : Tower = await _place_harpooner(kit)
	kit.check(harpooner.skill.skill_type == Utils.SkillType.Harpoon, "the Harpooner throws harpoons")
	kit.check(harpooner.can_choose_target, "it aims by tactic")
	kit.check(harpooner.target_tactic == Utils.TargetTactic.Flyers, "it aims at flyers by default")
	kit.check(TalentEffect.get_building_flag(harpooner) == TalentEffect.HARPOONER, "talents see it as a Harpooner")
	kit.check_near(harpooner.stats.get_stat_value(Utils.StatType.TetherTime), 2.0, "a 2 s tether")
	kit.check_near(harpooner.stats.get_stat_value(Utils.StatType.TetherSlow), 0.5, "at half speed")
	var list : BuildingListElement = load("res://scenes/unit/building/buildings/puffe_harpooner.tres")
	kit.check(list.unlock_level == 37 and not list.is_unlocked(36) and list.is_unlocked(37), "it unlocks on level 37")


func test_flyers_tactic(kit : TestKit) -> void:
	await kit.load_level(6)
	var walker : Enemy = await _enemy(kit, "weakling", 10.0)
	var flyer : Enemy = await _enemy(kit, "batling", 10.0)
	kit.check(flyer.is_flying and not walker.is_flying, "a flyer and a walker")
	var candidates : Array[Node2D] = [walker, flyer]
	kit.check(TargetPicker.pick(Utils.TargetTactic.Flyers, candidates, Vector2.ZERO) == flyer, "the flyer first")
	candidates = [walker]
	kit.check(TargetPicker.pick(Utils.TargetTactic.Flyers, candidates, Vector2.ZERO) == walker, "a walker when no flyer is in range")
	kit.check(TargetPicker.MENU_ORDER.has(Utils.TargetTactic.Flyers), "the Target menu offers it")


func test_tether_slows_then_lets_go(kit : TestKit) -> void:
	await kit.load_level(1)
	var harpooner : Tower = await _place_harpooner(kit)
	var enemy : Enemy = await _enemy(kit, "weakling", 1000.0)
	var speed : float = enemy.stats.get_stat_value(Utils.StatType.Speed)
	_harpoon(harpooner, enemy)
	var tether : HarpoonTether = enemy.get_node_or_null(NodePath(HarpoonTether.NODE_NAME)) as HarpoonTether
	kit.check(tether != null and tether.is_tethered(), "a direct hit tethers")
	kit.check_near(enemy.stats.get_stat_value(Utils.StatType.Speed), speed * 0.5, "at half speed")
	await kit.run_until(func() -> bool: return not tether.is_tethered(), 4.0)
	kit.check(not tether.is_tethered(), "the tether runs out")
	kit.check_near(enemy.stats.get_stat_value(Utils.StatType.Speed), speed, "and the speed comes back")


func test_flyer_dragged_down(kit : TestKit) -> void:
	await kit.load_level(6)
	var harpooner : Tower = await _place_harpooner(kit)
	var flyer : Enemy = await _enemy(kit, "batling", 1000.0)
	_harpoon(harpooner, flyer)
	kit.check(not flyer.is_flying, "a harpooned flyer lands")
	kit.check(not flyer.point_path.is_empty(), "and walks a ground path")
	kit.check(flyer.walk_animation == GlobalAnimationNames.WALK_ANIMATION, "with its own walk")
	harpooner.evolve_tree.evolve_element = Utils.Element.Poison
	var rotten : Enemy = await _enemy(kit, "batling", 1000.0)
	_harpoon(harpooner, rotten, Utils.DamageType.Poison)
	kit.check_near(EnemyMarks.get_bonus(rotten, Utils.DamageType.Fire), HarpoonTether.ROT_SHARE, "a Poison harpoon rots a grounded flyer's armour")
	harpooner.evolve_tree.evolve_element = Utils.Element.Frost
	var chilled : Enemy = await _enemy(kit, "batling", 1000.0)
	_harpoon(harpooner, chilled, Utils.DamageType.Frost)
	kit.check(chilled.is_frozen, "a Frost harpoon freezes a grounded flyer")


func test_boss_flyer_held(kit : TestKit) -> void:
	await kit.load_level(6)
	var harpooner : Tower = await _place_harpooner(kit)
	var boss : Enemy = await _enemy(kit, "batling", 1000.0)
	boss.is_boss = true
	_harpoon(harpooner, boss)
	kit.check(boss.is_flying, "a boss flyer stays a flyer")
	kit.check(boss.is_held, "but is held")
	await kit.run_until(func() -> bool: return not boss.is_held, HarpoonTether.BOSS_HOLD_SECONDS + 1.0)
	kit.check(not boss.is_held, "and lets go after the hold")
	_harpoon(harpooner, boss)
	kit.check(not boss.is_held, "not again before the cooldown")
