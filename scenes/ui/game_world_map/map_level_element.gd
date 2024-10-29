class_name MapLevelElement
extends Panel


signal is_selected(MapLevelElement)

@onready var tooltip : Panel = $Tooltip
@onready var start_button : Button = $Tooltip/StartButton
@onready var close_button : Button = $Tooltip/CloseButton
@onready var select_button : Button = $SelectButton

@export var is_locked : bool = false
@export var level_number : int = 1


func _ready() -> void:
	is_locked = PlayerProgress.level_progress < level_number
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
