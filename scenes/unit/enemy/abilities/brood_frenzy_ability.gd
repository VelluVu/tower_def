class_name BroodFrenzyAbility
extends ScreechAbility

## Brood frenzy (the Broodmother under 33%, once): a screech, then she speeds up and a swarm
## of flyers leaves her back for the castle.

## Multiply on Speed, 0.5 = 50% faster.
@export var speed_bonus : float = 0.5
@export var swarm_scene : PackedScene
@export var swarm_count : int = 6


func _on_screech() -> void:
	var haste : ModifierData = ModifierData.new()
	haste.calculate_type = Utils.ModifyType.Multiply
	haste.stat_type = Utils.StatType.Speed
	haste.value = speed_bonus
	enemy.modifier_manager.add_modifier(haste)

	if swarm_scene != null:
		EnemySummon.summon_around(swarm_scene, enemy, swarm_count, enemy.grid_position)
