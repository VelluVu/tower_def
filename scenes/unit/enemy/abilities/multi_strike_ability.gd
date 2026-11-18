class_name MultiStrikeAbility
extends EnemyAbility

## Stops, plays the strike animation and hits up to `targets` different towers near it at once, nearest
## first: the Bog Hydra's heads (one tower per head) and the Dragonslayer's last-stand sweep (every tower).

## In tiles from the enemy to the tower.
@export var strike_range : float = 2.5
@export var targets : int = 3
@export var damage : float = 2.0
@export var damage_type : Utils.DamageType = Utils.DamageType.Physical
@export var strike_animation : String = GlobalAnimationNames.ATTACK_ANIMATION
## Seconds a struck tower stops attacking (the Dragonslayer's cleave); 0 = none.
@export var silence_time : float = 0.0

var struck : Array[Building] = []


func _can_use() -> bool:
	struck = _pick_targets()
	return not struck.is_empty()


func _run() -> void:
	enemy.animation_control.flip(struck[0].global_position - enemy.global_position)
	if not await _play_and_wait(strike_animation):
		return

	for building in struck:
		if is_instance_valid(building) and not building.is_dead:
			var damage_data : DamageData = DamageData.new()
			damage_data.damage_type = damage_type
			damage_data.damage = damage
			building.take_damage(damage_data)
			damage_data.free()
			if silence_time > 0.0 and building is Tower and not building.is_dead:
				building.silence(silence_time)
	_finish()


func _pick_targets() -> Array[Building]:
	var found : Array[Building] = []
	if enemy == null or enemy.level == null:
		return found

	var reach : float = strike_range * Utils.TILE_SIZE
	for building in enemy.level.all_buildings:
		if is_instance_valid(building) and building is Tower and not building.is_dead and building.is_placed \
				and building.global_position.distance_to(enemy.global_position) <= reach:
			found.append(building)

	found.sort_custom(_is_picked_before)
	return found.slice(0, targets)


#nearest first
func _is_picked_before(a : Building, b : Building) -> bool:
	return a.global_position.distance_squared_to(enemy.global_position) < b.global_position.distance_squared_to(enemy.global_position)
