class_name EmitPathNotBlocked
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	GameSignals.enemy_path_blocked_change.emit(false)
	actor.is_pathing_around_obstacle = false
	return SUCCESS
