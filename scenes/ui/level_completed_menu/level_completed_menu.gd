class_name LevelCompletedMenu
extends Control

const LEVEL_COMPLETED_TEXT : String = "Level Completed"
const GAME_WON_TEXT : String = "All castles saved!\nYou won the game."

const TALENT_POINTS_TEXT : String = "Talent points: %d / %d (best %d)"
## The story's end after the last castle (placeholder words for the user to rewrite).
const EPILOGUE_TEXT : String = "The Ashen Wyrm falls into its own fire, and the mountain goes quiet. Its dead lie down again in the sand, the humans who served it scatter, and the rest march home over the northern bridge. In every castle the eggs begin to crack.\n\nPuffe yawns. The volcano is warm, for once, and quiet. He sleeps."
const EPILOGUE_WIDTH : float = 220.0

@onready var label : Label = $MarginContainer/VBoxContainer/Label
@onready var talent_points_label : Label = $MarginContainer/VBoxContainer/TalentPoints


## After the last level the menu tells the player the game is won.
func show_result(is_last_level : bool) -> void:
	label.text = GAME_WON_TEXT if is_last_level else LEVEL_COMPLETED_TEXT
	if is_last_level:
		var epilogue : Label = Label.new()
		epilogue.text = EPILOGUE_TEXT
		epilogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		epilogue.custom_minimum_size = Vector2(EPILOGUE_WIDTH, 0)
		label.add_sibling(epilogue)


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
