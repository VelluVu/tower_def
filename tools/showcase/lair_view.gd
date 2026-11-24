extends RefCounted

## Screenshots of a boss lair in a window (lighting, torches, the castle's camouflage and its reveal): loads the level,
## lets a few enemies walk in, saves a shot, spawns the boss and saves shots through the reveal.
## Run it windowed (gd.py is headless), on the editor's display:
##     godot --path . --position X,Y res://tools/test/test_runner.tscn -- --run res://tools/showcase/lair_view.gd level=8 boss=broodmother shots=C:/out [ambient=0.1]
## ambient= overrides the lair's ambient light (a low one shows where the lights reach).

const SETTLE_FRAMES : int = 90
const WALK_FRAMES : int = 240
const REVEAL_SHOT_FRAMES : Array[int] = [6, 18, 40, 90]
## The overview fits a 48-wide map in the 640x360 view (fractional zoom: only for looking).
const OVERVIEW_ZOOM : float = 0.8
## The castle close-up looks a little east of the castle, into the cave.
const CASTLE_VIEW_SHIFT : Vector2 = Vector2(140, 0)
const LIGHTING_NODE : String = "LairLighting"


func run(kit : TestKit, args : PackedStringArray) -> void:
	var level_number : int = 8
	var boss_name : String = "broodmother"
	var shots : String = ""
	var ambient_override : float = -1.0
	for arg in args:
		if arg.begins_with("level="):
			level_number = int(arg.get_slice("=", 1))
		elif arg.begins_with("boss="):
			boss_name = arg.get_slice("=", 1)
		elif arg.begins_with("shots="):
			shots = arg.get_slice("=", 1)
		elif arg.begins_with("ambient="):
			ambient_override = float(arg.get_slice("=", 1))
	SettingsManager._options[SettingsManager.OPTION_PAUSE_ON_FOCUS_LOSS] = false
	await kit.load_level(level_number)
	var lighting : LairLighting = kit.level.get_node_or_null(LIGHTING_NODE) as LairLighting
	if lighting != null and ambient_override >= 0.0:
		lighting.lit_material.set_shader_parameter(LairLighting.AMBIENT_PARAMETER, Color(ambient_override, ambient_override, ambient_override))
	var camera : Camera2D = Camera2D.new()
	kit.level.add_child(camera)
	camera.make_current()
	var playfield : Rect2 = kit.level.grid.get_playfield_rect()
	var castle : Vector2 = kit.level.get_spawners()[0].end_point.global_position
	await kit.frames(SETTLE_FRAMES)
	_view(camera, playfield.get_center(), OVERVIEW_ZOOM)
	await kit.frames(2)
	_shot(kit, shots, "%d_overview" % level_number)
	_view(camera, castle + CASTLE_VIEW_SHIFT, 1.0)
	await kit.frames(2)
	_shot(kit, shots, "%d_castle" % level_number)
	var walkers : Array[Enemy] = []
	for index in kit.level.get_spawners().size():
		walkers.append(kit.spawn_enemy("weakling", index))
	await kit.frames(WALK_FRAMES)
	_view(camera, playfield.get_center(), OVERVIEW_ZOOM)
	await kit.frames(2)
	_shot(kit, shots, "%d_enemies" % level_number)
	_view(camera, castle + CASTLE_VIEW_SHIFT, 1.0)
	var boss : Enemy = kit.spawn_enemy(boss_name)
	var done : int = 0
	for frame in REVEAL_SHOT_FRAMES:
		await kit.frames(frame - done)
		done = frame
		_shot(kit, shots, "%d_reveal_%d" % [level_number, frame])
	for walker in walkers:
		if is_instance_valid(walker):
			walker.die()
	if is_instance_valid(boss):
		boss.die()
	await kit.frames(2)


func _view(camera : Camera2D, at : Vector2, amount : float) -> void:
	camera.global_position = at
	camera.zoom = Vector2.ONE * amount


func _shot(kit : TestKit, folder : String, tag : String) -> void:
	if folder.is_empty():
		return
	var image : Image = kit.root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [folder, tag])
