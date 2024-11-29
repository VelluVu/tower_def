class_name EvolveStatsLeaf
extends EvolveLeaf


#for serialized leaf
var modifiers : Array[Modifier] :
	get:
		for child in get_children():
			if child is Modifier:
				if modifiers.has(child):
					continue
				modifiers.append(child)
		return modifiers


var modifier_datas : Array[ModifierData]


func evolve(actor : Node) -> void:
	#check serialized
	if not modifiers.is_empty():
		add_modifiers(actor)
	#check script added
	if not modifier_datas.is_empty():
		add_modifier_datas(actor)


func add_modifier_datas(actor : Node) -> void:
	var stat : Stat = null
	
	for modifier in modifier_datas:
		#skill stat
		if modifier.is_skill_modifier:
			if modifier.skill_type != actor.skill.skill_type:
				continue
			if modifier.skill_name != actor.skill.skill_name and modifier.skill_name != "Skill":
				continue
			
			stat = actor.skill.stats.get_stat(modifier.stat)
		
			if stat == null:
				print(name , " tried to modify unexisting stat: ", modifier.stat, " for ", actor.name)
				continue
			
			stat.add_modifier_data(modifier)
			continue
		
		# actor stat
		stat = actor.stats.get_stat(modifier.stat)
		
		if stat == null:
			print(name , " tried to modify unexisting stat: ", modifier.stat, " for ", actor.name)
			continue
		
		stat.add_modifier_data(modifier)


func add_modifiers(actor : Node) -> void:
	var stat : Stat = null
	
	for modifier in modifiers:
		#skill stat
		if modifier.is_skill_modifier:
			if modifier.skill_type != actor.skill.skill_type:
				continue
			if modifier.skill_name != actor.skill.skill_name and modifier.skill_name != "Skill":
				continue
			
			stat = actor.skill.stats.get_stat(modifier.stat)
		
			if stat == null:
				print(name , " tried to modify unexisting stat: ", modifier.stat, " for ", actor.name)
				continue
			
			stat.add_modifier_data(modifier.get_modifier_data())
			continue
		
		# actor stat
		stat = actor.stats.get_stat(modifier.stat)
		
		if stat == null:
			print(name , " tried to modify unexisting stat: ", modifier.stat, " for ", actor.name)
			continue
		
		stat.add_modifier_data(modifier.get_modifier_data())
