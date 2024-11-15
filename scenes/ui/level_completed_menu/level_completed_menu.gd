class_name LevelCompletedMenu
extends Control

#should continue to game world map screen "level selection", instead straight to next level?
func _on_continue_button_pressed() -> void:
	UISignals.continue_next_level_pressed.emit()


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)
