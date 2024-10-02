class_name PathAroundObstacle
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	var actor_cell_position : Vector2i = actor.level.world_position_to_grid(actor.global_position)
	var closest_cell : Vector2i = actor.get_closest_cell()
	
	if closest_cell == Vector2i(-9999,-9999):
		return FAILURE
	
	actor.point_path.append(actor.level.grid_position_to_world(closest_cell))
	actor.update_movement_history()
	actor.next_waypoint = actor.point_path[actor.current_waypoint_index]
	
	return SUCCESS
