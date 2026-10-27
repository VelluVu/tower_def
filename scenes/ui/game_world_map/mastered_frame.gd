class_name MasteredFrame
extends Control
## A pulsing coin-gold frame around a world map level that has all its talent points.


const OUTER_COLOR : Color = Color("feae34")
const INNER_COLOR : Color = Color("fee761")
const OUTLINE_COLOR : Color = Color("181425")
const MARGIN : int = 3
const PULSE_TIME : float = 0.8
const PULSE_MIN_ALPHA : float = 0.45


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = -MARGIN
	offset_top = -MARGIN
	offset_right = MARGIN
	offset_bottom = MARGIN
	var tween : Tween = create_tween().set_loops()
	tween.tween_property(self, "modulate:a", PULSE_MIN_ALPHA, PULSE_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 1.0, PULSE_TIME).set_trans(Tween.TRANS_SINE)


#whole-pixel rects: dark outline, gold frame, light inner edge, like the bold UI frames
func _draw() -> void:
	var rect : Rect2 = Rect2(Vector2.ZERO, size)
	_draw_frame(rect, OUTLINE_COLOR)
	_draw_frame(rect.grow(-1.0), OUTER_COLOR)
	_draw_frame(rect.grow(-2.0), INNER_COLOR)


func _draw_frame(rect : Rect2, color : Color) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), color)
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 1.0), Vector2(rect.size.x, 1.0)), color)
	draw_rect(Rect2(rect.position, Vector2(1.0, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 1.0, 0.0), Vector2(1.0, rect.size.y)), color)
