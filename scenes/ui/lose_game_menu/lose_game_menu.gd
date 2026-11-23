class_name LoseGameMenu
extends Control

const SURVIVED_FORMAT : String = "Survived %d waves"
const NEW_BEST_TEXT : String = "New best!"
const BEST_FORMAT : String = "Best: %d waves"
#an escaped newline: a line break inside the literal carries the file's \r on Windows checkouts
const LINES_FORMAT : String = "%s\n%s"

const BROKE_FORMAT : String = "Wave %d/%d broke through"
const ENDLESS_BROKE_FORMAT : String = "Wave %d broke through"
const LEAK_FORMAT : String = "%d %s"
const LIVES_FORMAT : String = "-%d"
const MAX_LEAK_ROWS : int = 4
const LEAK_ROW_SEPARATION : int = 3
const BOTTOM_GAP : float = 4.0
## Wider text wraps.
const TIP_WIDTH : float = 200.0
const FLYER_TIP : String = "Flyers ignore the maze. Bolters and Beamers hit them; the Nova only from its T2."
const BOSS_TIP : String = "Bosses are tough and slow: keep gold for their wave and stack damage near the castle."
const MAZE_TIP : String = "Walls make the path longer, so enemies spend more time under your towers."
## A flyer tip once flyers cost this share of the lives.
const FLYER_TIP_SHARE : float = 0.34
#Endesga 32: blood red lives, grey-blue tip
const LIVES_COLOR : Color = Color("e43b44")
const TIP_COLOR : Color = Color("8b9bb4")
const HEART_ICON : Texture2D = preload("res://assets/art/ui/stat_icons/stat_health.png")
const DEFEAT_BOX_NAME : StringName = &"DefeatSummary"

@onready var survival_label : Label = $MarginContainer/VBoxContainer/SurvivalLabel


func _ready() -> void:
	GameSignals.survival_run_ended.connect(_on_survival_run_ended)
	#the plundered hall above the result
	var box : VBoxContainer = survival_label.get_parent()
	var picture : EndVignette = EndVignette.build(EndVignette.Kind.LOSE)
	box.add_child(picture)
	box.move_child(picture, 0)


func _on_survival_run_ended(waves_cleared : int, best_waves : int, is_new_best : bool) -> void:
	survival_label.text = LINES_FORMAT % [SURVIVED_FORMAT % waves_cleared, NEW_BEST_TEXT if is_new_best else BEST_FORMAT % best_waves]
	survival_label.visible = true


## The wave that broke through, the enemies that cost the most lives, and one tip that fits them.
## leaks: enemy scene path -> {count, lives} (PlayerStats.leaks).
func show_defeat(wave_number : int, wave_count : int, leaks : Dictionary[String, Dictionary]) -> void:
	var box_parent : Node = survival_label.get_parent()
	var old : Node = box_parent.get_node_or_null(NodePath(DEFEAT_BOX_NAME))
	if old != null:
		box_parent.remove_child(old)
		old.queue_free()
	var box : VBoxContainer = VBoxContainer.new()
	box.name = DEFEAT_BOX_NAME
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override(&"separation", 1)

	var wave_label : Label = Label.new()
	wave_label.text = ENDLESS_BROKE_FORMAT % wave_number if wave_count <= 0 else BROKE_FORMAT % [wave_number, wave_count]
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(wave_label)

	var rows : Array[Dictionary] = get_leak_rows(leaks)
	for row in rows.slice(0, MAX_LEAK_ROWS):
		box.add_child(_make_leak_row(row))

	var tip : Label = Label.new()
	tip.text = get_tip(rows)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = TIP_WIDTH
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_color_override(&"font_color", TIP_COLOR)
	box.add_child(tip)
	#a little room before the buttons
	var gap : Control = Control.new()
	gap.custom_minimum_size.y = BOTTOM_GAP
	box.add_child(gap)
	survival_label.add_sibling(box)


## Most lives first: {scene, name, count, lives, flying, boss}.
static func get_leak_rows(leaks : Dictionary[String, Dictionary]) -> Array[Dictionary]:
	var rows : Array[Dictionary] = []
	for path in leaks:
		var scene : PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if scene == null:
			continue
		var kind : Dictionary = WavePreview.enemy_kind(scene)
		rows.append({"scene": scene, "name": kind.name, "count": leaks[path].count, "lives": leaks[path].lives, "flying": kind.flying, "boss": kind.boss})
	rows.sort_custom(func(a : Dictionary, b : Dictionary) -> bool: return a.lives > b.lives)
	return rows


## A boss that got through beats flyers; flyers count once they cost a third of the lives.
static func get_tip(rows : Array[Dictionary]) -> String:
	var total : int = 0
	var flying : int = 0
	for row in rows:
		if row.boss:
			return BOSS_TIP
		total += row.lives
		if row.flying:
			flying += row.lives
	if total > 0 and float(flying) / float(total) >= FLYER_TIP_SHARE:
		return FLYER_TIP
	return MAZE_TIP


func _make_leak_row(row : Dictionary) -> Control:
	var line : HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", LEAK_ROW_SEPARATION)
	var portrait : TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(WavePreview.PORTRAIT_SIZE, WavePreview.PORTRAIT_SIZE)
	portrait.texture = WavePreview.enemy_kind(row.scene).portrait
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	line.add_child(portrait)
	var name_label : Label = Label.new()
	name_label.text = LEAK_FORMAT % [row.count, row.name]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var lives : Label = Label.new()
	lives.text = LIVES_FORMAT % row.lives
	lives.add_theme_color_override(&"font_color", LIVES_COLOR)
	line.add_child(lives)
	var heart : TextureRect = TextureRect.new()
	heart.texture = HEART_ICON
	heart.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	line.add_child(heart)
	return line


func _on_quit_button_pressed() -> void:
	UISignals.resign_level.emit()


func _on_retry_button_pressed() -> void:
	UISignals.retry_level_pressed.emit()


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)
