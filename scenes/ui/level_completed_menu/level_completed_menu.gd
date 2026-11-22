class_name LevelCompletedMenu
extends Control

const LEVEL_COMPLETED_TEXT : String = "Level Completed"
const GAME_WON_TEXT : String = "All castles saved!\nYou won the game."

const TALENT_POINTS_TEXT : String = "Talent points: %d / %d (best %d)"
## The story's end after the last castle (placeholder words for the user to rewrite).
const EPILOGUE_TEXT : String = "The Ashen Wyrm falls into its own fire, and the mountain goes quiet. Its dead lie down again in the sand, the humans who served it scatter, and the rest march home over the northern bridge. In every castle the eggs begin to crack.\n\nPuffe yawns. The volcano is warm, for once, and quiet. He sleeps."
const EPILOGUE_WIDTH : float = 220.0
const POINT_EARNED : Texture2D = preload("res://assets/art/ui/talent_points/point_earned.png")
const POINT_MISSED : Texture2D = preload("res://assets/art/ui/talent_points/point_missed.png")
#Endesga 32 grey-blue for a missed condition; met ones keep the theme's mint
const MISSED_COLOR : Color = Color("8b9bb4")
const CONDITION_SEPARATION : int = 4
const CHECKLIST_BOTTOM_GAP : float = 4.0
const CHECKLIST_NAME : StringName = &"PointChecklist"

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


## One row per talent point condition: a gold gem when met, an empty socket when missed.
func show_point_conditions(conditions : Array[Dictionary]) -> void:
	var old : Node = talent_points_label.get_parent().get_node_or_null(NodePath(CHECKLIST_NAME))
	if old != null:
		old.get_parent().remove_child(old)
		old.queue_free()
	var checklist : VBoxContainer = build_checklist(conditions)
	#a little room before the buttons
	var gap : Control = Control.new()
	gap.custom_minimum_size.y = CHECKLIST_BOTTOM_GAP
	checklist.add_child(gap)
	talent_points_label.add_sibling(checklist)


## The point conditions as rows (gem or socket, then the text); the pause menu shows them too.
static func build_checklist(conditions : Array[Dictionary]) -> VBoxContainer:
	var checklist : VBoxContainer = VBoxContainer.new()
	checklist.name = CHECKLIST_NAME
	checklist.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	checklist.add_theme_constant_override(&"separation", 1)
	for condition in conditions:
		var row : HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", CONDITION_SEPARATION)
		var marker : TextureRect = TextureRect.new()
		marker.texture = POINT_EARNED if condition.met else POINT_MISSED
		marker.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(marker)
		var text : Label = Label.new()
		text.text = condition.text
		if not condition.met:
			text.add_theme_color_override(&"font_color", MISSED_COLOR)
		row.add_child(text)
		checklist.add_child(row)
	return checklist


func _on_continue_button_pressed() -> void:
	UISignals.continue_next_level_pressed.emit()


func _on_retry_button_pressed() -> void:
	UISignals.retry_level_pressed.emit()


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)
