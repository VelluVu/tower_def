extends RefCounted

## The Spotter (2026-11-24): a long-range sniper that aims at bosses and elites first, marks its target for an
## element (EnemyMarks) and, with ExecuteBelow, finishes off enemies left under a share of their health.


func _place_spotter(kit : TestKit) -> Tower:
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))
	return await kit.place("puffe_spotter", cell)


func _enemy(kit : TestKit, health : float) -> Enemy:
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	for stat_type in [Utils.StatType.MaxHealth, Utils.StatType.Health]:
		enemy.stats.get_stat(stat_type).value = health
	return enemy


func _hit(source : Building, damage_type : Utils.DamageType, damage : float) -> DamageData:
	var hit : DamageData = DamageData.new()
	hit.source = source
	hit.damage_type = damage_type
	hit.damage = damage
	return hit


func test_spotter_basics(kit : TestKit) -> void:
	await kit.load_level(1)
	var spotter : Tower = await _place_spotter(kit)
	kit.check(spotter.skill.skill_type == Utils.SkillType.Sniper, "the Spotter is a sniper")
	kit.check(spotter.can_choose_target, "it aims by tactic")
	kit.check(spotter.target_tactic == Utils.TargetTactic.Elite, "it aims at elites by default")
	kit.check(TalentEffect.get_building_flag(spotter) == TalentEffect.SPOTTER, "talents see it as a Spotter")
	kit.check(spotter.stats.get_stat(Utils.StatType.MarkShare) != null and spotter.stats.get_stat(Utils.StatType.ExecuteBelow) != null, "it has the mark and execute stats")
	kit.check(spotter.skill.stats.get_stat_value(Utils.StatType.AttackRange) > 5.0, "it has a long range")
	var list : BuildingListElement = load("res://scenes/unit/building/buildings/puffe_spotter.tres")
	kit.check(list.unlock_level == 31 and not list.is_unlocked(30) and list.is_unlocked(31), "it unlocks on level 31")


func test_elite_tactic_order(kit : TestKit) -> void:
	await kit.load_level(1)
	var big : Enemy = await _enemy(kit, 500.0)
	var elite : Enemy = await _enemy(kit, 100.0)
	Elite.make(elite, Elite.Affix.Shielded)
	var candidates : Array[Node2D] = [big, elite]
	kit.check(TargetPicker.pick(Utils.TargetTactic.Elite, candidates, Vector2.ZERO) == elite, "an elite before a stronger common enemy")
	var boss : Enemy = await _enemy(kit, 50.0)
	boss.is_boss = true
	candidates.append(boss)
	kit.check(TargetPicker.pick(Utils.TargetTactic.Elite, candidates, Vector2.ZERO) == boss, "a boss before an elite")
	kit.check(TargetPicker.MENU_ORDER.has(Utils.TargetTactic.Elite), "the Target menu offers it")


func test_mark_raises_its_element(kit : TestKit) -> void:
	await kit.load_level(1)
	var spotter : Tower = await _place_spotter(kit)
	var enemy : Enemy = await _enemy(kit, 1000.0)
	EnemyMarks.mark(enemy, Utils.DamageType.Fire, 0.2, 1.0)
	kit.check_near(EnemyMarks.get_bonus(enemy, Utils.DamageType.Fire), 0.2, "the fire mark")
	kit.check_near(EnemyMarks.get_bonus(enemy, Utils.DamageType.Frost), 0.0, "no frost mark")
	var fire : DamageData = _hit(spotter, Utils.DamageType.Fire, 10.0)
	var before : float = enemy.stats.get_stat_value(Utils.StatType.Health)
	enemy.take_damage(fire)
	var fire_lost : float = before - enemy.stats.get_stat_value(Utils.StatType.Health)
	fire.free()
	var frost : DamageData = _hit(spotter, Utils.DamageType.Frost, 10.0)
	before = enemy.stats.get_stat_value(Utils.StatType.Health)
	enemy.take_damage(frost)
	var frost_lost : float = before - enemy.stats.get_stat_value(Utils.StatType.Health)
	frost.free()
	kit.check(fire_lost > frost_lost * 1.1, "the marked element hits harder (%.1f > %.1f)" % [fire_lost, frost_lost])
	await kit.run_until(func() -> bool: return EnemyMarks.get_bonus(enemy, Utils.DamageType.Fire) == 0.0, 3.0)
	kit.check_near(EnemyMarks.get_bonus(enemy, Utils.DamageType.Fire), 0.0, "the mark runs out")


func test_direct_hit_marks(kit : TestKit) -> void:
	await kit.load_level(1)
	var spotter : Tower = await _place_spotter(kit)
	spotter.stats.get_stat(Utils.StatType.MarkShare).value = 0.1
	var enemy : Enemy = await _enemy(kit, 1000.0)
	var hit : DamageData = _hit(spotter, Utils.DamageType.Poison, 5.0)
	enemy.take_damage(hit)
	hit.free()
	kit.check_near(EnemyMarks.get_bonus(enemy, Utils.DamageType.Poison), 0.1, "a direct hit marks for its element")


func test_execute(kit : TestKit) -> void:
	await kit.load_level(1)
	var spotter : Tower = await _place_spotter(kit)
	spotter.stats.get_stat(Utils.StatType.ExecuteBelow).value = 0.15
	var low : Enemy = await _enemy(kit, 100.0)
	var hit : DamageData = _hit(spotter, Utils.DamageType.Physical, 88.0)
	low.take_damage(hit)
	hit.free()
	kit.check(low.is_dead, "an enemy left under 15% dies to the hit")
	var high : Enemy = await _enemy(kit, 100.0)
	hit = _hit(spotter, Utils.DamageType.Physical, 50.0)
	high.take_damage(hit)
	hit.free()
	kit.check(not high.is_dead, "one left above 15% lives")
	var boss : Enemy = await _enemy(kit, 100.0)
	boss.is_boss = true
	hit = _hit(spotter, Utils.DamageType.Physical, 88.0)
	boss.take_damage(hit)
	hit.free()
	kit.check(not boss.is_dead, "a boss is never executed")
