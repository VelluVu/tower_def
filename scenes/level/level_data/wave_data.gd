class_name WaveData
extends Resource

#reusable between levels as long as the spawner ids exist there

@export var spawn_groups : Array[SpawnGroupData] = []
#gold for starting this wave before the previous one is cleared (placeholder until the formula is decided)
@export var early_start_bonus : float = 0.0
