extends RefCounted

## LevelUpgrades: cards on placed buildings, caps, Gold and XP Gain cards.

const WEAKLING_KILL_XP : float = 30.0


func test_damage_cards_are_capped(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await kit.place("puffe_bolter", Vector2i(12, 6))
	var base_damage : float = bolter.skill.stats.get_stat_value(Utils.StatType.Damage)

	#0.36 each: two fully (0.72), the third half past the +75% soft cap (0.75 + 0.33 / 2)
	kit.pick_card("projectile_damage", 0.36)
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.Damage), base_damage * 1.36, "one card counts fully")
	kit.pick_card("projectile_damage", 0.36)
	kit.pick_card("projectile_damage", 0.36)
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.Damage), base_damage * 1.915, "the third card is half past the soft cap")
	for i in 6:
		kit.pick_card("damage", 0.24)
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.Damage), base_damage * 2.5, "hard cap at +150%")
	kit.check(not kit.level.upgrades._can_offer(load(TestKit.CARD_PATH % "damage"), 9), "a capped card is not offered")


func test_cards_reach_later_buildings(kit : TestKit) -> void:
	await kit.load_level(1)
	kit.pick_card("attack_speed", 0.2)
	var bolter : Building = await kit.place("puffe_bolter", Vector2i(12, 6))
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.AttackSpeed), 0.2, "a building placed later gets the card")


func test_max_health_fits_walls_only_health(kit : TestKit) -> void:
	await kit.load_level(1)
	var wall : Building = await kit.place("wall", Vector2i(12, 6))
	var max_health : float = wall.stats.get_stat_value(Utils.StatType.MaxHealth)
	kit.pick_card("max_health", 0.4)
	kit.check_near(wall.stats.get_stat_value(Utils.StatType.MaxHealth), max_health * 1.4, "wall max health")
	kit.check_near(wall.stats.get_stat_value(Utils.StatType.Health), max_health * 1.4, "an undamaged wall is healed to the new max")
	kit.check(not kit.level.upgrades._fits(load(TestKit.CARD_PATH % "damage"), wall, 2), "walls don't take damage cards")


func test_gold_card_and_max_picks(kit : TestKit) -> void:
	await kit.load_level(1)
	var gold : float = kit.level.player_stats.gold
	kit.pick_card("gold", 8.0)
	kit.check_near(kit.level.player_stats.gold, gold + 8.0, "gold is added once")
	kit.pick_card("gold")
	kit.check(not kit.level.upgrades._can_offer(load(TestKit.CARD_PATH % "gold"), 4), "gold stops after 2 picks")


func test_xp_gain_card(kit : TestKit) -> void:
	await kit.load_level(1)
	kit.pick_card("xp_gain", 0.3)
	kit.pick_card("xp_gain", 0.45)
	kit.check_near(kit.level.upgrades.xp_bonus, 0.5, "xp bonus capped at +50%")
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames()
	var xp : float = kit.level.upgrades.xp
	kit.level.upgrades._on_enemy_destroyed(enemy)
	kit.check_near(kit.level.upgrades.xp - xp, WEAKLING_KILL_XP * 1.5, "kill xp with the bonus")
