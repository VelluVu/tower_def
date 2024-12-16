class_name LaunchProjectile
extends Skill


@export var projectile_scene : PackedScene

var launched_projectiles : Array[Node2D]
var projectile_pool : Array[Node2D]
var count : int = 0


func use(_target) -> void:
	super(_target)


func new_projectile(new_scene : PackedScene) -> void:
	if not launched_projectiles.is_empty():
		for old_projectile in launched_projectiles:
			old_projectile.is_old = true
	
	if not projectile_pool.is_empty():
		for item in projectile_pool:
			item.is_old = true
	
	projectile_scene = new_scene


func activate() -> void:
	super()
	var projectile : Node2D = _get_projectile()
	var skill_data = SkillData.new()
	skill_data.damage_data = damage_data
	skill_data.target = target
	skill_data.active_time = active_timer.wait_time
	skill_data.max_range = stats.get_range_in_tiles()
	projectile.launch(skill_data)
	
	if cast_timer.wait_time == 0:
		await get_tree().create_timer(1.0).timeout
		
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
