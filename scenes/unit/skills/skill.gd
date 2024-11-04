class_name Skill
extends Node2D


@onready var cast_timer : CustomTimer = $SkillStateTimers/CastTimer
@onready var cooldown_timer : CustomTimer = $SkillStateTimers/CooldownTimer
@onready var active_timer : CustomTimer = $SkillStateTimers/ActiveTimer
@onready var damage_data : DamageData = $DamageData :
	get = _get_damage_data

@export var is_continuous : bool = false
@export var base_cast_time : float = 0.0
@export var base_active_time : float = 0.0
@export var base_cooldown : float = 2.0
@export var actor : Node :
	get:
		if actor == null:
			actor = get_parent()
		return actor

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
		return base_cast_time + base_active_time


func _ready() -> void:
	cast_timer.timeout.connect(_on_cast_finished)
	cooldown_timer.timeout.connect(_on_cooldown_end)
	active_timer.timeout.connect(_on_active_end)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	
	#alternat these with actor speed scale?
	cast_timer.base_wait_time = base_cast_time
	cooldown_timer.base_wait_time = base_cooldown
	active_timer.base_wait_time = base_active_time
	
	_on_time_scale_change(Utils.game_control.time_scale)


func use(_target) -> void:
	if not is_continuous and not is_ready:
		return
	
	if not _is_target_valid(_target):
		print(name, " use failed, not valid target... returning")
		return
	
	target = _target
	
	# if one shot skill, cast everytime when used even on same target
	if not is_continuous:
		start_skill_cast()


func start_skill_cast() -> void:
	print(name, " use skill ")
	
	is_ready = false
	actor.animation_control.play_animation(GlobalAnimationNames.ATTACK_ANIMATION, cast_timer.wait_time)
	
	if cast_timer.wait_time > 0.0:
		cast_timer.start()
		return
	
	activate()


func activate() -> void:
	print(name, " is active ")
	
	#is ready is enabled elsewhere for continuous skill and it is active until is ready change
	if is_continuous:
		return
	
	if active_timer.wait_time > 0.0:
		#interrupt active skill
		if active_timer.time_left > 0.0:
			active_timer.stop()
			_interrupted_active()
		
		active_timer.start()
	
	if cooldown_timer.wait_time > 0.0:
		cooldown_timer.start()
		return


func stop() -> void:
	cast_timer.stop()
	cooldown_timer.stop()
	active_timer.stop()
	is_ready = true


func _on_cast_finished() -> void:
	print(name, " cast finished ")
	activate()


func _on_active_end() -> void:
	print(name, " active end ")
	pass


func _interrupted_active() -> void:
	print(name, " interrupted active ")
	pass


func _on_cooldown_end() -> void:
	print(name, " cooldown end ")
	is_ready = true


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
	var _damage_data : DamageData = damage_data.duplicate()
	#add actor stats
	_damage_data.source = actor
	_damage_data.damage += actor.stats_manager.stats.damage
	_damage_data.calculate_critical()
	return _damage_data
