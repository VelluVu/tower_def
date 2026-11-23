class_name MapLevelElement
extends Panel


signal is_selected(MapLevelElement)

const LEVEL_DATA_PATH_FORMAT : String = "res://scenes/level/level_data/level_%03d_data.tres"
const DEFAULT_NAME_FORMAT : String = "Level %d"
const INFO_FORMAT : String = "Level %d, %d waves\nStart: %d gold, %d life"
const STORY_FORMAT : String = "%s\n\n%s"
const MODE_POINTS_FORMAT : String = "%s
%d/%d talent points"
const SURVIVAL_BEST_FORMAT : String = "%s\nBest: %d waves"
const MODE_LOCKED_FORMAT : String = "%s
Coming later"
const MODE_NEEDS_NORMAL_FORMAT : String = "%s
Clear Normal first"
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
const BOSS_LEVELS : Array[int] = [8, 24, 36, 48, 57, 60]
const BOSS_ROW : int = 5
const BOSS_RING_MARGIN : int = 5
const TOKEN_STATES : Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled"]
const HOVER_PRESSED_STATE : StringName = &"hover_pressed"
const PRESSED_STATE_COLUMN : int = 2
## The arrow over the next level to play: ARROW_GAP pixels above the node, bobbing ARROW_BOB_PIXELS on its own
## beat. On a new game a "Start here" label stands beside it.
const NEXT_ARROW : Texture2D = preload("res://assets/art/ui/map_nodes/next_level_arrow.png")
const ARROW_GAP : int = 1
const ARROW_BOB_PIXELS : int = 2
const ARROW_BOB_TIME : float = 0.35
const START_HERE_TEXT : String = "Start here"
const START_LABEL_GAP : int = 2
const START_LABEL_RAISE : int = 2
## The level panel (polish, 2026-11-22): the selected mode's points as gems, the level's enemies, a big Start.
const POINT_EARNED : Texture2D = preload("res://assets/art/ui/talent_points/point_earned.png")
const POINT_MISSED : Texture2D = preload("res://assets/art/ui/talent_points/point_missed.png")
const POINTS_TEXT : String = "Points"
const BEST_WAVES_FORMAT : String = "Best: %d waves"
const ENEMIES_TEXT : String = "Enemies"
const START_TEXT : String = "Start"
const START_BUTTON_VARIATION : StringName = &"BigButton"
#Endesga 32 grey-blue row labels, as the win screen's missed lines
const ROW_LABEL_COLOR : Color = Color("8b9bb4")
const ROW_LABEL_WIDTH : float = 40.0
const ROW_SEPARATION : int = 2
## Room under the rows for the big Start button.
const PANEL_BOTTOM_MARGIN : int = 32
## Over the other nodes' arrows and rings.
const PANEL_Z_INDEX : int = 10
## Kept inside the screen by this much when it opens near an edge.
const SCREEN_MARGIN : float = 4.0
## The area's picture under the level name (tools/art/area_banners.py, 80x22 at 2x), one per LEVELS_PER_AREA.
const AREA_BANNERS : Array[Texture2D] = [
	preload("res://assets/art/ui/area_banners/area_banner_caves.png"),
	preload("res://assets/art/ui/area_banners/area_banner_swamp.png"),
	preload("res://assets/art/ui/area_banners/area_banner_wasted_lands.png"),
	preload("res://assets/art/ui/area_banners/area_banner_ash_desert.png"),
	preload("res://assets/art/ui/area_banners/area_banner_volcano.png"),
]
const AREA_BANNER_SCALE : int = 2
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
var next_arrow : TextureRect = null
var start_label : Label = null
var level_data : LevelData = null
var point_icons : Array[TextureRect] = []
var best_waves_label : Label = null


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
	_add_area_banner()
	_show_talent_points()
	_add_points_row()
	_add_enemy_row()
	start_button.text = START_TEXT
	start_button.theme_type_variation = START_BUTTON_VARIATION
	(info_label.get_parent().get_parent() as Control).add_theme_constant_override(&"margin_bottom", PANEL_BOTTOM_MARGIN)
	tooltip.z_index = PANEL_Z_INDEX
	if is_next_to_play():
		_bob()
		_add_next_arrow()


## The level unlocked but not cleared yet.
func is_next_to_play() -> bool:
	return not is_locked and not _is_normal_cleared()


## The level's area: 0 Caves, 1 Swamp, 2 Wasted Lands, 3 Ash Desert, 4 Volcano.
static func area_of(level : int) -> int:
	return clampi(floori((level - 1) / float(LEVELS_PER_AREA)), 0, AREA_BANNERS.size() - 1)


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


#on the button, so it pops in and bobs with the node; it hides while the node is hovered or its panel open
func _add_next_arrow() -> void:
	next_arrow = TextureRect.new()
	next_arrow.texture = NEXT_ARROW
	next_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_arrow.z_index = 1
	var arrow_size : Vector2 = NEXT_ARROW.get_size()
	var base_position : Vector2 = Vector2(floorf((size.x - arrow_size.x) * 0.5), -arrow_size.y - ARROW_GAP)
	next_arrow.position = base_position
	select_button.add_child(next_arrow)

	#nothing cleared yet: a new game
	if PlayerProgress.level_progress <= 1:
		start_label = Label.new()
		start_label.text = START_HERE_TEXT
		start_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		start_label.position = Vector2(arrow_size.x + START_LABEL_GAP, -START_LABEL_RAISE)
		next_arrow.add_child(start_label)

	var tween : Tween = create_tween().set_loops()
	tween.tween_interval(ARROW_BOB_TIME)
	tween.tween_callback(func() -> void: next_arrow.position.y = base_position.y - ARROW_BOB_PIXELS)
	tween.tween_interval(ARROW_BOB_TIME)
	tween.tween_callback(func() -> void: next_arrow.position.y = base_position.y)

	select_button.mouse_entered.connect(_update_next_arrow.bind(true))
	select_button.mouse_exited.connect(_update_next_arrow.bind(false))
	#the map also closes this panel when another node is picked
	tooltip.visibility_changed.connect(_update_next_arrow.bind(false))


func _update_next_arrow(is_hovered : bool = false) -> void:
	if next_arrow != null:
		next_arrow.visible = not is_hovered and not tooltip.visible


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
	level_data = data
	if not data.level_name.is_empty():
		name_label.text = data.level_name
	info_label.text = INFO_FORMAT % [level_number, data.waves.size(), data.starting_gold, data.starting_life]
	if not data.story_text.is_empty():
		info_label.text = STORY_FORMAT % [data.story_text, info_label.text]


## The area's picture right under the level name, above the mode tabs.
func _add_area_banner() -> void:
	var banner : TextureRect = TextureRect.new()
	banner.texture = AREA_BANNERS[area_of(level_number)]
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_SCALE
	banner.custom_minimum_size = banner.texture.get_size() * AREA_BANNER_SCALE
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_sibling(banner)


#one tab per mode under the title, built here so the six map tooltips stay the same; a mode
#with all its points gets a gold tab, its points show on hover
func _add_mode_tabs() -> void:
	var tabs : HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override(SEPARATION_NAME, MODE_TABS_SEPARATION)
	var group : ButtonGroup = ButtonGroup.new()

	for mode : Utils.LevelMode in Utils.LevelMode.values():
		var mode_name : String = Utils.LevelMode.keys()[mode]
		var tab : Button = RichTooltipButton.new()
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
	_update_points_row()


## "Points" and five gems for the selected mode, earned ones gold; Survival adds its best run.
func _add_points_row() -> void:
	var row : HBoxContainer = _new_row(POINTS_TEXT)
	for i in TalentRules.MAX_POINTS_PER_LEVEL:
		var icon : TextureRect = TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		point_icons.append(icon)
	best_waves_label = Label.new()
	best_waves_label.add_theme_color_override(FONT_COLOR_NAME, ROW_LABEL_COLOR)
	row.add_child(best_waves_label)
	info_label.add_sibling(row)
	_update_points_row()


func _update_points_row() -> void:
	var points : int = PlayerProgress.get_level_mode_talent_points(level_number, selected_mode)
	for i in point_icons.size():
		point_icons[i].texture = POINT_EARNED if i < points else POINT_MISSED
	var best_waves : int = PlayerProgress.get_survival_best_waves(level_number)
	best_waves_label.text = BEST_WAVES_FORMAT % best_waves if selected_mode == Utils.LevelMode.Survival and best_waves > 0 else ""


## Every enemy kind the level sends, with the flyer and boss badges.
func _add_enemy_row() -> void:
	if level_data == null or level_data.waves.is_empty():
		return
	var row : HBoxContainer = _new_row(ENEMIES_TEXT)
	var roster : WavePreview = WavePreview.new()
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(roster)
	roster.show_roster(level_data.waves)
	roster.alignment = FlowContainer.ALIGNMENT_BEGIN
	var vbox : Node = info_label.get_parent()
	vbox.add_child(row)


func _new_row(label_text : String) -> HBoxContainer:
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(SEPARATION_NAME, ROW_SEPARATION)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label : Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = ROW_LABEL_WIDTH
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override(FONT_COLOR_NAME, ROW_LABEL_COLOR)
	row.add_child(label)
	return row


## Grows the panel upwards to fit its rows (its bottom stays by the node), then keeps it on screen.
func _fit_tooltip() -> void:
	var content : Control = info_label.get_parent().get_parent() as Control
	var height : float = maxf(tooltip.custom_minimum_size.y, content.get_combined_minimum_size().y)
	tooltip.offset_top = tooltip.offset_bottom - height
	var screen : Rect2 = get_viewport_rect().grow(-SCREEN_MARGIN)
	var rect : Rect2 = tooltip.get_global_rect()
	var shift : Vector2 = Vector2.ZERO
	shift.x = minf(0.0, screen.end.x - rect.end.x) + maxf(0.0, screen.position.x - rect.position.x)
	shift.y = minf(0.0, screen.end.y - rect.end.y) + maxf(0.0, screen.position.y - rect.position.y)
	tooltip.position += shift.round()


func _on_select_button_pressed() -> void:
	if is_locked:
		return
		
	tooltip.visible = true
	_fit_tooltip.call_deferred()
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
