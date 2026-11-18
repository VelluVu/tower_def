extends RefCounted

## Element walls: bought per wall after the shared line's Up 2, the maze-area effect and the blocking side.


func _wall(kit : TestKit) -> Wall:
	return await kit.place("wall", kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c))))


func test_element_options_after_up_2(kit : TestKit) -> void:
	#Fortress waits for its Building tree node: learn it for this test (never saved)
	var progress : ProgressData = PlayerProgress._save.progress
	var saved_ranks : Dictionary[StringName, Dictionary] = progress.talent_ranks
	progress.talent_ranks = {&"building": {&"fortress_t1": 1}}
	await kit.load_level(1)
	kit.level.player_stats.gold = 500.0
	var wall : Wall = await _wall(kit)
	var upgrades : BuildingTypeUpgrades = kit.level.building_type_upgrades
	GameSignals.selected_unit.emit(wall)
	kit.check(upgrades.options.filter(func(o : GoldUpgradeOption) -> bool: return o.wall_element != Utils.Element.None).is_empty(), "no elements before Up 2")
	UISignals.gold_upgrade_pressed.emit(0)
	UISignals.gold_upgrade_pressed.emit(0)
	var element_options : Array = upgrades.options.filter(func(o : GoldUpgradeOption) -> bool: return o.wall_element != Utils.Element.None)
	kit.check(element_options.size() == 4, "four elements at Up 2 (%d)" % element_options.size())
	var frost_index : int = upgrades.options.find(element_options.filter(func(o : GoldUpgradeOption) -> bool: return o.wall_element == Utils.Element.Frost)[0])
	UISignals.gold_upgrade_pressed.emit(frost_index)
	kit.check(wall.element == Utils.Element.Frost, "the wall is a Frost wall")
	kit.check(upgrades.options.filter(func(o : GoldUpgradeOption) -> bool: return o.wall_element != Utils.Element.None).is_empty(), "and offers no more elements")
	progress.talent_ranks = saved_ranks


func test_frost_ground_and_thorns(kit : TestKit) -> void:
	await kit.load_level(1)
	var wall : Wall = await _wall(kit)
	var beside : Vector2i = kit.level.grid.get_walkable_surrounding_cells(wall.grid_position)[0]
	var plain : float = kit.level.grid.get_move_speed_factor(beside)
	wall.set_element(Utils.Element.Frost)
	kit.check(kit.level.grid.get_move_speed_factor(beside) < plain, "freezing ground beside a Frost wall")

	var fortress : Wall = await _wall(kit)
	fortress.set_element(Utils.Element.Physical)
	var attacker : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	var before : float = attacker.stats.get_stat_value(Utils.StatType.Health)
	var hit : DamageData = DamageData.new()
	hit.damage = 4.0
	hit.source = attacker
	fortress.take_damage(hit)
	hit.free()
	kit.check_near(before - attacker.stats.get_stat_value(Utils.StatType.Health), 2.0, "thorns: half the damage back")


func test_wall_tiers(kit : TestKit) -> void:
	var progress : ProgressData = PlayerProgress._save.progress
	var saved_ranks : Dictionary[StringName, Dictionary] = progress.talent_ranks
	progress.talent_ranks = {&"frost": {&"wall_t2": 1}}
	await kit.load_level(1)
	kit.level.player_stats.gold = 500.0
	var wall : Wall = await _wall(kit)
	var upgrades : BuildingTypeUpgrades = kit.level.building_type_upgrades
	wall.set_element(Utils.Element.Frost)
	GameSignals.selected_unit.emit(wall)
	var tier_options : Callable = func() -> Array: return upgrades.options.filter(func(o : GoldUpgradeOption) -> bool: return o.wall_tier > 0)
	kit.check(tier_options.call().is_empty(), "no tier before the shared line's Up 4")
	for i in 4:
		UISignals.gold_upgrade_pressed.emit(0)
	kit.check(tier_options.call().size() == 1 and not tier_options.call()[0].is_locked, "Frost walls T2 at Up 4, open with its node")
	var beside : Vector2i = kit.level.grid.get_walkable_surrounding_cells(wall.grid_position)[0]
	var before : float = kit.level.grid.get_move_speed_factor(beside)
	UISignals.gold_upgrade_pressed.emit(upgrades.options.find(tier_options.call()[0]))
	kit.check(wall.get_element_tier() == 2, "every Frost wall is T2")
	kit.check(kit.level.grid.get_move_speed_factor(beside) < before, "colder ground beside it")
	for i in 2:
		UISignals.gold_upgrade_pressed.emit(0)
	kit.check(tier_options.call().size() == 1 and tier_options.call()[0].is_locked, "T3 at Up 6, locked without its node")
	progress.talent_ranks = saved_ranks


func test_rectangle_group(kit : TestKit) -> void:
	await kit.load_level(1)
	kit.level.player_stats.gold = 500.0
	var group : WallGroupSelect = kit.level.get_node(Level.WALL_GROUP_NAME)
	var first : Wall = await _wall(kit)
	var second : Wall = await _wall(kit)
	#the shared wall line to Up 2, through the panel like a player
	GameSignals.selected_unit.emit(first)
	UISignals.gold_upgrade_pressed.emit(0)
	UISignals.gold_upgrade_pressed.emit(0)
	group.drag_start = first.global_position.min(second.global_position) - Vector2(4, 4)
	group.drag_end = first.global_position.max(second.global_position) + Vector2(4, 4)
	group._collect()
	kit.check(group.walls.size() == 2, "both walls in the box (%d)" % group.walls.size())
	kit.check(group.element_options.size() == 3 and group.element_options[0].cost == BuildingTypeUpgrades.WALL_ELEMENT_PRICE * 2, "three elements (no Fortress node), priced for two walls")
	var gold : float = kit.level.player_stats.gold
	UISignals.wall_group_action.emit(0)
	kit.check(first.element != Utils.Element.None and first.element == second.element, "one purchase gives both walls the element")
	kit.check_near(gold - kit.level.player_stats.gold, BuildingTypeUpgrades.WALL_ELEMENT_PRICE * 2, "for twice the price")
	UISignals.wall_group_action.emit(WallGroupSelect.SELL_ACTION)
	await kit.frames(2)
	kit.check(not kit.level.all_buildings.has(first) and not kit.level.all_buildings.has(second), "Sell all sells them")


#a group takes the selection panel: the unit selected before it lets go, so its card cannot show through or stay
#behind as an empty "N walls" card after Sell all
func test_rectangle_group_lets_go_of_the_selection(kit : TestKit) -> void:
	await kit.load_level(1)
	var group : WallGroupSelect = kit.level.get_node(Level.WALL_GROUP_NAME)
	var first : Wall = await _wall(kit)
	var second : Wall = await _wall(kit)
	GameSignals.forced_selection.emit(first)
	kit.check(kit.level.unit_selection.selected_unit == first, "the wall is selected")
	group.drag_start = first.global_position.min(second.global_position) - Vector2(4, 4)
	group.drag_end = first.global_position.max(second.global_position) + Vector2(4, 4)
	group._collect()
	kit.check(group.walls.size() == 2, "the group has both walls")
	kit.check(kit.level.unit_selection.selected_unit == null, "the selection let go")
	var selectable : SelectableUnit = first.get_children().filter(func(n : Node) -> bool: return n is SelectableUnit)[0]
	kit.check(not selectable.is_selected, "and the wall is no longer selected")
