class_name Emitter
extends Node2D


@export var particle_scene : PackedScene
@export var amount_particles : int = 16

@onready var timer : CustomTimer = $CustomTimer

var is_old : bool = false
var is_emitting : bool = false
var count : int = 0
var rad_step : float = 0.0
var current_rad : float = 0.0
var speed : float = 0.0
var pool : Array[Node2D]
var alive_particles : Array[Node2D]

signal finished(node : Node2D)


func _ready() -> void:
	timer.timeout.connect(_on_timer_end)
	count = 0


func start(_max_range : float, _active_time : float) -> void:
	timer.base_wait_time = _active_time
	speed = _max_range / _active_time
	
	for n in amount_particles:
		var new_particle : Node2D = _get_particle()
		new_particle.global_position = global_position
		alive_particles.append(new_particle)
	
	timer.start()
	_emit_projectiles_in_circle_pattern()


func _exit_tree() -> void:
	clear_all_particles()


func _on_timer_end() -> void:
	if is_old:
		clear_all_particles()
		finished.emit(self)
		return
		
	for particle in alive_particles:
		pool.push_back(particle)
		particle.hide()
		
	alive_particles.clear()
	finished.emit(self)


func clear_all_particles() -> void:
	if not alive_particles.is_empty():
		for particle in alive_particles:
			if particle != null:
				particle.queue_free()
		alive_particles.clear()
	
	if not pool.is_empty():
		for item in pool:
			if item != null:
				item.queue_free()
		pool.clear()


func _emit_projectiles_in_circle_pattern() -> void:
	rad_step = 2.0 * PI / amount_particles
	current_rad = 0.0
	
	for particle in alive_particles:
		_emit_projectile_int_circle_pattern(particle)


func _emit_projectile_int_circle_pattern(particle : Node2D) -> void:
	var direction : Vector2 = Vector2.RIGHT.rotated(current_rad)
	var velocity : Vector2 = direction * speed
	particle.launch(global_position, velocity, timer.base_wait_time)
	current_rad += rad_step


func _get_particle() -> Node2D:
	var new_particle : Node2D = null
	
	if pool.is_empty():
		new_particle = particle_scene.instantiate()
		Utils.game_control.scene_manager.current_level.add_child(new_particle)
	else:
		new_particle = pool.pop_back()
		new_particle.show()
	
	count += 1
	new_particle.name = new_particle.name + str(count) + "_" + get_parent().name
	return new_particle
