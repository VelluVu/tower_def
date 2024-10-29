class_name BuildingOption
extends Panel


@onready var button : Button = $SelectBuildingButton

var building_index : int = 0

signal is_activated(is_activated : bool, option : BuildingOption)


func _ready() -> void:
	GameSignals.building_placement_change.connect(_on_building_placement_change)
	UISignals.focus_building_option.connect(_focus_building_changed)
	UISignals.building_option_updated.connect(_on_building_option_updated)


func _on_building_placement_change(is_placing : bool) -> void:
	if not is_placing:
		if button.button_pressed:
			button.button_pressed = false


func _focus_building_changed(index : int):
	if index < 0:
		if button.button_pressed:
			button.button_pressed = false
	if index == building_index:
		button.button_pressed = true


func _on_select_building_button_pressed() -> void:
	is_activated.emit(button.button_pressed, self)
	UISignals.building_option_selected.emit(building_index)


func _on_building_option_updated(_building_index : int, _icon : Texture2D) -> void:
	if building_index != _building_index:
		return
		
	button.icon = _icon
