class_name LaunchProjectile
extends Skill


const STOP_ATTACK_DELAY : float = 1.0
#seconds between an attack and each of its extra shots (the ExtraShots stat), at 1x speed
const EXTRA_SHOT_DELAY : float = 0.4
#an extra shot hits for this share of the attack's damage
const EXTRA_SHOT_DAMAGE_SHARE : float = 0.5

@export var projectile_scene : PackedScene

var launched_projectiles : Array[Node2D]
var projectile_pool : Array[Node2D]
var count : int = 0
var extra_shot_timer : CustomTimer = null
var extra_shots_left : int = 0


func use(_target : Node2D) -> void:
	super(_target)


func new_projectile(new_scene : PackedScene) -> void:
	if not launched_projectiles.is_empty():
		for old_projectile in launched_projectiles:
			old_projectile.is_old = true
	
	if not projectile_pool.is_empty():
		for item in projectile_pool:
			item.is_old = true
	
	projectile_scene = new_scene


func _ready() -> void:
	super()
	extra_shot_timer = CustomTimer.new()
	extra_shot_timer.one_shot = true
	add_child(extra_shot_timer)
	extra_shot_timer.unscaled_base_value = EXTRA_SHOT_DELAY
	extra_shot_timer.timeout.connect(_on_extra_shot_timer_timeout)


func activate() -> void:
	super()
	_launch()
	#the ExtraShots stat (mechanic card): the same attack again a moment later, no extra cooldown
	extra_shots_left = roundi(actor.stats.get_stat_value(Utils.StatType.ExtraShots))
	if extra_shots_left > 0:
		extra_shot_timer.start()

	#without a cast the attack animation gets a moment before stopping; the timer pauses with the game,
	#follows the game speed, and its connection is dropped if the tower is sold meanwhile
	if cast_timer.wait_time == 0:
		get_tree().create_timer(STOP_ATTACK_DELAY / current_time_scale, false).timeout.connect(_play_stop_attack_animation)
		return

	_play_stop_attack_animation()


func _launch(damage_share : float = 1.0) -> void:
	var projectile : Node2D = _get_projectile()
	var skill_data = SkillData.new()
	skill_data.damage_data = damage_data
	skill_data.damage_data.damage *= damage_share
	skill_data.target = target
	skill_data.active_time = active_timer.wait_time
	skill_data.max_range = stats.get_range_in_tiles()
	skill_data.ricochets = roundi(actor.stats.get_stat_value(Utils.StatType.Ricochet))
	skill_data.pierces = roundi(actor.stats.get_stat_value(Utils.StatType.Pierce))
	projectile.launch(skill_data)


func _on_extra_shot_timer_timeout() -> void:
	if extra_shots_left <= 0 or not is_valid_target:
		extra_shots_left = 0
		return

	extra_shots_left -= 1
	_launch(EXTRA_SHOT_DAMAGE_SHARE)

	if extra_shots_left > 0:
		extra_shot_timer.start()


func stop() -> void:
	super()
	extra_shots_left = 0
	if extra_shot_timer != null:
		extra_shot_timer.stop()


func _play_stop_attack_animation() -> void:
	actor.animation_control.play_animation(GlobalAnimationNames.STOP_ATTACK_ANIMATION, cooldown_timer.time_left, true)


func _exit_tree() -> void:
	clear_all_particles()


func clear_all_particles() -> void:
	if not launched_projectiles.is_empty():
		for projectile in launched_projectiles:
			if projectile != null:
				projectile.queue_free()
		launched_projectiles.clear()
	
	if not projectile_pool.is_empty():
		for item in projectile_pool:
			if item != null:
				item.queue_free()
		projectile_pool.clear()


func _get_projectile() -> Node2D:
	var projectile : Node2D = null
	
	if not projectile_pool.is_empty():
		projectile = projectile_pool.pop_back()
		if projectile.is_old:
			projectile = null
	
	if projectile == null:
		projectile = projectile_scene.instantiate()
		count += 1
		projectile.name = actor.name + "'s " + projectile.name + str(count)
		launched_projectiles.append(projectile)
	
	if projectile.get_parent() == null:
		Utils.game_control.add_child(projectile)
		
	projectile.global_position = global_position
	
	if not projectile.finished.is_connected(_on_projectile_finished):
		projectile.finished.connect(_on_projectile_finished)
		
	return projectile


func _get_shooting_position(target_position : Vector2) -> Vector2:
	var get_parent_position : Vector2 = get_parent().global_position
	return get_parent_position + ((target_position - get_parent_position).normalized() * Utils.TILE_SIZE)


func _on_projectile_finished(projectile : Node2D) -> void:
	if projectile.is_old:
		if launched_projectiles.has(projectile):
			launched_projectiles.erase(projectile)
		if projectile_pool.has(projectile):
			projectile_pool.erase(projectile)
		projectile.clear()
		return
	
	if projectile_pool.has(projectile):
		return
	
	projectile_pool.push_back(projectile)
