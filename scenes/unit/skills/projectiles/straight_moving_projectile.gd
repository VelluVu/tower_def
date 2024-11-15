class_name StraightMovingProjectile
extends Node2D


@onready var animation_player : AnimationPlayer = $AnimationPlayer

var live_timer : CustomTimer = null : 
	get:
		if live_timer == null:
			for child in get_children():
				if child is CustomTimer:
					live_timer = child
		return live_timer

var is_active : bool = false
var fade_max_value : int = 4
var fade_time : float = 0.0
var velocity : Vector2 = Vector2.ZERO

var current_time_scale : float = 1.0
var is_time_altered : bool = false :
	get:
		return current_time_scale != 1.0


func launch(_start_position : Vector2, _velocity : Vector2, _live_time : float) -> void:
	live_timer.stop()
	animation_player.stop()
	material.set_shader_parameter("fade", 0)
	global_position = _start_position
	velocity = _velocity
	fade_time = _live_time * 0.2 * current_time_scale
	live_timer.base_wait_time = _live_time - fade_time
	live_timer.start()


func _ready() -> void:
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	_on_time_scale_change(Utils.game_control.time_scale)
	if not live_timer.timeout.is_connected(_on_live_timer_end):
		live_timer.timeout.connect(_on_live_timer_end)


func _process(delta: float) -> void:
	global_position += velocity * delta * current_time_scale
	look_at(global_position + velocity)


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale
	animation_player.speed_scale = current_time_scale


func _on_live_timer_end() -> void:
	#var remaining_time : float = live_timer.base_wait_time * 0.1 * 2
	animation_player.speed_scale = (1 / fade_time) * current_time_scale
	animation_player.play("fade")
