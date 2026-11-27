extends RefCounted

## The sell refund rule (2026-11-26): the full price back in the wave or build break a building
## was placed in, UpgradeRules.LATE_SELL_SHARE of it (rounded up) after that.


func test_refund_rule(kit : TestKit) -> void:
	kit.check_near(UpgradeRules.sell_refund(10.0, true), 10.0, "same round: the full price")
	kit.check_near(UpgradeRules.sell_refund(10.0, false), 8.0, "later: 75% rounded up")
	kit.check_near(UpgradeRules.sell_refund(1.0, false), 1.0, "a 1 gold wall still refunds 1")


func test_sell_in_the_same_round_refunds_in_full(kit : TestKit) -> void:
	await kit.load_level(1)
	var cell : Vector2i = kit.find_cell(func(_cell : Vector2i) -> bool: return true)
	var tower : Building = await kit.place("puffe_bolter", cell)
	var price : float = tower.stats.get_stat_value(Utils.StatType.Price)
	var gold : float = kit.level.player_stats.gold
	GameSignals.sell_building.emit(tower)
	kit.check_near(kit.level.player_stats.gold - gold, price, "sold in the build break it was placed in")


func test_sell_after_a_wave_refunds_a_share(kit : TestKit) -> void:
	await kit.load_level(1)
	var cell : Vector2i = kit.find_cell(func(_cell : Vector2i) -> bool: return true)
	var tower : Building = await kit.place("puffe_bolter", cell)
	var price : float = tower.stats.get_stat_value(Utils.StatType.Price)
	#a wave start ends the round the tower was placed in
	kit.level.build_round += 1
	var gold : float = kit.level.player_stats.gold
	GameSignals.sell_building.emit(tower)
	kit.check_near(kit.level.player_stats.gold - gold, UpgradeRules.sell_refund(price, false), "sold a round later")
	kit.check(UpgradeRules.sell_refund(price, false) < price, "less than the price (%s)" % price)


## A tower picked from the tray sits right under the Level while placing; the selection card asks
## for its sell refund then, which crashed when Building.level took the grandparent (2026-11-27).
func test_placing_preview_finds_its_level(kit : TestKit) -> void:
	await kit.load_level(1)
	var preview : Building = load(TestKit.BUILDING_PATH % "puffe_bolter").instantiate()
	kit.level.add_child(preview)
	await kit.frames()
	kit.check(preview.level == kit.level, "the preview's level is the Level")
	kit.check(preview.get_sell_refund() >= 0.0, "the refund can be read while placing")
	preview.free()
