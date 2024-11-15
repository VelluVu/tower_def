class_name LoseGameMenu
extends Control


func _on_quit_button_pressed() -> void:
	UISignals.resign_level.emit()


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)
