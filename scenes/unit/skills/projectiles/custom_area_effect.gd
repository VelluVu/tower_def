class_name CustomAreaEffect
extends Area2D


@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var emitter : Emitter = $Emitter
@onready var collider : CollisionShape2D : 
	get:
		if collider == null:
			collider = $CollisionShape2D
		return collider

@export var animation_name : String = "default"
## A burst reaches flyers when its tower does (Tower.hits_air: the Nova from its T2 on).
@export var can_hit_air : bool = false

var is_old : bool = false :
	set = _set_is_old
var is_time_altered : bool:
	get:
		return current_time_scale != 1.0
var current_time_scale : float = 1.0
var skill_data : SkillData = null

signal finished(node : Node)


func launch(_skill_data : SkillData) -> void:
	skill_data = _skill_data 
	
	#fix collider enlarging animation to the skill time
	var nova_animation : Animation = animation_player.get_animation(animation_name)
	nova_animation.length = skill_data.active_time
	
	if nova_animation.track_get_key_count(0) < 1:
		nova_animation.track_insert_key(0, skill_data.active_time, skill_data.max_range)
	
	nova_animation.track_set_key_time(0, 1, skill_data.active_time)
	nova_animation.track_set_key_value(0,0, 0.01)
	nova_animation.track_set_key_value(0, nova_animation.track_find_key(0, skill_data.active_time, Animation.FIND_MODE_EXACT), skill_data.max_range)
	
	activate()
	animation_player.play(animation_name)
	emitter.start(skill_data.max_range, skill_data.active_time)


func activate() -> void:
	collider.disabled = false
	monitoring = true
	monitorable = true
	show()


func clear() -> void:
	queue_free()


func _set_is_old(new_value : bool) -> void:
	if is_old == new_value:
		return

	is_old = new_value
	emitter.is_old = is_old


func _ready() -> void:
	#launch() rewrites the burst animation to the tower's range and time; the scene's library is shared by every
	#burst, so each gets its own copy or two Novas bursting at once take each other's radius
	var library : AnimationLibrary = animation_player.get_animation_library(&"")
	animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", library.duplicate(true))
	area_entered.connect(_on_enemy_hit)
	emitter.finished.connect(_on_emitter_finished)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	_on_time_scale_change(Utils.game_control.time_scale)


func _on_emitter_finished(_node : Node2D) -> void:
	_deactivate()


func _deactivate() -> void:
	#print(name, " finished")
	collider.shape.radius = 0
	collider.disabled = true
	monitoring = false
	monitorable = false
	animation_player.stop()
	hide()
	finished.emit(self)


func _on_enemy_hit(area_hit : Area2D) -> void:
	if area_hit.actor is Enemy and area_hit.actor.is_flying and not _reaches_air():
		return
	area_hit.actor.take_damage(skill_data.damage_data)


func _reaches_air() -> bool:
	if can_hit_air:
		return true
	var tower : Tower = skill_data.damage_data.source as Tower if skill_data != null and is_instance_valid(skill_data.damage_data) else null
	return tower != null and is_instance_valid(tower) and tower.hits_air


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale
	animation_player.speed_scale = current_time_scale
