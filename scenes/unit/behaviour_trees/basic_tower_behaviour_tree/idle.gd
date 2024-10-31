class_name Idle
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)
	return SUCCESS
