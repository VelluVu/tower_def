class_name Idle
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.animation_control.animation != actor.IDLE_ANIMATION:
		actor.animation_control.play(actor.IDLE_ANIMATION)
		return SUCCESS
	else:
		if not actor.animation_control.is_playing():
			actor.animation_control.play(actor.IDLE_ANIMATION)
		
	return SUCCESS
