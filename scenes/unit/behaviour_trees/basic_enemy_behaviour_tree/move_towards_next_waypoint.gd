@tool
class_name MoveTowardsNextWaypoint
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.animation_control.play_animation(GlobalAnimationNames.WALK_ANIMATION)
	var move_direction : Vector2 = actor.global_position.direction_to(actor.next_waypoint)
	var speed : float = actor.stats.get_stat_value(Utils.StatType.Speed) * actor.get_spacing_speed_factor(move_direction)
	actor.velocity = speed * move_direction * actor.current_time_scale
	actor.linear_velocity = actor.velocity
	actor.last_position = actor.global_position
	return SUCCESS
