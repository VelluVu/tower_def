class_name Idle
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.animation_control.is_current_animation_finished:
		actor.animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)
	return SUCCESS
