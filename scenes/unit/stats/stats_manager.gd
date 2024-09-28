class_name StatsManager
extends Node


signal stat_changed(stat_type, value)

@export var base_stats : Stats

var stats : Stats
var previous_stats : Stats

func _ready() -> void:
	stats = base_stats.duplicate()
	previous_stats = stats.duplicate()
	stats.changed.connect(_on_stats_changed)

#THIS IS BECAUSE CANNOT MAKE OWN OBEJECT UNIQUE SIGNALS IN RESOURCES
func _on_stats_changed() -> void:
	if stats.health != previous_stats.health:
		stat_changed.emit(Utils.StatType.Health, stats.health)
		previous_stats.health = stats.health
		
	if stats.max_health != previous_stats.max_health:
		stat_changed.emit(Utils.StatType.MaxHealth, stats.max_health)
		previous_stats.max_health = stats.max_health
		
	if stats.damage != previous_stats.damage:
		stat_changed.emit(Utils.StatType.Damage, stats.damage)
		previous_stats.damage = stats.damage
		
	if stats.price != previous_stats.price:
		stat_changed.emit(Utils.StatType.Price, stats.price)
		previous_stats.price = stats.price
		
	if stats.speed != previous_stats.speed:
		stat_changed.emit(Utils.StatType.Speed, stats.speed)
		previous_stats.speed = stats.speed
		
	if stats.attack_range != previous_stats.attack_range:
		stat_changed.emit(Utils.StatType.AttackRange, stats.attack_range)
		previous_stats.attack_range = stats.attack_range


#func set_health(new_value : int):
	#if stats.health == new_value:
		#return
		#
	#stats.health = new_value
	#stat_changed.emit()
#
#
#func set_max_health(new_value : int):
	#if stats.max_health == new_value:
		#return
		#
	#stats.max_health = new_value
	#stat_changed.emit()
#
#
#func set_damage(new_value : int):
	#if stats.damage == new_value:
		#return
		#
	#stats.damage = new_value
	#stat_changed.emit()
#
#
#func set_price(new_value : int): 
	#if stats.price == new_value:
		#return
		#
	#stats.price = new_value
	#stat_changed.emit()
#
#
#func set_speed(new_value : float):
	#if stats.speed == new_value:
		#return
		#
	#stats.speed = new_value
	#stat_changed.emit()
