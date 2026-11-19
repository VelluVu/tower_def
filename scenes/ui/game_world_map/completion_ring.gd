class_name CompletionRing
extends Control
## The ring round a world map level that shows how far it is done: bronze once Normal is cleared, silver at
## SILVER_POINTS of its talent points, gold at all of them. Bronze is still, silver has a glint sweeping round now
## and then, gold pulses and sparkles. Drawn in whole pixels like the bold UI frames.

enum Tier { NONE, BRONZE, SILVER, GOLD }

## Talent points (of the level's 15 over every mode) for silver.
const SILVER_POINTS : int = 10
const OUTLINE_COLOR : Color = Color("181425")
## Outer and inner ring colour per tier (Endesga 32).
const TIER_COLORS : Dictionary[Tier, Array] = {
	Tier.BRONZE: [Color("b86f50"), Color("e4a672")],
	Tier.SILVER: [Color("8b9bb4"), Color("c0cbdc")],
	Tier.GOLD: [Color("feae34"), Color("fee761")],
}
const GOLD_COLOR : Color = Color("feae34")
const GLINT_COLOR : Color = Color("ffffff")
const MARGIN : int = 3
const PULSE_TIME : float = 0.8
const PULSE_MIN_ALPHA : float = 0.45
## Silver: a glint every GLINT_INTERVAL seconds that takes GLINT_TIME to go round, GLINT_WIDTH radians wide.
const GLINT_INTERVAL : float = 2.5
const GLINT_TIME : float = 0.6
const GLINT_WIDTH : float = 0.7
## Gold: one sparkle at a time on the ring, SPARKLE_TIME long, a new one every SPARKLE_INTERVAL seconds.
const SPARKLE_INTERVAL : float = 0.7
const SPARKLE_TIME : float = 0.35
const SPARKLE_ARMS : Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NO_GLINT : float = -10.0

var tier : Tier = Tier.NONE :
	set = _set_tier
#the glint's angle while it sweeps, NO_GLINT between sweeps
var glint_angle : float = NO_GLINT :
	set = _set_glint_angle
var sparkle_cell : Vector2i = Vector2i(-1, -1)
## Pixels between the button's edge and the ring; set before the ring enters the tree.
var margin : int = MARGIN
var effect_tween : Tween = null


## The tier for a level: Normal cleared, then its talent points over every mode.
static func tier_for(is_normal_cleared : bool, points : int, max_points : int) -> Tier:
	if points >= max_points:
		return Tier.GOLD
	if points >= SILVER_POINTS:
		return Tier.SILVER
	if is_normal_cleared:
		return Tier.BRONZE
	return Tier.NONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = -margin
	offset_top = -margin
	offset_right = margin
	offset_bottom = margin
	visible = tier != Tier.NONE
	_start_effect()


func _set_tier(value : Tier) -> void:
	if tier == value:
		return

	tier = value
	visible = tier != Tier.NONE
	if is_node_ready():
		_start_effect()
	queue_redraw()


func _set_glint_angle(value : float) -> void:
	glint_angle = value
	queue_redraw()


func _start_effect() -> void:
	if effect_tween != null:
		effect_tween.kill()
		effect_tween = null
	modulate.a = 1.0
	glint_angle = NO_GLINT
	sparkle_cell = Vector2i(-1, -1)

	match tier:
		Tier.SILVER:
			effect_tween = create_tween().set_loops()
			effect_tween.tween_interval(GLINT_INTERVAL)
			effect_tween.tween_property(self, "glint_angle", TAU, GLINT_TIME).from(0.0)
			effect_tween.tween_callback(func() -> void: glint_angle = NO_GLINT)
		Tier.GOLD:
			effect_tween = create_tween().set_loops()
			effect_tween.tween_property(self, "modulate:a", PULSE_MIN_ALPHA, PULSE_TIME).set_trans(Tween.TRANS_SINE)
			effect_tween.parallel().tween_callback(_show_sparkle).set_delay(SPARKLE_INTERVAL * 0.5)
			effect_tween.tween_property(self, "modulate:a", 1.0, PULSE_TIME).set_trans(Tween.TRANS_SINE)
			effect_tween.parallel().tween_callback(_show_sparkle).set_delay(SPARKLE_INTERVAL * 0.5)


#a sparkle on a random cell of the gold band, gone after SPARKLE_TIME
func _show_sparkle() -> void:
	var ring : Array[Vector2i] = []
	for y in int(size.y):
		for x in int(size.x):
			if _band(x, y) == 1:
				ring.append(Vector2i(x, y))
	if ring.is_empty():
		return
	sparkle_cell = ring.pick_random()
	queue_redraw()
	#a tween of this node, so it goes with the ring when the map closes
	create_tween().tween_callback(func() -> void:
		sparkle_cell = Vector2i(-1, -1)
		queue_redraw()).set_delay(SPARKLE_TIME)


#0 the dark outline, 1 the colour, 2 the light inner edge; -1 off the ring
func _band(x : int, y : int) -> int:
	var centre : Vector2 = size * 0.5
	var radius : float = minf(size.x, size.y) * 0.5
	var band : int = int(radius - Vector2(x + 0.5, y + 0.5).distance_to(centre))
	return band if band >= 0 and band <= 2 else -1


#a whole-pixel ring round the round level button: dark outline, the tier's colour, its light inner edge
func _draw() -> void:
	if tier == Tier.NONE:
		return

	var colors : Array = TIER_COLORS[tier]
	var ring_colors : Array[Color] = [OUTLINE_COLOR, colors[0], colors[1]]
	var centre : Vector2 = size * 0.5

	for y in int(size.y):
		for x in int(size.x):
			var band : int = _band(x, y)
			if band < 0:
				continue
			var color : Color = ring_colors[band]
			if band > 0 and glint_angle != NO_GLINT:
				var angle : float = fposmod((Vector2(x + 0.5, y + 0.5) - centre).angle() + PI * 0.5, TAU)
				if absf(angle_difference(angle, glint_angle)) < GLINT_WIDTH * 0.5:
					color = GLINT_COLOR
			draw_rect(Rect2(x, y, 1.0, 1.0), color)

	if sparkle_cell.x >= 0:
		draw_rect(Rect2(sparkle_cell, Vector2.ONE), GLINT_COLOR)
		for arm in SPARKLE_ARMS:
			draw_rect(Rect2(sparkle_cell + arm, Vector2.ONE), TIER_COLORS[Tier.GOLD][1])
