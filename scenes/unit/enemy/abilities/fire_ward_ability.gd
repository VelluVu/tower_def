class_name FireWardAbility
extends EnemyAbility

## The ember cultist's prayer: raises its burning staff (ATTACK) and wards up to `targets` nearby enemies without a
## ward, itself included; each ward soaks the next direct hit (FireWard).

## In tiles.
@export var ward_range : float = 3.0
@export var targets : int = 4
## The ward ring's colour (the cave shaman's stone skin is grey).
@export var ward_color : Color = FireWard.COLOR

var warded : Array[Enemy] = []


func _can_use() -> bool:
	warded = _pick_targets()
	return not warded.is_empty()


func _run() -> void:
	if not await _play_and_wait(GlobalAnimationNames.ATTACK_ANIMATION):
		return
	for other in warded:
		if is_instance_valid(other):
			FireWard.give(other, ward_color)
	_finish()


func _pick_targets() -> Array[Enemy]:
	var found : Array[Enemy] = []
	if enemy == null or enemy.level == null:
		return found
	var reach : float = ward_range * Utils.TILE_SIZE
	for other in enemy.level.existing_enemies:
		if is_instance_valid(other) and not other.is_dead and not other.is_deactivated and other.fire_ward == null \
				and other.global_position.distance_to(enemy.global_position) <= reach:
			found.append(other)
	found.sort_custom(_is_nearer)
	return found.slice(0, targets)


func _is_nearer(a : Enemy, b : Enemy) -> bool:
	return a.global_position.distance_squared_to(enemy.global_position) < b.global_position.distance_squared_to(enemy.global_position)
