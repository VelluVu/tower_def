class_name BossSpawnArt
extends AnimatedSprite2D

## A boss lair's spawn art (2026-11-24, the Hydra's pool): plays BOIL for a few loops when a boss spawns, then goes
## back to IDLE. Only looks.

## How many times BOIL plays before the art settles again.
@export var boil_loops : int = 6

var loops_left : int = 0


func _ready() -> void:
	GameSignals.enemy_spawned.connect(_on_enemy_spawned)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	animation_looped.connect(_on_animation_looped)


func _on_enemy_spawned(enemy : Enemy) -> void:
	if not enemy.is_boss or not sprite_frames.has_animation(GlobalAnimationNames.BOIL_ANIMATION):
		return
	loops_left = boil_loops
	play(GlobalAnimationNames.BOIL_ANIMATION)


func _on_animation_looped() -> void:
	if animation != GlobalAnimationNames.BOIL_ANIMATION:
		return
	loops_left -= 1
	if loops_left <= 0:
		play(GlobalAnimationNames.IDLE_ANIMATION)


func _on_time_scale_change(new_time_scale : float) -> void:
	speed_scale = new_time_scale
