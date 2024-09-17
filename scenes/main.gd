class_name Main
extends Node


@onready var scene_manager : SceneManager = $SceneManager
@onready var game_camera : GameCamera = $GameCamera
@onready var ui : UI = $UI


func _ready() -> void:
	ui.initialize(scene_manager)
	MenuSignals.start_game.connect(_on_start_new_game)
	GameStateSignals.game_pause.connect(_on_pause_game)


func _on_start_new_game() -> void:
	scene_manager.unload_scene_by_name(ui.MAIN_MENU_NAME, scene_manager.SceneType.UI)
	scene_manager.load_level_by_number(1, self)
	game_camera.current_mode = game_camera.CameraMode.Free


func _on_pause_game(is_paused : bool) -> void:
	get_tree().paused = is_paused
