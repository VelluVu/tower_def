class_name ShootBolt
extends TowerSkill


@export var projectile_scene : PackedScene

var projectile_pool : Array[Node2D]


func use(target, damage : int) -> void:
	super(target, damage)
	var projectile : Bolt = _get_projectile()
	projectile.launch(_get_shooting_position(target.global_position), target, damage)


func _get_projectile() -> Node2D:
	for pooled_projectile in projectile_pool:
		if not pooled_projectile.is_visible():
			return pooled_projectile
		
	var projectile = projectile_scene.instantiate()
	add_child(projectile)
	projectile_pool.append(projectile)
	projectile.name = name + str(projectile_pool.size())
	return projectile


func _get_shooting_position(target_position : Vector2) -> Vector2:
	var get_parent_position : Vector2 = get_parent().global_position
	return get_parent_position + ((target_position - get_parent_position).normalized() * Utils.TILE_SIZE)
