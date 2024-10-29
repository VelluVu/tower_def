class_name UI
extends CanvasLayer


const GAME_WORLD_MAP_SCENE_NAME : String = "game_world_map"
const PAUSE_MENU_OPEN_INPUT_NAME : String = "Escape"
const MAIN_MENU_NAME : String = "menu"
const OPTIONS_NAME : String = "options"
const PAUSE_MENU_NAME : String = "pause_menu"
const RESOURCE_DISPLAY_NAME : String = "resource_display"
const BOTTOM_PANEL_NAME : String = "bottom_panel"
const LOSE_GAME_MENU_NAME : String = "lose_game_menu"
const LEVEL_COMPLETED_MENU_NAME : String = "level_completed_menu"
const SPEED_CONTROL_PANEL_NAME : String = "speed_control_panel"

var scene_manager : SceneManager


func initialize(_scene_manager : SceneManager):
	scene_manager = _scene_manager
	scene_manager.load_scene_by_name(MAIN_MENU_NAME, scene_manager.SceneType.UI, self)
	UISignals.options.connect(_options)
	UISignals.to_menu.connect(_menu)
	UISignals.resign_level.connect(_on_resign_level)
	UISignals.continue_from_pause_menu.connect(_continue_from_pause_menu)
	GameSignals.level_loaded.connect(_on_level_loaded)
	GameSignals.lose_game.connect(_on_lose_game)
	GameSignals.level_completed.connect(_on_level_completed)
	$DeveloperModeNotification.visible = GameSignals.testing


func load_game_world_map(from_menu : bool) -> void:
	if from_menu:
		scene_manager.unload_scene_by_name(MAIN_MENU_NAME, scene_manager.SceneType.UI)
		scene_manager.load_scene_by_name(GAME_WORLD_MAP_SCENE_NAME, scene_manager.SceneType.UI, self)
		return
	
	scene_manager.unload_all_ui_scenes()
	scene_manager.unload_current_level()
	GameSignals.game_pause.emit(false)
	scene_manager.load_scene_by_name(GAME_WORLD_MAP_SCENE_NAME, scene_manager.SceneType.UI, self)


func is_other_menus_open() -> bool:
	return scene_manager.is_scene_loaded(LOSE_GAME_MENU_NAME, scene_manager.SceneType.UI) or scene_manager.is_scene_loaded(LEVEL_COMPLETED_MENU_NAME, scene_manager.SceneType.UI)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(PAUSE_MENU_OPEN_INPUT_NAME):
		if not is_other_menus_open() and scene_manager.is_in_level():
			if scene_manager.is_scene_loaded(PAUSE_MENU_NAME, scene_manager.SceneType.UI):
				UISignals.continue_from_pause_menu.emit()
			else:
				UISignals.to_menu.emit(false, "")


func _on_level_loaded(_level : Level) -> void:
	_load_game_play_interface()


func _on_resign_level() -> void:
	load_game_world_map(false)


func _on_lose_game() -> void:
	scene_manager.load_scene_by_name(LOSE_GAME_MENU_NAME, scene_manager.SceneType.UI, self)


func _on_level_completed(_level : Level) -> void:
	scene_manager.load_scene_by_name(LEVEL_COMPLETED_MENU_NAME, scene_manager.SceneType.UI, self)


func _menu(_to_main_menu : bool, from_scene_name : String) -> void:
	if from_scene_name != "":
		print(name, " trying to unload " , from_scene_name)
		scene_manager.unload_scene_by_name(from_scene_name, scene_manager.SceneType.UI)
		GameSignals.game_pause.emit(false)
		
	if _to_main_menu:
		if scene_manager.is_in_level():
			_unload_game_play_interface()
			scene_manager.unload_current_level()
		scene_manager.load_scene_by_name(MAIN_MENU_NAME, scene_manager.SceneType.UI, self)
	else:
		scene_manager.load_scene_by_name(PAUSE_MENU_NAME, scene_manager.SceneType.UI, self)
		GameSignals.game_pause.emit(true)


func _options() -> void:
	if not scene_manager.is_in_level():
		scene_manager.unload_scene_by_name(MAIN_MENU_NAME, scene_manager.SceneType.UI)
	else: 
		scene_manager.unload_scene_by_name(PAUSE_MENU_NAME, scene_manager.SceneType.UI)
		
	var options = scene_manager.load_scene_by_name(OPTIONS_NAME, scene_manager.SceneType.UI, self)
	options.in_main_menu = not scene_manager.is_in_level()


func _continue_from_pause_menu() -> void:
	scene_manager.unload_scene_by_name(PAUSE_MENU_NAME, scene_manager.SceneType.UI)
	GameSignals.game_pause.emit(false)


func _load_game_play_interface() -> void:
	scene_manager.load_scene_by_name(RESOURCE_DISPLAY_NAME, scene_manager.SceneType.UI, self)
	scene_manager.load_scene_by_name(SPEED_CONTROL_PANEL_NAME, scene_manager.SceneType.UI, self)
	scene_manager.load_scene_by_name(BOTTOM_PANEL_NAME, scene_manager.SceneType.UI, self)
	UISignals.game_play_interface_loaded.emit()


func _unload_game_play_interface() -> void:
	scene_manager.unload_scene_by_name(RESOURCE_DISPLAY_NAME, scene_manager.SceneType.UI)
	scene_manager.unload_scene_by_name(SPEED_CONTROL_PANEL_NAME, scene_manager.SceneType.UI)
	scene_manager.unload_scene_by_name(BOTTOM_PANEL_NAME, scene_manager.SceneType.UI)
