class_name LoseGameMenu
extends Control

const SURVIVED_FORMAT : String = "Survived %d waves"
const NEW_BEST_TEXT : String = "New best!"
const BEST_FORMAT : String = "Best: %d waves"
#an escaped newline: a line break inside the literal carries the file's \r on Windows checkouts
const LINES_FORMAT : String = "%s\n%s"

@onready var survival_label : Label = $MarginContainer/VBoxContainer/SurvivalLabel


func _ready() -> void:
	GameSignals.survival_run_ended.connect(_on_survival_run_ended)


func _on_survival_run_ended(waves_cleared : int, best_waves : int, is_new_best : bool) -> void:
	survival_label.text = LINES_FORMAT % [SURVIVED_FORMAT % waves_cleared, NEW_BEST_TEXT if is_new_best else BEST_FORMAT % best_waves]
	survival_label.visible = true


func _on_quit_button_pressed() -> void:
	UISignals.resign_level.emit()


func _on_retry_button_pressed() -> void:
	UISignals.retry_level_pressed.emit()


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)
