class_name MapFog
extends Control

## Fog over the world map's land not reached yet (2026-11-24, the user's ask): clear round every level node on show
## and along the trails between them, so the explored land grows as one shape; elsewhere a drifting sea of cloud. The
## level being revealed clears its own patch while its trail draws in (reveal), wider when it opens a new area. Over
## the volcano's lava the fog glows red, so the journey's end shows from the start. Lies over the map picture and
## MapAmbience, under the trails and the nodes; only looks. Shader: assets/shaders/map_fog.gdshader.

const SHADER : Shader = preload("res://assets/shaders/map_fog.gdshader")
## Map units per density texel (the map is 1200x672 units: 150x84 texels).
const CELL : float = 8.0
## Map units: the clearing round a node, round a node that opens a new area, and along a trail (one spot every
## TRAIL_STEP units); the fog thickens over EDGE units past a clearing.
const NODE_RADIUS : float = 56.0
const NEW_AREA_RADIUS : float = 110.0
const TRAIL_RADIUS : float = 34.0
const TRAIL_STEP : float = 24.0
const EDGE : float = 48.0
## How much the fog over lava takes the glow's colours (0..1; the texture's green channel, spread a texel round).
const LAVA_GLOW : float = 0.4
const LAVA_COLORS : Array[Color] = [Color("e43b44"), Color("f77622"), Color("feae34")]
const COLOR_TOLERANCE : float = 0.03
## How long the newest level's clearing takes to open (with its trail, MapTrails.REVEAL_SECONDS).
const REVEAL_SECONDS : float = 1.4
const MAX_REVEAL_SPOTS : int = 32
const LEVELS_PER_AREA : int = 12

var trails : MapTrails = null
var density : Image = null
var density_texture : ImageTexture = null
var shader_material : ShaderMaterial = null
#the level opening right now; its clearings stay out of the density texture until it has opened
var revealing_level : int = 0
var reveal_spots : Array[Vector4] = []
var reveal_progress : float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_material = ShaderMaterial.new()
	shader_material.shader = SHADER
	material = shader_material


## Paints the fog for the levels on show; `opening` (if any) is left fogged for reveal to open.
func setup(map_trails : MapTrails, opening : int = 0) -> void:
	trails = map_trails
	revealing_level = opening
	var map_size : Vector2 = _map_size()
	size = map_size
	shader_material.set_shader_parameter(&"map_size", map_size)
	_paint(map_size)
	reveal_spots = _spots_of(opening) if opening > 0 else ([] as Array[Vector4])
	_set_reveal_progress(0.0 if opening > 0 else 1.0)
	queue_redraw()


## Opens the clearing of the level set up as opening, along its trail and then round its node.
func reveal() -> void:
	if revealing_level <= 0:
		return
	var tween : Tween = create_tween()
	tween.tween_method(_set_reveal_progress, 0.0, 1.0, REVEAL_SECONDS)


## How thick the fog is at `at` (map units), 0 clear to 1 deep, the opening clearing included; without the drift.
func density_at(at : Vector2) -> float:
	if density == null:
		return 0.0
	var texel : Vector2i = Vector2i((at / CELL).floor()).clamp(Vector2i.ZERO, density.get_size() - Vector2i.ONE)
	var value : float = density.get_pixelv(texel).r
	for spot in reveal_spots:
		var opened : float = smoothstep(spot.w, minf(1.0, spot.w + 0.35), reveal_progress)
		value = minf(value, clampf((at.distance_to(Vector2(spot.x, spot.y)) - spot.z * opened) / EDGE, 0.0, 1.0) + 1.0 - opened)
	return value


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


func _map_size() -> Vector2:
	var picture : TextureRect = get_parent() as TextureRect
	if picture != null and picture.texture != null:
		#the picture is shown at 2 units per art pixel
		return picture.texture.get_size() * 2.0
	return get_parent_area_size()


func _set_reveal_progress(value : float) -> void:
	reveal_progress = value
	shader_material.set_shader_parameter(&"reveal_progress", value)


#the levels on show (cleared and the next), but the one opening now
func _shown_levels() -> Array[int]:
	var levels : Array[int] = []
	if trails == null:
		return levels
	for level in trails.elements:
		if trails.elements[level].visible and level != revealing_level:
			levels.append(level)
	return levels


#clearings as x, y, radius and when it starts opening (0..1 of the reveal): along the trail, then the node
func _spots_of(level : int) -> Array[Vector4]:
	var spots : Array[Vector4] = []
	if trails == null or not trails.elements.has(level):
		return spots
	var path : PackedVector2Array = trails.trail_points(level)
	var points : Array[Vector2] = _along(path)
	for i in points.size():
		spots.append(Vector4(points[i].x, points[i].y, TRAIL_RADIUS, 0.6 * i / maxf(1.0, points.size())))
	var element : MapLevelElement = trails.elements[level]
	var radius : float = NEW_AREA_RADIUS if level > 1 and (level - 1) % LEVELS_PER_AREA == 0 else NODE_RADIUS
	var centre : Vector2 = element.position + element.size * 0.5
	spots.append(Vector4(centre.x, centre.y, radius, 0.55))
	return spots.slice(maxi(0, spots.size() - MAX_REVEAL_SPOTS))


#points every TRAIL_STEP units along a path
func _along(path : PackedVector2Array) -> Array[Vector2]:
	var points : Array[Vector2] = []
	if path.size() < 2:
		return points
	var travelled : float = 0.0
	var next_point : float = 0.0
	for i in range(1, path.size()):
		var segment : float = path[i - 1].distance_to(path[i])
		while next_point <= travelled + segment:
			points.append(path[i - 1].lerp(path[i], (next_point - travelled) / maxf(segment, 0.001)))
			next_point += TRAIL_STEP
		travelled += segment
	return points


func _paint(map_size : Vector2) -> void:
	var texels : Vector2i = Vector2i((map_size / CELL).ceil())
	#red: how thick the fog is; green: how much lava glows under it
	density = Image.create(texels.x, texels.y, false, Image.FORMAT_RG8)
	density.fill(Color(1.0, 0.0, 0.0))
	var stamps : Array[Vector3] = []
	for level in _shown_levels():
		var element : MapLevelElement = trails.elements[level]
		var radius : float = NEW_AREA_RADIUS if level > 1 and (level - 1) % LEVELS_PER_AREA == 0 else NODE_RADIUS
		var centre : Vector2 = element.position + element.size * 0.5
		stamps.append(Vector3(centre.x, centre.y, radius))
		var previous : MapLevelElement = trails.elements.get(level - 1)
		if previous != null and previous.visible:
			for point in _along(trails.trail_points(level)):
				stamps.append(Vector3(point.x, point.y, TRAIL_RADIUS))
	for stamp in stamps:
		_stamp(Vector2(stamp.x, stamp.y), stamp.z, texels)
	_let_lava_through(texels)
	if density_texture == null:
		density_texture = ImageTexture.create_from_image(density)
	else:
		density_texture.set_image(density)
	shader_material.set_shader_parameter(&"density_texture", density_texture)
	shader_material.set_shader_parameter(&"reveal_edge", EDGE)
	var spots : Array[Vector4] = _spots_of(revealing_level) if revealing_level > 0 else ([] as Array[Vector4])
	shader_material.set_shader_parameter(&"reveal_spots", spots)
	shader_material.set_shader_parameter(&"reveal_count", spots.size())


#clears round one spot: each texel keeps the thinner of its fog and this clearing's
func _stamp(at : Vector2, radius : float, texels : Vector2i) -> void:
	var reach : float = radius + EDGE
	var low : Vector2i = Vector2i(((at - Vector2.ONE * reach) / CELL).floor()).max(Vector2i.ZERO)
	var high : Vector2i = Vector2i(((at + Vector2.ONE * reach) / CELL).ceil()).min(texels - Vector2i.ONE)
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var texel_centre : Vector2 = (Vector2(x, y) + Vector2.ONE * 0.5) * CELL
			var value : float = clampf((texel_centre.distance_to(at) - radius) / EDGE, 0.0, 1.0)
			var old : Color = density.get_pixel(x, y)
			if value < old.r:
				density.set_pixel(x, y, Color(value, old.g, 0.0))


#over lava the fog glows, so the volcano shows from the start; spread a texel round so the glow has soft edges
func _let_lava_through(texels : Vector2i) -> void:
	var picture : TextureRect = get_parent() as TextureRect
	if picture == null or picture.texture == null:
		return
	var image : Image = picture.texture.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	var to_image : Vector2 = Vector2(image.get_size()) / (Vector2(texels) * CELL)
	var lava_texels : Array[Vector2i] = []
	for y in texels.y:
		for x in texels.x:
			var here : Color = image.get_pixelv(Vector2i(((Vector2(x, y) + Vector2.ONE * 0.5) * CELL * to_image).floor()).min(image.get_size() - Vector2i.ONE))
			for lava in LAVA_COLORS:
				if absf(here.r - lava.r) + absf(here.g - lava.g) + absf(here.b - lava.b) <= COLOR_TOLERANCE:
					lava_texels.append(Vector2i(x, y))
					break
	for texel in lava_texels:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var at : Vector2i = texel + Vector2i(dx, dy)
				if at.x < 0 or at.y < 0 or at.x >= texels.x or at.y >= texels.y:
					continue
				var glow : float = LAVA_GLOW if dx == 0 and dy == 0 else LAVA_GLOW * 0.5
				var old : Color = density.get_pixelv(at)
				if glow > old.g:
					density.set_pixelv(at, Color(old.r, glow, 0.0))
