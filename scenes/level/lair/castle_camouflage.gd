class_name CastleCamouflage
extends AnimatedSprite2D

## A boss lair's castle under rock (2026-11-24): placed over the castle in the level scene, it glows through its crack
## (IDLE) until the level's boss spawns, then sheds the rock (REVEAL, one shot, the camera shakes) and frees itself.
## Only looks: the castle under it works as always.

const REVEAL_SHAKE_PIXELS : float = 2.0

var is_revealing : bool = false


func _ready() -> void:
	play(GlobalAnimationNames.IDLE_ANIMATION)
	GameSignals.enemy_spawned.connect(_on_enemy_spawned)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	animation_finished.connect(_on_animation_finished)


func _on_enemy_spawned(enemy : Enemy) -> void:
	if is_revealing or not enemy.is_boss:
		return
	is_revealing = true
	play(GlobalAnimationNames.REVEAL_ANIMATION)
	var camera : GameCamera = get_viewport().get_camera_2d() as GameCamera
	if camera != null:
		camera.shake(REVEAL_SHAKE_PIXELS)


func _on_time_scale_change(new_time_scale : float) -> void:
	speed_scale = new_time_scale


func _on_animation_finished() -> void:
	if animation == GlobalAnimationNames.REVEAL_ANIMATION:
		queue_free()
