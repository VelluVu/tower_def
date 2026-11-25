class_name SynergyFlash
extends Node2D

## A synergy showing itself (design doc "Synergies", 2026-11-25): a short bright line between its two sources, or a
## ring where it happened, fading in game time. Players learn the synergies by seeing them.

const SECONDS : float = 0.45
const RING_START : float = 3.0
const RING_END : float = 11.0
const LINE_WIDTH : float = 1.0

var color : Color = Color.WHITE
var to : Vector2 = Vector2.ZERO
var is_ring : bool = false
var age : float = 0.0


## A line from from_position to to_position.
static func line(level : Node, from_position : Vector2, to_position : Vector2, line_color : Color) -> SynergyFlash:
	var flash : SynergyFlash = _make(level, from_position, line_color)
	flash.to = to_position - from_position
	return flash


## A ring growing out of at.
static func ring(level : Node, at : Vector2, ring_color : Color) -> SynergyFlash:
	var flash : SynergyFlash = _make(level, at, ring_color)
	flash.is_ring = true
	return flash


static func _make(level : Node, at : Vector2, flash_color : Color) -> SynergyFlash:
	var flash : SynergyFlash = SynergyFlash.new()
	flash.color = flash_color
	flash.z_index = 25
	level.add_child(flash)
	flash.global_position = at
	return flash


func _process(delta : float) -> void:
	var time_scale : float = Utils.game_control.time_scale if Utils.game_control != null else 1.0
	age += delta * time_scale
	if age >= SECONDS:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var share : float = clampf(age / SECONDS, 0.0, 1.0)
	var faded : Color = Color(color, 1.0 - share)
	if is_ring:
		draw_arc(Vector2.ZERO, roundf(lerpf(RING_START, RING_END, share)), 0.0, TAU, 20, faded, LINE_WIDTH)
	else:
		draw_line(Vector2.ZERO, to.round(), faded, LINE_WIDTH)
