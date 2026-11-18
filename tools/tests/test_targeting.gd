extends RefCounted

## Tower targeting tactics: which enemy in range a Bolter or Beamer shoots.


func _spawn_three(kit : TestKit) -> Array[Enemy]:
	var enemies : Array[Enemy] = [kit.spawn_enemy("weakling"), kit.spawn_enemy("beefling"), kit.spawn_enemy("fastling")]
	await kit.frames(1)
	return enemies


func test_tactics_pick_their_enemy(kit : TestKit) -> void:
	await kit.load_level(1)
	var enemies : Array[Enemy] = await _spawn_three(kit)
	var weakling : Enemy = enemies[0]
	var beefling : Enemy = enemies[1]
	var fastling : Enemy = enemies[2]
	var tower_at : Vector2 = Vector2.ZERO
	weakling.global_position = tower_at + Vector2(16, 0)
	beefling.global_position = tower_at + Vector2(48, 0)
	fastling.global_position = tower_at + Vector2(32, 0)
	var candidates : Array[Node2D] = [weakling, beefling, fastling]
	kit.check(TargetPicker.pick(Utils.TargetTactic.Strongest, candidates, tower_at) == beefling, "Strongest: the beefling")
	kit.check(TargetPicker.pick(Utils.TargetTactic.Closest, candidates, tower_at) == weakling, "Closest: the weakling")
	kit.check(TargetPicker.pick(Utils.TargetTactic.Farthest, candidates, tower_at) == beefling, "Farthest: the beefling")
	kit.check(TargetPicker.pick(Utils.TargetTactic.Fastest, candidates, tower_at) == fastling, "Fastest: the fastling")
	var weakest : Enemy = TargetPicker.pick(Utils.TargetTactic.Weakest, candidates, tower_at)
	var least : float = INF
	for each in enemies:
		least = minf(least, each.stats.get_stat_value(Utils.StatType.Health))
	kit.check(weakest.stats.get_stat_value(Utils.StatType.Health) == least, "Weakest: the one with the least health")
	var last : Enemy = TargetPicker.pick(Utils.TargetTactic.Last, candidates, tower_at)
	var most_left : int = 0
	for each in enemies:
		most_left = maxi(most_left, each.get_remaining_path_waypoint_count())
	kit.check(last.get_remaining_path_waypoint_count() == most_left, "Last: the one farthest back on its road")
	weakling.die()
	kit.check(TargetPicker.pick(Utils.TargetTactic.Closest, candidates, tower_at) == fastling, "a dead enemy is never picked")


func test_tactics_cycle(kit : TestKit) -> void:
	var tactic : Utils.TargetTactic = Utils.TargetTactic.First
	var seen : Array[Utils.TargetTactic] = []
	for i in Utils.TargetTactic.size():
		seen.append(tactic)
		tactic = TargetPicker.next_tactic(tactic)
	kit.check(tactic == Utils.TargetTactic.First and seen.size() == Utils.TargetTactic.size(),
		"every tactic once, then back to First (%d)" % seen.size())
	kit.check(TargetPicker.MENU_ORDER.size() == Utils.TargetTactic.size(), "the Target menu lists every tactic")
	for each in TargetPicker.MENU_ORDER:
		kit.check(TargetPicker.TACTIC_NAMES.has(each) and TargetPicker.TACTIC_TOOLTIPS.has(each), "tactic %d has a name and a tooltip" % each)


func test_only_targeting_towers_choose(kit : TestKit) -> void:
	await kit.load_level(1)
	var cells : Array[Vector2i] = []
	for tower_name in ["puffe_bolter", "puffe_beamer", "puffe_nova"]:
		var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
			return not cells.has(c) and kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))
		cells.append(cell)
		var tower : Tower = await kit.place(tower_name, cell)
		kit.check(tower.can_choose_target == (tower_name != "puffe_nova"), "%s chooses its target: %s" % [tower_name, tower.can_choose_target])
