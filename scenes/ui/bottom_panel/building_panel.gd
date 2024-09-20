class_name BuildingPanel
extends MarginContainer

@onready var grid_container : GridContainer = $BackgroundImage/ScrollContainer/GridContainer
var building_options : Array[BuildingOption]


func _ready() -> void:
	_get_building_options()


func _get_building_options() -> void:
	var children = grid_container.get_children()
	for child in children:
		if child is BuildingOption:
			building_options.append(child)
			child.is_activated.connect(_on_button_activated)


func _on_button_activated(_activated : bool, building_option : BuildingOption) -> void:
	if not _activated:
		return
		
	for option in building_options:
		if option != building_option:
			option.button.button_pressed = false
