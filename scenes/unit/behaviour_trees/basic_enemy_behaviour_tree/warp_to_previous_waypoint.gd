class_name WarpToPreviousWaypoint
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.global_position = actor.get_first_nearby_free_position()
	actor.collision_body = null
	actor.clear_path()
	return SUCCESS
