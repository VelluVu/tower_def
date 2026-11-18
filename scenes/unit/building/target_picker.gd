class_name TargetPicker
extends RefCounted

## Which enemy in range a tower shoots, by its targeting tactic (Utils.TargetTactic, set per tower in the
## selection panel). Dead, gone, burrowed and storm-hidden enemies are never picked.

const TACTIC_NAMES : Dictionary[Utils.TargetTactic, String] = {
	Utils.TargetTactic.First: "First",
	Utils.TargetTactic.Strongest: "Strongest",
	Utils.TargetTactic.Closest: "Closest",
	Utils.TargetTactic.Farthest: "Farthest",
	Utils.TargetTactic.Fastest: "Fastest",
	Utils.TargetTactic.Weakest: "Weakest",
	Utils.TargetTactic.Last: "Last",
}
const TACTIC_TOOLTIPS : Dictionary[Utils.TargetTactic, String] = {
	Utils.TargetTactic.First: "The enemy closest to the castle",
	Utils.TargetTactic.Last: "The enemy farthest back on its road",
	Utils.TargetTactic.Strongest: "The enemy with the most health left",
	Utils.TargetTactic.Weakest: "The enemy with the least health left",
	Utils.TargetTactic.Closest: "The enemy nearest to this tower",
	Utils.TargetTactic.Farthest: "The enemy farthest from this tower, still in range",
	Utils.TargetTactic.Fastest: "The fastest enemy",
}
## The order of the Target menu: road position, health, distance, speed.
const MENU_ORDER : Array[Utils.TargetTactic] = [Utils.TargetTactic.First, Utils.TargetTactic.Last,
	Utils.TargetTactic.Strongest, Utils.TargetTactic.Weakest, Utils.TargetTactic.Closest, Utils.TargetTactic.Farthest,
	Utils.TargetTactic.Fastest]


static func pick(tactic : Utils.TargetTactic, candidates : Array[Node2D], from_position : Vector2) -> Node2D:
	var best : Node2D = null
	var best_score : float = -INF

	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate is not Enemy:
			continue
		var enemy : Enemy = candidate
		if enemy.is_dead or enemy.is_deactivated or enemy.is_burrowed or enemy.is_concealed:
			continue
		var score : float = _score(tactic, enemy, from_position)
		if score > best_score:
			best_score = score
			best = enemy

	return best


## The tactic after this one in the menu's order, back to the first after the last.
static func next_tactic(tactic : Utils.TargetTactic) -> Utils.TargetTactic:
	return MENU_ORDER[(MENU_ORDER.find(tactic) + 1) % MENU_ORDER.size()]


#higher is better
static func _score(tactic : Utils.TargetTactic, enemy : Enemy, from_position : Vector2) -> float:
	match tactic:
		Utils.TargetTactic.Strongest:
			return enemy.stats.get_stat_value(Utils.StatType.Health)
		Utils.TargetTactic.Closest:
			return -from_position.distance_squared_to(enemy.global_position)
		Utils.TargetTactic.Farthest:
			return from_position.distance_squared_to(enemy.global_position)
		Utils.TargetTactic.Fastest:
			return enemy.stats.get_stat_value(Utils.StatType.Speed)
		Utils.TargetTactic.Weakest:
			return -enemy.stats.get_stat_value(Utils.StatType.Health)
		Utils.TargetTactic.Last:
			return float(enemy.get_remaining_path_waypoint_count())
	#First: the fewest waypoints left to the castle
	return -float(enemy.get_remaining_path_waypoint_count())
