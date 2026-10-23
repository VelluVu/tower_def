class_name Options
extends Control

## Audio, display, gameplay and controls settings, read from and written to SettingsManager.
## The rows are built here, so a new setting is one more _add_row call.

const MASTER_LABEL : String = "Master"
const MUSIC_LABEL : String = "Music"
const SFX_LABEL : String = "Effects"
const MUTE_TEXT : String = "Mute"
const FULLSCREEN_LABEL : String = "Fullscreen"
const VSYNC_LABEL : String = "VSync"
const VSYNC_TOOLTIP : String = "Waits for the screen's refresh, so the picture never tears."
const MAX_FPS_LABEL : String = "FPS limit"
const MAX_FPS_UNLIMITED_TEXT : String = "Unlimited"
const PIXEL_PERFECT_LABEL : String = "Sharp pixels"
const PIXEL_PERFECT_TOOLTIP : String = "Scales the picture in whole steps only, so every pixel is the same size. Can leave black bars at the edges."
const DAMAGE_NUMBERS_LABEL : String = "Damage numbers"
const CAMERA_SPEED_LABEL : String = "Camera speed"
const EDGE_SCROLL_LABEL : String = "Edge scrolling"
const EDGE_SCROLL_TOOLTIP : String = "Moves the camera when the mouse touches the edge of the window."
const FOCUS_PAUSE_LABEL : String = "Pause in background"
const FOCUS_PAUSE_TOOLTIP : String = "Opens the pause menu when you switch to another window during a level."
const CONTROLS_TAB_NAME : String = "Controls"
const PERCENT_FORMAT : String = "%d%%"
const SPEED_FORMAT : String = "%.2fx"
## Fits the longest label, "Pause in background".
const ROW_LABEL_WIDTH : float = 128.0
const VALUE_LABEL_WIDTH : float = 32.0
const ROW_HEIGHT : float = 18.0
const VOLUME_STEP : float = 0.05
const CAMERA_SPEED_MIN : float = 0.5
const CAMERA_SPEED_MAX : float = 2.0
const CAMERA_SPEED_STEP : float = 0.25

@onready var tab_container : TabContainer = %TabContainer
@onready var audio_tab : VBoxContainer = %Audio
@onready var display_tab : VBoxContainer = %Display
@onready var gameplay_tab : VBoxContainer = %Gameplay
@onready var back_button : Button = %Back

var in_main_menu : bool = false
var _key_bindings : KeyBindingsTab


func _ready() -> void:
	for bus : StringName in [SettingsManager.BUS_MASTER, SettingsManager.BUS_MUSIC, SettingsManager.BUS_SFX]:
		_add_volume_row(bus)

	_add_check_row(display_tab, FULLSCREEN_LABEL, "", SettingsManager.fullscreen, SettingsManager.set_fullscreen)
	_add_option_check_row(display_tab, VSYNC_LABEL, VSYNC_TOOLTIP, SettingsManager.OPTION_VSYNC)
	_add_max_fps_row()
	_add_check_row(display_tab, PIXEL_PERFECT_LABEL, PIXEL_PERFECT_TOOLTIP, SettingsManager.pixel_perfect, SettingsManager.set_pixel_perfect)
	_add_option_check_row(display_tab, DAMAGE_NUMBERS_LABEL, "", SettingsManager.OPTION_DAMAGE_NUMBERS)

	_add_camera_speed_row()
	_add_option_check_row(gameplay_tab, EDGE_SCROLL_LABEL, EDGE_SCROLL_TOOLTIP, SettingsManager.OPTION_EDGE_SCROLL)
	_add_option_check_row(gameplay_tab, FOCUS_PAUSE_LABEL, FOCUS_PAUSE_TOOLTIP, SettingsManager.OPTION_PAUSE_ON_FOCUS_LOSS)

	_key_bindings = KeyBindingsTab.new()
	_key_bindings.setup(InputManager)
	_key_bindings.name = CONTROLS_TAB_NAME
	tab_container.add_child(_key_bindings)

	back_button.pressed.connect(_on_back_pressed)


## Esc goes back (or cancels a key capture) instead of reaching UI, which would open the
## pause menu on top. Children get _input before UI.
func _input(event : InputEvent) -> void:
	if _key_bindings.try_capture(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(InputManager.ACTION_CANCEL):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _add_volume_row(bus : StringName) -> void:
	var labels : Dictionary = {
		SettingsManager.BUS_MASTER: MASTER_LABEL,
		SettingsManager.BUS_MUSIC: MUSIC_LABEL,
		SettingsManager.BUS_SFX: SFX_LABEL,
	}
	var slider : HSlider = _new_slider(0.0, 1.0, VOLUME_STEP, SettingsManager.get_volume(bus))
	var value_label : Label = _new_value_label(PERCENT_FORMAT % roundi(slider.value * 100.0))
	var mute_check : CheckButton = CheckButton.new()
	mute_check.text = MUTE_TEXT
	mute_check.button_pressed = SettingsManager.is_muted(bus)

	slider.value_changed.connect(func(value : float) -> void:
		SettingsManager.set_volume(bus, value)
		value_label.text = PERCENT_FORMAT % roundi(value * 100.0))
	# Saving on every tick of a drag would write the file dozens of times.
	slider.drag_ended.connect(func(_changed : bool) -> void: SettingsManager.save_settings())
	mute_check.toggled.connect(func(muted : bool) -> void: SettingsManager.set_muted(bus, muted))
	_add_row(audio_tab, labels[bus], "", [slider, value_label, mute_check])


func _add_max_fps_row() -> void:
	var option_button : OptionButton = OptionButton.new()
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for fps : int in SettingsManager.MAX_FPS_CHOICES:
		option_button.add_item(MAX_FPS_UNLIMITED_TEXT if fps == 0 else str(fps))

	var current : int = SettingsManager.MAX_FPS_CHOICES.find(int(SettingsManager.get_option(SettingsManager.OPTION_MAX_FPS)))
	option_button.select(maxi(current, 0))
	option_button.item_selected.connect(func(index : int) -> void:
		SettingsManager.set_option(SettingsManager.OPTION_MAX_FPS, SettingsManager.MAX_FPS_CHOICES[index]))
	_add_row(display_tab, MAX_FPS_LABEL, "", [option_button])


func _add_camera_speed_row() -> void:
	var current : float = SettingsManager.get_option(SettingsManager.OPTION_CAMERA_SPEED)
	var slider : HSlider = _new_slider(CAMERA_SPEED_MIN, CAMERA_SPEED_MAX, CAMERA_SPEED_STEP, current)
	var value_label : Label = _new_value_label(SPEED_FORMAT % current)

	slider.value_changed.connect(func(value : float) -> void: value_label.text = SPEED_FORMAT % value)
	slider.drag_ended.connect(func(_changed : bool) -> void:
		SettingsManager.set_option(SettingsManager.OPTION_CAMERA_SPEED, slider.value))
	_add_row(gameplay_tab, CAMERA_SPEED_LABEL, "", [slider, value_label])


## A toggle for one of the named options in SettingsWiring.
func _add_option_check_row(tab : Control, label_text : String, tooltip : String, option_key : String) -> void:
	_add_check_row(tab, label_text, tooltip, SettingsManager.get_option(option_key), func(on : bool) -> void:
		SettingsManager.set_option(option_key, on))


func _add_check_row(tab : Control, label_text : String, tooltip : String, is_on : bool, on_toggled : Callable) -> void:
	var check : CheckButton = CheckButton.new()
	check.button_pressed = is_on
	check.toggled.connect(on_toggled)
	_add_row(tab, label_text, tooltip, [check])


## A fixed-width label, then the controls; the tooltip covers the whole row.
func _add_row(tab : Control, label_text : String, tooltip : String, controls : Array[Control]) -> void:
	var row : HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	var label : Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = ROW_LABEL_WIDTH
	label.tooltip_text = tooltip
	label.mouse_filter = Control.MOUSE_FILTER_PASS if tooltip != "" else Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	for control : Control in controls:
		control.tooltip_text = tooltip
		row.add_child(control)

	tab.add_child(row)


func _new_slider(min_value : float, max_value : float, step : float, value : float) -> HSlider:
	var slider : HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return slider


func _new_value_label(text : String) -> Label:
	var label : Label = Label.new()
	label.text = text
	label.custom_minimum_size.x = VALUE_LABEL_WIDTH
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func _on_back_pressed() -> void:
	UISignals.to_menu.emit(in_main_menu, name)
