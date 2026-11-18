class_name HealAbility
extends EnemyAbility

## The priest's prayer: stops, raises its staff (ATTACK) and heals the most hurt enemy in reach, itself
## included, by a share of its max health; can also cure its poison stacks. A short sparkle shows on the healed.

## In tiles.
@export var heal_range : float = 3.0
## Share of the target's max health.
@export var heal_ratio : float = 0.25
@export var cures_poison : bool = true
@export var sparkle_texture : Texture2D = null
@export var sparkle_hframes : int = 2
@export var sparkle_vframes : int = 2

var target : Enemy = null


func _can_use() -> bool:
	target = _pick_target()
	return target != null


func _run() -> void:
	enemy.animation_control.flip(target.global_position - enemy.global_position)
	if not await _play_and_wait(GlobalAnimationNames.ATTACK_ANIMATION):
		return

	if is_instance_valid(target) and not target.is_dead:
		_heal(target)
	_finish()


func _pick_target() -> Enemy:
	if enemy == null or enemy.level == null:
		return null

	var reach : float = heal_range * Utils.TILE_SIZE
	var best : Enemy = null
	var best_ratio : float = 1.0

	for other in enemy.level.existing_enemies:
		if not is_instance_valid(other) or other.is_dead or other.is_deactivated or other.is_burrowed or other.global_position.distance_to(enemy.global_position) > reach:
			continue

		var max_health : float = other.stats.get_stat_value(Utils.StatType.MaxHealth)
		var ratio : float = other.stats.get_stat_value(Utils.StatType.Health) / max_health if max_health > 0.0 else 1.0
		var poisoned : bool = cures_poison and not other.overtime_effect_handler.get_active_stacks(Utils.DamageType.Poison).is_empty()
		#a poisoned enemy counts as hurt even at full health
		if poisoned:
			ratio = minf(ratio, 0.99)
		if ratio < best_ratio:
			best = other
			best_ratio = ratio

	return best


func _heal(other : Enemy) -> void:
	var damage_data : DamageData = DamageData.new()
	damage_data.damage = -other.stats.get_stat_value(Utils.StatType.MaxHealth) * heal_ratio
	other.take_damage(damage_data)
	damage_data.free()

	if cures_poison:
		for stack in other.overtime_effect_handler.get_active_stacks(Utils.DamageType.Poison):
			stack.stop()

	if sparkle_texture != null:
		# a shot that does not move: plays its frames once over the healed enemy, then frees itself
		var sparkle : EnemyShot = EnemyShot.new()
		sparkle.setup(sparkle_texture, sparkle_hframes, sparkle_vframes, other.global_position + Vector2(0, -12), other.global_position + Vector2(0, -16))
		sparkle.speed = 16.0
		sparkle.frame_time = 0.06
		enemy.level.add_child(sparkle)
