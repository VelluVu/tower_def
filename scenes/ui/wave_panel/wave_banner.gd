class_name WaveBanner
extends VBoxContainer

## "Wave 3/6" across the upper screen when a wave starts, with a warning line when the wave brings flyers for the
## first time in the level or a boss (polish, 2026-11-20). Made by WavePanel; fades out in steps like the pixel fade.

const WAVE_TEXT : String = "Wave %d/%d"
const ENDLESS_WAVE_TEXT : String = "Wave %d"
const FINAL_WAVE_TEXT : String = "Final wave"
const FLYERS_TEXT : String = "Flyers incoming"
const BOSS_TEXT : String = "%s approaches"
const CLEARED_TEXT : String = "Wave %d cleared"
const BREAK_TEXT : String = "Time to build"
const BOSS_DEFEATED_FORMAT : String = "%s defeated!"
const CASTLE_SAVED_TEXT : String = "Castle saved!"
const SELECTABLE_NODE : NodePath = ^"SelectableUnit"
const TITLE_VARIATION : StringName = &"TitleLabel"
#Endesga 32: coin gold for the flyer warning, blood red for a boss
const FLYERS_COLOR : Color = Color("feae34")
const BOSS_COLOR : Color = Color("e43b44")
#Endesga 32 green for a cleared wave
const CLEARED_COLOR : Color = Color("63c74d")
#coin gold for a fallen boss and a saved castle
const TRIUMPH_COLOR : Color = Color("feae34")
#upper third of the 640x360 UI, under the boss health bar
const TOP : float = 72.0
## Over the HUD panels loaded after the wave panel (Puffe's dialogue box reaches this far down).
const BANNER_Z_INDEX : int = 10
const HOLD_SECONDS : float = 1.6
const FADE_STEPS : Array[float] = [0.66, 0.33, 0.0]
const FADE_STEP_SECONDS : float = 0.08

var title : Label = null
var warning : Label = null
var level : Level = null
var tween : Tween = null
#flyer scenes seen in earlier waves of this level: the warning comes only once per kind of news
var flyers_seen : bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_index = BANNER_Z_INDEX
	alignment = BoxContainer.ALIGNMENT_CENTER
	title = Label.new()
	title.theme_type_variation = TITLE_VARIATION
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	warning = Label.new()
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(warning)
	modulate.a = 0.0
	GameSignals.wave_started.connect(_on_wave_started)
	GameSignals.wave_cleared.connect(_on_wave_cleared)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	GameSignals.level_completed.connect(_on_level_completed)
	GameSignals.level_loaded.connect(_on_level_loaded)
	var manager : Object = Utils.game_control.get(&"scene_manager") if Utils.game_control != null else null
	var current : Object = manager.get(&"current_level") if manager != null else null
	if current is Level:
		level = current


func _on_level_loaded(new_level : Level) -> void:
	level = new_level
	flyers_seen = false


func _on_wave_started(wave_number : int) -> void:
	if level == null or not is_instance_valid(level):
		return
	var runner : WaveRunner = level.wave_runner
	var count : int = runner.wave_count
	title.remove_theme_color_override(&"font_color")
	if count <= 0:
		title.text = ENDLESS_WAVE_TEXT % wave_number
	elif wave_number >= count:
		title.text = FINAL_WAVE_TEXT
	else:
		title.text = WAVE_TEXT % [wave_number, count]
	_set_warning(runner.waves[(wave_number - 1) % runner.waves.size()] if not runner.waves.is_empty() else null)
	_show()


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if not enemy.is_boss:
		return
	var selectable : SelectableUnit = enemy.get_node_or_null(SELECTABLE_NODE) as SelectableUnit
	var boss_name : String = selectable.get_display_name() if selectable != null else _kind(load(enemy.scene_file_path)).name
	title.text = BOSS_DEFEATED_FORMAT % boss_name
	title.add_theme_color_override(&"font_color", TRIUMPH_COLOR)
	warning.text = ""
	_show()


## The win screen waits a moment (UI.WIN_SCREEN_DELAY) so this shows; after a boss it adds a line under its name.
func _on_level_completed(_level : Level) -> void:
	if title.text.ends_with(BOSS_DEFEATED_FORMAT.trim_prefix("%s")) and modulate.a > 0.0:
		warning.text = CASTLE_SAVED_TEXT
		warning.add_theme_color_override(&"font_color", TRIUMPH_COLOR)
	else:
		title.text = CASTLE_SAVED_TEXT
		title.add_theme_color_override(&"font_color", TRIUMPH_COLOR)
		warning.text = ""
	_show()


## The last wave never comes here: it ends the level (the win screen).
func _on_wave_cleared(wave_number : int) -> void:
	title.text = CLEARED_TEXT % wave_number
	title.remove_theme_color_override(&"font_color")
	warning.text = BREAK_TEXT
	warning.add_theme_color_override(&"font_color", CLEARED_COLOR)
	_show()


## A boss in the wave beats the flyer warning; the flyer warning shows once per level.
func _set_warning(wave : WaveData) -> void:
	warning.text = ""
	if wave == null:
		return
	var has_flyers : bool = false
	for group in wave.spawn_groups:
		if group.enemy_scene == null:
			continue
		var kind : Dictionary = _kind(group.enemy_scene)
		if kind.boss:
			warning.text = BOSS_TEXT % kind.name
			warning.add_theme_color_override(&"font_color", BOSS_COLOR)
			return
		has_flyers = has_flyers or kind.flying
	if has_flyers and not flyers_seen:
		flyers_seen = true
		warning.text = FLYERS_TEXT
		warning.add_theme_color_override(&"font_color", FLYERS_COLOR)


#read once per enemy scene from its saved state, without making the enemy
func _kind(scene : PackedScene) -> Dictionary:
	return WavePreview.enemy_kind(scene)


func _show() -> void:
	warning.visible = not warning.text.is_empty()
	reset_size()
	var screen : Vector2 = get_viewport_rect().size
	position = Vector2(roundf((screen.x - size.x) / 2.0), TOP)
	if tween != null:
		tween.kill()
	modulate.a = 1.0
	tween = create_tween()
	tween.tween_interval(HOLD_SECONDS)
	for alpha in FADE_STEPS:
		tween.tween_callback(func() -> void: modulate.a = alpha)
		tween.tween_interval(FADE_STEP_SECONDS)
