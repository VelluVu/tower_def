class_name WavePanel
extends Control


const WAVE_TEXT : String = "Wave %d/%d"
const ENDLESS_WAVE_TEXT : String = "Wave %d"
const START_WAVE_TEXT : String = "Start wave"
const EARLY_START_TEXT : String = "Early! +%d"
## The early start, made noticeable (2026-11-25, the user): the button glows gold while it is open, a notice with a
## coin slides in when it opens, the bonus floats up when it is taken, and a counter shows the early starts toward the
## talent points (half of them earns one, all of them another).
const EARLY_READY_TEXT : String = "Early start ready: +%d gold  [%s]"
const EARLY_COUNT_TEXT : String = "Early %d/%d"
const EARLY_TAKEN_TEXT : String = "+%d gold"
const GOLD_COLOR : Color = Color("feae34")
const GOLD_LIGHT_COLOR : Color = Color("fee761")
const COUNT_COLOR : Color = Color("a2f6db")
const GLOW_COLOR : Color = Color(1.35, 1.15, 0.65)
const GLOW_SECONDS : float = 0.55
const NOTICE_SECONDS : float = 3.0
const NOTICE_FADE_SECONDS : float = 0.6
const NOTICE_SLIDE : float = 6.0
const TAKEN_RISE : float = 18.0
const TAKEN_SECONDS : float = 1.0
const COIN : Texture2D = preload("res://assets/art/ui/puffe_coin.png")
const NOTICE_PANEL_TYPE : StringName = &"InsetPanelContainer"
const START_WAVE_TOOLTIP : String = "Start wave  [%s]
Sends the next wave."
const EARLY_START_TOOLTIP : String = "Early start  [%s]
Sends the next wave now, while this one is still out. Pays %d bonus gold."
## Auto start (2026-11-26, the user): every wave after the first goes out as soon as it can, as an early start.
const AUTO_ON_TEXT : String = "Auto: On"
const AUTO_OFF_TEXT : String = "Auto: Off"
const AUTO_TOOLTIP : String = "Auto start
Sends every wave after the first as soon as it can go, each one an early start with its bonus gold. The first wave always waits for you."

@onready var wave_value : Label = $MarginContainer/Panel/MarginContainer/VBoxContainer/WaveValue
@onready var start_wave_button : Button = $MarginContainer/Panel/MarginContainer/VBoxContainer/StartWaveButton
@onready var wave_box : VBoxContainer = $MarginContainer/Panel/MarginContainer/VBoxContainer
@onready var panel : Panel = $MarginContainer/Panel
@onready var panel_margin : MarginContainer = $MarginContainer/Panel/MarginContainer

var preview : WavePreview = null
#the scene's panel height, before the preview row grew it
var base_panel_height : float = -1.0
var early_count_label : Label = null
var early_notice : PanelContainer = null
var early_notice_label : Label = null
var is_early_open : bool = false
var early_bonus_shown : float = 0.0
var glow_tween : Tween = null
var notice_tween : Tween = null
var auto_button : Button = null
#a plain bool, so it stays on from level to level for the session
static var is_auto_start : bool = false
#set by an auto start until the next wave_state_changed, so one open start never sends two waves
var is_auto_waiting : bool = false


func _ready() -> void:
	GameSignals.wave_state_changed.connect(_on_wave_state_changed)
	add_child(WaveBanner.new())
	preview = WavePreview.new()
	wave_box.add_child(preview)
	preview.hide()
	early_count_label = Label.new()
	early_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	early_count_label.add_theme_color_override(&"font_color", COUNT_COLOR)
	early_count_label.hide()
	wave_box.add_child(early_count_label)
	wave_box.move_child(early_count_label, start_wave_button.get_index() + 1)
	_make_early_notice()
	_make_auto_button()
	InputManager.shortcut_pressed.connect(_on_shortcut_pressed)


#the notice that slides in under the panel when the early start opens: a coin and the bonus on a dark inset, so it
#reads over any ground
func _make_early_notice() -> void:
	early_notice = PanelContainer.new()
	early_notice.theme_type_variation = NOTICE_PANEL_TYPE
	early_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row : HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 2)
	early_notice.add_child(row)
	var coin : TextureRect = TextureRect.new()
	coin.texture = COIN
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coin)
	early_notice_label = Label.new()
	early_notice_label.add_theme_color_override(&"font_color", GOLD_LIGHT_COLOR)
	early_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(early_notice_label)
	early_notice.modulate.a = 0.0
	add_child(early_notice)


func _make_auto_button() -> void:
	auto_button = RichTooltipButton.new()
	auto_button.toggle_mode = true
	auto_button.button_pressed = is_auto_start
	auto_button.tooltip_text = AUTO_TOOLTIP
	wave_box.add_child(auto_button)
	wave_box.move_child(auto_button, start_wave_button.get_index() + 1)
	auto_button.toggled.connect(_on_auto_toggled)
	_show_auto_state()


func _on_auto_toggled(is_on : bool) -> void:
	is_auto_start = is_on
	_show_auto_state()


func _show_auto_state() -> void:
	auto_button.text = AUTO_ON_TEXT if is_auto_start else AUTO_OFF_TEXT


#checked every frame rather than on wave_state_changed: a card choice may pause the game just as a wave could go
func _process(_delta : float) -> void:
	if is_auto_start:
		_try_auto_start()


## Sends the next wave when auto start is on and the button could: never the first wave (the build phase is the player's).
func _try_auto_start() -> void:
	if not is_auto_start or is_auto_waiting or not is_inside_tree() or not start_wave_button.visible or start_wave_button.disabled:
		return
	var level : Level = _current_level()
	if level == null or level.wave_runner.wave_number < 1 or get_tree().paused:
		return
	is_auto_waiting = true
	_on_start_wave_pressed()


func _on_shortcut_pressed(action : StringName) -> void:
	#the same rules as the button: only while it shows and can start a wave
	if action == InputManager.ACTION_START_WAVE and start_wave_button.visible and not start_wave_button.disabled:
		_on_start_wave_pressed()


func _on_start_wave_pressed() -> void:
	if is_early_open:
		_float_taken_bonus(early_bonus_shown)
	UISignals.start_wave_pressed.emit()


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)


func _on_wave_state_changed(wave_number : int, wave_count : int, can_start_next : bool, early_start_bonus : float) -> void:
	is_auto_waiting = false
	#a wave count of 0: Survival, the waves never end
	var is_endless : bool = wave_count <= 0
	wave_value.text = ENDLESS_WAVE_TEXT % wave_number if is_endless else WAVE_TEXT % [wave_number, wave_count]
	start_wave_button.visible = is_endless or wave_number < wave_count
	start_wave_button.disabled = not can_start_next
	start_wave_button.text = EARLY_START_TEXT % early_start_bonus if early_start_bonus > 0.0 else START_WAVE_TEXT
	var key : String = InputManager.get_binding_text(InputManager.ACTION_START_WAVE)
	start_wave_button.tooltip_text = EARLY_START_TOOLTIP % [key, early_start_bonus] if early_start_bonus > 0.0 else START_WAVE_TOOLTIP % key

	var next_wave : WaveData = get_next_wave() if start_wave_button.visible else null
	preview.show_wave(next_wave)
	_fit_panel.call_deferred()
	if next_wave != null:
		start_wave_button.tooltip_text += "
" + WavePreview.describe(next_wave)
	_show_early_start(start_wave_button.visible and can_start_next and early_start_bonus > 0.0, early_start_bonus, key)
	_show_early_count(wave_count)
	auto_button.visible = start_wave_button.visible


func _show_early_start(is_open : bool, bonus : float, key : String) -> void:
	var was_open : bool = is_early_open
	is_early_open = is_open
	early_bonus_shown = bonus
	if is_open:
		start_wave_button.add_theme_color_override(&"font_color", GOLD_LIGHT_COLOR)
		start_wave_button.add_theme_color_override(&"font_hover_color", GOLD_LIGHT_COLOR)
		if not was_open:
			_start_glow()
			_show_notice(EARLY_READY_TEXT % [bonus, key])
	else:
		start_wave_button.remove_theme_color_override(&"font_color")
		start_wave_button.remove_theme_color_override(&"font_hover_color")
		_stop_glow()


#the button breathes a warm gold while the early start is open
func _start_glow() -> void:
	_stop_glow()
	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(start_wave_button, "self_modulate", GLOW_COLOR, GLOW_SECONDS).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(start_wave_button, "self_modulate", Color.WHITE, GLOW_SECONDS).set_trans(Tween.TRANS_SINE)


func _stop_glow() -> void:
	if glow_tween != null:
		glow_tween.kill()
		glow_tween = null
	start_wave_button.self_modulate = Color.WHITE


func _show_notice(text : String) -> void:
	early_notice_label.text = text
	early_notice.reset_size()
	if notice_tween != null:
		notice_tween.kill()
	early_notice.modulate.a = 0.0
	#a frame later: the panel grows to fit its preview row first, and the notice goes under its new bottom
	await get_tree().process_frame
	if not is_inside_tree() or not is_early_open:
		return
	var panel_rect : Rect2 = panel.get_global_rect()
	var at : Vector2 = Vector2(panel_rect.end.x - early_notice.size.x, panel_rect.end.y + 2.0) - global_position
	early_notice.position = (at + Vector2(0, -NOTICE_SLIDE)).round()
	if notice_tween != null:
		notice_tween.kill()
	notice_tween = create_tween()
	notice_tween.tween_property(early_notice, "modulate:a", 1.0, 0.2)
	notice_tween.parallel().tween_property(early_notice, "position", at.round(), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	notice_tween.tween_interval(NOTICE_SECONDS)
	notice_tween.tween_property(early_notice, "modulate:a", 0.0, NOTICE_FADE_SECONDS)


#the bonus floats up from the button when the early start is taken
func _float_taken_bonus(bonus : float) -> void:
	var label : Label = Label.new()
	label.text = EARLY_TAKEN_TEXT % bonus
	label.add_theme_color_override(&"font_color", GOLD_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.reset_size()
	var button_rect : Rect2 = start_wave_button.get_global_rect()
	label.position = (Vector2(button_rect.get_center().x - label.size.x * 0.5, button_rect.position.y - label.size.y) - global_position).round()
	var tween : Tween = label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - TAKEN_RISE, TAKEN_SECONDS).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, TAKEN_SECONDS).set_delay(TAKEN_SECONDS * 0.4)
	tween.tween_callback(label.queue_free)
	if notice_tween != null:
		notice_tween.kill()
	early_notice.modulate.a = 0.0


#early starts so far out of the waves that could be started early (every wave but the first), toward the talent
#points; gold once half of them are (the first early-start point)
func _show_early_count(wave_count : int) -> void:
	var level : Level = _current_level()
	var chances : int = wave_count - 1
	if level == null or chances <= 0 or level.wave_runner.wave_number < 1:
		early_count_label.hide()
		_fit_panel.call_deferred()
		return
	early_count_label.text = EARLY_COUNT_TEXT % [level.early_starts, chances]
	early_count_label.add_theme_color_override(&"font_color", GOLD_COLOR if level.early_starts * 2 >= chances else COUNT_COLOR)
	early_count_label.show()
	_fit_panel.call_deferred()


## A Panel does not grow with its content: fit its height to the preview row (deferred, so the new entries have their size).
func _fit_panel() -> void:
	if base_panel_height < 0.0:
		base_panel_height = panel.custom_minimum_size.y
	panel.custom_minimum_size.y = maxf(base_panel_height, panel_margin.get_combined_minimum_size().y)


## The level being played, or null.
static func _current_level() -> Level:
	var manager : Object = Utils.game_control.get(&"scene_manager") if Utils.game_control != null else null
	#untyped and checked first: a level freed under the manager would be a script error in a typed variable
	var level : Variant = manager.get(&"current_level") if manager != null else null
	if not is_instance_valid(level) or not level is Level or level.wave_runner == null:
		return null
	return level


## The wave the button sends; in Survival the grown copy the runner will make.
static func get_next_wave() -> WaveData:
	var level : Level = _current_level()
	if level == null:
		return null
	var runner : WaveRunner = level.wave_runner
	if runner.is_endless:
		return SurvivalRules.make_wave(runner.waves, runner.wave_number + 1) if not runner.waves.is_empty() else null
	return runner.next_wave
