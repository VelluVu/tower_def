extends RefCounted

## Effect potency: effects tick for a share of the hit, potency scales them, slows stop at the floor.

const FROST_LEAF_NAME : String = "FrostElementEvolveLeaf"
const SLOW_HITS : int = 30
const POISON_LEAF_NAME : String = "PoisonElementEvolveLeaf"
const FIGHT_SECONDS : float = 6.0
const TOUGH_HEALTH : float = 1000.0
const BURN_SECONDS : float = 4.5
const ELEMENT_TOWERS : Array[String] = ["bolter", "nova", "beamer"]
const UPGRADE_DATA_PATH : String = "res://scenes/upgrades/building_upgrades/%s_upgrade_data.tres"


func test_tick_damage_from_hit_and_potency(kit : TestKit) -> void:
	kit.check_near(OvertimeEffectData.scaled_tick_damage(1.0, 0.3, 10.0, 0.0), 3.0, "30% of a 10 hit")
	kit.check_near(OvertimeEffectData.scaled_tick_damage(1.0, 0.3, 10.0, 0.5), 4.5, "+50% potency")
	kit.check_near(OvertimeEffectData.scaled_tick_damage(-2.0, 0.0, 10.0, 0.5), -2.0, "a fixed tick ignores the hit and potency")


func test_slow_floor(kit : TestKit) -> void:
	var slow : ModifierData = _multiply(-0.5)
	var boost : ModifierData = _multiply(0.2)
	var multiply : Array[ModifierData] = [slow, slow, boost]
	var slowed : float = ModifierManager.combine(20.0, [], [], multiply)
	kit.check_near(slowed, 6.0, "two 50% slows and a 20% boost")
	kit.check_near(ModifierManager.floor_slows(slowed, 20.0, [], [], multiply), 9.6, "slows stop at 40% of the boosted speed")
	kit.check_near(ModifierManager.floor_slows(18.0, 20.0, [], [], [_multiply(-0.1)]), 18.0, "a small slow is not changed")


func test_upgrades_after_the_element_add_potency(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await _frost_bolter(kit)
	kit.check_near(bolter.stats.get_stat_value(Utils.StatType.EffectPotency), 0.0, "Up 1-2 and the element give no potency")
	_buy(kit, 0)
	_buy(kit, 0)
	kit.check_near(bolter.stats.get_stat_value(Utils.StatType.EffectPotency), 0.3, "Up 3-4 give 15% each")


func test_every_element_tower_has_potency_upgrades(kit : TestKit) -> void:
	for tower in ELEMENT_TOWERS:
		var data : BuildingUpgradeData = load(UPGRADE_DATA_PATH % tower)
		var has_potency : bool = data.evolved_upgrade_resources.any(func(resource : EvolveResource) -> bool: return resource.modify_stat_type == Utils.StatType.EffectPotency)
		kit.check(has_potency, "%s Up 3-6 give potency" % tower)


func test_potency_card_fits_element_towers(kit : TestKit) -> void:
	await kit.load_level(1)
	var card : EvolveResource = load(TestKit.CARD_PATH % "effect_potency")
	var plain_bolter : Building = await kit.place("puffe_bolter", Vector2i(14, 6))
	var bolter : Building = await _frost_bolter(kit)
	kit.check(not kit.level.upgrades._fits(card, plain_bolter, 1), "no element, no potency card")
	kit.check(kit.level.upgrades._fits(card, bolter, 1), "a Frost bolter takes the card")


func test_frost_slow_scales_and_stops_at_the_floor(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await _frost_bolter(kit)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames()
	var speed : float = enemy.stats.get_stat_value(Utils.StatType.Speed)
	var slow_per_stack : float = bolter.skill.damage_data.overtime_effect_datas[0].modifier_datas[0].value

	_slow(enemy, bolter, 1)
	kit.check_near(enemy.stats.get_stat_value(Utils.StatType.Speed), speed * (1.0 + slow_per_stack), "one stack")

	kit.pick_card("effect_potency", 0.5)
	_slow(enemy, bolter, 1)
	kit.check_near(enemy.stats.get_stat_value(Utils.StatType.Speed), speed * (1.0 + slow_per_stack) * (1.0 + slow_per_stack * 1.5), "+50% potency slows 50% more")

	_slow(enemy, bolter, SLOW_HITS)
	kit.check_near(enemy.stats.get_stat_value(Utils.StatType.Speed), speed * ModifierManager.SLOW_FLOOR, "many stacks stop at the floor")


func test_stack_cap_replaces_the_weakest(kit : TestKit) -> void:
	await kit.load_level(1)
	var enemy : Enemy = _tough_enemy(kit)
	await kit.frames()
	var burn : OvertimeEffectData = _burn_data(2)
	var handler : OvertimeEffectHandler = enemy.overtime_effect_handler

	handler.add_overtime_effect(burn, 2.0)
	handler.add_overtime_effect(burn, 2.0)
	handler.add_overtime_effect(burn, 1.0)
	kit.check(_tick_damages(handler) == [1.0, 1.0], "a weaker hit at the cap is dropped")
	handler.add_overtime_effect(burn, 4.0)
	kit.check(_tick_damages(handler) == [1.0, 2.0], "a stronger hit replaces the weakest stack")
	burn.free()


func test_element_stats(kit : TestKit) -> void:
	var burn : OvertimeEffectData = _burn_data(3)
	burn.chance_to_apply = 0.1
	burn.chance_bonus = 0.05
	burn.duration_bonus = 1
	burn.stacks_bonus = 1
	burn.tick_rate = 0.25
	kit.check_near(burn.get_chance(), 0.15, "chance points add up")
	kit.check(burn.get_tick_count() == 4, "one more tick")
	kit.check(burn.get_max_stacks() == 4, "one more stack")
	kit.check_near(burn.get_tick_interval(), 0.8, "ticks 25% faster")
	burn.max_count = 0
	kit.check(burn.get_tick_count() == 0, "an endless effect stays endless")
	burn.free()


func test_a_stack_ticks_its_duration(kit : TestKit) -> void:
	await kit.load_level(1)
	var enemy : Enemy = _tough_enemy(kit)
	await kit.frames()
	var burn : OvertimeEffectData = _burn_data(3)
	burn.duration_bonus = 1
	var ticks : Array[int] = [0]
	var count_tick : Callable = func(_position : Vector2, data : DamageData) -> void: ticks[0] += 1 if data.is_overtime else 0
	GameSignals.damage_taken.connect(count_tick)
	enemy.overtime_effect_handler.add_overtime_effect(burn, 2.0)
	await kit.run_until(func() -> bool: return false, BURN_SECONDS)
	GameSignals.damage_taken.disconnect(count_tick)
	kit.check(ticks[0] == 4, "3 ticks + 1 from the duration bonus (%d)" % ticks[0])
	kit.check(enemy.overtime_effect_handler.get_active_stacks(Utils.DamageType.Fire).is_empty(), "the stack ended")
	burn.free()


func test_hits_leave_no_orphan_nodes(kit : TestKit) -> void:
	await kit.load_level(1)
	var spawner : Spawner = kit.level.get_spawners()[0]
	var spawn_cell : Vector2i = kit.level.grid.world_position_to_grid(spawner.global_position)
	#beam hits, poison ticks and the trap's melee hit; projectiles need Main in the tree, see the SkillData test
	await _evolve(kit, "puffe_beamer", spawn_cell + Vector2i(-1, 1), POISON_LEAF_NAME)
	await kit.place("leopard_trap", spawn_cell)
	var hits : Array[int] = [0]
	var count_hit : Callable = func(_position : Vector2, _data : DamageData) -> void: hits[0] += 1
	GameSignals.damage_taken.connect(count_hit)
	await kit.frames(2)
	var orphans : float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	for i in 3:
		_tough_enemy(kit)
	await kit.run_until(func() -> bool: return false, FIGHT_SECONDS)
	await kit.frames(2)
	GameSignals.damage_taken.disconnect(count_hit)

	var new_orphans : float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) - orphans
	kit.check(hits[0] >= 10, "the towers hit (%d hits)" % hits[0])
	kit.check(new_orphans == 0, "%d hits left %d orphan nodes" % [hits[0], new_orphans])


func test_skill_data_frees_its_hit(kit : TestKit) -> void:
	var hit : DamageData = DamageData.new()
	var skill_data : SkillData = SkillData.new()
	skill_data.damage_data = hit
	skill_data = null
	await kit.frames(2)
	kit.check(not is_instance_valid(hit), "the projectile's hit is freed with its SkillData")


func _frost_bolter(kit : TestKit, cell : Vector2i = Vector2i(12, 6)) -> Building:
	return await _evolve(kit, "puffe_bolter", cell, FROST_LEAF_NAME)


## Places a tower and buys Up 1-2 and the element leaf_name with free gold.
func _evolve(kit : TestKit, building_name : String, cell : Vector2i, leaf_name : String) -> Building:
	var building : Building = await kit.place(building_name, cell)
	kit.level.player_stats.gold = 999
	kit.level.building_type_upgrades._on_unit_selected(building)
	_buy(kit, 0)
	_buy(kit, 0)
	var options : Array[GoldUpgradeOption] = kit.level.building_type_upgrades.options
	for i in options.size():
		if str(options[i].element_leaf_path).ends_with(leaf_name):
			_buy(kit, i)
			break
	kit.check(building.evolve_tree.evolve_element != Utils.Element.Physical, "%s evolved by %s" % [building_name, leaf_name])
	return building


func _tough_enemy(kit : TestKit) -> Enemy:
	var enemy : Enemy = kit.spawn_enemy("swbeefling")
	enemy.stats.get_stat(Utils.StatType.MaxHealth).value = TOUGH_HEALTH
	enemy.stats.get_stat(Utils.StatType.Health).value = TOUGH_HEALTH
	return enemy


## A burn: half the hit per tick, 3 ticks 1 s apart, max_stacks per enemy. Free it after the test.
func _burn_data(max_stacks : int) -> OvertimeEffectData:
	var burn : OvertimeEffectData = OvertimeEffectData.new()
	burn.effectType = Utils.OvertimeEffectType.Stack
	burn.damage_type = Utils.DamageType.Fire
	burn.hit_share = 0.5
	burn.max_count = 3
	burn.max_stacks = max_stacks
	return burn


func _tick_damages(handler : OvertimeEffectHandler) -> Array[float]:
	var damages : Array[float] = []
	for stack in handler.get_active_stacks(Utils.DamageType.Fire):
		damages.append(stack.tick_damage)
	damages.sort()
	return damages


func _buy(kit : TestKit, index : int) -> void:
	kit.level.building_type_upgrades._on_gold_upgrade_pressed(index)


#the slow's effect data without the hit damage, so the weakling never dies of it; no crits (a crit adds two stacks)
func _slow(enemy : Enemy, bolter : Building, hits : int) -> void:
	for i in hits:
		var datas : Array[OvertimeEffectData] = bolter.skill.damage_data.overtime_effect_datas
		for data in datas:
			data.is_critical = false
		enemy.overtime_effect_handler.handle_overtime_effects(datas, 0.0)


func _multiply(value : float) -> ModifierData:
	var data : ModifierData = ModifierData.new()
	data.stat_type = Utils.StatType.Speed
	data.calculate_type = Utils.ModifyType.Multiply
	data.value = value
	return data
