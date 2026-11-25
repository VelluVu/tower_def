class_name BufferAuraRing
extends Node2D

## A placed Buffer's aura on the ground: a faint dotted ring at its edge in the element's colour, and now and then a
## pulse that runs out from the drakeling to the edge. Cosmetic: real time, under the units.

const COLORS : Dictionary[Utils.Element, Color] = {
	Utils.Element.None: Color("68ffd0"),
	Utils.Element.Physical: Color("c0cbdc"),
	Utils.Element.Fire: Color("f77622"),
	Utils.Element.Frost: Color("2ce8f5"),
	Utils.Element.Poison: Color("b6d53c"),
}
const RING_ALPHA : float = 0.35
const PULSE_ALPHA : float = 0.3
const PULSE_SECONDS : float = 1.2
const PULSE_GAP_SECONDS : float = 2.0
## Every other few degrees: a dotted edge.
const DOT_STEP_DEGREES : float = 6.0

@onready var buffer : Buffer = get_parent()

var time : float = 0.0


func _ready() -> void:
	show_behind_parent = true
	z_index = -1


func _process(delta : float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	if not buffer.is_placed:
		return
	var radius : float = roundf(buffer.radius)
	var color : Color = COLORS.get(buffer.element, COLORS[Utils.Element.None])
	var dots : int = int(360.0 / DOT_STEP_DEGREES)
	for i in dots:
		if i % 2:
			continue
		var angle : float = deg_to_rad(i * DOT_STEP_DEGREES)
		draw_rect(Rect2((Vector2.from_angle(angle) * radius).round(), Vector2.ONE), Color(color, RING_ALPHA))
	var phase : float = fmod(time, PULSE_SECONDS + PULSE_GAP_SECONDS) / PULSE_SECONDS
	if phase <= 1.0:
		var pulse_radius : float = roundf(radius * phase)
		if pulse_radius >= 2.0:
			draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 48, Color(color, PULSE_ALPHA * (1.0 - phase)), 1.0, false)
