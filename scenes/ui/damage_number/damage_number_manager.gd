class_name DamageNumberManager
extends Node


const damage_number_scene : PackedScene = preload("res://scenes/ui/damage_number/damage_number.tscn")
var damage_number_pool : Array[DamageNumber]
var spawned_count : int = 0


func _ready() -> void:
	GameSignals.damage_taken.connect(_on_damage_taken)


func _on_damage_taken(_position : Vector2, _amount : int, _type : Utils.DamageType) -> void:
	var damage_number : DamageNumber = _get_damage_number()
	damage_number.activate(_position, _amount, _type)

#fix this signal is not happening
func _get_damage_number() -> DamageNumber:
	var number : DamageNumber = null
	
	if damage_number_pool.is_empty():
		number = damage_number_scene.instantiate()
		spawned_count += 1
		number.name = number.name + str(spawned_count)
		add_child(number)
	else:
		number = damage_number_pool.pop_back()
	
	#this is not signaled
	if not number.deactivated.is_connected(_on_damage_number_available):
		number.deactivated.connect(_on_damage_number_available)
		
	return number

#this never occurs somehow
func _on_damage_number_available(damage_number : DamageNumber) -> void:
	if damage_number_pool.has(damage_number):
		return
		
	damage_number_pool.push_back(damage_number)
