extends RefCounted

## The thirteen cards of 2026-11-27 (tools/new_cards_2026_11_27.py): each reaches its stat, paired cards both stats,
## and the level-wide Bounty, Thrift and Stonemason their hooks.

const NEW_CARDS : Array[String] = ["shrapnel", "piercing_bolts", "shockwave", "flash_freeze", "executioner", "marked_prey",
	"split_shot", "quickening", "lingering_ground", "spreading_plague", "stonemason", "bounty", "thrift"]


func _free_cell(kit : TestKit, taken : Array[Vector2i]) -> Vector2i:
	return kit.find_cell(func(c : Vector2i) -> bool:
		return not taken.has(c) and kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))


func test_every_card_is_in_the_pool(kit : TestKit) -> void:
	var names : Array[String] = []
	for resource in RandomEvolveResourceCollection.all_evolve_resources:
		names.append(resource.resource_path.get_file().get_basename())
	for card_name in NEW_CARDS:
		kit.check(names.has(card_name), "%s is in the card pool" % card_name)


func test_tower_cards_reach_their_stats(kit : TestKit) -> void:
	await kit.load_level(4)
	var bolter_cell : Vector2i = _free_cell(kit, [])
	var bolter : Building = await kit.place("puffe_bolter", bolter_cell)
	var nova : Building = await kit.place("puffe_nova", _free_cell(kit, [bolter_cell]))
	kit.pick_card("shrapnel")
	kit.pick_card("piercing_bolts")
	kit.pick_card("shockwave")
	kit.pick_card("flash_freeze")
	kit.pick_card("executioner")
	kit.pick_card("marked_prey")
	kit.pick_card("split_shot")
	kit.pick_card("lingering_ground")
	var expected : Dictionary[Utils.StatType, float] = {
		Utils.StatType.SplashRadius: 0.5, Utils.StatType.Knockback: 1.0, Utils.StatType.FreezeChance: 0.05,
		Utils.StatType.FreezeDuration: 0.75, Utils.StatType.ExecuteBelow: 0.08, Utils.StatType.MarkShare: 0.08,
		Utils.StatType.SplitCount: 1.0, Utils.StatType.SplitShare: 0.3, Utils.StatType.PatchDuration: 2.0,
		Utils.StatType.PatchShare: 0.1}
	for tower in [bolter, nova]:
		for stat_type in expected:
			kit.check_near(tower.stats.get_stat_value(stat_type), expected[stat_type], "%s %s" % [tower.name, Utils.StatType.keys()[stat_type]])
	kit.check_near(bolter.stats.get_stat_value(Utils.StatType.Pierce), 1.0, "Piercing Bolts reach the Bolter")
	kit.check_near(nova.stats.get_stat_value(Utils.StatType.Pierce), 0.0, "and not the Nova")


func test_thrift_lowers_upgrade_prices(kit : TestKit) -> void:
	await kit.load_level(4)
	await kit.place("puffe_bolter", _free_cell(kit, []))
	var before : float = kit.level.building_type_upgrades._price_share()
	kit.pick_card("thrift", 0.2)
	kit.check_near(kit.level.upgrades.upgrade_discount, 0.2, "Thrift's discount")
	kit.check_near(kit.level.building_type_upgrades._price_share(), before - 0.2, "upgrades cost 20% less")


func test_stonemason_armours_walls(kit : TestKit) -> void:
	await kit.load_level(4)
	var wall : Building = await kit.place("wall", _free_cell(kit, []))
	kit.pick_card("stonemason", 0.3)
	var health : float = wall.stats.get_stat_value(Utils.StatType.Health)
	var hit : DamageData = DamageData.new()
	hit.damage = 1.0
	wall.take_damage(hit)
	hit.free()
	kit.check_near(health - wall.stats.get_stat_value(Utils.StatType.Health), 0.7, "the wall takes 30% less")


func test_bounty_adds_whole_gold(kit : TestKit) -> void:
	await kit.load_level(4)
	await kit.place("wall", _free_cell(kit, []))
	kit.pick_card("bounty", 1.0)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames()
	var reward : float = enemy.stats.get_stat_value(Utils.StatType.Price)
	var gold : float = kit.level.player_stats.gold
	var hit : DamageData = DamageData.new()
	hit.damage = 99999.0
	enemy.take_damage(hit)
	hit.free()
	await kit.frames()
	kit.check_near(kit.level.player_stats.gold - gold, reward + 1.0, "a sure Bounty drops 1 more gold")
