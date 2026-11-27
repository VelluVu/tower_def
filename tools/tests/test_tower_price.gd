extends RefCounted

## The tower price step: every tower on the map makes the next one dearer; walls, traps and upgrades stay at base.


func test_price_step_extra(kit : TestKit) -> void:
	kit.check_near(UpgradeRules.price_step_extra(1.0, 0), 0.0, "the first tower costs its base price")
	kit.check_near(UpgradeRules.price_step_extra(1.0, 9), 9.0, "the tenth tower costs 9 more")


func test_each_tower_costs_more(kit : TestKit) -> void:
	await kit.load_level(1)
	kit.level.player_stats.gold = 1000.0
	var cells : Array[Vector2i] = []
	for i in 4:
		cells.append(kit.find_cell(func(cell : Vector2i) -> bool: return not cells.has(cell) and kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(cell))))

	var first : Building = await kit.place("puffe_bolter", cells[0])
	var base : float = first.stats.get_stat(Utils.StatType.Price).base_value
	kit.check_near(first.stats.get_stat_value(Utils.StatType.Price), base, "the first tower costs its base price")

	var second : Building = await kit.place("puffe_nova", cells[1])
	#its own base price (the Nova costs 5 since 2026-11-27) plus the one tower already standing
	kit.check_near(second.stats.get_stat_value(Utils.StatType.Price), second.stats.get_stat(Utils.StatType.Price).base_value + 1.0, "every tower type counts")

	var wall : Building = await kit.place("wall", cells[2])
	kit.check_near(wall.stats.get_stat_value(Utils.StatType.Price), wall.stats.get_stat(Utils.StatType.Price).base_value, "walls have no step")

	var gold_before : float = kit.level.player_stats.gold
	var third : Building = await kit.place("puffe_beamer", cells[3])
	kit.check_near(third.stats.get_stat_value(Utils.StatType.Price), base + 2.0, "walls do not count")
	kit.check_near(gold_before - kit.level.player_stats.gold, base + 2.0, "placing pays the stepped price")

	kit.level.building_type_upgrades._on_unit_selected(third)
	var options : Array[GoldUpgradeOption] = kit.level.building_type_upgrades.options
	var data : BuildingUpgradeData = third.evolve_tree.upgrade_data
	kit.check(not options.is_empty() and is_equal_approx(options[0].cost, UpgradeRules.gold_price(base, data.upgrade_cost_ratios[0])), "upgrades use the base price")

	gold_before = kit.level.player_stats.gold
	GameSignals.sell_building.emit(third)
	await kit.frames(2)
	kit.check_near(kit.level.player_stats.gold - gold_before, base + 2.0, "selling refunds what was paid")
	kit.check(kit.level.get_price_step_count() == 2, "a sold tower no longer counts")
