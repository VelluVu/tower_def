class_name AttackClosestBuilding
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if not actor.skill.is_ready:
		return FAILURE
	
	actor.animation_control.play_animation(GlobalAnimationNames.ATTACK_ANIMATION)
	var building : Building = actor.get_building_in_next_waypoint()
	
	if building == null:
		return FAILURE
		
	actor.skill.use(building)
	return SUCCESS
