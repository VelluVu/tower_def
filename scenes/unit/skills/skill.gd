class_name Skill
extends Node2D


@onready var cast_timer : CustomTimer = $SkillStateTimers/CastTimer
@onready var cooldown_timer : CustomTimer = $SkillStateTimers/CooldownTimer
@onready var active_timer : CustomTimer = $SkillStateTimers/ActiveTimer

@onready var damage_data : DamageData = $DamageData :
	get = _get_damage_data

@onready var stats : Stats = $Stats :
	get:
		if stats == null:
			for child in get_children():
				if child is Stats:
					stats = child
		return stats

@export var skill_type : Utils.SkillType = Utils.SkillType.Projectile
@export var skill_name : String = "Skill"
@export var is_continuous : bool = false
@export var base_cast_time : float = 0.0
@export var base_active_time : float = 0.0
@export var base_cooldown : float = 2.0

@export var actor : Node :
	get:
		if actor == null:
			actor = get_parent()
		return actor

var flip_h : bool = false :
	set = _set_flip_h
var is_ready : bool = true
var current_time_scale : float = 1.0
var target : Node2D = null :
	set = _set_target

var is_valid_target : bool :
	get = _get_is_valid_target
	
var is_time_altered : bool = false :
	get:
		return current_time_scale != 1.0

var total_duration : float :
	get:
		return cast_timer.base_wait_time + active_timer.base_wait_time

var attack_speed : float :
	get = _get_attack_speed

signal is_ready_signal(value : bool)


func use(_target) -> void:
	if not is_continuous and not is_ready:
		return
	
	target = _target

	# if one shot skill, cast everytime when used even on same target
	if not is_continuous:
		start_skill_cast()


func _set_flip_h(_is_flipped : bool) -> void:
	if _is_flipped == flip_h:
		return
	
	flip_h = _is_flipped
	position.x = position.x * -1


func replace_damage_data(new_damage_data_scene : PackedScene) -> void:
	damage_data.queue_free()
	damage_data = new_damage_data_scene.instantiate()
	add_child(damage_data)


func start_skill_cast() -> void:
	#print(name, " use skill ")
	if target == null:
		return
		
	is_ready = false
	
	if actor.animation_control.sprite_frames.has_animation(GlobalAnimationNames.START_ATTACK_ANIMATION):
		actor.animation_control.play_animation(GlobalAnimationNames.START_ATTACK_ANIMATION, cast_timer.wait_time if cast_timer.wait_time > 0.0 else 1.0)
	else:
		actor.animation_control.play_animation(GlobalAnimationNames.ATTACK_ANIMATION, cast_timer.wait_time)
	
	if cast_timer.base_wait_time > 0.0:
		cast_timer.start()
		return
	
	activate()


func activate() -> void:
	#print(name, " is active ")
	
	#is ready is enabled elsewhere for continuous skill and it is active until is ready change
	if is_continuous:
		return
	
	if active_timer.base_wait_time > 0.0:
		#interrupt active skill
		if active_timer.base_wait_time > 0.0:
			active_timer.stop()
			_interrupted_active()
		
		active_timer.start()
	
	if cooldown_timer.base_wait_time > 0.0:
		cooldown_timer.start()
		return


func stop() -> void:
	cast_timer.stop()
	cooldown_timer.stop()
	active_timer.stop()
	is_ready = true


func _ready() -> void:
	cast_timer.timeout.connect(_on_cast_finished)
	cooldown_timer.timeout.connect(_on_cooldown_end)
	active_timer.timeout.connect(_on_active_end)
	stats.stat_changed.connect(_on_skill_stat_changed)
	actor.stats.stat_changed.connect(_on_actor_stat_changed)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	
	cast_timer.unscaled_base_value = base_cast_time
	cooldown_timer.unscaled_base_value = base_cooldown
	active_timer.unscaled_base_value = base_active_time 
	
	_on_time_scale_change(Utils.game_control.time_scale)


func _on_skill_stat_changed(stat : Stat) -> void:
	if stat.type == Utils.StatType.AttackSpeed:
		var attack_speed_stat_value : float = stat.value
		cooldown_timer.scale_wait_time(attack_speed_stat_value)
		cast_timer.scale_wait_time(attack_speed_stat_value)
		
	if stat.type == Utils.StatType.ActiveDuration:
		active_timer.scale_wait_time(stat.value)


func _on_actor_stat_changed(stat : Stat) -> void:
	if stat.type == Utils.StatType.AttackSpeed:
		var attack_speed_stat : float = stats.get_stat_value(Utils.StatType.AttackSpeed)
		cooldown_timer.scale_wait_time(attack_speed_stat)
		cast_timer.scale_wait_time(attack_speed_stat)
	
	if stat.type == Utils.StatType.ActiveDuration:
		active_timer.scale_wait_time(stats.get_stat_value(Utils.StatType.ActiveDuration))


func _on_cast_finished() -> void:
	#print(name, " cast finished ")
	activate()


func _on_active_end() -> void:
	#print(name, " active end ")
	pass


func _interrupted_active() -> void:
	#print(name, " interrupted active ")
	pass


func _on_cooldown_end() -> void:
	#print(name, " cooldown end ")
	is_ready = true
	is_ready_signal.emit(is_ready)


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale


func _is_target_valid(_target : Node2D) -> bool:
	if _target == null:
		return false
	
	if actor is Building:
		if not actor.targets.has(_target):
			return false
	
	if _target.is_dead:
		return false
		
	return true


func _get_is_valid_target() -> bool:
	if target == null:
		return false
	
	if actor is Building:
		if not actor.targets.has(target):
			return false
	
	if target.is_dead:
		return false
		
	return true


func _set_target(new_target : Node2D) -> void:
	if new_target == target:
		return
		
	target = new_target
	
	# if continuous interrupt previous skill and cast when new target is set
	if is_continuous:
		if not is_ready:
			stop()
		
		start_skill_cast()


func _get_damage_data() -> DamageData:
	if damage_data == null:
		damage_data = $DamageData
	
	var _damage_data : DamageData = damage_data.duplicate()
	var damage : float = stats.get_stat_value(Utils.StatType.Damage)
	var critical_chance : float = stats.get_stat_value(Utils.StatType.CriticalChance)
	
	_damage_data.source = actor
	_damage_data.is_critical = randf() < critical_chance
	_damage_data.damage = stats.get_stat_value(Utils.StatType.CriticalMultiplier) * damage if _damage_data.is_critical else damage
	
	for effect_data in _damage_data.overtime_effect_datas:
		effect_data.is_critical = _damage_data.is_critical
		
	return _damage_data


func _get_attack_speed() -> float:
	return (cast_timer.wait_time + cooldown_timer.wait_time)
