extends RefCounted

## The whole world map in one picture (2026-11-25): every level shown, the four corners shot and stitched into
## <shots>/map_full.png (1200x672 map units, one pixel per unit), menu buttons hidden.
## Run it windowed (gd.py is headless), on the editor's display:
##     godot --path . --position X,Y res://tools/test/test_runner.tscn -- --run res://tools/showcase/world_map_full.gd shots=C:/out

const SETTLE_FRAMES : int = 120
const SHOT_FRAMES : int = 10


func run(kit : TestKit, args : PackedStringArray) -> void:
	var shots : String = ""
	for arg in args:
		if arg.begins_with("shots="):
			shots = arg.get_slice("=", 1)
	var saved : ProgressData = PlayerProgress._save.progress
	var progress : ProgressData = ProgressData.new()
	progress.level_progress = 61
	progress.map_revealed_level = 60
	PlayerProgress._save.progress = progress
	var map : GameWorldMap = load("res://scenes/ui/game_world_map/game_world_map.tscn").instantiate()
	kit.root.add_child(map)
	await kit.frames(SETTLE_FRAMES)
	map.to_menu_button.hide()
	map.talents_button.hide()
	var view : Vector2 = map.map_view.size
	var size : Vector2 = map.map.size
	var full : Image = Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at : Vector2 = corner * (view - size)
		map.map.position = at
		await kit.frames(SHOT_FRAMES)
		var shot : Image = kit.root.get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(int(view.x), int(view.y), Image.INTERPOLATE_NEAREST)
		full.blit_rect(shot, Rect2i(Vector2i.ZERO, Vector2i(view)), Vector2i(-at))
	if not shots.is_empty():
		full.save_png("%s/map_full.png" % shots)
	map.queue_free()
	await kit.frames(2)
	PlayerProgress._save.progress = saved
