class_name PauseMenu
extends Control


func _on_options_pressed() -> void:
	MenuSignals.options.emit()


func _on_quit_pressed() -> void:
	#save?
	MenuSignals.to_menu.emit(true, name)


func _on_continue_pressed() -> void:
	MenuSignals.continue_from_pause_menu.emit()
