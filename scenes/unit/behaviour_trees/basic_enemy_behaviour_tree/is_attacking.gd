class_name IsAttacking
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.animation_control.animation == GlobalAnimationNames.ATTACK_ANIMATION and actor.animation_control.is_playing():
		return SUCCESS
	return FAILURE
