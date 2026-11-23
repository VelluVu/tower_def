extends RefCounted

## Losing window focus in a level opens the pause menu (2026-11-23 fix: it used to pause the game with no menu,
## so the game looked frozen, because the focus notification arrives while the UI cannot take children).


func test_focus_loss_opens_the_pause_menu(kit : TestKit) -> void:
	kit.load_level(2)
	var scene_manager : SceneManager = Utils.game_control.scene_manager
	scene_manager._get_ui_packed_scenes_from_project_folder()
	var ui : UI = UI.new()
	ui.scene_manager = scene_manager
	kit.root.add_child(ui)
	UISignals.to_menu.connect(ui._menu)
	var was_on : Variant = SettingsManager.get_option(SettingsManager.OPTION_PAUSE_ON_FOCUS_LOSS)
	SettingsManager.set_option(SettingsManager.OPTION_PAUSE_ON_FOCUS_LOSS, true)
	#Main pauses the tree on this signal; the tests' stand-in Main is not in the tree, so watch the request
	var pause_requests : Array[bool] = []
	var watch : Callable = func(is_pause : bool) -> void: pause_requests.append(is_pause)
	GameSignals.game_pause.connect(watch)

	#the engine sends it down the whole tree, as when the player alt-tabs
	kit.root.get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await kit.frames(2)
	var pause_menu : Node = null
	for scene in scene_manager.loaded_ui_scenes:
		if is_instance_valid(scene) and scene.name.to_snake_case() == UI.PAUSE_MENU_NAME:
			pause_menu = scene
	kit.check(pause_menu != null and pause_menu.is_inside_tree(), "the pause menu shows")
	kit.check(pause_requests == [true], "and the game is paused under it")

	kit.root.get_tree().root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await kit.frames(2)
	var menus : int = scene_manager.loaded_ui_scenes.filter(func(scene : Node) -> bool: return is_instance_valid(scene) and scene.name.to_snake_case() == UI.PAUSE_MENU_NAME).size()
	kit.check(menus == 1, "a second focus loss opens no second menu: %d" % menus)

	GameSignals.game_pause.disconnect(watch)
	UISignals.to_menu.disconnect(ui._menu)
	SettingsManager.set_option(SettingsManager.OPTION_PAUSE_ON_FOCUS_LOSS, was_on)
	scene_manager.unload_scene_by_name(UI.PAUSE_MENU_NAME, scene_manager.SceneType.UI)
	ui.queue_free()
	kit.free_level()
	await kit.frames(1)
