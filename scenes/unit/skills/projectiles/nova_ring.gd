class_name NovaRing
extends Node2D

## Draws a nova's burst: a two-pixel ring on the edge of the hit area, a faint disc inside
## and a flash at the start. Follows the area's collider radius each frame, so what is drawn
## is exactly what hits, at any game speed. Child of a CustomAreaEffect.

## Outer pixel of the ring and the flash.
@export var light_color : Color = Color("c1ffda")
## Inner pixel of the ring and the disc.
@export var dark_color : Color = Color("54ffc1")
@export var disc_alpha : float = 0.18
@export var flash_alpha : float = 0.45
## Share of the burst the flash lasts.
@export var flash_share : float = 0.2
## From this share of the burst on, the ring fades out.
@export var fade_start_share : float = 0.6

#alpha moves in steps like the pixel fade shader, not smoothly
const ALPHA_STEPS : float = 4.0

@onready var area_effect : CustomAreaEffect = get_parent()


func _ready() -> void:
	#over the ground, under the units' sprites drawn after it
	show_behind_parent = true


func _process(_delta : float) -> void:
	queue_redraw()


func _draw() -> void:
	if not area_effect.visible or area_effect.skill_data == null:
		return

	var max_radius : float = area_effect.skill_data.max_range
	var radius : float = roundf((area_effect.collider.shape as CircleShape2D).radius)
	if max_radius <= 0.0 or radius < 1.0:
		return

	var progress : float = clampf(radius / max_radius, 0.0, 1.0)
	var fade : float = 1.0
	if progress > fade_start_share:
		fade = 1.0 - (progress - fade_start_share) / (1.0 - fade_start_share)
	fade = _stepped(fade)

	draw_circle(Vector2.ZERO, radius, _with_alpha(dark_color, disc_alpha * fade), true, -1.0, false)

	if progress < flash_share:
		var flash : float = _stepped(1.0 - progress / flash_share)
		draw_circle(Vector2.ZERO, radius, _with_alpha(light_color, flash_alpha * flash), true, -1.0, false)

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, _point_count(radius), _with_alpha(light_color, fade), 1.0, false)
	if radius > 2.0:
		draw_arc(Vector2.ZERO, radius - 1.0, 0.0, TAU, _point_count(radius), _with_alpha(dark_color, fade), 1.0, false)


static func _stepped(value : float) -> float:
	return ceilf(clampf(value, 0.0, 1.0) * ALPHA_STEPS) / ALPHA_STEPS


static func _with_alpha(color : Color, alpha : float) -> Color:
	return Color(color, color.a * alpha)


#enough points that the ring reads as a circle at 16 px tiles, few for small radii
static func _point_count(radius : float) -> int:
	return clampi(int(radius * 1.5), 12, 96)
