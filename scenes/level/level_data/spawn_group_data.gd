class_name SpawnGroupData
extends Resource

#one enemy type from one spawner, part of a wave

@export var enemy_scene : PackedScene = null
@export var count : int = 5
#seconds between spawns at 1x speed, 0 spawns the whole group at once
@export var interval : float = 3.0
#seconds after the wave starts before the first spawn
@export var delay : float = 0.0
#matches Spawner.id in the level scene
@export var spawner_id : int = 0
