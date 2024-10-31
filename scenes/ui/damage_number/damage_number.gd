class_name DamageNumber
extends Control


const FONT_COLOR_PROPERTY_NAME : String = "font_color"
const GLOBAL_POSITION_PROPERTY_NAME : String = "global_position"

@onready var number_label : Label = $NumberLabel
@onready var live_timer : Timer = $LiveTimer

@export var lift_distance : float = 8.0

var tween : Tween = null

signal deactivated(damage_number : DamageNumber)


func _ready() -> void:
	live_timer.timeout.connect(_on_live_timer_timeout)


func activate(_position : Vector2, _amount : int, _type : Utils.DamageType) -> void:
	global_position = _position
	number_label.text = str(_amount)
	number_label.add_theme_color_override(FONT_COLOR_PROPERTY_NAME, Utils.get_damage_type_color(_type))
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
