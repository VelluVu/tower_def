class_name Spawner
extends Node2D


const NO_SPAWNABLE_SCENE_WARNING : String = " There are no spawnable scene!"

@onready var spawn_interval_timer : Timer = $SpawnIntervalTimer
@onready var spawn_start_delay_timer : Timer = $SpawnStartDelayTimer

@export var start_from_timer : bool = true
@export var id : int = 0
@export var max_spawns : int = 3
@export var spawn_interval : float = 3.0
@export var start_spawn_delay_time : float = 2.0
@export var spawnable_packed_scene : PackedScene
@export var end_point : Marker2D

var current_spawn_count : int = 0


func _ready() -> void:
	if not is_in_group(GroupNames.SPAWNER):
		add_to_group(GroupNames.SPAWNER)
	
	spawn_interval_timer.wait_time = spawn_interval
	spawn_start_delay_timer.wait_time = start_spawn_delay_time
	spawn_interval_timer.timeout.connect(_on_spawn_interval_tick)
	spawn_start_delay_timer.timeout.connect(_on_spawn_delay_finished)
	
	if start_from_timer:
		spawn_start_delay_timer.start()
		return
	
	spawn_interval_timer.start()


func _on_spawn_delay_finished() -> void:
	spawn_interval_timer.start()


func _on_spawn_interval_tick() -> void:
	if spawnable_packed_scene == null:
		push_warning(name, NO_SPAWNABLE_SCENE_WARNING)
		return
	
	if current_spawn_count >= max_spawns:
		spawn_interval_timer.stop()
		return
	
	var spawn = spawnable_packed_scene.instantiate()
	
	if spawn is Enemy:
		spawn.end_point = end_point
		
	add_child(spawn)
	current_spawn_count += 1
