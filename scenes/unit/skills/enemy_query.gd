class_name EnemyQuery
extends RefCounted

## Finds enemies near a point for skills that hop between targets (ricochets, beam chains).


## The living enemy closest to from within max_distance (pixels), skipping exclude; null if none.
static func closest_enemy(tree : SceneTree, from : Vector2, max_distance : float, exclude : Array) -> Enemy:
	var closest : Enemy = null
	var closest_distance : float = max_distance * max_distance

	for node in tree.get_nodes_in_group(GroupNames.ENEMIES):
		var enemy : Enemy = node as Enemy
		if not is_hittable(enemy) or exclude.has(enemy):
			continue

		var distance : float = from.distance_squared_to(enemy.body_center)
		if distance <= closest_distance:
			closest = enemy
			closest_distance = distance

	return closest


static func is_hittable(enemy : Enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.is_dead and not enemy.is_deactivated and not enemy.is_burrowed
