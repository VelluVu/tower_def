class_name TelegraphLine
extends Node2D

## A warning on the ground where a boss's attack will land (the Ashen Wyrm's breath): a dashed band of fire colour,
## blinking; the ability that made it frees it. As a flame (make_flame) it is the breath itself: layered bands of
## fire that flicker for FLAME_SECONDS, then it frees itself.

const COLOR : Color = Color(0.89, 0.23, 0.27, 0.5)
const EDGE : Color = Color("fee761")
const DASH : float = 4.0
const BLINK_SECONDS : float = 0.25
const FLAME_SECONDS : float = 0.5
const FLAME_LAYERS : Array[Color] = [Color("a22633"), Color("e43b44"), Color("f77622"), Color("fee761")]

var from : Vector2 = Vector2.ZERO
var to : Vector2 = Vector2.ZERO
var half_width : float = 8.0
var shown : bool = true
var elapsed : float = 0.0
var is_flame : bool = false
#game speed: the blink and the flame count game time, like every other gameplay clock
var current_time_scale : float = 1.0


static func make(level : Level, start : Vector2, end : Vector2, width : float) -> TelegraphLine:
	var line : TelegraphLine = TelegraphLine.new()
	line.from = start
	line.to = end
	line.half_width = width
	line.z_index = 1
	level.add_child(line)
	return line


static func make_flame(level : Level, start : Vector2, end : Vector2, width : float) -> TelegraphLine:
	var line : TelegraphLine = make(level, start, end, width)
	line.is_flame = true
	line.z_index = 16
	return line


func _ready() -> void:
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	if Utils.game_control != null:
		_on_time_scale_change(Utils.game_control.time_scale)


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale


func _process(delta : float) -> void:
	elapsed += delta * current_time_scale
	if is_flame:
		if elapsed >= FLAME_SECONDS:
			queue_free()
		queue_redraw()
		return
	var now_shown : bool = int(elapsed / BLINK_SECONDS) % 2 == 0
	if now_shown != shown:
		shown = now_shown
		queue_redraw()


func _draw() -> void:
	var a : Vector2 = to_local(from).round()
	var b : Vector2 = to_local(to).round()
	if is_flame:
		_draw_flame(a, b)
		return
	if not shown:
		return
	draw_line(a, b, COLOR, half_width * 2.0)
	var length : float = a.distance_to(b)
	var dir : Vector2 = (b - a) / maxf(length, 1.0)
	var t : float = 0.0
	while t < length:
		draw_line((a + dir * t).round(), (a + dir * minf(t + DASH, length)).round(), EDGE, 1.0)
		t += DASH * 2.0


#narrower and brighter towards the core; the edges flicker, and the flame thins out as it dies
func _draw_flame(a : Vector2, b : Vector2) -> void:
	var fade : float = 1.0 - elapsed / FLAME_SECONDS
	for i in FLAME_LAYERS.size():
		var width : float = roundf(half_width * 2.0 * fade * (1.0 - i * 0.22) + (randi() % 3) - 1)
		if width >= 1.0:
			draw_line(a, b, FLAME_LAYERS[i], width)
