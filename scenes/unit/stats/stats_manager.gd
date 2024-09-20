class_name StatsManager
extends Node


@export var base_stats : Stats

var stats : Stats


func _ready() -> void:
	stats = base_stats.duplicate()


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
