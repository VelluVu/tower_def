extends RefCounted

## The Hoard Keeper (2026-11-25): never attacks, pays gold after every cleared wave; only the first two pay in full.


func _tower_cells(kit : TestKit, count : int) -> Array[Vector2i]:
	var cells : Array[Vector2i] = []
	var used : Array[Vector2i] = []
	for i in count:
		var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
			return not used.has(c) and kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)) \
				and not kit.level.grid.has_building_in_cell_position(c))
		used.append(cell)
		cells.append(cell)
	return cells


func test_hoard_keeper_pays_after_a_wave(kit : TestKit) -> void:
	await kit.load_level(10)
	var cells : Array[Vector2i] = _tower_cells(kit, 3)
	var keepers : Array[HoardKeeper] = []
	for cell in cells:
		var keeper : Building = await kit.place("puffe_hoard", cell)
		kit.check(keeper is HoardKeeper, "a Hoard Keeper is placed")
		keepers.append(keeper)
	kit.check(TalentEffect.get_building_flag(keepers[0]) == TalentEffect.HOARD_KEEPER, "talents see it as a Hoard Keeper")
	kit.check_near(keepers[0].get_pay(), HoardKeeper.BASE_PAY, "the first pays in full")
	kit.check_near(keepers[1].get_pay(), HoardKeeper.BASE_PAY, "so does the second")
	kit.check_near(keepers[2].get_pay(), floorf(HoardKeeper.BASE_PAY * HoardKeeper.PARTIAL_SHARE), "the third pays less")
	var gold : float = kit.level.player_stats.gold
	GameSignals.wave_cleared.emit(1)
	await kit.frames(1)
	kit.check_near(kit.level.player_stats.gold, gold + HoardKeeper.BASE_PAY * 2.0 + floorf(HoardKeeper.BASE_PAY * HoardKeeper.PARTIAL_SHARE),
		"a cleared wave pays them all")
