extends RefCounted

## A watched playtest: the soak bot plays a level (same arguments as tools/reports/soak_level.gd) in a window, and the
## game's view is saved every shot_every seconds of game time to shots=<folder> (absolute), named <level>_<n>.png.
## Run it windowed (not through gd.py, which is headless):
##     godot --path . --position X,Y --fixed-fps 60 res://tools/test/test_runner.tscn -- --run res://tools/showcase/scorched_playtest.gd level=48 shots=C:/out

const FRAMES_PER_SHOT : int = 60 * 20

var shots_folder : String = ""
var level_name : String = ""
var is_done : bool = false


func run(kit : TestKit, args : PackedStringArray) -> void:
	var soak_args : PackedStringArray = []
	for arg in args:
		if arg.begins_with("shots="):
			shots_folder = arg.get_slice("=", 1)
		else:
			soak_args.append(arg)
			if arg.begins_with("level="):
				level_name = arg.get_slice("=", 1)
	#the window starts without focus: no pause menu on focus loss (in memory only, the player's settings file is not written)
	SettingsManager._options[SettingsManager.OPTION_PAUSE_ON_FOCUS_LOSS] = false
	if not shots_folder.is_empty():
		_shoot(kit)
	await load("res://tools/reports/soak_level.gd").new().run(kit, soak_args)
	is_done = true
	_save(kit, "end")


func _shoot(kit : TestKit) -> void:
	var count : int = 0
	while not is_done:
		for i in FRAMES_PER_SHOT:
			await kit.root.get_tree().process_frame
			if is_done:
				return
			#the bot starts the level by signal and never closes the start menu; it hides the view, not the game
			var menu : Control = kit.root.find_child("Menu", true, false) as Control
			if menu != null and menu.visible and not kit.root.get_tree().paused:
				menu.hide()
			_shoot_events(kit)
		count += 1
		_save(kit, str(count))


#one shot of each Scorched Lands moment: a sandstorm halfway over the map, a fissure warning, lava that cooled
func _shoot_events(kit : TestKit) -> void:
	var main : Main = Utils.game_control as Main
	if main == null or not is_instance_valid(main.scene_manager.current_level):
		return
	var level : Level = main.scene_manager.current_level as Level
	if level == null:
		return
	var storm : Sandstorm = level.get_node_or_null(Level.SANDSTORM_NAME) as Sandstorm
	if storm != null and storm.is_blowing and absf(storm.get_band().get_center().x - storm.playfield.get_center().x) < 16.0:
		_save_once(kit, "storm")
	for child in level.get_children():
		if child is Fissure and child.is_warning:
			_save_once(kit, "fissure_warning")
	var lava_field : LavaField = level.get_node_or_null(Level.LAVA_FIELD_NAME) as LavaField
	if lava_field != null and not lava_field.cell_cooled.is_connected(_on_cooled):
		lava_field.cell_cooled.connect(_on_cooled.bind(kit))


var saved : Dictionary[String, bool] = {}


func _save_once(kit : TestKit, tag : String) -> void:
	if not saved.has(tag):
		saved[tag] = true
		_save(kit, tag)


func _on_cooled(_cell : Vector2i, kit : TestKit) -> void:
	_save_once(kit, "cooled")


func _save(kit : TestKit, tag : String) -> void:
	if shots_folder.is_empty():
		return
	var image : Image = kit.root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%s.png" % [shots_folder, level_name, tag])
	print("SHOT ", tag)
