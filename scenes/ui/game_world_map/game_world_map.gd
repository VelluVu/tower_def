class_name GameWorldMap
extends Control


@onready var to_menu_button : Button = $ToMenuButton
@onready var map : Node = $MarginContainer/Map
var map_level_elements : Array[MapLevelElement]


func _ready() -> void:
	_get_map_level_elements()
	to_menu_button.pressed.connect(_on_to_menu_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("RightClick"):
		for map_element in map_level_elements:
			map_element._on_close_button_pressed()


func _get_map_level_elements() -> void:
	for child in map.get_children():
		if child is MapLevelElement:
			map_level_elements.append(child)
			if not child.is_selected.is_connected(_on_element_is_selected):
				child.is_selected.connect(_on_element_is_selected)


func _on_element_is_selected(map_level_element : MapLevelElement) -> void:
	for element in map_level_elements:
		if element == map_level_element:
			continue
			
		element._on_close_button_pressed()


func _on_to_menu_pressed() -> void:
	UISignals.to_menu.emit(true, name)
