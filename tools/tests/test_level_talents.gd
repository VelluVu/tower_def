extends RefCounted

## The level-wide talent kinds of 2026-11-16 (LevelTalents): vulnerability, weakness, maze slow, freezes,
## prices, wall armour. Ranks are set straight in the loaded progress, never saved.


func _with_ranks(ranks : Dictionary[StringName, Dictionary]) -> Dictionary[StringName, Dictionary]:
	var progress : ProgressData = PlayerProgress._save.progress
	var saved : Dictionary[StringName, Dictionary] = progress.talent_ranks
	progress.talent_ranks = ranks
	return saved


func _hit(target : Node, damage : float, source : Node = null) -> float:
	var health : Stat = target.stats.get_stat(Utils.StatType.Health)
	var before : float = health.value
	var hit : DamageData = DamageData.new()
	hit.damage = damage
	hit.source = source
	target.take_damage(hit)
	hit.free()
	return before - health.value


func test_frost_talents(kit : TestKit) -> void:
	var saved : Dictionary = _with_ranks({&"frost": {&"cold_heart": 1, &"absolute_zero": 1, &"snap_freeze": 2}})
	await kit.load_level(1)
	var enemy : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	enemy.resistances = null
	kit.check_near(_hit(enemy, 10.0), 10.0, "a plain hit in full")
	enemy.freeze_for(1.0)
	kit.check_near(_hit(enemy, 10.0), 10.6, "Cold Heart: a frozen enemy takes 6% more")
	kit.check_near(enemy.freeze_timer.unscaled_base_value, 1.0 * 1.5 + 0.5, "Absolute Zero and Snap Freeze make a 1 s freeze 2 s")
	PlayerProgress._save.progress.talent_ranks = saved


func test_building_level_talents(kit : TestKit) -> void:
	var saved : Dictionary = _with_ranks({&"building": {&"narrow_ways": 3, &"haggling": 2, &"stubborn_stone": 2, &"spoils": 1}})
	await kit.load_level(1)
	kit.check_near(kit.level.grid.talent_maze_slow, 0.09, "Narrow Ways: 9 points of maze slow")
	kit.check_near(kit.level.building_type_upgrades._price_share(), 0.8, "Haggling: upgrades 20% cheaper")
	var wall : Building = await kit.place("wall", kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c))))
	kit.check_near(_hit(wall, 10.0), 9.0, "Stubborn Stone: walls take 10% less")
	var gold : float = kit.level.player_stats.gold
	GameSignals.wave_cleared.emit(1)
	kit.check_near(kit.level.player_stats.gold - gold, 1.0, "Spoils: a gold per cleared wave")
	PlayerProgress._save.progress.talent_ranks = saved


func test_weakened_attackers(kit : TestKit) -> void:
	var saved : Dictionary = _with_ranks({&"frost": {&"numbing_cold": 2}})
	await kit.load_level(1)
	var wall : Building = await kit.place("wall", kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c))))
	var attacker : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	kit.check_near(_hit(wall, 10.0, attacker), 10.0, "an unslowed attacker hits in full")
	attacker.freeze_for(1.0)
	kit.check_near(_hit(wall, 10.0, attacker), 8.0, "a chilled attacker hits 20% softer")
	PlayerProgress._save.progress.talent_ranks = saved


## The mechanics (TalentMechanics, 2026-11-16): a strike on every Nth attack, a death burst, the castle dragon.
func test_pinning_shot_freezes_every_fifth_bolt(kit : TestKit) -> void:
	var saved : Dictionary = _with_ranks({&"frost": {&"pinning_shot": 1}})
	await kit.load_level(1)
	kit.check(kit.level.talents.mechanics != null, "a mechanic node makes the mechanics")
	var bolter : Building = await kit.place("puffe_bolter", kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c))))
	bolter.evolve_tree.choose_element(Utils.Element.Frost)
	var enemy : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	bolter.skill.target = enemy
	for i in 4:
		GameSignals.tower_attacked.emit(bolter.skill)
	kit.check(not enemy.is_frozen, "four bolts do not pin")
	GameSignals.tower_attacked.emit(bolter.skill)
	kit.check(enemy.is_frozen, "the fifth bolt freezes its target")
	#the target leaks (freed at once) while the next fifth bolt is cast: the strike skips it, no script error
	for i in 4:
		GameSignals.tower_attacked.emit(bolter.skill)
	enemy.free()
	GameSignals.tower_attacked.emit(bolter.skill)
	kit.check(not is_instance_valid(bolter.skill.target), "a strike on a target that has gone does nothing")
	PlayerProgress._save.progress.talent_ranks = saved


func test_ice_shards_burst(kit : TestKit) -> void:
	var saved : Dictionary = _with_ranks({&"frost": {&"ice_shards": 1}})
	await kit.load_level(1)
	var dying : Enemy = kit.spawn_enemy("beefling")
	var near : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	near.resistances = null
	near.global_position = dying.global_position
	var health : float = near.stats.get_stat_value(Utils.StatType.Health)
	dying.freeze_for(1.0)
	dying.die()
	kit.check_near(health - near.stats.get_stat_value(Utils.StatType.Health), dying.stats.get_stat_value(Utils.StatType.MaxHealth) * 0.2, "a frozen enemy shatters for 20% of its max health")
	PlayerProgress._save.progress.talent_ranks = saved


func test_keep_awakens(kit : TestKit) -> void:
	var saved : Dictionary = _with_ranks({&"fire": {&"keep_awakens": 1}})
	await kit.load_level(1)
	var first : Enemy = kit.spawn_enemy("weakling")
	var second : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	var life : float = kit.level.player_stats.life
	GameSignals.enemy_reached_end_point.emit(first)
	kit.check_near(kit.level.player_stats.life, life, "the dragon stops the first enemy of the wave at its castle")
	GameSignals.enemy_reached_end_point.emit(second)
	kit.check(kit.level.player_stats.life < life, "the second one costs life")
	var target : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	target.resistances = null
	target.global_position = kit.level.end_point.global_position
	var health : float = target.stats.get_stat_value(Utils.StatType.Health)
	kit.level.talents.mechanics._breathe()
	kit.check_near(health - target.stats.get_stat_value(Utils.StatType.Health), target.stats.get_stat_value(Utils.StatType.MaxHealth) * 0.1, "the breath burns 10% of max health near the castle")
	PlayerProgress._save.progress.talent_ranks = saved


func test_salvage_and_hoard(kit : TestKit) -> void:
	var saved : Dictionary = _with_ranks({&"building": {&"salvage": 2, &"hoard": 1}})
	await kit.load_level(1)
	var upgrades : BuildingTypeUpgrades = kit.level.building_type_upgrades
	var bolter : Building = await kit.place("puffe_bolter", kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c))))
	upgrades.selected_unit = bolter
	var data : BuildingUpgradeData = bolter.evolve_tree.upgrade_data
	var full : float = UpgradeRules.gold_price(bolter.stats.get_stat(Utils.StatType.Price).base_value, data.upgrade_cost_ratios[0])
	var half : float = UpgradeRules.gold_price(bolter.stats.get_stat(Utils.StatType.Price).base_value, data.upgrade_cost_ratios[0] * 0.5)
	kit.check(full > half, "the first upgrade costs something to halve")
	kit.check_near(upgrades._build_options()[0].cost, half, "Hoard: the first upgrade costs half")
	upgrades.upgrade_gold[bolter] = 10.0
	var gold : float = kit.level.player_stats.gold
	GameSignals.sell_building.emit(bolter)
	kit.check_near(kit.level.player_stats.gold - gold, bolter.stats.get_stat_value(Utils.StatType.Price) + 5.0, "Salvage: half the upgrade gold comes back with the price")
	PlayerProgress._save.progress.talent_ranks = saved
