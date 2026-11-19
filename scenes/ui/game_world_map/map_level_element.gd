class_name MapLevelElement
extends Panel


signal is_selected(MapLevelElement)

const LEVEL_DATA_PATH_FORMAT : String = "res://scenes/level/level_data/level_%03d_data.tres"
const DEFAULT_NAME_FORMAT : String = "Level %d"
const INFO_FORMAT : String = "Level %d, %d waves\nStart: %d gold, %d life"
const STORY_FORMAT : String = "%s\n\n%s"
const TALENT_POINTS_FORMAT : String = "%s\nTalent points: %d/%d"
const MODE_POINTS_FORMAT : String = "%s: %d/%d talent points"
const SURVIVAL_BEST_FORMAT : String = "%s\nBest: %d waves"
const MODE_LOCKED_FORMAT : String = "%s: coming later"
const MODE_NEEDS_NORMAL_FORMAT : String = "%s: clear Normal first"
const FONT_COLOR_NAME : StringName = &"font_color"
const FONT_COLOR_NAMES : Array[StringName] = [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color", &"font_disabled_color"]
## Modes that can be played; the rest show a disabled tab until they are built.
const PLAYABLE_MODES : Array[Utils.LevelMode] = [Utils.LevelMode.Normal, Utils.LevelMode.Hard, Utils.LevelMode.Survival]
const MODE_TABS_SEPARATION : int = 2
const SEPARATION_NAME : StringName = &"separation"
const MISSING_LEVEL_DATA_WARNING : String = "No level data for map level %d at %s"
## The next level to play bobs: BOB_PIXELS up and back down every BOB_TIME seconds, in whole pixels.
const BOB_PIXELS : int = 1
const BOB_TIME : float = 0.5
const POP_IN_TIME : float = 0.45
const POP_IN_DELAY : float = 0.3
## The area tokens (tools/sprite/parts/map_nodes.py): one TOKEN_CELL row per area plus the boss row last,
## columns normal, hover, pressed, disabled. The 20 px button draws its 24 px cell with TOKEN_EXPAND to spare.
const TOKEN_SHEET : Texture2D = preload("res://assets/art/ui/map_nodes/map_node_tokens.png")
const TOKEN_CELL : int = 24
const TOKEN_EXPAND : int = 2
const LEVELS_PER_AREA : int = 12
const BOSS_LEVELS : Array[int] = [8, 24, 36, 48, 60]
const BOSS_ROW : int = 5
const BOSS_RING_MARGIN : int = 5
const TOKEN_STATES : Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled"]
const HOVER_PRESSED_STATE : StringName = &"hover_pressed"
const PRESSED_STATE_COLUMN : int = 2
@onready var tooltip : Panel = $Tooltip
@onready var start_button : Button = $Tooltip/StartButton
@onready var close_button : Button = $Tooltip/CloseButton
@onready var select_button : Button = $SelectButton
@onready var lock_texture : TextureRect = $LockTexture
@onready var name_label : Label = $Tooltip/InfoMarginContainer/VBoxContainer/LevelName
@onready var info_label : Label = $Tooltip/InfoMarginContainer/VBoxContainer/LevelInfo

@export var level_number : int = 1

var is_locked : bool = false :
	set = _set_is_locked
var selected_mode : Utils.LevelMode = Utils.LevelMode.Normal
var completion_ring : CompletionRing = null


func _ready() -> void:
	is_locked = PlayerProgress.level_progress < level_number
	#only the cleared levels and the next one show; the lock art is not used
	visible = not is_locked
	if lock_texture != null:
		lock_texture.visible = false

	start_button.pressed.connect(_on_start_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	select_button.pressed.connect(_on_select_button_pressed)
	_apply_token()
	_show_level_info()
	_add_mode_tabs()
	_show_talent_points()
	if is_next_to_play():
		_bob()


## The level unlocked but not cleared yet.
func is_next_to_play() -> bool:
	return not is_locked and not _is_normal_cleared()


## The token row for a level: its area's, or the boss row for an area boss.
static func token_row(level : int) -> int:
	if BOSS_LEVELS.has(level):
		return BOSS_ROW
	return clampi(floori((level - 1) / float(LEVELS_PER_AREA)), 0, BOSS_ROW - 1)


#the area's token instead of the theme's gem, one region of the sheet per button state
func _apply_token() -> void:
	var row : int = token_row(level_number)
	for column in TOKEN_STATES.size():
		var style : StyleBoxTexture = StyleBoxTexture.new()
		style.texture = TOKEN_SHEET
		style.region_rect = Rect2(column * TOKEN_CELL, row * TOKEN_CELL, TOKEN_CELL, TOKEN_CELL)
		style.set_expand_margin_all(TOKEN_EXPAND)
		select_button.add_theme_stylebox_override(TOKEN_STATES[column], style)
		if column == PRESSED_STATE_COLUMN:
			select_button.add_theme_stylebox_override(HOVER_PRESSED_STATE, style)


## The node grows in from nothing, for a level unlocked since the map was last shown.
func pop_in() -> void:
	select_button.scale = Vector2.ZERO
	var tween : Tween = create_tween()
	#the size is laid out by the time the delay ends
	tween.tween_callback(func() -> void: select_button.pivot_offset = select_button.size * 0.5).set_delay(POP_IN_DELAY)
	tween.tween_property(select_button, "scale", Vector2.ONE, POP_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


#whole-pixel steps, not a smooth tween: every art pixel stays on a screen pixel
func _bob() -> void:
	var tween : Tween = create_tween().set_loops()
	tween.tween_interval(BOB_TIME)
	tween.tween_callback(func() -> void: select_button.position.y = -BOB_PIXELS)
	tween.tween_interval(BOB_TIME)
	tween.tween_callback(func() -> void: select_button.position.y = 0)


func _show_level_info() -> void:
	name_label.text = DEFAULT_NAME_FORMAT % level_number
	var path : String = LEVEL_DATA_PATH_FORMAT % level_number

	if not ResourceLoader.exists(path):
		push_warning(MISSING_LEVEL_DATA_WARNING % [level_number, path])
		info_label.text = ""
		return

	var data : LevelData = load(path) as LevelData
	if not data.level_name.is_empty():
		name_label.text = data.level_name
	info_label.text = INFO_FORMAT % [level_number, data.waves.size(), data.starting_gold, data.starting_life]
	if not data.story_text.is_empty():
		info_label.text = STORY_FORMAT % [data.story_text, info_label.text]


#one tab per mode under the title, built here so the six map tooltips stay the same; a mode
#with all its points gets a gold tab, its points show on hover
func _add_mode_tabs() -> void:
	var tabs : HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override(SEPARATION_NAME, MODE_TABS_SEPARATION)
	var group : ButtonGroup = ButtonGroup.new()

	for mode : Utils.LevelMode in Utils.LevelMode.values():
		var mode_name : String = Utils.LevelMode.keys()[mode]
		var tab : Button = Button.new()
		tab.text = mode_name
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_NONE
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var needs_normal : bool = mode != Utils.LevelMode.Normal and not _is_normal_cleared()
		tab.disabled = not PLAYABLE_MODES.has(mode) or needs_normal
		tab.button_pressed = mode == selected_mode

		if not PLAYABLE_MODES.has(mode):
			tab.tooltip_text = MODE_LOCKED_FORMAT % mode_name
		elif needs_normal:
			tab.tooltip_text = MODE_NEEDS_NORMAL_FORMAT % mode_name
		else:
			var points : int = PlayerProgress.get_level_mode_talent_points(level_number, mode)
			tab.tooltip_text = MODE_POINTS_FORMAT % [mode_name, points, TalentRules.MAX_POINTS_PER_LEVEL]
			var best_waves : int = PlayerProgress.get_survival_best_waves(level_number)
			if mode == Utils.LevelMode.Survival and best_waves > 0:
				tab.tooltip_text = SURVIVAL_BEST_FORMAT % [tab.tooltip_text, best_waves]
			if points >= TalentRules.MAX_POINTS_PER_LEVEL:
				for color_name in FONT_COLOR_NAMES:
					tab.add_theme_color_override(color_name, CompletionRing.GOLD_COLOR)

		tab.pressed.connect(_on_mode_tab_pressed.bind(mode))
		tabs.add_child(tab)

	name_label.add_sibling(tabs)


#the level's best points over every mode; the ring round the node shows how far it is done
func _show_talent_points() -> void:
	if is_locked:
		return

	var points : int = 0
	for mode : Utils.LevelMode in Utils.LevelMode.values():
		points += PlayerProgress.get_level_mode_talent_points(level_number, mode)

	var max_points : int = TalentRules.MAX_POINTS_PER_LEVEL * Utils.LevelMode.size()
	info_label.text = TALENT_POINTS_FORMAT % [info_label.text, points, max_points]

	#on the button, so it bobs and pops in with it
	completion_ring = CompletionRing.new()
	if token_row(level_number) == BOSS_ROW:
		completion_ring.margin = BOSS_RING_MARGIN
	select_button.add_child(completion_ring)
	completion_ring.tier = CompletionRing.tier_for(_is_normal_cleared(), points, max_points)

	#a longer text would run under the start button, so the title turns gold instead
	if points >= max_points:
		name_label.add_theme_color_override(FONT_COLOR_NAME, CompletionRing.GOLD_COLOR)


#Hard and Survival open once Normal is cleared, which unlocks the next level
func _is_normal_cleared() -> bool:
	return PlayerProgress.level_progress > level_number


func _on_mode_tab_pressed(mode : Utils.LevelMode) -> void:
	selected_mode = mode


func _on_select_button_pressed() -> void:
	if is_locked:
		return
		
	tooltip.visible = true
	is_selected.emit(self)


func _on_start_button_pressed() -> void:
	UISignals.start_level_button_pressed.emit(level_number, selected_mode)


func _on_close_button_pressed() -> void:
	tooltip.visible = false


func _set_is_locked(value : bool) -> void:
	if is_locked == value:
		return
	
	is_locked = value
	
	if lock_texture != null:
		lock_texture.visible = is_locked
