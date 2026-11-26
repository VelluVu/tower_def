class_name EnemyNeighbours
extends RefCounted
## The level's living enemies bucketed by 16 px cell, rebuilt at most once per frame, so the
## spacing of each enemy looks only at the few in the cells round it, not at every enemy
## (one pass per frame instead of n x n with 200+ on the map). Holds positions and speeds,
## never the enemies, so nothing freed is kept.


const BUCKET_SIZE : float = 16.0

var _frame : int = -1
#Vector3i(cell x, cell y, 1 for flyers) -> Array of [instance id, position, speed]
var _buckets : Dictionary = {}


## Positions and speeds of the enemies near the position (same ground or air layer), except
## the asker; written into the two given arrays.
func collect(enemies : Array[Enemy], asker : Enemy, out_positions : Array[Vector2], out_speeds : Array[float]) -> void:
	var frame : int = Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_rebuild(enemies)
	var cell : Vector2i = cell_of(asker.global_position)
	var air : int = 1 if asker.is_flying else 0
	var own_id : int = asker.get_instance_id()
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			var bucket : Array = _buckets.get(Vector3i(x, y, air), [])
			for entry : Array in bucket:
				if entry[0] != own_id:
					out_positions.append(entry[1])
					out_speeds.append(entry[2])


static func cell_of(position : Vector2) -> Vector2i:
	return Vector2i(floori(position.x / BUCKET_SIZE), floori(position.y / BUCKET_SIZE))


func _rebuild(enemies : Array[Enemy]) -> void:
	_buckets.clear()
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_deactivated:
			continue
		var cell : Vector2i = cell_of(enemy.global_position)
		var key : Vector3i = Vector3i(cell.x, cell.y, 1 if enemy.is_flying else 0)
		if not _buckets.has(key):
			_buckets[key] = []
		_buckets[key].append([enemy.get_instance_id(), enemy.global_position, enemy.stats.get_stat_value(Utils.StatType.Speed)])
