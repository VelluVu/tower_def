class_name WarpToPreviousWaypoint
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.global_position = actor.previous_waypoint
	actor.collision_body = null
	return SUCCESS
