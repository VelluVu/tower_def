class_name BurrowAbility
extends EnemyAbility

## Dig Up (the Broodmother at 66-33%): burrows out of reach, comes up further along her path
## and leaves a short-lived tunnel that sends a few enemies from where she came up.

@export var hidden_time : float = 2.5
## How many path cells further she comes up, rolled between these.
@export var min_cells_ahead : int = 5
@export var max_cells_ahead : int = 9
## She never comes up closer to the castle than this many path cells.
@export var castle_margin : int = 4
@export var tunnel_scene : PackedScene
@export var tunnel_count : int = 2


func _run() -> void:
	if not await _play_and_wait(GlobalAnimationNames.BURROW_ANIMATION):
		return

	enemy.set_burrowed(true)
	if not await _wait(hidden_time):
		return

	var emerge_position : Vector2 = _get_emerge_position(randi_range(min_cells_ahead, max_cells_ahead))
	enemy.global_position = emerge_position
	enemy.set_burrowed(false)
	enemy.path_to(emerge_position, enemy.end_point.global_position)

	if tunnel_scene != null:
		EnemySummon.summon_around(tunnel_scene, enemy, tunnel_count, enemy.level.grid.world_position_to_grid(emerge_position))

	await _play_and_wait(GlobalAnimationNames.EMERGE_ANIMATION)
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
