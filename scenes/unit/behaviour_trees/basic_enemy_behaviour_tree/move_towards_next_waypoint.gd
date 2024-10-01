class_name MoveTowardsNextWaypoint
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.animated_sprite.play(actor.WALK_ANIMATION)
	actor.velocity = actor.stats_manager.stats.speed * actor.global_position.direction_to(actor.next_waypoint)
	actor.linear_velocity = actor.velocity
	actor.last_position = actor.global_position
	return SUCCESS
