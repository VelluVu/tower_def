class_name GoreEmitter
extends Node2D

#different gore for damage types?
@export var gore_effect_scene : PackedScene

var pool : Array[GoreEffect]


func emit_gore(damage_data : DamageData) -> void:
	var gore : GoreEffect = get_gore()
	gore.main_effect_offset = position
	gore.emitter_name = get_parent().name
	gore.amount = damage_data.damage * 2
	gore.emitting = true


func get_gore() -> GoreEffect:
	#create new gore if pool is empty
	if pool.is_empty():
		return create_gore()
	
	#check if first is still emitting
	if not pool[0].emitting:
		var next_in_line = pool.pop_front()
		pool.push_back(next_in_line)
		return next_in_line
	
	#create new gore if pool has no finished gore
	return create_gore()


func create_gore() -> GoreEffect:
	var new_gore : GoreEffect = gore_effect_scene.instantiate()
	var new_name : String = new_gore.name + str(pool.size())
	new_gore.name = new_name
	add_child(new_gore)
	pool.push_back(new_gore)
	return new_gore
