class_name IsBuildingInMoveDirection
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	var actor_cell_position : Vector2i = actor.level.world_position_to_grid(actor.global_position)
	var move_direction : Vector2i = (actor_cell_position - actor.level.world_position_to_grid(actor.movement_history[0]))
	if actor.level.has_building_in_cell_position(actor_cell_position + move_direction):
		return SUCCESS
	return FAILURE
	
