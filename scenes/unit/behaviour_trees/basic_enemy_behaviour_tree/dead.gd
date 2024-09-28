class_name Dead
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.Die()
	return SUCCESS
