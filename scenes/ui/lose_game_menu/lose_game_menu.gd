class_name LoseGameMenu
extends Control


func _on_quit_button_pressed() -> void:
	MenuSignals.to_menu.emit(true, name)
