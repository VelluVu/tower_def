class_name GoreEffect
extends GPUParticles2D


@export var sub_gore_scene : PackedScene

var sub_gore_pool : Array[Node2D]
var main_effect_offset : Vector2 = Vector2.ZERO
var emitter_name : String = "some weakling"


func _ready() -> void:
	if not finished.is_connected(_on_finish_emit):
		finished.connect(_on_finish_emit)
	if not GameSignals.time_scale_change.is_connected(_on_time_scale_change):
		GameSignals.time_scale_change.connect(_on_time_scale_change)
	_on_time_scale_change(Utils.game_control.time_scale)


func _on_finish_emit() -> void:
	var gore_sub_effect : Node2D = _get_from_pool()
	gore_sub_effect.splat(global_position - main_effect_offset)


func _get_from_pool() -> Node2D:
	if sub_gore_pool.is_empty():
		return _create_gore_sub_effect()
	
	if not sub_gore_pool[0].is_draw:
		var first_in_queue = sub_gore_pool.pop_front()
		sub_gore_pool.push_back(first_in_queue)
		return first_in_queue
	
	return _create_gore_sub_effect()


func _create_gore_sub_effect() -> Node2D:
	var gore_sub_effect : Node2D = sub_gore_scene.instantiate()
	var new_name : String = gore_sub_effect.name + str(sub_gore_pool.size()) + "_" + emitter_name
	gore_sub_effect.name = new_name
	Utils.game_control.scene_manager.current_level.add_child(gore_sub_effect)
	sub_gore_pool.push_back(gore_sub_effect)
	return gore_sub_effect


func _on_time_scale_change(time_scale : float) -> void:
	speed_scale = time_scale
