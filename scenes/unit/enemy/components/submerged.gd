class_name Submerged
extends Node

## The bog lurker swims under the water: while more than `surface_cells` path cells are left to the castle it is
## submerged (Enemy.is_submerged): only area towers pick it (Nova, Mortar, Breather) and traps still bite; bolts,
## beams, harpoons, ricochets and chains pass it by. Near the castle it surfaces for good.

const CHECK_SECONDS : float = 0.25
const SUBMERGED_ALPHA : float = 0.45

@export var surface_cells : int = 8

@onready var enemy : Enemy = get_parent()

var timer : CustomTimer = null


func _ready() -> void:
	timer = CustomTimer.new()
	add_child(timer)
	timer.unscaled_base_value = CHECK_SECONDS
	timer.timeout.connect(_check)
	timer.start()
	#a child is ready before its enemy: the sprite is there only once the enemy is
	if not enemy.is_node_ready():
		await enemy.ready
	_set_submerged(true)


func _check() -> void:
	if not is_instance_valid(enemy) or enemy.is_dead or enemy.is_deactivated:
		timer.stop()
		return
	if enemy.has_path and enemy.get_remaining_path_waypoint_count() <= surface_cells:
		_set_submerged(false)
		timer.stop()


func _set_submerged(value : bool) -> void:
	enemy.is_submerged = value
	enemy.animation_control.modulate.a = SUBMERGED_ALPHA if value else 1.0
