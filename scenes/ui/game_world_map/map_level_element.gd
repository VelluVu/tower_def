class_name MapLevelElement
extends Panel


signal is_selected(MapLevelElement)

@onready var tooltip : Panel = $Tooltip
@onready var start_button : Button = $Tooltip/StartButton
@onready var close_button : Button = $Tooltip/CloseButton
@onready var select_button : Button = $SelectButton
@onready var lock_texture : TextureRect = $LockTexture

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
