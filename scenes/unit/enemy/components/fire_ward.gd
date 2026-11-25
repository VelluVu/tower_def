class_name FireWard
extends Node2D

## An ember cultist's ward on an enemy (FireWardAbility): the next direct hit from a tower is soaked whole, then the
## ward is gone. Damage over time ticks, splashes and reactions pass through it (a chain, line or ricochet hit is the
## tower's own attack landing, so it counts as direct). It fades on its own after DURATION seconds.

const NAME : String = "FireWard"
const DURATION : float = 8.0
const COLOR : Color = Color("f77622")
const RADIUS : float = 7.0

var enemy : Enemy = null
var timer : CustomTimer = null
#the ring's colour: flame for the cultist, stone grey for the cave shaman's stone skin
var color : Color = COLOR


## Wards the enemy unless it already has one; true when it got one.
static func give(target : Enemy, ring_color : Color = COLOR) -> bool:
	if target == null or target.fire_ward != null or target.is_dead or target.is_deactivated:
		return false
	var ward : FireWard = FireWard.new()
	ward.name = NAME
	ward.color = ring_color
	target.add_child(ward)
	return true


func _ready() -> void:
	enemy = get_parent()
	enemy.fire_ward = self
	position = enemy.hit_box.position
	z_index = 2
	timer = CustomTimer.new()
	timer.one_shot = true
	add_child(timer)
	timer.unscaled_base_value = DURATION
	timer.timeout.connect(_end)
	timer.start()


## True when the ward soaked this hit (and is gone now).
func absorb(damage_data : DamageData) -> bool:
	if damage_data.is_overtime or damage_data.is_healing or damage_data.is_splash or damage_data.is_reaction:
		return false
	_end()
	return true


func _end() -> void:
	if is_instance_valid(enemy) and enemy.fire_ward == self:
		enemy.fire_ward = null
	queue_free()


#a thin flame ring around the body
func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 16, color, 1.0)
