class_name IsBuildingInClosestCell
extends ConditionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	var closest_cell : Vector2 = actor.get_closest_cell()
	if actor.level.has_building_in_cell_position(closest_cell):
		return SUCCESS
	return FAILURE
