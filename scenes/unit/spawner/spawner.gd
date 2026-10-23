class_name Spawner
extends Node2D

#a spawn point, the level's WaveRunner tells it what to spawn

const NO_SPAWNABLE_SCENE_WARNING : String = " There are no spawnable scene!"
const SPAWN_GROUP_RUNNER_NAME : String = "SpawnGroupRunner"

@export var id : int = 0
@export var end_point : Marker2D


func _ready() -> void:
	if not is_in_group(GroupNames.SPAWNER):
		add_to_group(GroupNames.SPAWNER)


#on_finished is connected before the first spawn, so a group without delay still reports back
func spawn_group(group : SpawnGroupData, on_finished : Callable) -> void:
	var runner : SpawnGroupRunner = SpawnGroupRunner.new()
	runner.name = SPAWN_GROUP_RUNNER_NAME
	add_child(runner, true)
	runner.group_finished.connect(on_finished)
	runner.run(group, self)


func spawn(spawnable_packed_scene : PackedScene) -> void:
	if spawnable_packed_scene == null:
		push_warning(name, NO_SPAWNABLE_SCENE_WARNING)
		return

	var spawned : Node = spawnable_packed_scene.instantiate()

	if spawned is Enemy:
		spawned.end_point = end_point

	add_child(spawned)
