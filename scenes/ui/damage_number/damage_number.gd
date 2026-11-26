class_name DamageNumber
extends Control


const FONT_COLOR_PROPERTY_NAME : String = "font_color"
const FONT_SIZE_PROPERTY_NAME : String = "font_size"
const LIFT_PROPERTY_NAME : String = "lift"

@onready var number_label : Label = $NumberLabel
@onready var live_timer : Timer = $LiveTimer

@export var lift_distance : float = 8.0
#pixel font: keep the sizes at 8 or its multiples, other sizes blur the glyphs
@export var font_size : float = 8.0
@export var overtime_font_size : float = 8.0
@export var critical_font_size_multiplier : float = 2.0
@export var critical_color_lightener_value : float = 0.2
#in screen pixels, so it is the same at every zoom: the double-size crit text starts this much higher, off the enemy
@export var critical_screen_lift : float = 8.0

var current_font_size : float = 8.0
var tween : Tween = null
var world_position : Vector2 = Vector2.ZERO
var lift : float = 0.0
var screen_lift : float = 0.0
#a running total (the beam's ticks on one enemy): untyped, since the enemy may be freed while the number runs
var running_enemy : Object = null
var running_offset : Vector2 = Vector2.ZERO
var running_total : float = 0.0
var running_since_hit : float = 0.0

signal deactivated(damage_number : DamageNumber)


func _ready() -> void:
	live_timer.timeout.connect(_on_live_timer_timeout)


func activate(_position : Vector2, _damage_data : DamageData) -> void:
	world_position = _position
	lift = 0.0
	screen_lift = critical_screen_lift if _damage_data.is_critical else 0.0
	_update_screen_position()
	number_label.text = ("+" + str(int(-_damage_data.rounded_damage))) if _damage_data.is_healing else str(int(_damage_data.rounded_damage))
	var font_color : Color = Color.GREEN if _damage_data.is_healing else Utils.get_damage_type_color(_damage_data.damage_type)
	font_color = font_color if not _damage_data.is_critical else font_color.lightened(critical_color_lightener_value)
	number_label.add_theme_color_override(FONT_COLOR_PROPERTY_NAME, font_color)
	current_font_size = font_size if not _damage_data.is_overtime else overtime_font_size
	current_font_size = current_font_size if not _damage_data.is_critical else current_font_size * critical_font_size_multiplier
	number_label.add_theme_font_size_override(FONT_SIZE_PROPERTY_NAME, round(current_font_size))
	_show()


## A word instead of a number, such as an element reaction's name.
func activate_text(_position : Vector2, text : String, color : Color) -> void:
	world_position = _position
	lift = 0.0
	screen_lift = 0.0
	_update_screen_position()
	number_label.text = text
	number_label.add_theme_color_override(FONT_COLOR_PROPERTY_NAME, color)
	current_font_size = font_size
	number_label.add_theme_font_size_override(FONT_SIZE_PROPERTY_NAME, round(current_font_size))
	_show()


## Starts a running total on the enemy: it follows the enemy and counts up with add_running until release.
func activate_running(enemy : Enemy, offset : Vector2, _damage_data : DamageData) -> void:
	if tween:
		tween.kill()
	live_timer.stop()
	running_enemy = enemy
	running_offset = offset
	running_total = 0.0
	lift = 0.0
	screen_lift = 0.0
	current_font_size = font_size
	number_label.add_theme_font_size_override(FONT_SIZE_PROPERTY_NAME, round(current_font_size))
	visible = false
	add_running(_damage_data)


func add_running(_damage_data : DamageData) -> void:
	running_total += _damage_data.damage
	running_since_hit = 0.0
	number_label.text = str(roundi(running_total))
	number_label.add_theme_color_override(FONT_COLOR_PROPERTY_NAME, Utils.get_damage_type_color(_damage_data.damage_type))
	_follow_running_enemy()
	#shown once the total is big enough to show, like a single hit
	if not visible and running_total >= DamageNumberManager.MIN_SHOWN_DAMAGE:
		visible = true
		_update_screen_position()


func is_running() -> bool:
	return running_enemy != null


## The beam let go or the enemy is gone: the total floats off like a hit (or vanishes if it stayed too small).
func release() -> void:
	running_enemy = null
	if running_total < DamageNumberManager.MIN_SHOWN_DAMAGE:
		visible = false
		deactivated.emit(self)
		return
	_show()


func _follow_running_enemy() -> void:
	if is_instance_valid(running_enemy):
		var enemy : Enemy = running_enemy
		world_position = enemy.pop_up_spot.global_position + running_offset


## A number as the player reads it: one decimal, a whole number without its ".0" (0.3, 1, 12.5).
static func format(value : float) -> String:
	return String.num(snappedf(value, 0.1), 1)


func _show() -> void:
	live_timer.start()
	visible = true
	_animate_damage_text()


func _animate_damage_text() -> void:
	if tween:
		tween.kill()
		
	tween = create_tween()
	tween.tween_property(self, LIFT_PROPERTY_NAME, lift_distance, live_timer.wait_time)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.play()


func _process(_delta : float) -> void:
	if running_enemy != null:
		running_since_hit += _delta
		_follow_running_enemy()
	if visible:
		_update_screen_position()


#the number lives on a CanvasLayer so the camera zoom never stretches the pixel font; it follows its world point by hand
func _update_screen_position() -> void:
	position = (get_viewport().get_canvas_transform() * (world_position + Vector2.UP * lift) + Vector2.UP * screen_lift).round()


func _on_live_timer_timeout() -> void:
	visible = false
	deactivated.emit(self)
