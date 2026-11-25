class_name SpeedAura
extends Node

## The war drummer's beat: every other ground enemy within `radius` tiles moves `bonus` faster (one Multiply modifier
## each, taken off when it leaves the beat or the drummer falls). Two drummers do not stack on one enemy.

const UPDATE_SECONDS : float = 0.5
const DRUMMED_META : StringName = &"drummed_by"

## In tiles.
@export var radius : float = 2.5
@export var bonus : float = 0.25

@onready var enemy : Enemy = get_parent()

#enemy -> the modifier it got from this drummer; keys untyped so freed enemies can be checked
var buffed : Dictionary = {}
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
	for other in enemy.level.existing_enemies:
		if not is_instance_valid(other) or other == enemy:
			continue
		var inside : bool = not other.is_dead and not other.is_deactivated and not other.is_flying \
				and other.global_position.distance_to(enemy.global_position) <= reach
		if inside and not buffed.has(other) and not other.has_meta(DRUMMED_META):
			var modifier : ModifierData = Elite.multiply(Utils.StatType.Speed, 1.0 + bonus)
			other.modifier_manager.add_modifier(modifier)
			other.set_meta(DRUMMED_META, true)
			buffed[other] = modifier
		elif not inside and buffed.has(other):
			_release(other)
	for other in buffed.keys():
		if not is_instance_valid(other):
			buffed.erase(other)


func _release(other) -> void:
	var modifier : ModifierData = buffed[other]
	buffed.erase(other)
	if is_instance_valid(other):
		other.modifier_manager.remove_modifier(modifier)
		other.remove_meta(DRUMMED_META)


func _release_all() -> void:
	for other in buffed.keys():
		_release(other)


func _on_enemy_destroyed(destroyed : Enemy) -> void:
	if destroyed == enemy:
		_release_all()
		timer.stop()
	elif buffed.has(destroyed):
		buffed.erase(destroyed)


func _exit_tree() -> void:
	_release_all()
