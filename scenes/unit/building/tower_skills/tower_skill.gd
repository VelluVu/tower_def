class_name TowerSkill
extends Node2D


@export var base_cast_time : float = 0.0
@export var active_time : float = 0.0
@export var base_cooldown : float = 2.0 
@export var actor : Node :
	get:
		if actor == null:
			actor = get_parent()
		return actor
		
@onready var cast_timer : CustomTimer = $CastTimer
@onready var cooldown_timer : CustomTimer = $CooldownTimer

var is_ready : bool = true
var target : Node2D
var damage : float
var current_time_scale : float = 1.0
var is_time_altered : bool = false
var cast_wait_time : float = 0.0
var cooldown_wait_time : float = 0.0

var total_duration : float :
	get:
		return base_cast_time + base_cooldown + active_time


func _ready() -> void:
	cast_timer.timeout.connect(_on_cast_finished)
	cooldown_timer.timeout.connect(_on_ability_ready)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	cast_timer.base_wait_time = base_cast_time
	cooldown_timer.base_wait_time = base_cooldown
	cooldown_wait_time = base_cooldown / Utils.game_control.time_scale
	cast_wait_time = base_cast_time / Utils.game_control.time_scale
	_on_time_scale_change(Utils.game_control.time_scale)


func use(_target) -> void:
	is_ready = false
	target = _target
	damage = actor.stats_manager.stats.damage
	
	if cast_wait_time > 0.0:
		cast_timer.start(cast_wait_time)
	else:
		activate()


func activate() -> void:
	if cooldown_wait_time > 0.0:
		cooldown_timer.start(cooldown_wait_time)
	else:
		is_ready = true


func _on_cast_finished() -> void:
	activate()


func _on_ability_ready() -> void:
	is_ready = true


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale
	is_time_altered = current_time_scale != 1.0
	cast_wait_time = base_cast_time / current_time_scale
	cooldown_wait_time = base_cooldown / current_time_scale
