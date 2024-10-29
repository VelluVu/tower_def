class_name Main
extends Node


@export var time_scale_step : float = 0.5
@export var maximum_time_scale : float = 3.0
@export var minimum_time_scale : float = 1.0

@onready var scene_manager : SceneManager = $SceneManager
@onready var game_camera : GameCamera = $GameCamera
@onready var ui : UI = $UI

var is_game_paused : bool = false
var time_scale : float = 1.0


func reset_time_scale() -> void:
	time_scale = 1.0
	GameSignals.time_scale_change.emit(time_scale)


func pause_game(is_pause : bool) -> void:
	is_game_paused = is_pause
	get_tree().paused = is_game_paused


func _ready() -> void:
	Utils.game_control = self
	reset_time_scale()
	ui.initialize(scene_manager)
	GameSignals.game_pause.connect(_on_pause_game)
	GameSignals.level_loaded.connect(_on_level_loaded)
	GameSignals.level_completed.connect(_on_level_completed)
	GameSignals.lose_game.connect(_on_lose_level)
	UISignals.continue_next_level_pressed.connect(_on_continue_next_level_pressed)
	UISignals.start_level_button_pressed.connect(_on_start_level_pressed)
	UISignals.start_game.connect(_on_start_new_game)
	UISignals.continue_last_save.connect(_on_continue_game)
	UISignals.slower_speed_pressed.connect(_on_slower_speed_pressed)
	UISignals.faster_speed_pressed.connect(_on_faster_speed_pressed)


func _on_start_level_pressed(level_number : int) -> void:
	scene_manager.unload_scene_by_name(ui.GAME_WORLD_MAP_SCENE_NAME, scene_manager.SceneType.UI)
	scene_manager.load_level_by_number(level_number, self)


func _on_continue_game() -> void:
	PlayerProgress.load_last_progress_data()
	ui.load_game_world_map(true)


func _on_start_new_game() -> void:
	PlayerProgress.new_game()
	ui.load_game_world_map(true)


func _on_continue_next_level_pressed() -> void:
	PlayerProgress.level_progress += 1
	PlayerProgress.save_progress()
	ui.load_game_world_map(false)


func _on_level_loaded(_level : Level) -> void:
	reset_time_scale()


func _on_level_completed(_level : Level) -> void:
	reset_time_scale()


func _on_lose_level() -> void:
	reset_time_scale()
	pause_game(true)


func _on_pause_game(is_paused : bool) -> void:
	is_game_paused = is_paused
	get_tree().paused = is_game_paused


func _on_slower_speed_pressed() -> void:
	if time_scale <= minimum_time_scale:
		time_scale = minimum_time_scale
		return
	
	time_scale -= time_scale_step
	GameSignals.time_scale_change.emit(time_scale)


func _on_faster_speed_pressed() -> void:
	if time_scale >= maximum_time_scale:
		time_scale = maximum_time_scale
		return
		
	time_scale += time_scale_step
	GameSignals.time_scale_change.emit(time_scale)
