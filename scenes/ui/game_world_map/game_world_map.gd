class_name GameWorldMap
extends Control


const TALENTS_TEXT : String = "Talents"
const TALENTS_WITH_POINTS_TEXT : String = "Talents (%d)"

@onready var to_menu_button : Button = $ToMenuButton
@onready var talents_button : Button = $TalentsButton
@onready var map : Node = $MarginContainer/Map
var map_level_elements : Array[MapLevelElement]


func _ready() -> void:
	_get_map_level_elements()
	_reveal_new_level()
	to_menu_button.pressed.connect(_on_to_menu_pressed)
	talents_button.pressed.connect(_on_talents_pressed)
	PlayerProgress.talents_changed.connect(_update_talents_button)
	_update_talents_button()


#unspent points show on the button, so the player knows to spend them
func _update_talents_button() -> void:
	var unspent : int = PlayerProgress.get_talent_points_unspent()
	talents_button.text = TALENTS_WITH_POINTS_TEXT % unspent if unspent > 0 else TALENTS_TEXT


func _on_talents_pressed() -> void:
	UISignals.talents.emit(true)


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


#the level unlocked since the map was last shown pops in, once
func _reveal_new_level() -> void:
	var newest : int = PlayerProgress.level_progress
	if newest <= PlayerProgress.map_revealed_level:
		return

	for element in map_level_elements:
		if element.level_number == newest and element.visible:
			element.pop_in()
	PlayerProgress.map_revealed_level = newest
	PlayerProgress.save_progress()


func _on_element_is_selected(map_level_element : MapLevelElement) -> void:
	for element in map_level_elements:
		if element == map_level_element:
			continue
			
		element._on_close_button_pressed()


func _on_to_menu_pressed() -> void:
	UISignals.to_menu.emit(true, name)
