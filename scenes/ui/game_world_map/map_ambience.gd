class_name MapAmbience
extends Control

## The world map's living touches (2026-11-24, the user's ask): clouds drifting east with their shadows on the land,
## mist creeping through the swamp, smoke rising off the lava, a flock of birds now and then, and twinkles on the
## sea. Lies over the map picture, under the trails and the level nodes; finds its spots from the picture itself
## (water, swamp ground near the swamp's levels, lava), so it follows the art when the map is repainted. Only looks.

const SHEET : Texture2D = preload("res://assets/art/ui/world_map_ambience.png")
## Map units per art pixel (the map picture is drawn at 2x).
const PIXEL : float = 2.0
const CLOUD_REGIONS : Array[Rect2] = [Rect2(0, 0, 48, 20), Rect2(48, 0, 40, 16), Rect2(88, 0, 64, 24)]
const MIST_REGION : Rect2 = Rect2(0, 24, 64, 12)
const SMOKE_FIRST : Rect2 = Rect2(64, 24, 8, 8)
const SMOKE_FRAMES : int = 4
const BIRD_FIRST : Rect2 = Rect2(96, 24, 5, 4)
const BIRD_FRAME_STEP : float = 6.0
const SPARKLE_FIRST : Rect2 = Rect2(108, 24, 3, 3)
const SPARKLE_FRAME_STEP : float = 4.0
const WATER_COLOR : Color = Color("0099db")
const SWAMP_COLOR : Color = Color("265c42")
const LAVA_COLOR : Color = Color("e43b44")
const COLOR_TOLERANCE : float = 0.03
## Which levels' nodes the mist gathers round (the swamp, 13-24).
const SWAMP_LEVELS : Vector2i = Vector2i(13, 24)
const SEED : int = 2411

## Few and see-through: solid white clouds crawling over the art looked pasted on (the user: "hurts the eye").
const CLOUD_COUNT : int = 5
const CLOUD_SPEED : Vector2 = Vector2(5.0, 9.0)
const CLOUD_ALPHA : float = 0.55
const CLOUD_SHADOW_OFFSET : Vector2 = Vector2(14.0, 34.0)
const CLOUD_SHADOW_COLOR : Color = Color(0.09, 0.08, 0.15, 0.1)
const MIST_COUNT : int = 7
const MIST_ALPHA : float = 0.42
const MIST_SWAY : float = 18.0
const MIST_SWAY_SPEED : float = 0.12
const VENT_COUNT : int = 9
const SMOKE_RISE : float = 36.0
const SMOKE_SECONDS : float = 2.4
const SMOKE_PER_VENT : int = 4
const SPARKLE_COUNT : int = 36
const SPARKLE_SECONDS : float = 0.45
const SPARKLE_REST : Vector2 = Vector2(1.5, 5.0)
const FLOCK_EVERY : Vector2 = Vector2(9.0, 18.0)
const FLOCK_SPEED : float = 34.0
const FLOCK_SIZE : Vector2i = Vector2i(3, 5)
const WING_SECONDS : float = 0.18
const SAMPLE_TRIES : int = 4000

class Cloud:
	var at : Vector2
	var kind : int
	var speed : float


class Mist:
	var at : Vector2
	var phase : float


class Sparkle:
	var at : Vector2
	var wait : float
	#-1 while it rests
	var age : float = -1.0


var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var clouds : Array[Cloud] = []
var mists : Array[Mist] = []
var vents : Array[Vector2] = []
var sparkles : Array[Sparkle] = []
var flock : Array[Vector2] = []
var flock_velocity : Vector2 = Vector2.ZERO
var flock_wait : float = 0.0
var time : float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	#the map has its size once laid out
	_setup.call_deferred()


func _setup() -> void:
	rng.seed = SEED
	var picture : TextureRect = get_parent() as TextureRect
	var image : Image = picture.texture.get_image() if picture != null and picture.texture != null else null
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	var swamp_nodes : Array[Vector2] = _swamp_node_centres()
	var water : Array[Vector2] = _sample(image, WATER_COLOR, SPARKLE_COUNT)
	for spot in water:
		var sparkle : Sparkle = Sparkle.new()
		sparkle.at = spot
		sparkle.wait = rng.randf_range(0.0, SPARKLE_REST.y)
		sparkles.append(sparkle)
	vents = _sample(image, LAVA_COLOR, VENT_COUNT)
	for spot in _sample(image, SWAMP_COLOR, MIST_COUNT * 6):
		if mists.size() >= MIST_COUNT:
			break
		if swamp_nodes.any(func(centre : Vector2) -> bool: return centre.distance_to(spot) < size.x * 0.12):
			var mist : Mist = Mist.new()
			mist.at = spot
			mist.phase = rng.randf() * TAU
			mists.append(mist)
	for i in CLOUD_COUNT:
		var cloud : Cloud = Cloud.new()
		cloud.at = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		cloud.kind = i % CLOUD_REGIONS.size()
		cloud.speed = rng.randf_range(CLOUD_SPEED.x, CLOUD_SPEED.y)
		clouds.append(cloud)
	flock_wait = rng.randf_range(2.0, FLOCK_EVERY.x)


func _swamp_node_centres() -> Array[Vector2]:
	var centres : Array[Vector2] = []
	for child in get_parent().get_children():
		var element : MapLevelElement = child as MapLevelElement
		if element != null and element.level_number >= SWAMP_LEVELS.x and element.level_number <= SWAMP_LEVELS.y:
			centres.append(element.position + element.size * 0.5)
	return centres


## Up to `count` spots of the map picture with `colour`, in map units, spread out.
func _sample(image : Image, colour : Color, count : int) -> Array[Vector2]:
	var found : Array[Vector2] = []
	var scale_to_map : Vector2 = size / Vector2(image.get_size())
	for i in SAMPLE_TRIES:
		if found.size() >= count:
			break
		var pixel : Vector2i = Vector2i(rng.randi_range(0, image.get_width() - 1), rng.randi_range(0, image.get_height() - 1))
		var here : Color = image.get_pixelv(pixel)
		if absf(here.r - colour.r) + absf(here.g - colour.g) + absf(here.b - colour.b) > COLOR_TOLERANCE:
			continue
		var at : Vector2 = Vector2(pixel) * scale_to_map
		if found.any(func(other : Vector2) -> bool: return other.distance_to(at) < PIXEL * 12.0):
			continue
		found.append(at)
	return found


func _process(delta : float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	for cloud in clouds:
		cloud.at.x += cloud.speed * delta
		var width : float = CLOUD_REGIONS[cloud.kind].size.x * PIXEL
		if cloud.at.x > size.x + CLOUD_SHADOW_OFFSET.x:
			cloud.at = Vector2(-width - CLOUD_SHADOW_OFFSET.x, rng.randf() * size.y)
	for sparkle in sparkles:
		if sparkle.age < 0.0:
			sparkle.wait -= delta
			if sparkle.wait <= 0.0:
				sparkle.age = 0.0
		else:
			sparkle.age += delta
			if sparkle.age >= SPARKLE_SECONDS:
				sparkle.age = -1.0
				sparkle.wait = rng.randf_range(SPARKLE_REST.x, SPARKLE_REST.y)
	_update_flock(delta)
	queue_redraw()


func _update_flock(delta : float) -> void:
	if flock.is_empty():
		flock_wait -= delta
		if flock_wait > 0.0:
			return
		#a few birds in a loose V, crossing from one side to the other
		var from_left : bool = rng.randf() < 0.5
		var start : Vector2 = Vector2(-20.0 if from_left else size.x + 20.0, rng.randf_range(size.y * 0.1, size.y * 0.8))
		flock_velocity = Vector2(1.0 if from_left else -1.0, rng.randf_range(-0.25, 0.25)).normalized() * FLOCK_SPEED
		for i in rng.randi_range(FLOCK_SIZE.x, FLOCK_SIZE.y):
			var row : int = floori((i + 1) / 2.0)
			var side : float = -1.0 if i % 2 else 1.0
			flock.append(start - flock_velocity.normalized() * row * 10.0 + flock_velocity.orthogonal().normalized() * row * 8.0 * side)
		return
	var gone : bool = true
	for i in flock.size():
		flock[i] += flock_velocity * delta
		if Rect2(Vector2(-40, -40), size + Vector2(80, 80)).has_point(flock[i]):
			gone = false
	if gone:
		flock.clear()
		flock_wait = rng.randf_range(FLOCK_EVERY.x, FLOCK_EVERY.y)


func _draw() -> void:
	for sparkle in sparkles:
		if sparkle.age >= 0.0:
			var frame : int = mini(2, int(sparkle.age / SPARKLE_SECONDS * 3.0))
			_draw_piece(_frame(SPARKLE_FIRST, SPARKLE_FRAME_STEP, frame), sparkle.at)
	for mist in mists:
		var sway : float = sin(time * MIST_SWAY_SPEED + mist.phase) * MIST_SWAY
		_draw_piece(MIST_REGION, mist.at + Vector2(sway, 0.0) - MIST_REGION.size * PIXEL * 0.5, Color(1, 1, 1, MIST_ALPHA))
	for vent in vents:
		for k in SMOKE_PER_VENT:
			var t : float = fmod(time / SMOKE_SECONDS + float(k) / SMOKE_PER_VENT + vent.x * 0.01, 1.0)
			var frame : int = mini(SMOKE_FRAMES - 1, int(t * SMOKE_FRAMES))
			var drift : Vector2 = Vector2(sin(t * PI + vent.y) * 4.0, -t * SMOKE_RISE)
			_draw_piece(_frame(SMOKE_FIRST, SMOKE_FIRST.size.x, frame), vent + drift, Color(1, 1, 1, 1.0 - t * 0.6))
	for cloud in clouds:
		_draw_piece(CLOUD_REGIONS[cloud.kind], cloud.at + CLOUD_SHADOW_OFFSET, CLOUD_SHADOW_COLOR)
	for bird in flock:
		#posmod: a flock coming in from the left starts at negative x
		var wing : int = posmod(int(time / WING_SECONDS + bird.x * 0.1), 2)
		_draw_piece(_frame(BIRD_FIRST, BIRD_FRAME_STEP, wing), bird)
	for cloud in clouds:
		_draw_piece(CLOUD_REGIONS[cloud.kind], cloud.at, Color(1, 1, 1, CLOUD_ALPHA))


func _frame(first : Rect2, step : float, index : int) -> Rect2:
	return Rect2(first.position + Vector2(step * index, 0.0), first.size)


#on whole art pixels, so the pieces sit on the map's grid
func _draw_piece(region : Rect2, at : Vector2, modulate_color : Color = Color.WHITE) -> void:
	var snapped_at : Vector2 = (at / PIXEL).floor() * PIXEL
	draw_texture_rect_region(SHEET, Rect2(snapped_at, region.size * PIXEL), region, modulate_color)
