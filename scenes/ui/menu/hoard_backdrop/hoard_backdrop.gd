class_name HoardBackdrop
extends CanvasLayer


## The title screen's backdrop (2026-11-23): Puffe's castle courtyard at dusk with the treasure pile. The
## eggs on top hatch one after another, the hatchlings wander the courtyard, and when all have hatched they
## fly off one by one and the eggs come back. Art from tools/art/hoard_backdrop.py at 320x180, drawn at 2x;
## the spots below are that script's EGG_SPOTS, TORCH_SPOTS and FLAG_SPOTS, keep them in step.
enum Phase { HATCHING, LINGERING, LEAVING, RENEWING }

const BACKGROUND : Texture2D = preload("res://assets/art/ui/title/hoard/hoard_hall.png")
const FRAMES_PATH : String = "res://scenes/ui/menu/hoard_backdrop/frames/%s_frames.tres"
const EGG_FRAMES : String = "hoard_egg_%s"
const HATCHLING_FRAMES : String = "hatchling_%s"
const TORCH_FRAMES : String = "hoard_torch"
const FLAG_FRAMES : String = "hoard_flag"
const SPARKLE_FRAMES : String = "hoard_sparkle"
const ART_SIZE : Vector2 = Vector2(320, 180)
## Whole steps, so every art pixel stays square: 320x180 fills the 640x360 screen.
const ART_SCALE : int = 2
## Its own layer under the UI's.
const BACKDROP_LAYER : int = -1

## Egg bottoms on the pile, back to front, and the colour of each.
const EGG_SPOTS : Array[Vector2] = [Vector2(206, 100), Vector2(184, 107), Vector2(228, 107), Vector2(165, 120), Vector2(247, 120)]
const EGG_ELEMENTS : Array[String] = ["mint", "fire", "frost", "poison", "mint"]
## Flame bottoms on the wall sconces, and flag pole tops (the flag's left edge is the pole).
const TORCH_SPOTS : Array[Vector2] = [Vector2(146, 72), Vector2(266, 72)]
const TORCH_SIZE : Vector2 = Vector2(7, 11)
const FLAG_SPOTS : Array[Vector2] = [Vector2(118, 2), Vector2(296, 2), Vector2(30, 16)]

const FIRST_HATCH_DELAY : float = 3.0
## Between one egg starting to hatch and the next.
const HATCH_GAP : float = 21.0
## How long the whole brood wanders before they start flying off.
const LINGER_TIME : float = 22.0
const FLY_OFF_GAP : float = 1.6
const RENEW_DELAY : float = 2.5
## A hatchling leaves its egg a little above the egg's foot and lands this far either way of it.
const HATCH_RISE : float = 12.0
const LANDING_SPREAD : float = 34.0
const LANDING_Y_MIN : float = 164.0
const LANDING_Y_MAX : float = 175.0

## Where the hatchlings may walk, in art pixels: the menu covers the left, the pile the middle, the chest
## stands behind its left foot.
const WALK_AREA : Rect2 = Rect2(128, 150, 186, 26)
const PILE_FOOT : Vector2 = Vector2(206, 150)
const PILE_KEEP_OFF : Vector2 = Vector2(84, 17)
const TARGET_TRIES : int = 12
const PATH_SAMPLES : int = 10

const GLINT_INTERVAL : float = 0.28
const SPARKLE_MIDDLE : Vector2 = Vector2(2, 2)
## The pile's bright coins, where glints can show.
const GLINT_AREA : Rect2i = Rect2i(126, 80, 180, 96)
const GLINT_COLOURS : Array[Color] = [Color("fee761"), Color("ffffff")]

var phase : Phase = Phase.HATCHING
var stage : Node2D = null
## Eggs and hatchlings, drawn by their feet so the nearer one is in front.
var units : Node2D = null
var glints : Node2D = null
var eggs : Array[HoardEgg] = []
var hatchlings : Array[HoardHatchling] = []

var _timer : float = FIRST_HATCH_DELAY
var _glint_timer : float = 0.0
var _hatch_order : Array[int] = []
var _next_egg : int = 0
var _glint_points : PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	layer = BACKDROP_LAYER
	stage = Node2D.new()
	stage.scale = Vector2.ONE * ART_SCALE
	add_child(stage)
	_place_stage()

	var background : Sprite2D = Sprite2D.new()
	background.texture = BACKGROUND
	background.centered = false
	stage.add_child(background)

	for spot in TORCH_SPOTS:
		_add_prop(TORCH_FRAMES, spot - Vector2(floorf(TORCH_SIZE.x / 2.0), TORCH_SIZE.y))
	for spot in FLAG_SPOTS:
		_add_prop(FLAG_FRAMES, spot)

	glints = Node2D.new()
	stage.add_child(glints)
	units = Node2D.new()
	units.y_sort_enabled = true
	stage.add_child(units)

	for i in EGG_SPOTS.size():
		var egg : HoardEgg = HoardEgg.new()
		egg.setup(_frames(EGG_FRAMES % EGG_ELEMENTS[i]), EGG_ELEMENTS[i])
		egg.position = EGG_SPOTS[i]
		egg.hatched.connect(_on_egg_hatched)
		units.add_child(egg)
		eggs.append(egg)
	_find_glint_points()
	_start_brood()


func _process(delta : float) -> void:
	_place_stage()
	_update_glints(delta)
	_timer -= delta
	if _timer > 0.0:
		return
	match phase:
		Phase.HATCHING:
			if _next_egg < _hatch_order.size():
				eggs[_hatch_order[_next_egg]].start_hatching()
				_next_egg += 1
				_timer = HATCH_GAP
		Phase.LINGERING:
			phase = Phase.LEAVING
		Phase.LEAVING:
			for hatchling in hatchlings:
				if hatchling.state != HoardHatchling.State.FLY:
					hatchling.fly_off()
					_timer = FLY_OFF_GAP
					return
		Phase.RENEWING:
			for egg in eggs:
				egg.renew()
				_add_glint(egg.position + Vector2(0.0, -HoardEgg.FOOT.y * 0.5))
			_start_brood()


## A random place to walk to from `from`, on open floor and with the pile not in the way.
func pick_walk_target(from : Vector2) -> Vector2:
	for i in TARGET_TRIES:
		var candidate : Vector2 = Vector2(randf_range(WALK_AREA.position.x, WALK_AREA.end.x),
			randf_range(WALK_AREA.position.y, WALK_AREA.end.y))
		if _is_open_path(from, candidate):
			return candidate
	return from


static func is_walkable(spot : Vector2) -> bool:
	if not WALK_AREA.has_point(spot):
		return false
	var from_pile : Vector2 = (spot - PILE_FOOT) / PILE_KEEP_OFF
	#inside the pile's foot, or behind it where the pile would cover the hatchling
	if from_pile.length() < 1.0:
		return false
	return not (spot.y < PILE_FOOT.y and absf(spot.x - PILE_FOOT.x) < PILE_KEEP_OFF.x)


func _is_open_path(from : Vector2, to : Vector2) -> bool:
	for i in PATH_SAMPLES + 1:
		if not is_walkable(from.lerp(to, float(i) / PATH_SAMPLES)):
			return false
	return true


func _start_brood() -> void:
	phase = Phase.HATCHING
	_timer = FIRST_HATCH_DELAY
	_next_egg = 0
	_hatch_order.clear()
	for i in eggs.size():
		_hatch_order.append(i)
	_hatch_order.shuffle()


func _on_egg_hatched(egg : HoardEgg) -> void:
	var hatchling : HoardHatchling = HoardHatchling.new()
	hatchling.setup(_frames(HATCHLING_FRAMES % egg.element), egg.position + Vector2(0.0, -HATCH_RISE), pick_walk_target)
	hatchling.flown_off.connect(_on_hatchling_flown_off)
	units.add_child(hatchling)
	hatchlings.append(hatchling)
	var landing : Vector2 = Vector2(
		clampf(egg.position.x + randf_range(-LANDING_SPREAD, LANDING_SPREAD), WALK_AREA.position.x, WALK_AREA.end.x),
		randf_range(LANDING_Y_MIN, LANDING_Y_MAX))
	hatchling.hop_to(landing)
	if eggs.all(func(each : HoardEgg) -> bool: return each.is_hatched):
		phase = Phase.LINGERING
		_timer = LINGER_TIME


func _on_hatchling_flown_off(hatchling : HoardHatchling) -> void:
	hatchlings.erase(hatchling)
	if hatchlings.is_empty() and phase == Phase.LEAVING:
		phase = Phase.RENEWING
		_timer = RENEW_DELAY


func _add_prop(frames_name : String, top_left : Vector2) -> void:
	var prop : AnimatedSprite2D = AnimatedSprite2D.new()
	prop.sprite_frames = _frames(frames_name)
	prop.centered = false
	prop.position = top_left
	stage.add_child(prop)
	prop.play(GlobalAnimationNames.IDLE_ANIMATION)
	#not all in step
	prop.frame = randi() % prop.sprite_frames.get_frame_count(GlobalAnimationNames.IDLE_ANIMATION)


func _update_glints(delta : float) -> void:
	if _glint_points.is_empty():
		return
	_glint_timer -= delta
	if _glint_timer > 0.0:
		return
	_glint_timer = GLINT_INTERVAL
	_add_glint(_glint_points[randi() % _glint_points.size()])


func _add_glint(spot : Vector2) -> void:
	var glint : AnimatedSprite2D = AnimatedSprite2D.new()
	glint.sprite_frames = _frames(SPARKLE_FRAMES)
	#its middle pixel on the spot (centred, a 5x5 frame would sit half a pixel off)
	glint.centered = false
	glint.offset = -SPARKLE_MIDDLE
	glint.position = spot.round()
	glints.add_child(glint)
	glint.play(GlobalAnimationNames.IDLE_ANIMATION)
	glint.animation_looped.connect(glint.queue_free)


## The brightest coins of the background, read once from its image (none in a headless run, no glints then).
func _find_glint_points() -> void:
	var image : Image = BACKGROUND.get_image()
	if image == null or image.is_empty():
		return
	for y in range(GLINT_AREA.position.y, GLINT_AREA.end.y):
		for x in range(GLINT_AREA.position.x, GLINT_AREA.end.x):
			var colour : Color = image.get_pixel(x, y)
			for bright in GLINT_COLOURS:
				if colour.is_equal_approx(bright):
					_glint_points.append(Vector2(x, y))


func _frames(frames_name : String) -> SpriteFrames:
	return load(FRAMES_PATH % frames_name) as SpriteFrames


## Centred on the screen in whole pixels (the screen is the art's size at ART_SCALE).
func _place_stage() -> void:
	var screen : Vector2 = get_viewport().get_visible_rect().size
	stage.position = ((screen - ART_SIZE * ART_SCALE) / 2.0).round()
