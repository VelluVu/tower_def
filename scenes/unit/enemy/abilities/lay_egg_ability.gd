class_name LayEggAbility
extends EnemyAbility

## Stops, plays LAY_EGG and leaves an egg sac on the enemy's cell (the Broodmother above 66%).

@export var egg_scene : PackedScene


func _run() -> void:
	if not await _play_and_wait(GlobalAnimationNames.LAY_EGG_ANIMATION):
		return

	if egg_scene != null:
		EnemySummon.summon(egg_scene, enemy, enemy.level.grid.snap_position_to_grid(enemy.global_position))
	_finish()
