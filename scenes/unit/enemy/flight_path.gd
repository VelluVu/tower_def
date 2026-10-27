class_name FlightPath
extends RefCounted

## The route of a flyer: a straight line from the spawn to the castle with a gentle wave
## across it, ignoring the grid, the maze and the blocked tiles. The wave fades out at both
## ends, so the flyer leaves its spawn and reaches the castle on the line.

#waypoints one tile apart, so tower targeting (fewest waypoints left) compares flyers and walkers fairly
const STEP : float = 16.0
#in pixels: three quarters of a tile to each side, one wave per eight tiles
const WAVE_AMPLITUDE : float = 12.0
const WAVE_LENGTH : float = 128.0


#phase 0-1 shifts the wave, so a group of flyers does not fly one line
static func get_points(from : Vector2, to : Vector2, phase : float) -> PackedVector2Array:
	var points : PackedVector2Array = []
	var length : float = from.distance_to(to)
	var step_count : int = maxi(1, ceili(length / STEP))
	var across : Vector2 = from.direction_to(to).orthogonal()

	for i in range(1, step_count + 1):
		var t : float = float(i) / step_count
		var fade : float = sin(t * PI)
		var wave : float = sin((t * length / WAVE_LENGTH + phase) * TAU)
		points.append(from.lerp(to, t) + across * wave * WAVE_AMPLITUDE * fade)

	return points
