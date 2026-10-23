@tool
class_name FollowPath
extends ActionLeaf

## Walks the actor along its path: finds one when missing, steps to the next waypoint,
## reports the castle reached. Fails when a building blocks the way or the path ends
## short of the castle, so the tree can attack or idle instead.


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if not actor.has_path:
		actor.path_to(actor.global_position, actor.end_point.global_position)
		return FAILURE if actor.point_path.is_empty() else SUCCESS

	if actor.is_waypoint_reached():
		if not actor.is_last_waypoint():
			actor.iterate_next_waypoint()
			return SUCCESS
		if actor.is_end_point_in_reach():
			actor.is_the_end_point_reached = true
			return RUNNING
		return FAILURE

	if actor.get_building_in_next_waypoint() != null or actor.is_colliding_building:
		return FAILURE

	actor.move_towards_next_waypoint()
	return SUCCESS
