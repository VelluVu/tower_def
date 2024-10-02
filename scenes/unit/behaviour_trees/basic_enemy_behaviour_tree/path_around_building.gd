class_name PathAroundBuilding
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	var closest_cell : Vector2i = actor.get_closest_cell()
	
	if closest_cell == null:
		return FAILURE
	
	var actor_cell_position : Vector2i = actor.level.world_position_to_grid(actor.global_position)
	var move_direction : Vector2i = (closest_cell - actor_cell_position)
	var cell_behind_tower : Vector2i = closest_cell + move_direction
	var to_position : Vector2 = actor.level.grid_position_to_world(cell_behind_tower)
	
	if actor.movement_history.has(to_position):
		return FAILURE
	
	if not actor.level.astar_grid.is_in_boundsv(cell_behind_tower):
		print("cell behind tower is not in bounds of astar grid: ", cell_behind_tower, " pos: ", to_position)
		to_position = actor.end_point.global_position
	
	actor.point_path = actor.level.find_path(actor.level.snap_position_to_grid(actor.global_position), to_position)
	
	if actor.point_path.size() <= 1:
		if actor.point_path.is_empty():
			actor.point_path.append(actor.level.snap_position_to_grid(actor.global_position))
			actor.current_waypoint_index = 1
		return FAILURE
	
	actor.current_waypoint_index = 0
	actor.next_waypoint = actor.point_path[actor.current_waypoint_index]
	
	return SUCCESS
