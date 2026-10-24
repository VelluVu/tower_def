class_name DamageNumberManager
extends Node


const damage_number_scene : PackedScene = preload("res://scenes/ui/damage_number/damage_number.tscn")
const NUMBER_LAYER_NAME : String = "DamageNumberLayer"
const REACTION_TEXT_SUFFIX : String = "!"
const REACTION_TEXT_OFFSET : Vector2 = Vector2(0, -8)

var damage_number_pool : Array[DamageNumber]
#screen space, so the numbers stay crisp at any camera zoom; drawn under the UI layer that follows in Main
var number_layer : CanvasLayer = null
var spawned_count : int = 0


func _ready() -> void:
	number_layer = CanvasLayer.new()
	number_layer.name = NUMBER_LAYER_NAME
	add_child(number_layer)
	GameSignals.damage_taken.connect(_on_damage_taken)
	GameSignals.element_reaction.connect(_on_element_reaction)


func _on_damage_taken(_position : Vector2, _damage_data : DamageData) -> void:
	if _damage_data.rounded_damage == 0.0 or not SettingsManager.get_option(SettingsManager.OPTION_DAMAGE_NUMBERS):
		return
	var damage_number : DamageNumber = _get_damage_number()
	damage_number.activate(_position, _damage_data)

func _on_element_reaction(_position : Vector2, reaction : ElementReaction) -> void:
	if not SettingsManager.get_option(SettingsManager.OPTION_DAMAGE_NUMBERS):
		return
	#a bit higher, so the word does not cover the hit's own number
	_get_damage_number().activate_text(_position + REACTION_TEXT_OFFSET, reaction.display_name + REACTION_TEXT_SUFFIX, reaction.color)


#fix this signal is not happening
func _get_damage_number() -> DamageNumber:
	var number : DamageNumber = null
	
	if damage_number_pool.is_empty():
		number = damage_number_scene.instantiate()
		spawned_count += 1
		number.name = number.name + str(spawned_count)
		number_layer.add_child(number)
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
