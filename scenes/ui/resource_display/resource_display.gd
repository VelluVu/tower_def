class_name ResourceDisplay
extends Control


@export var resource_display_elements : Array[ResourceDisplayElement]


func _ready() -> void:
	GameSignals.resource_change.connect(_resource_change)


func _resource_change(new_value : int, index : int) -> void:
	if index >= resource_display_elements.size():
		push_warning(name ," resource index " , index , " is out of bounds")
		return
	
	resource_display_elements[index].change_value(new_value)
