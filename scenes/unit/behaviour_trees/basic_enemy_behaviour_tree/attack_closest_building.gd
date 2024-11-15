class_name AttackClosestBuilding
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if not actor.skill.is_ready:
		return FAILURE
	
	var building : Building = actor.get_building_in_next_waypoint()
	#check if there is a path before start attacking closest building?
	if building == null:
		building = actor.get_closest_building()
		if building == null:
			return FAILURE
		
	actor.skill.use(building)
	return SUCCESS
