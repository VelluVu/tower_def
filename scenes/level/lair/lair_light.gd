class_name LairLight
extends Node2D

## One light in a boss lair's darkness (LairLighting gathers every node in the group): a colour, a reach in tiles and a
## strength, with an optional flicker for torches. Only looks.

const GROUP : StringName = &"lair_light"
## A flickering light picks a new strength this often, in seconds.
const FLICKER_STEP_SECONDS : float = 0.12

@export var color : Color = Color(1.0, 0.75, 0.4)
@export var radius_tiles : float = 3.0
@export_range(0.0, 2.0) var strength : float = 0.8
## How far a flicker dips the strength (0 = steady).
@export_range(0.0, 1.0) var flicker : float = 0.0

var current_strength : float = 0.0
var flicker_left : float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	current_strength = strength


func _process(delta : float) -> void:
	if flicker <= 0.0:
		return
	flicker_left -= delta
	if flicker_left > 0.0:
		return
	flicker_left = FLICKER_STEP_SECONDS
	current_strength = strength * (1.0 - randf() * flicker)
