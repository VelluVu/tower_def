class_name Menu
extends Control


## The title screen (polish, 2026-11-22): the logo (tools/art/title_logo.py) over the buttons in a column on
## the left, the hatching hoard (HoardBackdrop, 2026-11-23) behind it, its pile right of the middle.
const LOGO : Texture2D = preload("res://assets/art/ui/title/title_logo.png")
## Whole steps, so every art pixel stays square.
const LOGO_SCALE : int = 2
const LOGO_TOP : float = 26.0
const TAGLINE_TEXT : String = "The drakelings hold the castles"
const TAGLINE_COLOR : Color = Color("a2f6db")
const TAGLINE_GAP : float = 4.0
## The column's middle; the panel's offsets in menu.tscn centre it here too.
const COLUMN_X : float = 155.0

@onready var continue_button : Button = $MarginContainer/VBoxContainer/ContinueButton
@onready var title_label : Label = $MarginContainer/VBoxContainer/TitleLabel

var backdrop : HoardBackdrop = null



func _ready() -> void:
	Utils.game_control.reset_time_scale()
	continue_button.visible = PlayerProgress.has_save
	_build_title()


func _build_title() -> void:
	if backdrop == null:
		backdrop = HoardBackdrop.new()
		add_child(backdrop)

	var logo : TextureRect = TextureRect.new()
	logo.texture = LOGO
	logo.top_level = true
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.size = LOGO.get_size() * LOGO_SCALE
	logo.position = Vector2(roundf(COLUMN_X - logo.size.x / 2.0), LOGO_TOP)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	var tagline : Label = Label.new()
	tagline.text = TAGLINE_TEXT
	tagline.top_level = true
	tagline.add_theme_color_override(&"font_color", TAGLINE_COLOR)
	add_child(tagline)
	tagline.reset_size()
	tagline.position = Vector2(roundf(COLUMN_X - tagline.size.x / 2.0), logo.position.y + logo.size.y + TAGLINE_GAP)
	#the logo says it now
	title_label.hide()


## Takes over a backdrop that is already playing (from Options), so the brood carries on instead of
## starting over.
func adopt_backdrop(playing : HoardBackdrop) -> void:
	if playing == null or playing == backdrop:
		return
	if backdrop != null:
		backdrop.queue_free()
	backdrop = playing
	if playing.get_parent() != null:
		playing.reparent(self)
	else:
		add_child(playing)


func _on_start_button_pressed() -> void:
	UISignals.start_game.emit()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_options_button_pressed() -> void:
	UISignals.options.emit()


func _on_continue_button_pressed() -> void:
	UISignals.continue_last_save.emit()
