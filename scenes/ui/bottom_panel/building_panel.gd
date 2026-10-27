class_name BuildingPanel
extends Panel


@onready var grid_container : GridContainer = $MarginContainer/BackgroundImage/ScrollContainer/GridContainer

var building_options : Array[BuildingOption]


func _ready() -> void:
	_get_building_options()
	UISignals.buildings_updated.connect(_on_buildings_updated)
	_fit_to_options()


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
	#locked buildings are hidden, so the tray grows as the levels unlock them
	for i in building_options.size():
		building_options[i].visible = i < available_buildings
	_fit_to_options()


#the scroll container hides the grid's size from the tray, so the tray width follows the visible slots by hand
func _fit_to_options() -> void:
	custom_minimum_size = grid_container.get_combined_minimum_size()
