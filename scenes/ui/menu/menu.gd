class_name Menu
extends Control


## The title screen (polish, 2026-11-22): the world map drifting behind a dark veil, the logo
## (tools/art/title_logo.py) over the buttons.
const MAP : Texture2D = preload("res://assets/art/ui/world_map.png")
const LOGO : Texture2D = preload("res://assets/art/ui/title/title_logo.png")
## Whole steps, so every art pixel stays square.
const MAP_SCALE : int = 3
const LOGO_SCALE : int = 2
## One sweep across the map and back.
const DRIFT_SECONDS : float = 90.0
const VEIL_COLOR : Color = Color(0.039, 0.09, 0.071, 0.55)
const LOGO_TOP : float = 26.0
const BACKDROP_LAYER : int = -1
const TAGLINE_TEXT : String = "The drakelings hold the castles"
const TAGLINE_COLOR : Color = Color("a2f6db")
const TAGLINE_GAP : float = 4.0

@onready var continue_button : Button = $MarginContainer/VBoxContainer/ContinueButton
@onready var title_label : Label = $MarginContainer/VBoxContainer/TitleLabel

var backdrop : TextureRect = null
var drift_time : float = 0.0


func _ready() -> void:
	Utils.game_control.reset_time_scale()
	continue_button.visible = PlayerProgress.has_save
	_build_title()


func _process(delta : float) -> void:
	if backdrop == null:
		return
	drift_time += delta
	var screen : Vector2 = get_viewport_rect().size
	var room : Vector2 = (backdrop.size - screen).max(Vector2.ZERO)
	#ease back and forth across the map, in whole pixels
	var sweep : float = 0.5 - 0.5 * cos(drift_time * TAU / DRIFT_SECONDS)
	backdrop.position = -Vector2(roundf(room.x * sweep), roundf(room.y * (1.0 - sweep)))


func _build_title() -> void:
	var screen : Vector2 = get_viewport_rect().size
	#its own layer under the UI's: top_level controls would draw over the menu panel
	var back_layer : CanvasLayer = CanvasLayer.new()
	back_layer.layer = BACKDROP_LAYER
	add_child(back_layer)
	backdrop = TextureRect.new()
	backdrop.texture = MAP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.size = MAP.get_size() * MAP_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_layer.add_child(backdrop)

	var veil : ColorRect = ColorRect.new()
	veil.color = VEIL_COLOR
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_layer.add_child(veil)

	var logo : TextureRect = TextureRect.new()
	logo.texture = LOGO
	logo.top_level = true
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.size = LOGO.get_size() * LOGO_SCALE
	logo.position = Vector2(roundf((screen.x - logo.size.x) / 2.0), LOGO_TOP)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	var tagline : Label = Label.new()
	tagline.text = TAGLINE_TEXT
	tagline.top_level = true
	tagline.add_theme_color_override(&"font_color", TAGLINE_COLOR)
	add_child(tagline)
	tagline.reset_size()
	tagline.position = Vector2(roundf((screen.x - tagline.size.x) / 2.0), logo.position.y + logo.size.y + TAGLINE_GAP)
	#the logo says it now
	title_label.hide()


func _on_start_button_pressed() -> void:
	UISignals.start_game.emit()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_options_button_pressed() -> void:
	UISignals.options.emit()


func _on_continue_button_pressed() -> void:
	UISignals.continue_last_save.emit()
