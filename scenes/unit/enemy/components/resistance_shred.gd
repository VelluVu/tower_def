class_name ResistanceShred
extends Node2D

## Torn armour from a Shredder's pulses: each stack takes `per_stack` off every resistance of the enemy (element and
## tower kind), never below 0; a new pulse adds a stack (up to `max_stacks`) and restarts the timer. Shown as small
## grey tears over the enemy.

const NAME : String = "ResistanceShred"
const COLOR : Color = Color("c0cbdc")

var enemy : Enemy = null
var stacks : int = 0
var per_stack : float = 0.15
var max_stacks : int = 3
var timer : CustomTimer = null


static func give(target : Enemy, share : float, most : int, seconds : float) -> void:
	if target == null or target.is_dead or target.is_deactivated:
		return
	var shred : ResistanceShred = target.get_node_or_null(NAME) as ResistanceShred
	if shred == null:
		shred = ResistanceShred.new()
		shred.name = NAME
		shred.enemy = target
		target.add_child(shred)
	shred.per_stack = share
	shred.max_stacks = most
	shred.stacks = mini(shred.stacks + 1, most)
	shred.timer.unscaled_base_value = seconds
	shred.timer.start()
	shred.queue_redraw()


## The share taken off each of the enemy's resistances (0 without a shred).
static func get_share(target : Enemy) -> float:
	var shred : ResistanceShred = target.get_node_or_null(NAME) as ResistanceShred
	return shred.per_stack * shred.stacks if shred != null else 0.0


func _ready() -> void:
	z_index = 2
	position = Vector2(0, -14)
	timer = CustomTimer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(queue_free)


#a short slash per stack
func _draw() -> void:
	for i in stacks:
		var x : float = (i - (stacks - 1) * 0.5) * 3.0
		draw_line(Vector2(x - 1, -1), Vector2(x + 1, 1), COLOR, 1.0)
