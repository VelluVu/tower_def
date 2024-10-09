class_name EndPointIsReached
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.is_the_end_point_reached = true
	return RUNNING
