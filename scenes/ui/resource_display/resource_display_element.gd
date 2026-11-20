class_name ResourceDisplayElement
extends PanelContainer


const FONT_COLOR_NAME : StringName = &"font_color"
#Endesga 32 red, on and off a few times: a stepped blink suits the pixel look better than a fade
const FLASH_COLOR : Color = Color("e43b44")
const FLASH_STEPS : int = 3
const FLASH_STEP_SECONDS : float = 0.1

@onready var value_display : Label = $HBoxContainer/Value

var last_value : int = 0
var flash_tween : Tween = null


func change_value(value : int) -> void:
	last_value = value
	value_display.text = str(value)


func flash() -> void:
	if flash_tween != null:
		flash_tween.kill()
	flash_tween = create_tween()
	for step in FLASH_STEPS:
		flash_tween.tween_callback(value_display.add_theme_color_override.bind(FONT_COLOR_NAME, FLASH_COLOR))
		flash_tween.tween_interval(FLASH_STEP_SECONDS)
		flash_tween.tween_callback(value_display.remove_theme_color_override.bind(FONT_COLOR_NAME))
		flash_tween.tween_interval(FLASH_STEP_SECONDS)
