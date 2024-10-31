class_name SelectTarget
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	var new_target = actor.get_closest_target_to_end()
	
	if new_target != null:
		#print(new_target.name)
		actor.target = new_target
		#actor.skill.target = actor.target
		return SUCCESS
		
	return FAILURE
