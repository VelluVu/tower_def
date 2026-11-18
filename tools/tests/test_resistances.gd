extends RefCounted

## Enemy resistances: per element and per tower kind, never more than 75% together.


func test_damage_factor_caps_at_75(kit : TestKit) -> void:
	kit.check_near(EnemyResistances.get_damage_factor(0.0, 0.0), 1.0, "no resistance, full damage")
	kit.check_near(EnemyResistances.get_damage_factor(0.4, 0.0), 0.6, "40% resisted")
	kit.check_near(EnemyResistances.get_damage_factor(0.5, 0.3), 0.35, "element and tower stack")
	kit.check_near(EnemyResistances.get_damage_factor(0.75, 0.5), 0.25, "never below a quarter")
	kit.check_near(EnemyResistances.get_damage_factor(2.0, 0.0), 0.25, "a wrong value is capped too")


func test_plaguepig_shrugs_off_poison_not_frost(kit : TestKit) -> void:
	await kit.load_level(14)
	var pig : Enemy = kit.spawn_enemy("plaguepig")
	await kit.frames(1)
	for case in [[Utils.DamageType.Poison, 2.5], [Utils.DamageType.Frost, 10.0]]:
		var before : float = pig.stats.get_stat_value(Utils.StatType.Health)
		var hit : DamageData = DamageData.new()
		hit.damage_type = case[0]
		hit.damage = 10.0
		pig.take_damage(hit)
		hit.free()
		kit.check_near(before - pig.stats.get_stat_value(Utils.StatType.Health), case[1], "a 10 hit of type %d takes %.1f" % case)


func test_fast_enemies_resist_bolts(kit : TestKit) -> void:
	await kit.load_level(25)
	var bolter : Building = await kit.place("puffe_bolter", kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c))))
	var scout : Enemy = kit.spawn_enemy("scout")
	var soldier : Enemy = kit.spawn_enemy("soldier")
	await kit.frames(1)
	var hit : DamageData = DamageData.new()
	hit.damage = 10.0
	hit.source = bolter
	kit.check_near(scout.get_resistance_factor(hit), 0.7, "a scout takes 70% of a bolt")
	kit.check_near(soldier.get_resistance_factor(hit), 1.0, "a soldier takes it all")
	hit.free()


func test_penetration_and_shatter(kit : TestKit) -> void:
	await kit.load_level(25)
	var bolter : Building = await kit.place("puffe_bolter", kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c))))
	var knight : Enemy = kit.spawn_enemy("armored_knight")
	await kit.frames(1)
	var hit : DamageData = DamageData.new()
	hit.damage = 10.0
	hit.source = bolter
	var plain : float = knight.get_resistance_factor(hit)
	kit.pick_card("armor_breaker", 0.1)
	await kit.frames(1)
	kit.check_near(bolter.stats.get_stat_value(Utils.StatType.ResistancePenetration), 0.1, "the card gives 10% penetration")
	kit.check_near(knight.get_resistance_factor(hit), plain + 0.1, "10 points less armour")
	bolter.stats.get_stat(Utils.StatType.CriticalPenetration).value = 1.0
	hit.is_critical = true
	kit.check_near(knight.get_resistance_factor(hit), 1.0, "a crit with critical penetration ignores it all")
	hit.free()
