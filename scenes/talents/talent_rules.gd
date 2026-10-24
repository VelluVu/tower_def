class_name TalentRules
extends RefCounted

## Static talent rules: which nodes are open, which ranks can be added or removed, and how many
## talent points a level result earns. ranks maps a node id to its rank in one tree.

const MAX_POINTS_PER_LEVEL : int = 5


## node id -> the node ids a rank in it opens.
static func get_opens(tree : TalentTree) -> Dictionary[StringName, Array]:
	var opens : Dictionary[StringName, Array] = {}

	for node in tree.nodes:
		if not opens.has(node.id):
			opens[node.id] = []

		for linked_id in node.links:
			opens[node.id].append(linked_id)

			if not opens.has(linked_id):
				opens[linked_id] = []
			opens[linked_id].append(node.id)

		for target_id in node.one_way_links:
			opens[node.id].append(target_id)

	return opens


static func get_rank(ranks : Dictionary, node_id : StringName) -> int:
	return ranks.get(node_id, 0)


static func is_open(tree : TalentTree, ranks : Dictionary, node : TalentNode) -> bool:
	if not _needs_met(node, ranks):
		return false

	if node.id == tree.start_id:
		return true

	var opens : Dictionary[StringName, Array] = get_opens(tree)

	for other_id in opens:
		if get_rank(ranks, other_id) > 0 and opens[other_id].has(node.id):
			return true

	return false


static func can_add(tree : TalentTree, ranks : Dictionary, node : TalentNode, unspent_points : int) -> bool:
	return unspent_points > 0 and get_rank(ranks, node.id) < node.max_rank and is_open(tree, ranks, node)


## The last rank of a node can only go if every learned node stays reachable from the start
## and keeps the node it needs.
static func can_remove(tree : TalentTree, ranks : Dictionary, node : TalentNode) -> bool:
	var rank : int = get_rank(ranks, node.id)

	if rank == 0:
		return false

	if rank > 1:
		return true

	var after : Dictionary = ranks.duplicate()
	after.erase(node.id)

	if after.is_empty():
		return true

	if get_rank(after, tree.start_id) == 0:
		return false

	var opens : Dictionary[StringName, Array] = get_opens(tree)
	var reached : Dictionary[StringName, bool] = {tree.start_id: true}
	var queue : Array[StringName] = [tree.start_id]

	while not queue.is_empty():
		for next_id in opens.get(queue.pop_front(), []):
			if get_rank(after, next_id) > 0 and not reached.has(next_id):
				reached[next_id] = true
				queue.append(next_id)

	for learned_id in after:
		if get_rank(after, learned_id) == 0:
			continue

		var learned : TalentNode = tree.get_node_by_id(learned_id)

		if not reached.has(learned_id) or (learned != null and not _needs_met(learned, after)):
			return false

	return true


static func get_spent(ranks : Dictionary) -> int:
	var spent : int = 0

	for node_id in ranks:
		spent += ranks[node_id]

	return spent


## 1 for the clear, 1 for half the lives left, 1 for no lives lost, 1 for starting at least half
## of the waves that could start early, 1 for starting all of them (placeholder thresholds).
static func points_for_result(life_left : float, starting_life : float, early_starts : int, early_start_chances : int) -> int:
	var points : int = 1

	if life_left * 2.0 >= starting_life:
		points += 1

	if life_left >= starting_life:
		points += 1

	if early_start_chances > 0 and early_starts * 2 >= early_start_chances:
		points += 1

	if early_start_chances > 0 and early_starts >= early_start_chances:
		points += 1

	return mini(points, MAX_POINTS_PER_LEVEL)


## The points a cleared level earns with its lives left and early starts. The first wave never
## starts early, so a level of n waves has n - 1 chances.
static func points_for_level(level : Level) -> int:
	var starting_life : float = level.level_data.starting_life if level.level_data != null else level.player_stats.life
	return points_for_result(level.player_stats.life, starting_life, level.early_starts, maxi(level.wave_runner.wave_count - 1, 0))


static func _needs_met(node : TalentNode, ranks : Dictionary) -> bool:
	return node.needs == &"" or get_rank(ranks, node.needs) > 0
