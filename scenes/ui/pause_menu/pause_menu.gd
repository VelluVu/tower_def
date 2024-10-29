class_name PauseMenu
extends Control


func _on_options_pressed() -> void:
	UISignals.options.emit()


func _on_quit_pressed() -> void:
	#save?
	UISignals.resign_level.emit()


func _on_continue_pressed() -> void:
	UISignals.continue_from_pause_menu.emit()
