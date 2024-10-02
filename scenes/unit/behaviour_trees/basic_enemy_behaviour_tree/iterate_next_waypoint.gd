class_name IterateNextWaypoint
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.iterate_next_waypoint()
	return SUCCESS
