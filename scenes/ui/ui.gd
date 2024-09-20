class_name UI
extends CanvasLayer


const PAUSE_MENU_OPEN_INPUT_NAME : String = "Escape"
const MAIN_MENU_NAME : String = "menu"
const OPTIONS_NAME : String = "options"
const PAUSE_MENU_NAME : String = "pause_menu"
const RESOURCE_DISPLAY_NAME : String = "resource_display"
const BOTTOM_PANEL_NAME : String = "bottom_panel"
const LOSE_GAME_MENU_NAME : String = "lose_game_menu"

var is_in_level : bool = false
var scene_manager : SceneManager


func initialize(_scene_manager : SceneManager):
	scene_manager = _scene_manager
	scene_manager.load_scene_by_name(MAIN_MENU_NAME, scene_manager.SceneType.UI, self)
	MenuSignals.options.connect(_options)
	MenuSignals.to_menu.connect(_menu)
	MenuSignals.continue_from_pause_menu.connect(_continue_from_pause_menu)
	GameStateSignals.level_loaded.connect(_on_level_loaded)
	GameSignals.lose_game.connect(_on_lose_game)
	$DeveloperModeNotification.visible = GameStateSignals.testing


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(PAUSE_MENU_OPEN_INPUT_NAME):
		if is_in_level:
			if scene_manager.is_scene_loaded(PAUSE_MENU_NAME, scene_manager.SceneType.UI):
				MenuSignals.continue_from_pause_menu.emit()
			else:
				MenuSignals.to_menu.emit(false, "")


func _on_level_loaded(_level : Level) -> void:
	is_in_level = true
	_load_game_play_interface()


func _on_lose_game() -> void:
	GameStateSignals.game_pause.emit(true)
	scene_manager.load_scene_by_name(LOSE_GAME_MENU_NAME, scene_manager.SceneType.UI, self)


func _menu(_to_main_menu : bool, from_scene_name : String) -> void:
	if from_scene_name != "":
		print(name, " trying to unload " , from_scene_name)
		scene_manager.unload_scene_by_name(from_scene_name, scene_manager.SceneType.UI)
		GameStateSignals.game_pause.emit(false)
		
	if _to_main_menu:
		if is_in_level:
			is_in_level = false
			_unload_game_play_interface()
			scene_manager.unload_current_level()
		scene_manager.load_scene_by_name(MAIN_MENU_NAME, scene_manager.SceneType.UI, self)
	else:
		scene_manager.load_scene_by_name(PAUSE_MENU_NAME, scene_manager.SceneType.UI, self)
		GameStateSignals.game_pause.emit(true)


func _options() -> void:
	if not is_in_level:
		scene_manager.unload_scene_by_name(MAIN_MENU_NAME, scene_manager.SceneType.UI)
	else: 
		scene_manager.unload_scene_by_name(PAUSE_MENU_NAME, scene_manager.SceneType.UI)
		
	var options = scene_manager.load_scene_by_name(OPTIONS_NAME, scene_manager.SceneType.UI, self)
	options.in_main_menu = not is_in_level


func _continue_from_pause_menu() -> void:
	scene_manager.unload_scene_by_name(PAUSE_MENU_NAME, scene_manager.SceneType.UI)
	GameStateSignals.game_pause.emit(false)


func _load_game_play_interface() -> void:
	scene_manager.load_scene_by_name(RESOURCE_DISPLAY_NAME, scene_manager.SceneType.UI, self)
	scene_manager.load_scene_by_name(BOTTOM_PANEL_NAME, scene_manager.SceneType.UI, self)
	UISignals.game_play_interface_loaded.emit()


func _unload_game_play_interface() -> void:
	scene_manager.unload_scene_by_name(RESOURCE_DISPLAY_NAME, scene_manager.SceneType.UI)
	scene_manager.unload_scene_by_name(BOTTOM_PANEL_NAME, scene_manager.SceneType.UI)
