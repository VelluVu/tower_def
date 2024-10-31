class_name AreaEffect
extends Area2D


@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var collider : CollisionShape2D : 
	get:
		if collider == null:
			collider = $CollisionShape2D
		return collider

@export var animation_name : String = "default"
@export var damage_type : Utils.DamageType = Utils.DamageType.Normal

var damage : float = 0
var max_radius : float = 0

var current_time_scale : float = 1.0
var is_time_altered : bool:
	get:
		return current_time_scale != 1.0


func _ready() -> void:
	area_entered.connect(_on_enemy_hit)
	animation_player.animation_finished.connect(_on_animation_finished)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	_on_time_scale_change(Utils.game_control.time_scale)


func start_nova(_max_radius : float, _damage : float) -> void:
	damage = _damage
	max_radius = _max_radius
	animated_sprite.scale = Vector2(max_radius * 0.01, max_radius * 0.01 )
	var nova_animation : Animation = animation_player.get_animation(animation_name)
	nova_animation.track_set_key_value(0, nova_animation.track_find_key(0,1.0,Animation.FIND_MODE_EXACT), max_radius)
	activate()
	animation_player.play(animation_name)


func _on_animation_finished(anim_name : String) -> void:
	if anim_name == animation_name:
		_deactivate()


func _on_tween_finished() -> void:
	_deactivate()


func activate() -> void:
	collider.disabled = false
	monitoring = true
	monitorable = true
	show()


func _deactivate() -> void:
	damage = 0
	collider.shape.radius = 0
	collider.disabled = true
	monitoring = false
	monitorable = false
	hide()


func _on_enemy_hit(area_hit : Area2D) -> void:
	print(name, " hits ", area_hit.actor.name)
	area_hit.actor.take_damage(damage, damage_type)


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale
	animation_player.speed_scale = current_time_scale
