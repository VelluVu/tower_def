class_name Dead
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.die()
	return RUNNING
