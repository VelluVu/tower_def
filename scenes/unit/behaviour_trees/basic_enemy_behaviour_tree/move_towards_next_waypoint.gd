class_name MoveTowardsNextWaypoint
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.velocity = actor.stats_manager.stats.speed * actor.global_position.direction_to(actor.next_waypoint)
	actor.linear_velocity = actor.velocity
	return SUCCESS
