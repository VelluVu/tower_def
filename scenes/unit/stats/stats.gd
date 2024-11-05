class_name Stats
extends Node


var stats : Array[Stat]
#@export var base_stats : Stats
signal stat_changed(stat : Stat)
signal stats_changed(stat : Stat)
#var stats : Stats
#var previous_stats : Stats


func _ready() -> void:
	for child in get_children():
		if child is Stat:
			stats.append(child)
			child.changed.connect(_on_stat_changed)
	#stats = base_stats.duplicate()
	#previous_stats = stats.duplicate()
	#stats.changed.connect(_on_stats_changed)


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
	return get_stat_value(Utils.StatType.AttackRange) * Utils.TILE_SIZE + (Utils.TILE_SIZE * 0.5)


#THIS IS BECAUSE CANNOT MAKE OWN OBEJECT UNIQUE SIGNALS IN RESOURCES
#func _on_stats_changed() -> void:
	#if stats.health != previous_stats.health:
		#stat_changed.emit(Utils.StatType.Health, stats.health)
		#previous_stats.health = stats.health
		#
	#if stats.max_health != previous_stats.max_health:
		#stat_changed.emit(Utils.StatType.MaxHealth, stats.max_health)
		#previous_stats.max_health = stats.max_health
		#
	#if stats.damage != previous_stats.damage:
		#stat_changed.emit(Utils.StatType.Damage, stats.damage)
		#previous_stats.damage = stats.damage
		#
	#if stats.price != previous_stats.price:
		#stat_changed.emit(Utils.StatType.Price, stats.price)
		#previous_stats.price = stats.price
		#
	#if stats.speed != previous_stats.speed:
		#stat_changed.emit(Utils.StatType.Speed, stats.speed)
		#previous_stats.speed = stats.speed
		#
	#if stats.attack_range != previous_stats.attack_range:
		#stat_changed.emit(Utils.StatType.AttackRange, stats.attack_range)
		#previous_stats.attack_range = stats.attack_range

#any stat changed
