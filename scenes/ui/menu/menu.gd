class_name Menu
extends Control


func _on_start_button_pressed() -> void:
	MenuSignals.start_game.emit()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_options_button_pressed() -> void:
	MenuSignals.options.emit()
