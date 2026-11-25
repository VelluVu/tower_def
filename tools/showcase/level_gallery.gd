extends RefCounted

## An overview shot of every level in a window (2026-11-25, the user: check each level's surroundings match its
## story): loads each level, fits its playfield and a little of what lies round it into the view, waits for the build
## break's route preview (dotted enemy routes, spawn and castle markers) and saves <shots>/level_NNN.png.
## Run it windowed (gd.py is headless), on the editor's display:
##     godot --path . --position X,Y res://tools/test/test_runner.tscn -- --run res://tools/showcase/level_gallery.gd shots=C:/out [levels=1-60]

const SETTLE_FRAMES : int = 60
## Tiles of surroundings shown round the playfield.
const MARGIN_TILES : float = 1.5
const VIEW_SIZE : Vector2 = Vector2(640, 360)


func run(kit : TestKit, args : PackedStringArray) -> void:
	var shots : String = ""
	var first : int = 1
	var last : int = 60
	for arg in args:
		if arg.begins_with("shots="):
			shots = arg.get_slice("=", 1)
		elif arg.begins_with("levels="):
			var span : String = arg.get_slice("=", 1)
			first = int(span.get_slice("-", 0))
			last = int(span.get_slice("-", 1)) if span.contains("-") else first
	SettingsManager._options[SettingsManager.OPTION_PAUSE_ON_FOCUS_LOSS] = false
	for number in range(first, last + 1):
		await kit.load_level(number)
		var camera : Camera2D = Camera2D.new()
		kit.level.add_child(camera)
		camera.make_current()
		var playfield : Rect2 = kit.level.grid.get_playfield_rect().grow(Utils.TILE_SIZE * MARGIN_TILES)
		var zoom : float = minf(VIEW_SIZE.x / playfield.size.x, VIEW_SIZE.y / playfield.size.y)
		camera.zoom = Vector2.ONE * zoom
		camera.global_position = playfield.get_center()
		await kit.frames(SETTLE_FRAMES)
		if not shots.is_empty():
			kit.root.get_viewport().get_texture().get_image().save_png("%s/level_%03d.png" % [shots, number])
		camera.queue_free()
		await kit.frames(2)
