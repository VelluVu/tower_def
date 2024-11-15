class_name NullSkillTarget
extends ActionLeaf


func tick(_actor : Node, _blackboard : Blackboard) -> int:
	_actor.target = null
	_actor.skill.target = null
	return SUCCESS
