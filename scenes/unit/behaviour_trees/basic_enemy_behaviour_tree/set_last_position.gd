class_name SetLastPosition
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.last_position = actor.global_position
	return SUCCESS
