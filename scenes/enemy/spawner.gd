class_name Spawner
extends Node2D

@onready var spawn_interval_timer : Timer = $SpawnIntervalTimer
@onready var spawn_start_delay_timer : Timer = $SpawnStartDelayTimer
@export var id : int = 0
@export var spawnable_packed_scene : PackedScene
@export var start_from_timer : bool = true
@export var end_point : Marker2D
@export var max_spawns : int = 3
var level : Level = null
var current_spawn_count : int = 0


func _ready() -> void:
	if start_from_timer:
		spawn_start_delay_timer.start()
		
	spawn_interval_timer.timeout.connect(_on_spawn_interval_tick)
	spawn_start_delay_timer.timeout.connect(_on_spawn_delay_finished)


func _on_spawn_delay_finished() -> void:
	spawn_interval_timer.start()


func _on_spawn_interval_tick() -> void:
	if spawnable_packed_scene == null:
		push_warning("There are no spawnable scene")
		return
	
	if current_spawn_count >= max_spawns:
		spawn_interval_timer.stop()
		return
	
	var spawn = spawnable_packed_scene.instantiate()
	spawn.name = spawn.name + str(id) + str(current_spawn_count)
	add_child(spawn)
	
	if spawn is Enemy:
		if level == null:
			level = get_parent()
		spawn.start_enemy(level, end_point)
		
	current_spawn_count += 1
