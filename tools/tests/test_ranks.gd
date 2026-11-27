extends RefCounted

## Ranks (2026-11-27): the repeatable gold step after a building's last step, each stat with a hard cap, for towers
## and the wall line; the gold sink of a player with few towers.

const TOWER_RANKS : RankData = preload("res://scenes/upgrades/ranks/tower_ranks.tres")
const WALL_RANKS : RankData = preload("res://scenes/upgrades/ranks/wall_ranks.tres")


func _buildable(kit : TestKit, taken : Array[Vector2i]) -> Vector2i:
	return kit.find_cell(func(c : Vector2i) -> bool:
		return not taken.has(c) and kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))


func _rank_index(upgrades : BuildingTypeUpgrades) -> int:
	for index in upgrades.options.size():
		if upgrades.options[index].is_rank:
			return index
	return -1


#buys the building's line (the first element at the choice) until a rank shows; false if it never does
func _buy_line(upgrades : BuildingTypeUpgrades) -> bool:
	for i in 30:
		if _rank_index(upgrades) >= 0:
			return true
		var bought : bool = false
		for index in upgrades.options.size():
			var option : GoldUpgradeOption = upgrades.options[index]
			if not option.is_locked and option.wall_element == Utils.Element.None:
				UISignals.gold_upgrade_pressed.emit(index)
				bought = true
				break
		if not bought:
			return false
	return false


func test_rank_data_caps(kit : TestKit) -> void:
	kit.check(TOWER_RANKS.get_max_ranks() == 10, "a tower caps at 10 ranks (%d)" % TOWER_RANKS.get_max_ranks())
	kit.check_near(TOWER_RANKS.get_total(0, 3), 0.15, "three ranks: +15% damage")
	kit.check_near(TOWER_RANKS.get_total(0, 40), 0.5, "never past the damage cap")
	kit.check_near(TOWER_RANKS.get_total(1, 40), 0.2, "never past the attack speed cap")
	kit.check(TOWER_RANKS.get_cost_ratio(1) > TOWER_RANKS.get_cost_ratio(0), "every rank is dearer")
	kit.check(WALL_RANKS.get_max_ranks() == 10, "the wall line caps at 10 ranks (%d)" % WALL_RANKS.get_max_ranks())
	kit.check_near(RankData.capped_total(-0.1, 5, 0.3), -0.3, "a negative step caps too")


func test_tower_ranks_after_the_last_step(kit : TestKit) -> void:
	await kit.load_level(1)
	kit.level.player_stats.gold = 9999.0
	var bolter : Building = await kit.place("puffe_bolter", _buildable(kit, []))
	var upgrades : BuildingTypeUpgrades = kit.level.building_type_upgrades
	upgrades._on_unit_selected(bolter)
	kit.check(_rank_index(upgrades) < 0, "no rank on a fresh tower")
	kit.check(_buy_line(upgrades), "a rank shows once the line is bought (T2 locked without its talent)")
	var damage_before : float = bolter.skill.stats.get_stat_value(Utils.StatType.Damage)
	var first_price : float = upgrades.options[_rank_index(upgrades)].cost
	kit.check_near(first_price, ceilf(bolter.stats.get_stat(Utils.StatType.Price).base_value * TOWER_RANKS.first_cost_ratio), "the first rank costs a tower")
	var gold_before : float = kit.level.player_stats.gold
	UISignals.gold_upgrade_pressed.emit(_rank_index(upgrades))
	kit.check_near(gold_before - kit.level.player_stats.gold, first_price, "the rank is paid")
	kit.check(upgrades.get_ranks(bolter) == 1, "one rank")
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.Damage), damage_before * 1.05, "+5% more damage")
	kit.check(upgrades.options[_rank_index(upgrades)].cost > first_price, "the next rank is dearer")
	for i in 20:
		var index : int = _rank_index(upgrades)
		if index < 0:
			break
		UISignals.gold_upgrade_pressed.emit(index)
	kit.check(upgrades.get_ranks(bolter) == 10, "ranks end at the caps (%d)" % upgrades.get_ranks(bolter))
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.Damage), damage_before * 1.5, "+50% damage at the cap, no more")
	kit.check(upgrades.rank_modifiers[bolter].size() == 2, "one modifier per rank stat, swapped on every rank")


func test_wall_ranks_reach_every_wall(kit : TestKit) -> void:
	await kit.load_level(1)
	kit.level.player_stats.gold = 9999.0
	var first_cell : Vector2i = _buildable(kit, [])
	var wall : Wall = await kit.place("wall", first_cell)
	var upgrades : BuildingTypeUpgrades = kit.level.building_type_upgrades
	upgrades._on_unit_selected(wall)
	kit.check(_buy_line(upgrades), "a rank shows once the wall line is bought")
	var health_before : float = wall.stats.get_stat_value(Utils.StatType.MaxHealth)
	UISignals.gold_upgrade_pressed.emit(_rank_index(upgrades))
	kit.check_near(wall.stats.get_stat_value(Utils.StatType.MaxHealth), health_before * 1.15, "+15% max health")
	kit.check_near(wall.stats.get_stat_value(Utils.StatType.Health), wall.stats.get_stat_value(Utils.StatType.MaxHealth), "the new health is filled in")
	kit.check_near(wall.stats.get_stat_value(Utils.StatType.EffectPotency), 0.1, "+10% ground damage")
	var later : Wall = await kit.place("wall", _buildable(kit, [first_cell]))
	kit.check_near(later.stats.get_stat_value(Utils.StatType.EffectPotency), 0.1, "a wall placed later has the ranks too")
	kit.check_near(later.stats.get_stat_value(Utils.StatType.MaxHealth), health_before * 1.15, "and their health")
