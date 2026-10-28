class_name EnemyAbility
extends Node

## One thing an enemy does besides walking (a boss phase move, an egg sac hatching). A child of
## EnemyAbilities; the UseAbilities leaf starts it when it is ready and holds the enemy still
## while it is active. Subclasses override _run and call _finish when done.

const NO_ANIMATION_WARNING : String = " has no animation: "

## Usable while the enemy's health share is in (min, max].
@export_range(0.0, 1.0) var min_health_ratio : float = 0.0
@export_range(0.0, 1.0) var max_health_ratio : float = 1.0
## Seconds between uses; 0 = only once.
@export var cooldown : float = 5.0
## The first use waits a full cooldown instead of starting at once.
@export var starts_on_cooldown : bool = false
## Uses per enemy; 0 = no limit.
@export var max_uses : int = 0

var enemy : Enemy = null
var is_active : bool = false
var use_count : int = 0
var cooldown_timer : CustomTimer = null

var health_ratio : float :
	get:
		var max_health : float = enemy.stats.get_stat_value(Utils.StatType.MaxHealth)
		return enemy.stats.get_stat_value(Utils.StatType.Health) / max_health if max_health > 0.0 else 0.0

var is_ready : bool :
	get:
		if is_active or not cooldown_timer.is_stopped():
			return false
		if cooldown <= 0.0 and use_count > 0:
			return false
		if max_uses > 0 and use_count >= max_uses:
			return false
		var ratio : float = health_ratio
		return ratio > min_health_ratio and ratio <= max_health_ratio


func setup(_enemy : Enemy) -> void:
	enemy = _enemy
	cooldown_timer = CustomTimer.new()
	cooldown_timer.one_shot = true
	add_child(cooldown_timer)
	cooldown_timer.unscaled_base_value = cooldown

	if starts_on_cooldown and cooldown > 0.0:
		cooldown_timer.start()


func use() -> void:
	is_active = true
	use_count += 1
	_run()


## The enemy died or was removed in the middle: drop what is left.
func interrupt() -> void:
	is_active = false


func _run() -> void:
	_finish()


func _finish() -> void:
	if not is_active:
		return

	is_active = false
	if cooldown > 0.0:
		cooldown_timer.start()


## Plays a one-shot animation and waits for it; false when the enemy died meanwhile.
func _play_and_wait(animation_name : String) -> bool:
	var sprite : AnimationControl = enemy.animation_control
	if not sprite.sprite_frames.has_animation(animation_name):
		push_warning(enemy.name, NO_ANIMATION_WARNING, animation_name)
		return _is_still_going()

	sprite.play_animation(animation_name)
	while sprite.animation == animation_name and sprite.is_playing():
		await sprite.animation_finished
	return _is_still_going()


func _wait(seconds : float) -> bool:
	var timer : CustomTimer = CustomTimer.new()
	timer.one_shot = true
	add_child(timer)
	timer.unscaled_base_value = seconds
	timer.start()
	await timer.timeout
	timer.queue_free()
	return _is_still_going()


func _is_still_going() -> bool:
	return is_active and is_instance_valid(enemy) and not enemy.is_dead and not enemy.is_deactivated
