class_name SlayersOathAbility
extends EnemyAbility

## Slayer's Oath (the Dragonslayer's last stand): he raises the sword, then takes less damage for a
## while, tinted gold. He walks on as soon as the oath is sworn; the ward runs on its own timer.

## Share of the damage he takes while the oath holds, 0.5 = half.
@export var damage_taken_factor : float = 0.5
@export var ward_time : float = 4.0
@export var ward_tint : Color = Color("fee761")

var ward_timer : CustomTimer = null


func setup(_enemy : Enemy) -> void:
	super(_enemy)
	ward_timer = CustomTimer.new()
	ward_timer.one_shot = true
	add_child(ward_timer)
	ward_timer.unscaled_base_value = ward_time
	ward_timer.timeout.connect(_end_ward)


func _run() -> void:
	if not await _play_and_wait(GlobalAnimationNames.OATH_ANIMATION):
		return

	enemy.damage_taken_factor = damage_taken_factor
	enemy.animation_control.self_modulate = ward_tint
	ward_timer.start()
	_finish()


func _end_ward() -> void:
	if not is_instance_valid(enemy):
		return

	enemy.damage_taken_factor = 1.0
	enemy.animation_control.self_modulate = Color.WHITE
