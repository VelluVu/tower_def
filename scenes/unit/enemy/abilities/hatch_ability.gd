class_name HatchAbility
extends EnemyAbility

## An egg sac's countdown: after the cooldown it bursts (HATCH) into a group of hatchlings and is
## gone without a reward. Popping it first is the towers' job. Set starts_on_cooldown.

@export var hatchling_scene : PackedScene
@export var hatchling_count : int = 6


func _run() -> void:
	if not await _play_and_wait(GlobalAnimationNames.HATCH_ANIMATION):
		return

	#the hatchlings exist before the sac is gone, so the wave never counts as cleared in between
	if hatchling_scene != null:
		EnemySummon.summon_around(hatchling_scene, enemy, hatchling_count, enemy.grid_position)
	_finish()
	enemy.remove_without_reward()
