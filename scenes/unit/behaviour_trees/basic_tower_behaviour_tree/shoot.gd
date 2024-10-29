class_name Shoot
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if not actor.skill.is_ready:
		return FAILURE
	
	if actor.skill.is_ready:
		actor.animation_control.play_animation(actor.ATTACK_ANIMATION, actor.skill.total_duration)
		actor.skill.use(actor.target)
		
	return SUCCESS
