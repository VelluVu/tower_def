class_name Main
extends Node

@onready var scene_manager : SceneManager = $SceneManager
@onready var game_camera : GameCamera = $GameCamera
@onready var ui : UI = $UI


func _ready() -> void:
	scene_manager.load_scene_by_name("menu", scene_manager.SceneType.UI, ui)
	MenuSignals.start_game.connect(_start_game)
	MenuSignals.options.connect(_options)
	MenuSignals.to_main_menu.connect(_menu)


func _start_game() -> void:
	scene_manager.unload_scene_by_name("menu", scene_manager.SceneType.UI)
	scene_manager.load_level_by_number(1, self)
	game_camera.current_mode = game_camera.CameraMode.Free


func _menu() -> void:
	scene_manager.unload_scene_by_name("options", scene_manager.SceneType.UI)
	scene_manager.load_scene_by_name("menu", scene_manager.SceneType.UI, ui)


func _options() -> void:
	scene_manager.unload_scene_by_name("menu", scene_manager.SceneType.UI)
	scene_manager.load_scene_by_name("options", scene_manager.SceneType.UI, ui)
