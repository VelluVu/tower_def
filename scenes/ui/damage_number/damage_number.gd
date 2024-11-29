class_name DamageNumber
extends Control


const FONT_COLOR_PROPERTY_NAME : String = "font_color"
const FONT_SIZE_PROPERTY_NAME : String = "font_size"
const GLOBAL_POSITION_PROPERTY_NAME : String = "global_position"

@onready var number_label : Label = $NumberLabel
@onready var live_timer : Timer = $LiveTimer

@export var lift_distance : float = 8.0
@export var font_size : float = 8.0
@export var overtime_font_size : float = 6.0
@export var critical_font_size_multiplier : float = 1.2
@export var critical_color_lightener_value : float = 0.2

var current_font_size : float = 8.0
var tween : Tween = null

signal deactivated(damage_number : DamageNumber)


func _ready() -> void:
	live_timer.timeout.connect(_on_live_timer_timeout)


func activate(_position : Vector2, _damage_data : DamageData) -> void:
	global_position = _position
	number_label.text = ("+" + str(_damage_data.rounded_damage * -1)) if _damage_data.is_healing else str(_damage_data.rounded_damage)
	var font_color : Color = Color.GREEN if _damage_data.is_healing else Utils.get_damage_type_color(_damage_data.damage_type)
	font_color = font_color if not _damage_data.is_critical else font_color.lightened(critical_color_lightener_value)
	number_label.add_theme_color_override(FONT_COLOR_PROPERTY_NAME, font_color)
	current_font_size = font_size if not _damage_data.is_overtime else overtime_font_size
	current_font_size = current_font_size if not _damage_data.is_critical else current_font_size * critical_font_size_multiplier
	number_label.add_theme_font_size_override(FONT_SIZE_PROPERTY_NAME, round(current_font_size))
	live_timer.start()
	visible = true
	_animate_damage_text()


func _animate_damage_text() -> void:
	if tween:
		tween.kill()
		
	tween = create_tween()
	tween.tween_property(self, GLOBAL_POSITION_PROPERTY_NAME, global_position + Vector2.UP * lift_distance, live_timer.wait_time)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.play()


func _on_live_timer_timeout() -> void:
	visible = false
	deactivated.emit(self)
