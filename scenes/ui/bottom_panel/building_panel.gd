class_name BuildingPanel
extends MarginContainer


@onready var grid_container : GridContainer = $BackgroundImage/ScrollContainer/GridContainer

var building_options : Array[BuildingOption]


func _ready() -> void:
	_get_building_options()
	UISignals.buildings_updated.connect(_on_buildings_updated)


func _get_building_options() -> void:
	var children = grid_container.get_children()
	var count : int = 0
	for child in children:
		if child is BuildingOption:
			building_options.append(child)
			child.building_index = count
			child.is_activated.connect(_on_button_activated)
			count += 1


func _on_button_activated(_activated : bool, building_option : BuildingOption) -> void:
	if not _activated:
		return
		
	for option in building_options:
		if option != building_option:
			option.button.button_pressed = false


func _on_buildings_updated(available_buildings : int) -> void:
	for i in range(building_options.size() - 1, -1, -1):
		if i < available_buildings:
			return
			
		building_options[i].visible = false
