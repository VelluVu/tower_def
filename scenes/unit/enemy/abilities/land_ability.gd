class_name LandAbility
extends EnemyAbility

## The Ashen Wyrm comes down (LAND, once, in its health window): it stops being a flyer and walks the maze from where it
## landed (GROUND_WALK). Over lava or rock it lands on the nearest cell it can walk on.

const SHADOW_NODE : String = "Shadow"
## How far (cells) to look for ground it can walk on.
const SEARCH_CELLS : int = 6


func _can_use() -> bool:
	return enemy != null and enemy.is_flying


func _run() -> void:
	if not await _play_and_wait(GlobalAnimationNames.LAND_ANIMATION):
		return
	land(enemy)
	_finish()


static func land(flyer : Enemy) -> void:
	if not flyer.is_flying:
		return
	flyer.flight_movement.queue_free()
	flyer.flight_movement = null
	flyer.freeze = false
	var shadow : Node2D = flyer.get_node_or_null(SHADOW_NODE) as Node2D
	if shadow != null:
		shadow.hide()
	flyer.animation_control.z_index = 0
	flyer.walk_animation = GlobalAnimationNames.GROUND_WALK_ANIMATION
	var grid : LevelGrid = flyer.level.grid
	var cell : Vector2i = flyer.grid_position
	if not grid.is_cell_walkable(cell):
		cell = nearest_walkable(grid, cell)
		flyer.global_position = grid.grid_position_to_world(cell)
	flyer.path_to(flyer.global_position, flyer.end_point.global_position)


static func nearest_walkable(grid : LevelGrid, from : Vector2i) -> Vector2i:
	for radius in range(1, SEARCH_CELLS + 1):
		var best : Vector2i = from
		var found : bool = false
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var cell : Vector2i = from + Vector2i(dx, dy)
				if grid.is_cell_walkable(cell) and (not found or Vector2(dx, dy).length() < Vector2(best - from).length()):
					best = cell
					found = true
		if found:
			return best
	return from
