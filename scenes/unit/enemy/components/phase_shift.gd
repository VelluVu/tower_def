class_name PhaseShift
extends Node

## The ash wraith fades out of the world for `phase_seconds` every `period` seconds (Enemy.is_phased): no tower picks
## it then and no direct hit lands, so a beam loses it and a slow bolt may arrive at nothing; damage over time still
## ticks and a burst that lands after it is back catches it.

const PHASED_ALPHA : float = 0.25

@export var period : float = 4.0
@export var phase_seconds : float = 1.0

@onready var enemy : Enemy = get_parent()

var period_timer : CustomTimer = null
var phase_timer : CustomTimer = null


func _ready() -> void:
	period_timer = CustomTimer.new()
	add_child(period_timer)
	period_timer.unscaled_base_value = period
	period_timer.timeout.connect(_fade_out)
	period_timer.start()
	phase_timer = CustomTimer.new()
	phase_timer.one_shot = true
	add_child(phase_timer)
	phase_timer.unscaled_base_value = phase_seconds
	phase_timer.timeout.connect(_fade_in)


func _fade_out() -> void:
	if not is_instance_valid(enemy) or enemy.is_dead or enemy.is_deactivated:
		period_timer.stop()
		return
	enemy.is_phased = true
	enemy.animation_control.modulate.a = PHASED_ALPHA
	phase_timer.start()


func _fade_in() -> void:
	if not is_instance_valid(enemy):
		return
	enemy.is_phased = false
	enemy.animation_control.modulate.a = 1.0
