extends RefCounted

## Screenshots of the world map in a window (2026-11-24, the bigger scrolling map): every level shown (or up to
## progress=N), shots at the four corners and while the newest trail draws in.
## Run it windowed (gd.py is headless), on the editor's display:
##     godot --path . --position X,Y res://tools/test/test_runner.tscn -- --run res://tools/showcase/world_map_view.gd shots=C:/out [progress=60]

const MAP_SCENE : String = "res://scenes/ui/game_world_map/game_world_map.tscn"
const SETTLE_FRAMES : int = 20
const TRAIL_SHOT_FRAMES : int = 30


func run(kit : TestKit, args : PackedStringArray) -> void:
	var shots : String = ""
	var progress_level : int = 60
	for arg in args:
		if arg.begins_with("shots="):
			shots = arg.get_slice("=", 1)
		elif arg.begins_with("progress="):
			progress_level = int(arg.get_slice("=", 1))
	var saved : ProgressData = PlayerProgress._save.progress
	var progress : ProgressData = ProgressData.new()
	progress.level_progress = progress_level
	progress.map_revealed_level = progress_level - 1
	PlayerProgress._save.progress = progress
	var map : GameWorldMap = load(MAP_SCENE).instantiate()
	kit.root.add_child(map)
	await kit.frames(TRAIL_SHOT_FRAMES)
	_shot(kit, shots, "map_newest_trail")
	await kit.frames(SETTLE_FRAMES * 3)
	_shot(kit, shots, "map_newest")
	var corners : Array[Vector2] = [Vector2(99999, 99999), Vector2(-99999, 0), Vector2(0, -99999), Vector2(99999, 0)]
	for i in corners.size():
		map.scroll_by(corners[i])
		await kit.frames(SETTLE_FRAMES)
		_shot(kit, shots, "map_corner_%d" % i)
	map.queue_free()
	await kit.frames(2)
	PlayerProgress._save.progress = saved


func _shot(kit : TestKit, folder : String, tag : String) -> void:
	if folder.is_empty():
		return
	var image : Image = kit.root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [folder, tag])
