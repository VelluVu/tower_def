class_name WaveRunner
extends Node

#starts the level's waves on request and tracks when a wave has finished spawning

const NO_SPAWNER_WITH_ID_WARNING : String = " No spawner with id: "

signal spawning_finished()

var waves : Array[WaveData] = []
var spawners : Dictionary[int, Spawner] = {}
var current_wave_index : int = -1
var running_groups : int = 0

var wave_count : int :
	get:
		return waves.size()

#1-based, 0 before the first wave
var wave_number : int :
	get:
		return current_wave_index + 1

var is_spawning : bool :
	get:
		return running_groups > 0

var is_last_wave_started : bool :
	get:
		return wave_number >= wave_count

var can_start_next_wave : bool :
	get:
		return not is_spawning and not is_last_wave_started

var next_wave : WaveData :
	get:
		return null if is_last_wave_started else waves[current_wave_index + 1]


func setup(_waves : Array[WaveData], spawner_nodes : Array[Spawner]) -> void:
	waves = _waves

	for spawner in spawner_nodes:
		spawners[spawner.id] = spawner


func start_next_wave() -> void:
	if not can_start_next_wave:
		return

	current_wave_index += 1
	var groups : Array[SpawnGroupData] = []

	for group in waves[current_wave_index].spawn_groups:
		if not spawners.has(group.spawner_id):
			push_warning(name, NO_SPAWNER_WITH_ID_WARNING, group.spawner_id)
			continue
		groups.append(group)

	#count every group first, a group without delay finishes inside spawn_group
	running_groups = groups.size()

	if groups.is_empty():
		spawning_finished.emit()
		return

	for group in groups:
		spawners[group.spawner_id].spawn_group(group, _on_group_finished)


func _on_group_finished() -> void:
	running_groups -= 1

	if running_groups == 0:
		spawning_finished.emit()
