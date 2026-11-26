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
	Utils.TargetTactic.Elite: "Elite",
	Utils.TargetTactic.Flyers: "Flyers",
	Utils.TargetTactic.Ground: "Ground",
}
const TACTIC_TOOLTIPS : Dictionary[Utils.TargetTactic, String] = {
	Utils.TargetTactic.First: "The enemy closest to the castle",
	Utils.TargetTactic.Last: "The enemy farthest back on its road",
	Utils.TargetTactic.Strongest: "The enemy with the most health left",
	Utils.TargetTactic.Weakest: "The enemy with the least health left",
	Utils.TargetTactic.Closest: "The enemy nearest to this tower",
	Utils.TargetTactic.Farthest: "The enemy farthest from this tower, still in range",
	Utils.TargetTactic.Fastest: "The fastest enemy",
	Utils.TargetTactic.Elite: "Bosses first, then elites, then the enemy with the most health left",
	Utils.TargetTactic.Flyers: "Flyers first, then the enemy closest to the castle",
	Utils.TargetTactic.Ground: "Enemies on foot first, then flyers; each by the one closest to the castle",
}
## Elite tactic: how far a boss or an elite ranks above the next kind (more than any enemy's health).
const ELITE_RANK_STEP : float = 1000000000.0
## A chained enemy, or one a harpoon flies at, ranks this far below the rest for a Harpooner (above every tactic's rank).
const HARPOONED_PENALTY : float = ELITE_RANK_STEP * 10.0
## A Harpooner's extra harpoons land within this many tiles of the main target (pick_cluster), plus CLUSTER_STEP_TILES
## per gold step bought on it and its area stat (SplashRadius, in tiles): the user, 2026-11-26.
const CLUSTER_TILES : float = 1.5
const CLUSTER_STEP_TILES : float = 0.5
## The order of the Target menu: road position, health, distance, speed.
const MENU_ORDER : Array[Utils.TargetTactic] = [Utils.TargetTactic.First, Utils.TargetTactic.Last,
	Utils.TargetTactic.Strongest, Utils.TargetTactic.Weakest, Utils.TargetTactic.Closest, Utils.TargetTactic.Farthest,
	Utils.TargetTactic.Fastest, Utils.TargetTactic.Elite, Utils.TargetTactic.Flyers, Utils.TargetTactic.Ground]


## reaches_submerged: an area tower (Nova, Mortar, Breather) may pick a submerged bog lurker, the others may not.
## avoids_harpooned: a Harpooner takes a chained enemy (or one a harpoon flies at) only when no other is in reach.
static func pick(tactic : Utils.TargetTactic, candidates : Array[Node2D], from_position : Vector2, reaches_submerged : bool = true,
		avoids_harpooned : bool = false) -> Node2D:
	var best : Node2D = null
	var best_score : float = -INF

	for candidate in candidates:
		if not is_pickable(candidate, reaches_submerged):
			continue
		var enemy : Enemy = candidate
		var score : float = _score(tactic, enemy, from_position)
		if avoids_harpooned and HarpoonTether.is_taken(enemy):
			score -= HARPOONED_PENALTY
		if score > best_score:
			best_score = score
			best = enemy

	return best


## Whether a tower may aim at it at all: a living enemy in sight (not dead, gone, burrowed, storm-hidden or phased; a
## submerged one only for the area towers).
static func is_pickable(candidate : Node2D, reaches_submerged : bool = true) -> bool:
	if not is_instance_valid(candidate) or candidate is not Enemy:
		return false
	var enemy : Enemy = candidate
	if enemy.is_dead or enemy.is_deactivated or enemy.is_burrowed or enemy.is_concealed or enemy.is_phased:
		return false
	return reaches_submerged or not enemy.is_submerged


## A Harpooner's extra harpoon (the user, 2026-11-26: the throw lands clustered round the main target, aimed[0]): the
## enemy nearest the main target within cluster_tiles, an unchained one before a chained one; null when none is that near.
static func pick_cluster(candidates : Array[Node2D], aimed : Array[Node2D], reaches_submerged : bool = true, cluster_tiles : float = CLUSTER_TILES) -> Node2D:
	if aimed.is_empty() or not is_instance_valid(aimed[0]):
		return null
	var centre : Vector2 = aimed[0].global_position
	var reach : float = cluster_tiles * Utils.TILE_SIZE
	var best : Node2D = null
	var best_score : float = -INF
	for candidate in candidates:
		if not is_pickable(candidate, reaches_submerged) or aimed.has(candidate):
			continue
		var distance : float = candidate.global_position.distance_to(centre)
		if distance > reach:
			continue
		var score : float = -distance - (HARPOONED_PENALTY if HarpoonTether.is_taken(candidate) else 0.0)
		if score > best_score:
			best_score = score
			best = candidate
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
		Utils.TargetTactic.Elite:
			#a boss outranks any elite, an elite any common enemy; health decides within each
			var rank : float = 2.0 if enemy.is_boss else 1.0 if enemy.get_node_or_null(NodePath(Elite.NAME)) != null else 0.0
			return rank * ELITE_RANK_STEP + enemy.stats.get_stat_value(Utils.StatType.Health)
		Utils.TargetTactic.Flyers:
			#any flyer outranks every enemy on the ground; the road decides within each
			return (ELITE_RANK_STEP if enemy.is_flying else 0.0) - float(enemy.get_remaining_path_waypoint_count())
		Utils.TargetTactic.Ground:
			return (0.0 if enemy.is_flying else ELITE_RANK_STEP) - float(enemy.get_remaining_path_waypoint_count())
	#First: the fewest waypoints left to the castle
	return -float(enemy.get_remaining_path_waypoint_count())
