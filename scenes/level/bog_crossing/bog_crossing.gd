@tool
class_name BogCrossing
extends Node2D

## A bog crossing placed in a swamp level: stepping stones from its position (the entry, on the
## shore) to `exit_offset` (the far shore). The bog stays blocked on the grid for everyone; only
## enemies with Enemy.can_wade use crossings, when the way over the stones is cheaper than the road
## (LevelGrid.find_wading_route). One way: entry to exit.

## The exit shore cell's centre, from the entry.
@export var exit_offset : Vector2 = Vector2(48, 0) :
	set = _set_exit_offset
## Walking speed on the stones, a share of the enemy's own.
@export_range(0.1, 1.0) var wade_speed_factor : float = 0.6

const STONE_SPACING : float = 5.0
const STONE_SIZE : Vector2 = Vector2(4, 3)
const STONE_COLOR : Color = Color("8b9bb4")
const STONE_LIGHT : Color = Color("c0cbdc")
const STONE_SHADOW : Color = Color("262b44")

var entry_position : Vector2 :
	get:
		return global_position

var exit_position : Vector2 :
	get:
		return global_position + exit_offset


## The route over the stones as a share of a walk on open ground, in cells.
func get_cost() -> float:
	return exit_offset.length() / Utils.TILE_SIZE / wade_speed_factor


func _set_exit_offset(value : Vector2) -> void:
	if value == exit_offset:
		return
	exit_offset = value
	queue_redraw()


#stepping stones across the water, on whole pixels
func _draw() -> void:
	var length : float = exit_offset.length()
	if length <= 0.0:
		return

	var direction : Vector2 = exit_offset / length
	var count : int = floori(length / STONE_SPACING)
	#a stone: dark underside, grey body, a light top edge (light from the top left)
	for i in range(1, count):
		var at : Vector2 = (direction * i * STONE_SPACING).round() - (STONE_SIZE / 2.0).floor()
		draw_rect(Rect2(at + Vector2(0, 1), STONE_SIZE), STONE_SHADOW)
		draw_rect(Rect2(at, STONE_SIZE), STONE_COLOR)
		draw_rect(Rect2(at, Vector2(STONE_SIZE.x - 1, 1)), STONE_LIGHT)
