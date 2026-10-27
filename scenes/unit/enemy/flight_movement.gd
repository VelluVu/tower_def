class_name FlightMovement
extends Node

## Makes its Enemy a flyer: a FlightPath route to the castle (through the spawner's flight_route) instead of the grid path,
## and its own movement step. The enemy keeps the guards that switch the ground behaviour off
## (maze, slow ground, turn pause, repaths, buildings, traps); the scene freezes the body
## (kinematic) so walls never push it.

@onready var enemy : Enemy = get_parent()

#global positions the flyer passes on its way, in order; set by the Spawner from its flight_route
var route_points : PackedVector2Array = []


func get_route(from : Vector2, to : Vector2) -> PackedVector2Array:
	var corners : PackedVector2Array = [from]
	corners.append_array(route_points)
	corners.append(to)
	return FlightPath.get_points(corners, randf())


#a frozen body ignores linear_velocity, so the flyer moves itself; spacing only counts other flyers
func move(move_direction : Vector2) -> void:
	var speed : float = enemy.stats.get_stat_value(Utils.StatType.Speed) * enemy.get_spacing_speed_factor(move_direction)
	enemy.velocity = speed * move_direction * enemy.current_time_scale
	var step : Vector2 = enemy.velocity * get_physics_process_delta_time()
	#never overshoot the waypoint, so a fast flyer at 3x does not circle it
	enemy.global_position += step.limit_length(enemy.global_position.distance_to(enemy.next_waypoint))
	enemy.last_position = enemy.global_position
	enemy.animation_control.flip_h = enemy.velocity.x <= 0
