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


#a whole-pixel ring round the round level button: dark outline, gold, light inner edge, like the bold UI frames
func _draw() -> void:
	var centre : Vector2 = size * 0.5
	var radius : float = minf(size.x, size.y) * 0.5
	var ring_colors : Array[Color] = [OUTLINE_COLOR, OUTER_COLOR, INNER_COLOR]

	for y in int(size.y):
		for x in int(size.x):
			var band : int = int(radius - Vector2(x + 0.5, y + 0.5).distance_to(centre))
			if band >= 0 and band < ring_colors.size():
				draw_rect(Rect2(x, y, 1.0, 1.0), ring_colors[band])
