class_name Stats
extends Node


var stats : Array[Stat] :
	get = _get_stats

signal stat_changed(stat : Stat)
signal stats_changed(stat : Stat)


func _ready() -> void:
	stats = _get_stats()


func _get_stats() -> Array[Stat]:
	if stats.is_empty():
		for child in get_children():
			if child is Stat:
				stats.append(child)
				if not child.changed.is_connected(_on_stat_changed):
					child.changed.connect(_on_stat_changed)
	return stats


func _on_stat_changed(_stat : Stat) -> void:
	stat_changed.emit(_stat)
	stats_changed.emit()


func get_stat(_stat_type : Utils.StatType) -> Stat:
	for stat in stats:
		if stat.type == _stat_type:
			return stat
	return null


func get_stat_value(_stat_type : Utils.StatType) -> float:
	for stat in stats:
		if stat.type == _stat_type:
			return stat.value
	return 0.0


func get_range_in_tiles() -> float:
	return get_stat_value(Utils.StatType.AttackRange) * Utils.TILE_SIZE + (Utils.TILE_SIZE * 0.25)
