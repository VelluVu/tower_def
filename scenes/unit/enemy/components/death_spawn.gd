class_name DeathSpawn
extends Node

## When its enemy is killed (not when it leaks), `count` enemies of `scene` come out where it fell: the obsidian golem
## cracks into two magma blobs.

@export var scene : PackedScene = null
@export var count : int = 2

@onready var enemy : Enemy = get_parent()


func _ready() -> void:
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)


func _on_enemy_destroyed(destroyed : Enemy) -> void:
	if destroyed != enemy or scene == null or not enemy.is_dead or not enemy.gives_reward or enemy.level == null:
		return
	EnemySummon.summon_around(scene, enemy, count, enemy.grid_position)
