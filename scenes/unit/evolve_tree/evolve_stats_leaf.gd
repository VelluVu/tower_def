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
	for modifier in modifier_datas:
		actor.modifier_manager.add_modifier(modifier)


func add_modifiers(actor : Node) -> void:
	for modifier in modifiers:
		actor.modifier_manager.add_modifier(modifier.get_modifier_data())
