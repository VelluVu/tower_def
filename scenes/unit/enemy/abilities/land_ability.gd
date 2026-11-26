class_name LandAbility
extends EnemyAbility

## The Ashen Wyrm comes down (LAND, once, in its health window; `land` also serves a Harpooner's harpoon): it stops being a flyer and walks the maze from where it
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
	#deferred: a harpoon lands it from inside a physics callback, where the body's mode cannot change
	flyer.set_deferred(&"freeze", false)
	var shadow : Node2D = flyer.get_node_or_null(SHADOW_NODE) as Node2D
	if shadow != null:
		shadow.hide()
	flyer.animation_control.z_index = 0
	#a flyer dragged down by a harpoon has no ground walk: it keeps flapping along the road
	if flyer.animation_control.sprite_frames.has_animation(GlobalAnimationNames.GROUND_WALK_ANIMATION):
		flyer.walk_animation = GlobalAnimationNames.GROUND_WALK_ANIMATION
	var grid : LevelGrid = flyer.level.grid
	var cell : Vector2i = flyer.grid_position
	#not into a wall or a tower, nor a pocket the maze walls in: a flyer dragged down over the maze landed inside a wall,
	#or shut in, and broke a wall to get out (bot checks, 2026-11-26)
	var castle : Vector2 = flyer.end_point.global_position
	if not grid.is_cell_free_to_walk(cell) or not grid.has_clear_route(cell, castle):
		cell = nearest_walkable(grid, cell, castle)
		flyer.global_position = grid.grid_position_to_world(cell)
	flyer.path_to(flyer.global_position, flyer.end_point.global_position)


## The nearest free cell, ring by ring; with castle, the nearest whose walk there needs no building broken (else the
## nearest free one).
static func nearest_walkable(grid : LevelGrid, from : Vector2i, castle : Variant = null) -> Vector2i:
	var fallback : Vector2i = from
	var has_fallback : bool = false
	for radius in range(1, SEARCH_CELLS + 1):
		var ring : Array[Vector2i] = []
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var cell : Vector2i = from + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == radius and grid.is_cell_free_to_walk(cell):
					ring.append(cell)
		ring.sort_custom(func(a : Vector2i, b : Vector2i) -> bool: return Vector2(a - from).length_squared() < Vector2(b - from).length_squared())
		for cell in ring:
			if castle == null or grid.has_clear_route(cell, castle):
				return cell
		if not has_fallback and not ring.is_empty():
			fallback = ring[0]
			has_fallback = true
	return fallback
