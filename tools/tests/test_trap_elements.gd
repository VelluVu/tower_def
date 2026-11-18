extends RefCounted

## The Leopard Trap's element choices (tools/trap_elements.py, 2026-11-16): each element's T1 does its thing on a snap.


func _evolved_trap(kit : TestKit, leaf_name : String) -> Building:
	var trap : Building = await kit.place("leopard_trap", kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c))))
	var upgrades : BuildingTypeUpgrades = kit.level.building_type_upgrades
	kit.level.player_stats.gold = 999
	upgrades._on_unit_selected(trap)
	upgrades._on_gold_upgrade_pressed(0)
	upgrades._on_gold_upgrade_pressed(0)
	for i in upgrades.options.size():
		if str(upgrades.options[i].element_leaf_path).ends_with(leaf_name):
			upgrades._on_gold_upgrade_pressed(i)
			break
	return trap


func _snap(trap : Building, enemy : Enemy) -> void:
	var hit : DamageData = trap.skill.damage_data
	enemy.take_damage(hit)
	hit.queue_free()


func test_trap_offers_four_elements(kit : TestKit) -> void:
	await kit.load_level(1)
	var trap : Building = await kit.place("leopard_trap", kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c))))
	var upgrades : BuildingTypeUpgrades = kit.level.building_type_upgrades
	kit.level.player_stats.gold = 999
	upgrades._on_unit_selected(trap)
	upgrades._on_gold_upgrade_pressed(0)
	upgrades._on_gold_upgrade_pressed(0)
	var leaves : int = upgrades.options.filter(func(o : GoldUpgradeOption) -> bool: return not str(o.element_leaf_path).is_empty()).size()
	kit.check(leaves == 4, "after Up 2 the trap offers Leopard, Fire, Frost and Poison (%d)" % leaves)


func test_frost_trap_roots(kit : TestKit) -> void:
	await kit.load_level(1)
	var trap : Building = await _evolved_trap(kit, "FrostElementEvolveLeaf")
	kit.check(trap.evolve_tree.evolve_element == Utils.Element.Frost, "the trap took Frost")
	var enemy : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	_snap(trap, enemy)
	kit.check(enemy.is_frozen, "a Frost snap roots its enemy")


func test_fire_trap_burns_the_ground(kit : TestKit) -> void:
	await kit.load_level(1)
	var trap : Building = await _evolved_trap(kit, "FireElementEvolveLeaf")
	kit.check(trap.evolve_tree.evolve_element == Utils.Element.Fire, "the trap took Fire")
	kit.check(trap.stats.get_stat_value(Utils.StatType.PatchDuration) >= 2.0, "a Fire trap leaves burning ground")
	var enemy : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	_snap(trap, enemy)
	kit.check(not enemy.overtime_effect_handler.get_active_stacks(Utils.DamageType.Fire).is_empty(), "the snap always ignites")
