class_name SteadfastAura
extends Node

## The standard bearer's banner: every enemy within `radius` tiles of it (itself too) is steadfast (Enemy.is_steadfast):
## slows do nothing to it and it cannot be frozen. The answer to a Frost build; kill the bearer first.

const UPDATE_SECONDS : float = 0.5

## In tiles.
@export var radius : float = 2.5

@onready var enemy : Enemy = get_parent()

#the enemies this banner made steadfast; untyped so freed ones can be checked
var covered : Array = []
var timer : CustomTimer = null


func _ready() -> void:
	timer = CustomTimer.new()
	add_child(timer)
	timer.unscaled_base_value = UPDATE_SECONDS
	timer.timeout.connect(_update)
	timer.start()
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)


func _update() -> void:
	if not is_instance_valid(enemy) or enemy.is_dead or enemy.is_deactivated or enemy.level == null:
		_release_all()
		return
	var reach : float = radius * Utils.TILE_SIZE
	var inside : Array = []
	for other in enemy.level.existing_enemies:
		if is_instance_valid(other) and not other.is_dead and not other.is_deactivated \
				and other.global_position.distance_to(enemy.global_position) <= reach:
			inside.append(other)
	for other in covered.duplicate():
		if not inside.has(other):
			_set_steadfast(other, false)
	for other in inside:
		if not covered.has(other):
			_set_steadfast(other, true)


func _set_steadfast(other, value : bool) -> void:
	if value:
		covered.append(other)
	else:
		covered.erase(other)
	if not is_instance_valid(other):
		return
	#another banner may still cover it: leave it steadfast then
	if not value and _is_covered_elsewhere(other):
		return
	other.is_steadfast = value
	other.modifier_manager.calculate_modifier(Utils.StatType.Speed)
	if value and other.is_frozen:
		other.freeze_timer.stop()
		other.freeze_timer.timeout.emit()


func _is_covered_elsewhere(other) -> bool:
	for aura in enemy.get_tree().get_nodes_in_group(GroupNames.STEADFAST_AURAS):
		if aura != self and is_instance_valid(aura) and aura.covered.has(other):
			return true
	return false


func _release_all() -> void:
	for other in covered.duplicate():
		_set_steadfast(other, false)


func _enter_tree() -> void:
	add_to_group(GroupNames.STEADFAST_AURAS)


func _on_enemy_destroyed(destroyed : Enemy) -> void:
	if destroyed == enemy:
		_release_all()
		timer.stop()
	elif covered.has(destroyed):
		covered.erase(destroyed)


func _exit_tree() -> void:
	_release_all()
