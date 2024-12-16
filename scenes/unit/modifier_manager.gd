class_name ModifierManager
extends Node


@onready var actor : Node = get_parent()


func add_modifier(modifier : ModifierData) -> void:
	match(modifier.modifier_type):
		Utils.ModifierType.StatModifier:
			actor.stats.get_stat(modifier.stat_type).add_modifier(modifier)
		Utils.ModifierType.SkillModifier:
			# what if have multiple skills, need a skill manager and check stat type of modifier
			actor.skill.stats.get_stat(modifier.stat_type).add_modifier(modifier)
		Utils.ModifierType.GlobalModifier:
			actor.stats.get_stat(modifier.stat_type).add_modifier(modifier)
	
	calculate_modifier(modifier.stat_type)


func remove_modifier(modifier : ModifierData) -> void:
	match(modifier.modifier_type):
		Utils.ModifierType.StatModifier:
			actor.stats.get_stat(modifier.stat_type).remove_modifier(modifier)
		Utils.ModifierType.SkillModifier:
			# what if have multiple skills, need a skill manager and check stat type of modifier
			actor.skill.stats.get_stat(modifier.stat_type).remove_modifier(modifier)
		Utils.ModifierType.GlobalModifier:
			actor.stats.get_stat(modifier.stat_type).remove_modifier(modifier)
	
	calculate_modifier(modifier.stat_type)


func calculate_all_modifiers() -> void:
	#do avoid double calculations after checked the main stat modifiers
	var calculated_stat_types : Array[Utils.StatType]
	
	for stat : Stat in actor.stats:
		if not stat.has_modifiers:
			continue
			
		calculate_modifier(stat.type)
		calculated_stat_types.append(stat.type)
	
	#what if main stat has no modifier but skill additive stat has?
	for stat : Stat in actor.skill.stats:
		#if already been calculated continue to next skill stat
		if not calculated_stat_types.is_empty():
			if calculated_stat_types.has(stat.type):
				continue
				
		if not stat.has_modifiers:
			continue
			
		calculate_modifier(stat.type)

## ONLY MAIN STATS CHANGE SO FETCH THE TOTAL DATA FROM ACTOR MAIN STATS
## CALCULATES ALL MODIFIERS FOR STAT
func calculate_modifier(stat_type : Utils.StatType) -> void:
	var main_stat : Stat = actor.stats.get_stat(stat_type)
	
	# need to be changed if have multiple skills,
	# then we need only to modify the correct skill stat, by skill type or stats of multiple skills!
	# test skill name if skill then fetch all skills stats and modify
	#this can be null, skills don't have all kind of stats
	var skill_stat : Stat = actor.skill.stats.get_stat(stat_type)
	
	var modified_value : float = main_stat.base_value
	
	if skill_stat != null:
		modified_value += skill_stat.base_value
	
	#calculations need to be applied in order
	
	
	#first add flat modifiers together
	if not main_stat.flat_modifiers.is_empty():
		for mod in main_stat.flat_modifiers:
			modified_value += mod.value
	
	if skill_stat != null:
		if not skill_stat.flat_modifiers.is_empty():
			for mod in skill_stat.flat_modifiers:
				modified_value += mod.value
	
	if not main_stat.global_flat_modifiers.is_empty():
		for mod in main_stat.global_flat_modifiers:
			modified_value += mod.value
	
	
	#then multipliers
	if not main_stat.multiply_modifiers.is_empty():
		for mod in main_stat.multiply_modifiers:
			modified_value *= (1.0 + mod.value)
	
	if skill_stat != null:
		if not skill_stat.multiply_modifiers.is_empty():
			for mod in skill_stat.multiply_modifiers:
				modified_value *= (1.0 + mod.value)
	
	if not main_stat.global_multiply_modifiers.is_empty():
		for mod in main_stat.global_multiply_modifiers:
			modified_value *= (1.0 + mod.value)
	
	
	print(actor.name, " ", str(Utils.StatType.keys()[stat_type]), " value has been modified to: ", modified_value)
	
	if skill_stat != null:
		skill_stat.value = modified_value
	else:
		main_stat.value = modified_value
