class_name Bolt
extends Area2D


signal hits_enemy_body(body)

@export var projectile_speed : float = 100

@onready var live_timer : Timer = $LiveTimer
@onready var collider : CollisionShape2D = $CollisionShape2D

var target_is_destroyed : bool = false
var damage : int = 0
var target = null


func _ready() -> void:
	if not live_timer.timeout.is_connected(_on_live_timer_timeout):
		live_timer.timeout.connect(_on_live_timer_timeout)
	if not GameSignals.enemy_destroyed.is_connected(_on_enemy_destroyed):
		GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)


func launch(start_point, _target, _damage) -> void:
	target = _target
	global_position = start_point
	damage = _damage
	_activate()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	
	if target_is_destroyed:
		global_position += transform.x * projectile_speed * delta
		return
		
	var move_direction : Vector2 = (target.global_position - global_position).normalized()
	look_at(target.global_position)
	global_position += move_direction * projectile_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if target == null:
		return
	
	if body != target:
		return
	
	print(name, " hits ", body.name)
	_deactivate()
	body.take_damage(damage)
	hits_enemy_body.emit(body)


func _on_live_timer_timeout() -> void:
	print(name, " timer timeout")
	_deactivate()


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if enemy == target:
		target_is_destroyed = true


func _activate() -> void:
	show()
	target_is_destroyed = false
	collider.set_deferred("disabled", false)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	
	if not live_timer.is_stopped():
		live_timer.stop()
		
	live_timer.start()


func _deactivate() -> void:
	live_timer.stop()
	collider.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	hide()
