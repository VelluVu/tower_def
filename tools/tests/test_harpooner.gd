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
	kit.check(list.unlock_level == 19 and not list.is_unlocked(18) and list.is_unlocked(19), "it unlocks on level 19")


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


#the user (2026-11-26): the Harpooner can slow the ground instead, flyers stay its default
func test_ground_tactic(kit : TestKit) -> void:
	await kit.load_level(6)
	var walker : Enemy = await _enemy(kit, "weakling", 10.0)
	var flyer : Enemy = await _enemy(kit, "batling", 10.0)
	var candidates : Array[Node2D] = [flyer, walker]
	kit.check(TargetPicker.pick(Utils.TargetTactic.Ground, candidates, Vector2.ZERO) == walker, "the walker first")
	candidates = [flyer]
	kit.check(TargetPicker.pick(Utils.TargetTactic.Ground, candidates, Vector2.ZERO) == flyer, "a flyer when no walker is in range")
	kit.check(TargetPicker.MENU_ORDER.has(Utils.TargetTactic.Ground), "the Target menu offers it")


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
	var speed : float = flyer.stats.get_stat_value(Utils.StatType.Speed)
	_harpoon(harpooner, flyer)
	kit.check(not flyer.is_flying, "a harpooned flyer lands")
	kit.check(not flyer.point_path.is_empty(), "and walks a ground path")
	kit.check(flyer.walk_animation == GlobalAnimationNames.WALK_ANIMATION, "with its own walk")
	#the crash (the user, 2026-11-26): stunned a couple of seconds, no ice tint, then slow on its feet for good
	kit.check(flyer.is_frozen and flyer.animation_control.self_modulate != Enemy.FROZEN_TINT, "it lies stunned where it lands")
	await kit.run_until(func() -> bool: return not flyer.is_frozen, HarpoonTether.GROUNDED_STUN_SECONDS + 1.0)
	kit.check(not flyer.is_frozen, "and gets up")
	var tether : HarpoonTether = flyer.get_node_or_null(NodePath(HarpoonTether.NODE_NAME)) as HarpoonTether
	await kit.run_until(func() -> bool: return tether == null or not tether.is_tethered(), 4.0)
	kit.check_near(flyer.stats.get_stat_value(Utils.StatType.Speed), speed * HarpoonTether.GROUNDED_SPEED_SHARE, "then walks slowly after the chain lets go")
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


#a flyer dragged down over the maze landed inside a wall and broke it to get out (2026-11-26 bot check): it lands on
#the nearest cell with no building
func test_a_grounded_flyer_lands_beside_a_wall(kit : TestKit) -> void:
	await kit.load_level(6)
	var grid : LevelGrid = kit.level.grid
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool: return grid.is_cell_walkable(c) and grid.is_position_buildable(grid.grid_position_to_world(c)))
	var wall : Building = await kit.place("wall", cell)
	var flyer : Enemy = await _enemy(kit, "batling", 100.0)
	flyer.global_position = grid.grid_position_to_world(cell)
	LandAbility.land(flyer)
	await kit.frames(3)
	kit.check(not flyer.is_flying, "it is on the ground")
	kit.check(flyer.grid_position != cell and grid.is_cell_free_to_walk(flyer.grid_position), "beside the wall, on a free cell (%s)" % flyer.grid_position)
	kit.check(is_instance_valid(wall) and not wall.is_dead, "and the wall still stands")


#several Harpooners on one target were wasted throws (the user, 2026-11-26): a chained enemy, or one a harpoon flies at,
#is taken only when no other is in reach
func test_harpooners_spread_their_chains(kit : TestKit) -> void:
	await kit.load_level(1)
	var harpooner : Tower = await _place_harpooner(kit)
	var chained : Enemy = await _enemy(kit, "weakling", 1000.0)
	var free : Enemy = await _enemy(kit, "weakling", 1000.0)
	var aimed : Enemy = await _enemy(kit, "weakling", 1000.0)
	HarpoonTether.attach(chained, harpooner, 2.0, 0.5)
	var candidates : Array[Node2D] = [chained, free]
	kit.check(TargetPicker.pick(Utils.TargetTactic.First, candidates, Vector2.ZERO, false, true) == free, "the free enemy before the chained one")
	candidates = [chained]
	kit.check(TargetPicker.pick(Utils.TargetTactic.First, candidates, Vector2.ZERO, false, true) == chained, "the chained one when it is alone")
	var harpoon : HomingBolt = load("res://scenes/unit/skills/projectiles/physical_harpoon.tscn").instantiate()
	harpoon.skill_data = SkillData.new()
	harpoon.skill_data.target = aimed
	HarpoonTether.claim(aimed, harpoon)
	candidates = [aimed, free]
	kit.check(HarpoonTether.is_taken(aimed), "a harpoon on its way claims its target")
	kit.check(TargetPicker.pick(Utils.TargetTactic.First, candidates, Vector2.ZERO, false, true) == free, "so another Harpooner aims elsewhere")
	harpoon.free()
	kit.check(not HarpoonTether.is_taken(aimed), "and the claim ends with the harpoon")


#a grounded giant eagle came down in a pocket the maze walled in and broke a wall to get out (2026-11-26 bot check): it
#lands where it can walk to the castle
func test_a_grounded_flyer_lands_outside_a_walled_pocket(kit : TestKit) -> void:
	await kit.load_level(6)
	var grid : LevelGrid = kit.level.grid
	var castle : Vector2 = kit.level.end_point.global_position
	var open : Callable = func(c : Vector2i) -> bool: return grid.is_cell_walkable(c) and grid.is_position_buildable(grid.grid_position_to_world(c))
	var pocket : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		if not grid.has_clear_route(c, castle):
			return false
		for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not open.call(c + side):
				return false
		return true)
	var walls : Array[Building] = []
	for side in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		walls.append(await kit.place("wall", pocket + side))
	kit.check(not grid.has_clear_route(pocket, castle), "the pocket is walled in")
	var flyer : Enemy = await _enemy(kit, "batling", 100.0)
	flyer.global_position = grid.grid_position_to_world(pocket)
	LandAbility.land(flyer)
	await kit.frames(3)
	kit.check(flyer.grid_position != pocket and grid.has_clear_route(flyer.grid_position, castle), "it lands outside, on a way out (%s)" % flyer.grid_position)
	kit.check(walls.all(func(w) -> bool: return is_instance_valid(w) and not w.is_dead), "and every wall stands")
