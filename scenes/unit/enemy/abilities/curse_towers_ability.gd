class_name CurseTowersAbility
extends EnemyAbility

## The bog witch's hex: stops, raises her staff (ATTACK) and curses up to `targets` towers within `curse_range`
## tiles, uncursed ones first, nearest first (TowerCurse: slower attacks for a while).

## In tiles.
@export var curse_range : float = 3.5
@export var targets : int = 2
## Taken off the tower's attack speed bonus (0.3: about 40% longer between attacks for a tower without bonus).
@export var slow : float = 0.3
@export var curse_seconds : float = 5.0

var cursed : Array[Tower] = []


func _can_use() -> bool:
	cursed = _pick_targets()
	return not cursed.is_empty()


func _run() -> void:
	enemy.animation_control.flip(cursed[0].global_position - enemy.global_position)
	if not await _play_and_wait(GlobalAnimationNames.ATTACK_ANIMATION):
		return
	for tower in cursed:
		TowerCurse.give(tower, slow, curse_seconds)
	_finish()


func _pick_targets() -> Array[Tower]:
	var fresh : Array[Tower] = []
	if enemy == null or enemy.level == null:
		return fresh
	var reach : float = curse_range * Utils.TILE_SIZE
	for building in enemy.level.all_buildings:
		if not is_instance_valid(building) or building is not Tower or building.is_dead or not building.is_placed:
			continue
		#already cursed: no use spending the cast on renewing it
		if building.has_node(TowerCurse.NAME) or building.global_position.distance_to(enemy.global_position) > reach:
			continue
		fresh.append(building)
	fresh.sort_custom(_is_nearer)
	return fresh.slice(0, targets)


func _is_nearer(a : Tower, b : Tower) -> bool:
	return a.global_position.distance_squared_to(enemy.global_position) < b.global_position.distance_squared_to(enemy.global_position)
