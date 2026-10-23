class_name LevelCompletedMenu
extends Control

const LEVEL_COMPLETED_TEXT : String = "Level Completed"
const GAME_WON_TEXT : String = "All castles saved!
You won the game."

@onready var label : Label = $MarginContainer/VBoxContainer/Label


## After the last level the menu tells the player the game is won.
func show_result(is_last_level : bool) -> void:
	label.text = GAME_WON_TEXT if is_last_level else LEVEL_COMPLETED_TEXT


func _on_continue_button_pressed() -> void:
	UISignals.continue_next_level_pressed.emit()


func _on_retry_button_pressed() -> void:
	UISignals.retry_level_pressed.emit()


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)
