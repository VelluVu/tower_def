class_name ResourceDisplayElement
extends PanelContainer


const FONT_COLOR_NAME : StringName = &"font_color"
#Endesga 32 red, on and off a few times: a stepped blink suits the pixel look better than a fade
const FLASH_COLOR : Color = Color("e43b44")
const FLASH_STEPS : int = 3
const FLASH_STEP_SECONDS : float = 0.1
## The low-lives pulse: red, then normal, this long each.
const ALARM_STEP_SECONDS : float = 0.45

@onready var value_display : Label = $HBoxContainer/Value

var last_value : int = 0
var flash_tween : Tween = null
## A slow red pulse that keeps going while on (few lives left).
var alarm_tween : Tween = null


func change_value(value : int) -> void:
	last_value = value
	value_display.text = str(value)


## On: the value pulses red until switched off; a flash still blinks over it.
func set_alarm(is_on : bool) -> void:
	if is_on == (alarm_tween != null):
		return
	if alarm_tween != null:
		alarm_tween.kill()
		alarm_tween = null
		value_display.remove_theme_color_override(FONT_COLOR_NAME)
		return
	alarm_tween = create_tween().set_loops()
	alarm_tween.tween_callback(value_display.add_theme_color_override.bind(FONT_COLOR_NAME, FLASH_COLOR))
	alarm_tween.tween_interval(ALARM_STEP_SECONDS)
	alarm_tween.tween_callback(value_display.remove_theme_color_override.bind(FONT_COLOR_NAME))
	alarm_tween.tween_interval(ALARM_STEP_SECONDS)


func flash() -> void:
	if flash_tween != null:
		flash_tween.kill()
	flash_tween = create_tween()
	for step in FLASH_STEPS:
		flash_tween.tween_callback(value_display.add_theme_color_override.bind(FONT_COLOR_NAME, FLASH_COLOR))
		flash_tween.tween_interval(FLASH_STEP_SECONDS)
		flash_tween.tween_callback(value_display.remove_theme_color_override.bind(FONT_COLOR_NAME))
		flash_tween.tween_interval(FLASH_STEP_SECONDS)
