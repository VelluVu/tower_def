class_name Bolt
extends Area2D


signal hits_enemy_body(body)

@export var damage_type : Utils.DamageType = Utils.DamageType.Normal
@export var projectile_speed : float = 100
@export var live_time = 10.0
@export var pierce : int = 1

@onready var live_timer : CustomTimer = $LiveTimer
@onready var collider : CollisionShape2D = $CollisionShape2D
@onready var animation_control : AnimationControl = $AnimatedSprite2D

var is_hit : bool = false
var target_is_destroyed : bool = false
var current_pierced : int = 0
var target : Node = null
var skill : Skill = null

var current_time_scale : float = 1.0
var is_time_altered : bool = false :
	get:
		return current_time_scale != 1.0


func _ready() -> void:
	if not live_timer.timeout.is_connected(_on_live_timer_timeout):
		live_timer.timeout.connect(_on_live_timer_timeout)
	if not GameSignals.enemy_destroyed.is_connected(_on_enemy_destroyed):
		GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	if not animation_control.animation_finished.is_connected(_on_animation_finished):
		animation_control.animation_finished.connect(_on_animation_finished)
	if not GameSignals.time_scale_change.is_connected(_on_time_scale_change):
		GameSignals.time_scale_change.is_connected(_on_time_scale_change)


func launch(_skill : Skill) -> void:
	skill = _skill
	target = skill.target
	global_position = skill.global_position
	_activate()


func _physics_process(delta: float) -> void:
	if target == null:
		target_is_destroyed = true
	
	if is_hit:
		return
		
	delta *= current_time_scale
	
	if target_is_destroyed:
		global_position += transform.x * projectile_speed * delta
		return
		
	var move_direction : Vector2 = (target.body_center - global_position).normalized()
	look_at(target.body_center)
	global_position += move_direction * projectile_speed * delta


func _on_body_entered(body: Node2D) -> void:
	_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_hit(area.actor)


func _hit(body : Node2D) -> void:
	if is_hit:
		return
		
	current_pierced += 1
	
	if current_pierced > pierce:
		is_hit = true
		_change_collision_state(false)
		animation_control.play_animation(GlobalAnimationNames.DEATH_ANIMATION)
		
	body.take_damage(skill.damage_data)
	hits_enemy_body.emit(body)


func _on_animation_finished() -> void:
	if animation_control.animation == GlobalAnimationNames.DEATH_ANIMATION:
		_deactivate()
	elif animation_control.animation == GlobalAnimationNames.FADE_ANIMATION:
		_deactivate()


func _on_live_timer_timeout() -> void:
	_change_collision_state(false)
	animation_control.play_animation(GlobalAnimationNames.FADE_ANIMATION)


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if enemy == target:
		target_is_destroyed = true
		live_timer.stop()
		live_timer.base_wait_time = (live_time * 0.2) 
		live_timer.start()


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale


func _change_collision_state(state : bool) -> void:
	collider.set_deferred("disabled", not state)
	set_deferred("monitoring", state)
	set_deferred("monitorable", state)


func _activate() -> void:
	_on_time_scale_change(Utils.game_control.time_scale)
	is_hit = false
	show()
	animation_control.play_animation(GlobalAnimationNames.WALK_ANIMATION)
	target_is_destroyed = false
	_change_collision_state(true)
	
	if not live_timer.is_stopped():
		live_timer.stop()
		
	live_timer.base_wait_time = live_time
	live_timer.start()


func _deactivate() -> void:
	live_timer.stop()
	hide()
