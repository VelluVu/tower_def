extends RefCounted

## Talents: open and removable nodes, one-way links, points per result, effects in a level.
## Ranks are set straight in the loaded progress, never through set_talent_rank, so no test saves.


func test_nodes_open_from_linked_ranks(kit : TestKit) -> void:
	var tree : TalentTree = _small_tree()
	kit.check(TalentRules.is_open(tree, {}, tree.get_node_by_id(&"s")), "the start is always open")
	kit.check(not TalentRules.is_open(tree, {}, tree.get_node_by_id(&"a")), "a node is closed until a linked node has a rank")
	kit.check(TalentRules.is_open(tree, {&"s": 1}, tree.get_node_by_id(&"a")), "a rank in the start opens its link")
	kit.check(TalentRules.is_open(tree, {&"s": 1, &"a": 1}, tree.get_node_by_id(&"s")), "links work both ways")
	kit.check(not TalentRules.can_add(tree, {&"s": 1}, tree.get_node_by_id(&"a"), 0), "no points, no rank")


func test_one_way_capstone_opens_nothing(kit : TestKit) -> void:
	var tree : TalentTree = _small_tree()
	var ranks : Dictionary = {&"s": 1, &"a": 1, &"k": 1}
	kit.check(TalentRules.is_open(tree, {&"s": 1, &"a": 1}, tree.get_node_by_id(&"k")), "a T3 opens the capstone")
	kit.check(not TalentRules.is_open(tree, ranks, tree.get_node_by_id(&"c")), "the capstone does not open another route's T3")
	kit.check(not TalentRules.can_remove(tree, ranks, tree.get_node_by_id(&"a")), "the way to a learned capstone stays")
	kit.check(TalentRules.can_remove(tree, ranks, tree.get_node_by_id(&"k")), "the capstone itself can go")


func test_needs_and_ranks(kit : TestKit) -> void:
	var tree : TalentTree = _small_tree()
	kit.check(not TalentRules.is_open(tree, {&"s": 1}, tree.get_node_by_id(&"n")), "a node waits for the node it needs")
	kit.check(TalentRules.is_open(tree, {&"s": 1, &"a": 1}, tree.get_node_by_id(&"n")), "and opens once that has a rank")
	kit.check(TalentRules.can_remove(tree, {&"s": 2, &"a": 1}, tree.get_node_by_id(&"s")), "an extra rank can always go")
	kit.check(not TalentRules.can_remove(tree, {&"s": 1, &"a": 1}, tree.get_node_by_id(&"s")), "the start's last rank holds the tree")


func test_points_for_result(kit : TestKit) -> void:
	kit.check(TalentRules.points_for_result(1.0, 10.0, 0, 5) == 1, "a clear is 1 point")
	kit.check(TalentRules.points_for_result(5.0, 10.0, 0, 5) == 2, "half the lives left")
	kit.check(TalentRules.points_for_result(10.0, 10.0, 0, 5) == 3, "no lives lost")
	kit.check(TalentRules.points_for_result(10.0, 10.0, 3, 5) == 4, "half the early starts")
	kit.check(TalentRules.points_for_result(10.0, 10.0, 5, 5) == 5, "every early start")
	kit.check(TalentRules.points_for_result(10.0, 10.0, 0, 0) == 3, "a one-wave level has no early start points")


func test_building_talents_in_a_level(kit : TestKit) -> void:
	var progress : ProgressData = PlayerProgress._save.progress
	var saved_ranks : Dictionary[StringName, Dictionary] = progress.talent_ranks
	progress.talent_ranks = {&"building": {&"war_chest": 2, &"hardened_shots": 1, &"thick_walls": 1}}

	await kit.load_level(1)
	kit.check_near(kit.level.player_stats.gold, kit.level_data(1).starting_gold + 2.0, "War Chest adds start gold")
	var bolter : Building = await kit.place("puffe_bolter", Vector2i(12, 6))
	var base_damage : float = bolter.skill.stats.get_stat_value(Utils.StatType.Damage) / 1.08
	kit.check(bolter.modifier_manager != null and kit.level.talents.applied_modifiers[bolter].size() == 1, "one talent fits a Physical Bolter")
	var wall : Building = await kit.place("wall", Vector2i(14, 6))
	kit.check(kit.level.talents.applied_modifiers[wall].size() == 1, "one talent fits a wall")
	kit.check_near(wall.stats.get_stat_value(Utils.StatType.Health), wall.stats.get_stat_value(Utils.StatType.MaxHealth), "a new wall starts at its raised max health")
	kit.check(base_damage > 0.0, "the Bolter deals damage")

	progress.talent_ranks = saved_ranks


func test_every_tree_is_whole(kit : TestKit) -> void:
	var book : TalentBook = load("res://scenes/talents/talent_book.tres")
	kit.check(book.trees.size() == 4, "four trees")

	for tree in book.trees:
		kit.check(tree.get_node_by_id(tree.start_id) != null, tree.id + " has its start")
		var opens : Dictionary[StringName, Array] = TalentRules.get_opens(tree)
		var reached : Dictionary[StringName, bool] = {tree.start_id: true}
		var queue : Array[StringName] = [tree.start_id]
		while not queue.is_empty():
			for next_id in opens.get(queue.pop_front(), []):
				if not reached.has(next_id):
					reached[next_id] = true
					queue.append(next_id)

		var broken : Array[String] = []
		for node in tree.nodes:
			for linked_id in node.links + node.one_way_links + ([node.needs] if node.needs != &"" else []):
				if tree.get_node_by_id(linked_id) == null:
					broken.append("%s -> %s" % [node.id, linked_id])
			if not reached.has(node.id):
				broken.append("%s unreachable" % node.id)
			for target_id in node.one_way_links:
				if not opens.get(target_id, []).is_empty():
					broken.append("%s opens something" % target_id)
		kit.check(broken.is_empty(), "%s links are whole: %s" % [tree.id, ", ".join(broken)])


#s (start) - a, s - b - c, n - s (n needs a); a is one route's T3, c another's; both open k one way.
func _small_tree() -> TalentTree:
	var tree : TalentTree = TalentTree.new()
	tree.start_id = &"s"
	tree.nodes = [_node(&"s", [&"a", &"b"], []), _node(&"a", [], [&"k"]), _node(&"c", [], [&"k"]), _node(&"k", [], []), _node(&"n", [&"s"], []), _node(&"b", [&"c"], [])]
	tree.nodes[0].max_rank = 3
	tree.nodes[4].needs = &"a"
	return tree


func _node(id : StringName, links : Array[StringName], one_way : Array[StringName]) -> TalentNode:
	var node : TalentNode = TalentNode.new()
	node.id = id
	node.links = links
	node.one_way_links = one_way
	return node
