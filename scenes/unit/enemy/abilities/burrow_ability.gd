class_name BurrowAbility
extends EnemyAbility

## Dig Up (the Broodmother at 66-33%), Submerge (the Bog Hydra), the burrower's dig and the leaper
## frog's leap: goes out of reach, comes up further along its path and may send a few enemies from
## where it came up (a tunnel, leeches).

@export var hidden_time : float = 2.5
## How many path cells further she comes up, rolled between these.
@export var min_cells_ahead : int = 5
@export var max_cells_ahead : int = 9
## She never comes up closer to the castle than this many path cells.
@export var castle_margin : int = 4
## Comes up where the fewest towers reach (the nearest such cell between min and max cells ahead) instead of
## at a rolled distance: a defence in one cluster gets dug past, one spread along the path keeps hitting
## (the Broodmother, 2026-11-20: two Beamers in one spot used to beat her).
@export var seeks_weak_spot : bool = false
@export var tunnel_scene : PackedScene
@export var tunnel_count : int = 2
@export var burrow_animation : String = GlobalAnimationNames.BURROW_ANIMATION
@export var emerge_animation : String = GlobalAnimationNames.EMERGE_ANIMATION


func _run() -> void:
	#an empty name: no animation (a variant enemy without the tags), straight under
	if not burrow_animation.is_empty() and not await _play_and_wait(burrow_animation):
		return

	enemy.set_burrowed(true)
	if not await _wait(hidden_time):
		return

	var emerge_position : Vector2 = _get_weak_spot() if seeks_weak_spot else _get_emerge_position(randi_range(min_cells_ahead, max_cells_ahead))
	enemy.global_position = emerge_position
	enemy.set_burrowed(false)
	enemy.path_to(emerge_position, enemy.end_point.global_position)

	if tunnel_scene != null:
		EnemySummon.summon_around(tunnel_scene, enemy, tunnel_count, enemy.level.grid.world_position_to_grid(emerge_position))

	if not emerge_animation.is_empty():
		await _play_and_wait(emerge_animation)
	_finish()


#a free cell on her own path, so she always comes up on the way to the castle
func _get_emerge_position(cells_ahead : int) -> Vector2:
	var path : PackedVector2Array = enemy.point_path
	var here : Vector2 = enemy.level.grid.snap_position_to_grid(enemy.global_position)
	if path.is_empty():
		return here

	var last : int = path.size() - 1 - castle_margin
	var index : int = mini(enemy.current_waypoint_index + cells_ahead, last)

	while index > enemy.current_waypoint_index:
		if enemy.level.grid.get_building_from_world_position(path[index]) == null:
			return path[index]
		index -= 1

	return here


## The free cell on her path, min to max cells ahead, that the fewest towers reach; the nearest one on a tie.
func _get_weak_spot() -> Vector2:
	var path : PackedVector2Array = enemy.point_path
	if path.is_empty():
		return enemy.level.grid.snap_position_to_grid(enemy.global_position)
	var last : int = path.size() - 1 - castle_margin
	var first : int = mini(enemy.current_waypoint_index + min_cells_ahead, last)
	var towers : Array[Tower] = []
	for building in enemy.level.all_buildings:
		if is_instance_valid(building) and building is Tower:
			towers.append(building)

	var best_index : int = -1
	var best_count : int = 0
	for index in range(first, mini(enemy.current_waypoint_index + max_cells_ahead, last) + 1):
		if enemy.level.grid.get_building_from_world_position(path[index]) != null:
			continue
		var count : int = count_towers_reaching(towers, path[index])
		if best_index < 0 or count < best_count:
			best_index = index
			best_count = count
	if best_index < 0:
		return _get_emerge_position(min_cells_ahead)
	return path[best_index]


static func count_towers_reaching(towers : Array[Tower], point : Vector2) -> int:
	var count : int = 0
	for tower in towers:
		var shape : CircleShape2D = tower.area_shape.shape as CircleShape2D if tower.area_shape != null else null
		if shape != null and tower.global_position.distance_to(point) <= shape.radius:
			count += 1
	return count
