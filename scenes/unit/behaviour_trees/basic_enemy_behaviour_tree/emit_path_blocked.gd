class_name EmitPathBlocked
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.is_pathing_around_obstacle = true
	GameSignals.enemy_path_blocked_change.emit(true)
	return SUCCESS
