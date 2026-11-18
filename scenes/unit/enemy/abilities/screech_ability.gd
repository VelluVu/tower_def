class_name ScreechAbility
extends EnemyAbility

## SCREECH: towers near the enemy stop attacking for a while (Tower.silence).

## In tiles from the enemy to the tower.
@export var silence_radius : float = 4.0
@export var silence_time : float = 2.0
## The Bone Colossus has no SCREECH; the Ashen Wyrm ROARs.
@export var screech_animation : String = GlobalAnimationNames.SCREECH_ANIMATION


func _run() -> void:
	if not await _play_and_wait(screech_animation):
		return

	_silence_towers()
	_on_screech()
	_finish()


func _silence_towers() -> void:
	var reach : float = silence_radius * Utils.TILE_SIZE
	for building in enemy.level.all_buildings:
		if building is Tower and is_instance_valid(building) and building.global_position.distance_to(enemy.global_position) <= reach:
			building.silence(silence_time)


#more after the screech in subclasses
func _on_screech() -> void:
	pass
