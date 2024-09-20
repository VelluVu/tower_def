class_name Stats
extends Resource


const STAT_CLASS_NAME : String = "Stat" 

@export var health : int :
	set(new_value):
		if health == new_value:
			return
		health = new_value
		emit_changed()

@export var max_health : int :
	set(new_value):
		if max_health == new_value:
			return
		max_health = new_value
		emit_changed()

@export var damage : int :
	set(new_value):
		if damage == new_value:
			return
		damage = new_value
		emit_changed()

@export var price : int :
	set(new_value):
		if price == new_value:
			return
		price = new_value
		emit_changed()

@export var speed : float :
	set(new_value):
		if speed == new_value:
			return
		speed = new_value
		emit_changed()
