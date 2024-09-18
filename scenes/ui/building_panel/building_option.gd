class_name BuildingOption
extends Panel


@onready var button : Button = $SelectBuildingButton
@export var building_index : int = 0
signal is_activated(is_activated : bool, option : BuildingOption)


func _ready() -> void:
	UiSignals.building_placement_change.connect(_on_building_placement_change)


func _on_building_placement_change(is_placing : bool) -> void:
	if not is_placing:
		if button.button_pressed:
			button.button_pressed = false


func _on_select_building_button_pressed() -> void:
	is_activated.emit(button.button_pressed, self)
	UiSignals.building_option_selected.emit(building_index)


func _on_select_building_button_toggled(toggled_on: bool) -> void:
	if not toggled_on:
		button.release_focus()
