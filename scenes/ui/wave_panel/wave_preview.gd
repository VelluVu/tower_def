class_name WavePreview
extends HFlowContainer

## The coming wave under the wave panel's button (polish, 2026-11-22): a 16x16 portrait per enemy
## kind with its count, and a badge for flyers, elites and bosses. WavePanel also puts the same as
## text in the start button's tooltip (describe).

const PORTRAIT_SIZE : int = 16
const BADGE_SIZE : int = 7
const FLYER_BADGE : Texture2D = preload("res://assets/art/ui/wave_preview/badge_flyer.png")
const ELITE_BADGE : Texture2D = preload("res://assets/art/ui/wave_preview/badge_elite.png")
const BOSS_BADGE : Texture2D = preload("res://assets/art/ui/wave_preview/badge_boss.png")
const SPRITE_NODE : StringName = &"AnimatedSprite2D"
const FLIGHT_NODE : StringName = &"FlightMovement"
const SPRITE_FRAMES_PROPERTY : StringName = &"sprite_frames"
const BOSS_PROPERTY : StringName = &"is_boss"
const COUNT_FORMAT : String = "%d"
const NEXT_TITLE : String = "Next wave:"
const LINE_FORMAT : String = "%d %s"
const FLYING_SUFFIX : String = " (flying)"
const ELITE_FORMAT : String = "%d elite %s"
const BOSS_FORMAT : String = "Boss: %s"
#Endesga 32: blood red for a boss, coin gold for elites (as the wave banner)
const BOSS_COLOR : Color = Color("e43b44")
const ELITE_COLOR : Color = Color("feae34")
const ENTRY_SEPARATION : int = 1

## A roster (the world map's level panel): every kind once, no counts, elites with their kind.
var show_counts : bool = true

## Each enemy scene keeps its kind ({name, flying, boss, portrait}) as metadata, read once and freed with
## the scene; a static cache kept the portraits past exit, and the engine reported hundreds of leaks.
const KIND_META : StringName = &"wave_preview_kind"


#the default alignment here, not in _ready, so a caller's own alignment set before adding it to the tree stays
func _init() -> void:
	alignment = FlowContainer.ALIGNMENT_CENTER


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"h_separation", 3)
	add_theme_constant_override(&"v_separation", 1)


## Shows the wave's kinds; null hides the row.
func show_wave(wave : WaveData) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	visible = wave != null
	if wave == null:
		return
	for entry in summarize(wave):
		add_child(_make_entry(entry))


## Every enemy kind the waves send, once each, in order of first appearance; flyers and bosses keep their badge.
func show_roster(waves : Array[WaveData]) -> void:
	show_counts = false
	var roster : WaveData = WaveData.new()
	var seen : Dictionary[String, bool] = {}
	for wave in waves:
		for group in wave.spawn_groups:
			if group.enemy_scene == null or seen.has(group.enemy_scene.resource_path):
				continue
			seen[group.enemy_scene.resource_path] = true
			var copy : SpawnGroupData = SpawnGroupData.new()
			copy.enemy_scene = group.enemy_scene
			copy.count = 1
			roster.spawn_groups.append(copy)
	show_wave(roster)


## One entry per enemy kind, elites of a kind apart from the plain ones, in the wave's order.
## Each: {scene, name, count, elite, flying, boss}.
static func summarize(wave : WaveData) -> Array[Dictionary]:
	var entries : Array[Dictionary] = []
	var by_key : Dictionary[String, Dictionary] = {}
	for group in wave.spawn_groups:
		if group.enemy_scene == null or group.count <= 0:
			continue
		var elites : int = clampi(group.elites, 0, group.count)
		for is_elite : bool in [false, true]:
			var count : int = elites if is_elite else group.count - elites
			if count <= 0:
				continue
			var key : String = group.enemy_scene.resource_path + (":elite" if is_elite else "")
			if not by_key.has(key):
				var kind : Dictionary = enemy_kind(group.enemy_scene)
				by_key[key] = {"scene": group.enemy_scene, "name": kind.name, "count": 0, "elite": is_elite, "flying": kind.flying, "boss": kind.boss}
				entries.append(by_key[key])
			by_key[key].count += count
	return entries


## "Next wave:" then one line per kind: "12 Soldier", "4 Giant Eagle (flying)", "2 elite Scout", "Boss: Dragonslayer".
static func describe(wave : WaveData) -> String:
	if wave == null:
		return ""
	var lines : PackedStringArray = [NEXT_TITLE]
	for entry in summarize(wave):
		if entry.boss:
			lines.append(BOSS_FORMAT % entry.name)
			continue
		var line : String = ELITE_FORMAT % [entry.count, entry.name] if entry.elite else LINE_FORMAT % [entry.count, entry.name]
		lines.append(line + (FLYING_SUFFIX if entry.flying else ""))
	return "\n".join(lines)


## Name, flyer and boss flags and a portrait, from the scene's saved state, without making the enemy.
static func enemy_kind(scene : PackedScene) -> Dictionary:
	if scene.has_meta(KIND_META):
		return scene.get_meta(KIND_META)
	var state : SceneState = scene.get_state()
	var kind : Dictionary = {"boss": false, "flying": false, "name": scene.resource_path.get_file().get_basename().capitalize(), "portrait": null}
	for node in state.get_node_count():
		var node_name : StringName = state.get_node_name(node)
		if node_name == FLIGHT_NODE:
			kind.flying = true
		for property in state.get_node_property_count(node):
			var property_name : StringName = state.get_node_property_name(node, property)
			if node == 0 and property_name == BOSS_PROPERTY:
				kind.boss = state.get_node_property_value(node, property)
			elif node_name == SPRITE_NODE and property_name == SPRITE_FRAMES_PROPERTY:
				kind.portrait = make_portrait(state.get_node_property_value(node, property))
	scene.set_meta(KIND_META, kind)
	return kind


## The first frame's top 16x16 around its drawn pixels: a big enemy shows its head, at whole pixels.
static func make_portrait(frames : SpriteFrames) -> Texture2D:
	if frames == null or frames.get_animation_names().is_empty():
		return null
	var animation : StringName = StringName(GlobalAnimationNames.IDLE_ANIMATION) if frames.has_animation(GlobalAnimationNames.IDLE_ANIMATION) else StringName(frames.get_animation_names()[0])
	if frames.get_frame_count(animation) == 0:
		return null
	var frame : Texture2D = frames.get_frame_texture(animation, 0)
	var image : Image = frame.get_image()
	if image == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	var used : Rect2i = image.get_used_rect()
	if used.size == Vector2i.ZERO:
		return null
	var crop : Rect2i = Rect2i(used.position.x + floori((used.size.x - PORTRAIT_SIZE) / 2.0), used.position.y, PORTRAIT_SIZE, PORTRAIT_SIZE)
	#a small sprite sits in the middle of the square instead
	if used.size.x <= PORTRAIT_SIZE and used.size.y <= PORTRAIT_SIZE:
		crop.position = used.position + Vector2i((Vector2(used.size - Vector2i(PORTRAIT_SIZE, PORTRAIT_SIZE)) / 2.0).floor())
	var portrait : Image = Image.create_empty(PORTRAIT_SIZE, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	var source : Rect2i = crop.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	portrait.blit_rect(image, source, source.position - crop.position)
	return ImageTexture.create_from_image(portrait)


func _make_entry(entry : Dictionary) -> Control:
	var box : HBoxContainer = HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", ENTRY_SEPARATION)

	var portrait : TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.texture = enemy_kind(entry.scene).portrait
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait)

	var badge_texture : Texture2D = BOSS_BADGE if entry.boss else ELITE_BADGE if entry.elite else FLYER_BADGE if entry.flying else null
	if badge_texture != null:
		var badge : TextureRect = TextureRect.new()
		badge.texture = badge_texture
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(PORTRAIT_SIZE - BADGE_SIZE, PORTRAIT_SIZE - BADGE_SIZE)
		portrait.add_child(badge)

	#a lone boss needs no "1"; a roster shows no counts
	if not show_counts or (entry.boss and entry.count == 1):
		return box
	var count : Label = Label.new()
	count.text = COUNT_FORMAT % entry.count
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	if entry.boss:
		count.add_theme_color_override(&"font_color", BOSS_COLOR)
	elif entry.elite:
		count.add_theme_color_override(&"font_color", ELITE_COLOR)
	box.add_child(count)
	return box
