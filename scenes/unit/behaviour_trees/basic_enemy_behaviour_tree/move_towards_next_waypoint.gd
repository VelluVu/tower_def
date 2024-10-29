class_name MoveTowardsNextWaypoint
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.animation_control.animation != actor.WALK_ANIMATION:
		actor.animation_control.play(actor.WALK_ANIMATION)
	var move_direction : Vector2 = actor.global_position.direction_to(actor.next_waypoint)
	actor.velocity = actor.stats_manager.stats.speed * move_direction * actor.current_time_scale
	actor.linear_velocity = actor.velocity
	actor.last_position = actor.global_position
	return SUCCESS
