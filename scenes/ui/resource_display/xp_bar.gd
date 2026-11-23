class_name XpBar
extends Control

## A thin XP bar along the bottom of the XP panel (polish, 2026-11-22): a dark track and Puffe's
## mint fill with a light top row, drawn at whole pixels. The fill slides to its new value; a level-up
## fills it gold for a moment before it starts again from empty.

const HEIGHT : float = 4.0
const TRACK_COLOR : Color = Color("0a1712")
const FILL_COLOR : Color = Color("2effb8")
const FILL_LIGHT_COLOR : Color = Color("87ffdb")
const LEVEL_UP_COLOR : Color = Color("feae34")
const SLIDE_SECONDS : float = 0.25
const LEVEL_UP_SECONDS : float = 0.35

## 0..1, what is drawn.
var shown_ratio : float = 0.0 :
	set = _set_shown_ratio
var is_level_up_flash : bool = false
var tween : Tween = null
var last_level : int = -1


func _ready() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A new XP state; a higher level than last time fills the bar gold first.
func set_xp(xp : float, xp_needed : float, level : int) -> void:
	var ratio : float = clampf(xp / xp_needed, 0.0, 1.0) if xp_needed > 0.0 else 0.0
	if tween != null:
		tween.kill()
	tween = create_tween()
	if last_level >= 0 and level > last_level:
		tween.tween_callback(func() -> void: is_level_up_flash = true)
		tween.tween_property(self, ^"shown_ratio", 1.0, SLIDE_SECONDS)
		tween.tween_interval(LEVEL_UP_SECONDS)
		tween.tween_callback(func() -> void:
			is_level_up_flash = false
			shown_ratio = 0.0)
	tween.tween_property(self, ^"shown_ratio", ratio, SLIDE_SECONDS)
	last_level = level


func _set_shown_ratio(value : float) -> void:
	if shown_ratio == value:
		return
	shown_ratio = value
	queue_redraw()


func _draw() -> void:
	var width : float = floorf(size.x)
	draw_rect(Rect2(0.0, 0.0, width, HEIGHT), TRACK_COLOR)
	var fill_width : float = floorf((width - 2.0) * shown_ratio)
	if fill_width <= 0.0:
		return
	var fill : Color = LEVEL_UP_COLOR if is_level_up_flash else FILL_COLOR
	draw_rect(Rect2(1.0, 1.0, fill_width, HEIGHT - 2.0), fill)
	if not is_level_up_flash:
		draw_rect(Rect2(1.0, 1.0, fill_width, 1.0), FILL_LIGHT_COLOR)
