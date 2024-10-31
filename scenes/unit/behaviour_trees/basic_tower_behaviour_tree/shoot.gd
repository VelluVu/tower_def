class_name Shoot
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.skill.use(actor.target)
	return SUCCESS
