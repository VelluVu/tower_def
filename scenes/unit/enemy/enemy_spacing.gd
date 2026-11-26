class_name EnemySpacing
extends RefCounted
## Keeps enemies from stacking on the grid path: a fixed lane offset inside the tile
## and a speed factor that queues an enemy behind the ones in front of it.


const MAX_LANE_OFFSET : float = 4.0
const SPACING_RADIUS : float = 8.0
const MIN_SPEED_FACTOR : float = 0.5
const MAX_SPEED_FACTOR : float = 1.2
#an enemy at least this much faster than the one in front walks past it instead of queueing
#(they never collide), so fastlings do not bunch up behind a brute (2026-11-26)
const PASS_SPEED_RATIO : float = 1.15


## Largest offset that keeps a body of the radius inside its tile,
## including the distance it may still be from a waypoint when it turns.
static func get_max_lane_offset(body_radius : float, turn_distance : float) -> float:
	return clampf(Utils.TILE_SIZE * 0.5 - body_radius - turn_distance, 0.0, MAX_LANE_OFFSET)


## Random offset in a square of +-max_offset; roll_x and roll_y are 0..1.
static func roll_lane_offset(max_offset : float, roll_x : float, roll_y : float) -> Vector2:
	return Vector2(lerpf(-max_offset, max_offset, roll_x), lerpf(-max_offset, max_offset, roll_y))


## Speed multiplier along the move direction: neighbours in front slow down, neighbours behind
## speed up a little. Only along the path, so the lane offset keeps the enemy inside its tile.
## With speeds given (one per neighbour), a clearly slower neighbour in front is passed, not queued behind.
static func get_speed_factor(position : Vector2, move_direction : Vector2, neighbour_positions : Array[Vector2],
		neighbour_speeds : Array[float] = [], own_speed : float = 0.0) -> float:
	var push : float = 0.0

	for index in neighbour_positions.size():
		var offset : Vector2 = position - neighbour_positions[index]
		var distance : float = offset.length()
		if distance >= SPACING_RADIUS or distance <= 0.0:
			continue
		var along : float = (offset / distance).dot(move_direction)
		if along < 0.0 and index < neighbour_speeds.size() and own_speed >= neighbour_speeds[index] * PASS_SPEED_RATIO:
			continue
		push += along * (1.0 - distance / SPACING_RADIUS)

	return clampf(1.0 + push, MIN_SPEED_FACTOR, MAX_SPEED_FACTOR)
