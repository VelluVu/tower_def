class_name Bolt
extends Area2D

const WALK_ANIMATION : String = "WALK"
const DEATH_ANIMATION : String = "DEATH"
const FADE_ANIMATION : String = "FADE"

signal hits_enemy_body(body)

@export var projectile_speed : float = 100
@export var live_time = 10.0
@export var pierce : int = 1

@onready var live_timer : Timer = $LiveTimer
@onready var collider : CollisionShape2D = $CollisionShape2D
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D

var is_hit : bool = false
var target_is_destroyed : bool = false
var damage : int = 0
var current_pierced : int = 0
var target = null


func _ready() -> void:
	if not live_timer.timeout.is_connected(_on_live_timer_timeout):
		live_timer.timeout.connect(_on_live_timer_timeout)
	if not GameSignals.enemy_destroyed.is_connected(_on_enemy_destroyed):
		GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)


func launch(start_point, _target, _damage) -> void:
	target = _target
	global_position = start_point
	damage = _damage
	_activate()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	
	if is_hit:
		return
	
	if target_is_destroyed:
		global_position += transform.x * projectile_speed * delta
		return
		
	var move_direction : Vector2 = (target.global_position - global_position).normalized()
	look_at(target.global_position)
	global_position += move_direction * projectile_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if is_hit:
		return
	
	current_pierced += 1
	if current_pierced > pierce:
		is_hit = true
		animated_sprite.play(DEATH_ANIMATION)
	body.take_damage(damage)
	hits_enemy_body.emit(body)


func _on_animation_finished() -> void:
	if animated_sprite.animation == DEATH_ANIMATION:
		_deactivate()
	elif animated_sprite.animation == FADE_ANIMATION:
		_deactivate()


func _on_live_timer_timeout() -> void:
	_disable_physics()
	animated_sprite.play(FADE_ANIMATION)


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if enemy == target:
		target_is_destroyed = true
		live_timer.stop()
		live_timer.wait_time = 2.0
		live_timer.start()


func _disable_physics() -> void:
	collider.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func _activate() -> void:
	live_timer.wait_time = live_time
	is_hit = false
	show()
	animated_sprite.play(WALK_ANIMATION)
	target_is_destroyed = false
	collider.set_deferred("disabled", false)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	
	if not live_timer.is_stopped():
		live_timer.stop()
		
	live_timer.start()


func _deactivate() -> void:
	live_timer.stop()
	hide()
