class_name GoreEmitter
extends Node2D

#different gore for damage types?
@export var gore_effect_scene : PackedScene

@export_group("Death")
## Gore bursts when the unit dies, one after another over the death animation (0 = none; a boss leaves a pool).
@export var death_bursts : int = 0
## Particles per death burst, like a hit for half as much damage.
@export var death_burst_amount : int = 12
## The bursts land up to this many pixels left and right of the unit, half as far up and down.
@export var death_spread : float = 16.0
## Seconds between death bursts, at 1x speed.
@export var death_burst_interval : float = 0.08

var pool : Array[GoreEffect]
var death_bursts_left : int = 0
var death_timer : CustomTimer = null


func emit_gore(damage_data : DamageData) -> void:
	if damage_data.damage < 1.0:
		return
	_emit_burst(Vector2.ZERO, round(damage_data.damage * 2))


## The death bursts (death_bursts); the corpse waits for them through is_emitting.
func emit_death_gore() -> void:
	if death_bursts <= 0:
		return

	if death_timer == null:
		death_timer = CustomTimer.new()
		death_timer.one_shot = true
		add_child(death_timer)
		death_timer.unscaled_base_value = death_burst_interval
		death_timer.timeout.connect(_on_death_timer_timeout)

	death_bursts_left = death_bursts
	_on_death_timer_timeout()


func is_emitting() -> bool:
	return death_bursts_left > 0 or pool.any(func(gore : GoreEffect) -> bool: return gore.is_busy)


func _emit_burst(offset : Vector2, amount : int) -> void:
	var gore : GoreEffect = get_gore()
	#the splat lands at the gore's position minus the emitter's own offset: under the unit, moved by offset
	gore.position = offset
	gore.main_effect_offset = position
	gore.emitter_name = get_parent().name
	gore.play(amount)


func _on_death_timer_timeout() -> void:
	if death_bursts_left <= 0:
		return

	death_bursts_left -= 1
	_emit_burst(Vector2(randf_range(-1.0, 1.0) * death_spread, randf_range(-0.5, 0.5) * death_spread), death_burst_amount)

	if death_bursts_left > 0:
		death_timer.start()


func get_gore() -> GoreEffect:
	#create new gore if pool is empty
	if pool.is_empty():
		return create_gore()
	
	#check if first has landed its splat
	if not pool[0].is_busy:
		var next_in_line = pool.pop_front()
		pool.push_back(next_in_line)
		return next_in_line
	
	#create new gore if the first is still busy
	return create_gore()


func create_gore() -> GoreEffect:
	var new_gore : GoreEffect = gore_effect_scene.instantiate()
	var new_name : String = new_gore.name + str(pool.size())
	new_gore.name = new_name
	add_child(new_gore)
	pool.push_back(new_gore)
	return new_gore
