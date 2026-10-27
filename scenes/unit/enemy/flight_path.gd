class_name FlightPath
extends RefCounted

## The route of a flyer: straight lines from the spawn through the level's route points (if any)
## to the castle, with a gentle wave across them, ignoring the grid, the maze and the blocked tiles.
## The wave fades out at every corner, so the flyer passes each route point exactly.

#waypoints one tile apart, so tower targeting (fewest waypoints left) compares flyers and walkers fairly
const STEP : float = 16.0
#in pixels: three quarters of a tile to each side, one wave per eight tiles
const WAVE_AMPLITUDE : float = 12.0
const WAVE_LENGTH : float = 128.0


#corners: the spawn, the route points, the castle; phase 0-1 shifts the wave, so a group of
#flyers does not fly one line
static func get_points(corners : PackedVector2Array, phase : float) -> PackedVector2Array:
	var points : PackedVector2Array = []
	#the wave keeps going over the corners instead of starting again on every leg
	var flown : float = 0.0

	for corner in range(corners.size() - 1):
		var from : Vector2 = corners[corner]
		var to : Vector2 = corners[corner + 1]
		var length : float = from.distance_to(to)
		if is_zero_approx(length):
			continue

		var step_count : int = maxi(1, ceili(length / STEP))
		var across : Vector2 = from.direction_to(to).orthogonal()

		for i in range(1, step_count + 1):
			var t : float = float(i) / step_count
			var fade : float = sin(t * PI)
			var wave : float = sin(((flown + t * length) / WAVE_LENGTH + phase) * TAU)
			points.append(from.lerp(to, t) + across * wave * WAVE_AMPLITUDE * fade)

		flown += length

	return points
