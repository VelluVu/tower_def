class_name SpikeSlow
extends Node

## A Spike Field's sting in the feet: the enemy moves `share` slower (one Multiply modifier) for a moment. A new
## sting restarts it; stings never stack.

const NAME : String = "SpikeSlow"

var enemy : Enemy = null
var modifier : ModifierData = null
var timer : CustomTimer = null


static func give(target : Enemy, share : float, seconds : float) -> void:
	var old : SpikeSlow = target.get_node_or_null(NAME) as SpikeSlow
	if old != null:
		old.timer.start()
		return
	var slow : SpikeSlow = SpikeSlow.new()
	slow.name = NAME
	slow.enemy = target
	slow.modifier = Elite.multiply(Utils.StatType.Speed, 1.0 - share)
	target.add_child(slow)
	slow.timer.unscaled_base_value = seconds
	slow.timer.start()


func _ready() -> void:
	timer = CustomTimer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_end)
	enemy.modifier_manager.add_modifier(modifier)


func _end() -> void:
	if is_instance_valid(enemy):
		enemy.modifier_manager.remove_modifier(modifier)
	queue_free()
