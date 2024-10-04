class_name PathAroundBuilding
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	var actor_cell_position : Vector2i = actor.level.world_position_to_grid(actor.global_position)
	var actor_last_cell_position : Vector2i = actor.level.world_position_to_grid(actor.movement_history[0])
	var move_direction : Vector2i = (actor_cell_position - actor_last_cell_position)
	var tower_cell : Vector2i = actor_cell_position + move_direction
	var cell_behind_tower : Vector2i = tower_cell + move_direction
	var to_position : Vector2 = actor.level.grid_position_to_world(cell_behind_tower)
	
	if not actor.level.astar_grid.is_in_boundsv(cell_behind_tower):
		print("cell behind tower is not in bounds of astar grid: ", cell_behind_tower, " pos: ", to_position)
		
		to_position = actor.level.grid_position_to_world(actor.get_optimal_cell_to_move())
	
	actor.point_path = actor.level.find_path(actor.level.snap_position_to_grid(actor.global_position), to_position)
	
	if actor.point_path.size() <= 1:
		if actor.point_path.is_empty():
			actor.point_path.clear()
			actor.point_path.append(actor.level.grid_position_to_world(tower_cell))
			actor.update_movement_history()
			actor.current_waypoint_index = 0
			actor.next_waypoint = actor.point_path[actor.current_waypoint_index]
		return FAILURE
	
	actor.update_movement_history()
	actor.current_waypoint_index = 0
	actor.next_waypoint = actor.point_path[actor.current_waypoint_index]
	
	return SUCCESS
