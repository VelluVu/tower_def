class_name AttackClosestBuilding
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.animated_sprite.animation != actor.ATTACK_ANIMATION:
		actor.animated_sprite.play(actor.ATTACK_ANIMATION)
	
	actor.get_closest_building()
	
	if actor.animated_sprite.animation == actor.ATTACK_ANIMATION:
		if actor.is_attack_finished:
			if actor.closest_building == null:
				actor.is_attack_finished = false
				return SUCCESS
				
			var vector_to_closest_building = (actor.closest_building.global_position - actor.global_position)
			actor.animated_sprite.flip_h = vector_to_closest_building.x < 0
			actor.closest_building.take_damage(actor.stats_manager.stats.damage)
			#print(name, " attacks tower for: ", actor.stats_manager.stats.damage, " damage")
			actor.is_attack_finished = false
			return SUCCESS
		else:
			if not actor.animated_sprite.is_playing():
				actor.animated_sprite.play(actor.ATTACK_ANIMATION)
				
			return RUNNING
			
	return FAILURE
