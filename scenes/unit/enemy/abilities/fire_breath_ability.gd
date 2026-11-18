class_name FireBreathAbility
extends EnemyAbility

## The Ashen Wyrm's breath: it picks the line through the towers in reach that crosses the most of them, shows the line
## on the ground for warn_time seconds (a TelegraphLine), then breathes (ATTACK): every building on the line burns.
## The warning gives the player time to see it coming; it does not dodge, towers cannot move.

## In tiles: how far a tower may stand to be aimed at, and how long the line of fire is.
@export var aim_range : float = 6.0
@export var breath_length : float = 8.0
@export var damage : float = 4.0
@export var damage_type : Utils.DamageType = Utils.DamageType.Fire
@export var warn_time : float = 1.5
## In pixels: how near the line a building must stand to burn.
@export var half_width : float = 8.0

var direction : Vector2 = Vector2.ZERO


func _can_use() -> bool:
	direction = _pick_direction()
	return direction != Vector2.ZERO


func _run() -> void:
	var from : Vector2 = enemy.global_position
	var to : Vector2 = from + direction * breath_length * Utils.TILE_SIZE
	enemy.animation_control.flip(direction)
	var telegraph : TelegraphLine = TelegraphLine.make(enemy.level, from, to, half_width)
	var still_going : bool = await _wait(warn_time)
	if is_instance_valid(telegraph):
		telegraph.queue_free()
	if not still_going or not await _play_and_wait(GlobalAnimationNames.ATTACK_ANIMATION):
		return
	TelegraphLine.make_flame(enemy.level, from, to, half_width)
	for building in buildings_on_line(enemy.level, from, to, half_width):
		var burn : DamageData = DamageData.new()
		burn.damage_type = damage_type
		burn.damage = damage
		building.take_damage(burn)
		burn.free()
	_finish()


## Every standing, non-trap building within half_width of the segment.
static func buildings_on_line(level : Level, from : Vector2, to : Vector2, width : float) -> Array[Building]:
	var hit : Array[Building] = []
	for building in level.all_buildings:
		if is_instance_valid(building) and not building.is_dead and building.is_placed and not building is Trap \
				and Geometry2D.get_closest_point_to_segment(building.global_position, from, to).distance_to(building.global_position) <= width:
			hit.append(building)
	return hit


#through the tower in reach whose line crosses the most buildings
func _pick_direction() -> Vector2:
	if enemy == null or enemy.level == null:
		return Vector2.ZERO
	var reach : float = aim_range * Utils.TILE_SIZE
	var best : Vector2 = Vector2.ZERO
	var best_count : int = 0
	for building in enemy.level.all_buildings:
		if not is_instance_valid(building) or building.is_dead or building is not Tower:
			continue
		var offset : Vector2 = building.global_position - enemy.global_position
		if offset.length() > reach or offset.is_zero_approx():
			continue
		var dir : Vector2 = offset.normalized()
		var count : int = buildings_on_line(enemy.level, enemy.global_position, enemy.global_position + dir * breath_length * Utils.TILE_SIZE, half_width).size()
		if count > best_count:
			best_count = count
			best = dir
	return best
