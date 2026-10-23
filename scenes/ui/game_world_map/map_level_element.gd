class_name MapLevelElement
extends Panel


signal is_selected(MapLevelElement)

const LEVEL_DATA_PATH_FORMAT : String = "res://scenes/level/level_data/level_%03d_data.tres"
const DEFAULT_NAME_FORMAT : String = "Level %d"
const INFO_FORMAT : String = "%d waves
Start: %d gold, %d life"
const STORY_FORMAT : String = "%s

%s"
const MISSING_LEVEL_DATA_WARNING : String = "No level data for map level %d at %s"

@onready var tooltip : Panel = $Tooltip
@onready var start_button : Button = $Tooltip/StartButton
@onready var close_button : Button = $Tooltip/CloseButton
@onready var select_button : Button = $SelectButton
@onready var lock_texture : TextureRect = $LockTexture
@onready var name_label : Label = $Tooltip/InfoMarginContainer/VBoxContainer/LevelName
@onready var info_label : Label = $Tooltip/InfoMarginContainer/VBoxContainer/LevelInfo

@export var level_number : int = 1

var is_locked : bool = false :
	set = _set_is_locked


func _ready() -> void:
	is_locked = PlayerProgress.level_progress < level_number
	
	if lock_texture != null:
		lock_texture.visible = is_locked
		
	start_button.pressed.connect(_on_start_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	select_button.pressed.connect(_on_select_button_pressed)
	_show_level_info()


func _show_level_info() -> void:
	name_label.text = DEFAULT_NAME_FORMAT % level_number
	var path : String = LEVEL_DATA_PATH_FORMAT % level_number

	if not ResourceLoader.exists(path):
		push_warning(MISSING_LEVEL_DATA_WARNING % [level_number, path])
		info_label.text = ""
		return

	var data : LevelData = load(path) as LevelData
	if not data.level_name.is_empty():
		name_label.text = data.level_name
	info_label.text = INFO_FORMAT % [data.waves.size(), data.starting_gold, data.starting_life]
	if not data.story_text.is_empty():
		info_label.text = STORY_FORMAT % [data.story_text, info_label.text]


func _on_select_button_pressed() -> void:
	if is_locked:
		return
		
	tooltip.visible = true
	is_selected.emit(self)


func _on_start_button_pressed() -> void:
	UISignals.start_level_button_pressed.emit(level_number)


func _on_close_button_pressed() -> void:
	tooltip.visible = false


func _set_is_locked(value : bool) -> void:
	if is_locked == value:
		return
	
	is_locked = value
	
	if lock_texture != null:
		lock_texture.visible = is_locked
