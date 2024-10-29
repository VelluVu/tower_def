class_name LevelCompletedMenu
extends Control

#should continue to game world map screen "level selection", instead straight to next level?
func _on_continue_button_pressed() -> void:
	UISignals.continue_next_level_pressed.emit()
