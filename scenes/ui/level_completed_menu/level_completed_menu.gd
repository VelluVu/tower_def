class_name LevelCompletedMenu
extends Control

const LEVEL_COMPLETED_TEXT : String = "Level Completed"
const GAME_WON_TEXT : String = "All castles saved!
You won the game."

const TALENT_POINTS_TEXT : String = "Talent points: %d / %d (best %d)"

@onready var label : Label = $MarginContainer/VBoxContainer/Label
@onready var talent_points_label : Label = $MarginContainer/VBoxContainer/TalentPoints


## After the last level the menu tells the player the game is won.
func show_result(is_last_level : bool) -> void:
	label.text = GAME_WON_TEXT if is_last_level else LEVEL_COMPLETED_TEXT


## The best is read with this run counted, so it does not matter whether the save came first.
func show_talent_points(points : int, best : int) -> void:
	talent_points_label.text = TALENT_POINTS_TEXT % [points, TalentRules.MAX_POINTS_PER_LEVEL, maxi(points, best)]


func _on_continue_button_pressed() -> void:
	UISignals.continue_next_level_pressed.emit()


func _on_retry_button_pressed() -> void:
	UISignals.retry_level_pressed.emit()


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)
