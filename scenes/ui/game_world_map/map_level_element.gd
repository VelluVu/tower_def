class_name MapLevelElement
extends Panel


signal is_selected(MapLevelElement)

const LEVEL_DATA_PATH_FORMAT : String = "res://scenes/level/level_data/level_%03d_data.tres"
const DEFAULT_NAME_FORMAT : String = "Level %d"
const INFO_FORMAT : String = "%d waves
Start: %d gold, %d life"
const STORY_FORMAT : String = "%s

%s"
const TALENT_POINTS_FORMAT : String = "%s
Talent points: %d/%d"
const MODE_POINTS_FORMAT : String = "%s: %d/%d talent points"
const MODE_LOCKED_FORMAT : String = "%s: coming later"
const FONT_COLOR_NAME : StringName = &"font_color"
const FONT_COLOR_NAMES : Array[StringName] = [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color", &"font_disabled_color"]
## Modes that can be played; the rest show a disabled tab until they are built.
const PLAYABLE_MODES : Array[Utils.LevelMode] = [Utils.LevelMode.Normal]
const MODE_TABS_SEPARATION : int = 2
const SEPARATION_NAME : StringName = &"separation"
const MISSING_LEVEL_DATA_WARNING : String = "No level data for map level %d at %s"

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


func _ready() -> void:
	is_locked = PlayerProgress.level_progress < level_number
	
	if lock_texture != null:
		lock_texture.visible = is_locked
		
	start_button.pressed.connect(_on_start_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	select_button.pressed.connect(_on_select_button_pressed)
	_show_level_info()
	_add_mode_tabs()
	_show_talent_points()


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
	info_label.text = INFO_FORMAT % [data.waves.size(), data.starting_gold, data.starting_life]
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
		tab.disabled = not PLAYABLE_MODES.has(mode)
		tab.button_pressed = mode == selected_mode

		if tab.disabled:
			tab.tooltip_text = MODE_LOCKED_FORMAT % mode_name
		else:
			var points : int = PlayerProgress.get_level_mode_talent_points(level_number, mode)
			tab.tooltip_text = MODE_POINTS_FORMAT % [mode_name, points, TalentRules.MAX_POINTS_PER_LEVEL]
			if points >= TalentRules.MAX_POINTS_PER_LEVEL:
				for color_name in FONT_COLOR_NAMES:
					tab.add_theme_color_override(color_name, MasteredFrame.OUTER_COLOR)

		tab.pressed.connect(_on_mode_tab_pressed.bind(mode))
		tabs.add_child(tab)

	name_label.add_sibling(tabs)


#the level's best points over every mode; all of them put a gold frame on the map node
func _show_talent_points() -> void:
	if is_locked:
		return

	var points : int = 0
	for mode : Utils.LevelMode in Utils.LevelMode.values():
		points += PlayerProgress.get_level_mode_talent_points(level_number, mode)

	var max_points : int = TalentRules.MAX_POINTS_PER_LEVEL * Utils.LevelMode.size()
	info_label.text = TALENT_POINTS_FORMAT % [info_label.text, points, max_points]

	#a longer text would run under the start button, so the title turns gold instead
	if points >= max_points:
		add_child(MasteredFrame.new())
		name_label.add_theme_color_override(FONT_COLOR_NAME, MasteredFrame.OUTER_COLOR)


#the start button does not pass the mode yet: only Normal can be picked
func _on_mode_tab_pressed(mode : Utils.LevelMode) -> void:
	selected_mode = mode


func _on_select_button_pressed() -> void:
	if is_locked:
		return
		
	tooltip.visible = true
	is_selected.emit(self)


func _on_start_button_pressed() -> void:
	UISignals.start_level_button_pressed.emit(level_number)


func _on_close_button_pressed() -> void:
	tooltip.visible = false


func _set_is_locked(value : bool) -> void:
	if is_locked == value:
		return
	
	is_locked = value
	
	if lock_texture != null:
		lock_texture.visible = is_locked
