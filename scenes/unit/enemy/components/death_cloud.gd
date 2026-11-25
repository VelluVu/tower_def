class_name DeathCloud
extends Node

## The spore carrier's end: killed (not leaked), it bursts into a healing SporeCloud where it fell.

## In tiles.
@export var radius : float = 1.5
@export var duration : float = 4.0
## Of each enemy's max health per second.
@export var heal_share : float = 0.06

@onready var enemy : Enemy = get_parent()


func _ready() -> void:
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)


func _on_enemy_destroyed(destroyed : Enemy) -> void:
	if destroyed != enemy or not enemy.is_dead or not enemy.gives_reward or enemy.level == null:
		return
	SporeCloud.make(enemy.level, enemy.global_position, radius, duration, heal_share)
