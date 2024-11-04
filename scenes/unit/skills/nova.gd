class_name Nova
extends Skill


@export var area_effect_scene : PackedScene

var effects : Array[AreaEffect]


func use(_target) -> void:
	super(_target)


func activate() -> void:
	super()
	var effect : AreaEffect = null
	if not effects.is_empty():
		effect = effects[0]
		if effect.visible:
			effect = area_effect_scene.instantiate()
			effect.name = effect.name + str(effects.size())
			add_child(effect)
		else:
			effect = effects.pop_front()
	else:
		effect = area_effect_scene.instantiate()
		effect.name = effect.name + str(effects.size())
		add_child(effect)
	
	effects.push_back(effect)
	effect.start_nova(self)
