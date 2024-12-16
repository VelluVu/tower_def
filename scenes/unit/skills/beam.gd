class_name Beam
extends Skill


@onready var line : Line2D = $Line2D :
	get: 
		if line == null:
			for child in get_children():
				if child is Line2D:
					line = child
		return line
		
@onready var damage_timer : CustomTimer = $DamageTimer

@export var end_line_index : int = 1
@export var tick_speed : float = 1.0
@export var beam_texture : CompressedTexture2D :
	set = _set_beam_texture
		

var is_active : bool :
	set = _set_is_active
var position_update_timer : float = 0.0
var position_update_interval : float = 0.25


func _ready() -> void:
	line.texture = beam_texture
	damage_timer.unscaled_base_value = tick_speed
	damage_timer.timeout.connect(_on_timer_tick)
	super()


func _process(delta: float) -> void:
	if not is_active:
		return
		
	position_update_timer += delta * current_time_scale
	
	if position_update_timer > position_update_interval:
		position_update_timer = 0
		
		if not is_valid_target:
			is_active = false
			return
		
		line.set_point_position(end_line_index, (target.body_center - global_position))


func activate() -> void:
	super()
	is_active = true


func stop() -> void:
	super()
	is_active = false


func _on_skill_stat_changed(stat : Stat) -> void:
	super(stat)
	
	if stat.type == Utils.StatType.AttackSpeed:
		damage_timer.scale_wait_time(stat.value)


func _on_actor_stat_changed(stat : Stat) -> void:
	super(stat)
	
	if stat.type == Utils.StatType.AttackSpeed:
		damage_timer.scale_wait_time(stats.get_stat_value(Utils.StatType.AttackSpeed))


func _on_timer_tick() -> void:
	if not is_valid_target:
		is_active = false
		return
	
	line.set_point_position(end_line_index, (target.body_center - global_position))
	target.take_damage(damage_data)


func _set_is_active(value : bool) -> void:
	if value == is_active:
		return
	
	is_active = value
	
	if is_active:
		actor.animation_control.play_animation(GlobalAnimationNames.ATTACK_ANIMATION)
		line.set_point_position(end_line_index, (target.body_center - global_position))
		target.take_damage(damage_data)
		damage_timer.start()
	else:
		line.set_point_position(1, Vector2.ZERO)
		damage_timer.stop()
		actor.animation_control.play_animation(GlobalAnimationNames.STOP_ATTACK_ANIMATION)
		is_ready = true


func _set_beam_texture(new_texture : CompressedTexture2D) -> void:
	if new_texture == beam_texture:
		return
		
	beam_texture = new_texture
	
	if line == null:
		return

	line.texture = beam_texture


func _get_attack_speed() -> float:
	return damage_timer.wait_time
