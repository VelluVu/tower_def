class_name FindNewPath
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.path_to(actor.global_position, actor.end_point.global_position)
	if actor.point_path.is_empty():
		return FAILURE
	return SUCCESS
