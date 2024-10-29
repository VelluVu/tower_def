class_name Menu
extends Control


@onready var continue_button : Button = $MarginContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	print("in menu")
	Utils.game_control.reset_time_scale()
	continue_button.visible = PlayerProgress.has_save


func _on_start_button_pressed() -> void:
	UISignals.start_game.emit()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_options_button_pressed() -> void:
	UISignals.options.emit()


func _on_continue_button_pressed() -> void:
	UISignals.continue_last_save.emit()
