class_name SpawnGroupRunner
extends CustomTimer

#spawns one SpawnGroupData from its spawner and frees itself when done

const NO_ENEMY_SCENE_WARNING : String = " Spawn group has no enemy scene!"

signal group_finished()

var group : SpawnGroupData = null
var spawner : Spawner = null
var spawned_count : int = 0


func run(_group : SpawnGroupData, _spawner : Spawner) -> void:
	group = _group
	spawner = _spawner
	one_shot = true
	timeout.connect(_spawn_next)

	if group.enemy_scene == null or group.count <= 0:
		push_warning(name, NO_ENEMY_SCENE_WARNING)
		_finish()
		return

	if group.delay > 0.0:
		_wait(group.delay)
		return

	_spawn_next()


func _spawn_next() -> void:
	spawner.spawn(group.enemy_scene)
	spawned_count += 1

	if group.interval <= 0.0:
		while spawned_count < group.count:
			spawner.spawn(group.enemy_scene)
			spawned_count += 1

	if spawned_count >= group.count:
		_finish()
		return

	_wait(group.interval)


func _wait(seconds : float) -> void:
	unscaled_base_value = seconds
	start()


func _finish() -> void:
	group_finished.emit()
	queue_free()
