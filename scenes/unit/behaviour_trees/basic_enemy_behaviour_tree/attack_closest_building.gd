class_name AttackClosestBuilding
extends ActionLeaf


var has_attacked : bool = false
var building : Building = null


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.animation_control.animation != actor.ATTACK_ANIMATION:
		building = actor.get_building_in_next_waypoint()
		actor.animation_control.play(actor.ATTACK_ANIMATION)
	
	if actor.animation_control.animation == actor.ATTACK_ANIMATION:
		if actor.animation_control.is_playing() and actor.animation_control.frame == actor.attack_frame and !has_attacked:
			if building == null:
				return FAILURE
				
			has_attacked = true
			var vector_to_closest_building = (building.global_position - actor.global_position)
			actor.animation_control.flip_h = vector_to_closest_building.x < 0
			building.take_damage(actor.stats_manager.stats.damage)
			#print(name, " attacks tower for: ", actor.stats_manager.stats.damage, " damage")
			return SUCCESS
		else:
			if not actor.animation_control.is_playing():
				actor.animation_control.play(actor.ATTACK_ANIMATION)
				has_attacked = false
				
			return RUNNING
			
	return FAILURE
