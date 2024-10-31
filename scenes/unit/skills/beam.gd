class_name Beam
extends Skill


@onready var line : Line2D = $Line2D
@onready var damage_timer : CustomTimer = $DamageTimer

@export var damage_type : Utils.DamageType = Utils.DamageType.Normal
@export var end_line_index : int = 1
@export var tick_speed : float = 1.0

var is_beaming : bool :
	set = _set_is_beaming
var position_update_timer : float = 0.0
var position_update_interval : float = 0.25


func _ready() -> void:
	damage_timer.base_wait_time = tick_speed
	damage_timer.timeout.connect(_on_timer_tick)
	super()


func _process(delta: float) -> void:
	if not is_beaming:
		return
		
	position_update_timer += delta * current_time_scale
	
	if position_update_timer > position_update_interval:
		position_update_timer = 0
		
		if not is_valid_target:
			is_beaming = false
			return
		
		line.set_point_position(end_line_index, (target.body_center - global_position))


func activate() -> void:
	super()
	is_beaming = true


func stop() -> void:
	super()
	is_beaming = false


func _on_timer_tick() -> void:
	if not is_valid_target:
		is_beaming = false
		return
	
	line.set_point_position(end_line_index, (target.body_center - global_position))
	target.take_damage(damage, damage_type)


func _set_is_beaming(value : bool) -> void:
	if value == is_beaming:
		return
	
	is_beaming = value
	
	if is_beaming:
		line.set_point_position(end_line_index, (target.body_center - global_position))
		target.take_damage(damage, damage_type)
		damage_timer.start()
	else:
		line.set_point_position(1, Vector2.ZERO)
		damage_timer.stop()
		is_ready = true
