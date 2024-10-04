class_name PathAroundObstacle
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	var optimal_cell : Vector2i = actor.get_optimal_cell_to_move()
	
	if optimal_cell == Utils.BAD_CELL:
		actor.clear_path()
		return FAILURE
	
	actor.point_path.append(actor.level.grid_position_to_world(optimal_cell))
	
	return SUCCESS
