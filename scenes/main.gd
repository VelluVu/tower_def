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
#the running Survival level, until its run is recorded (lost or quit)
var survival_level : Level = null


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
	UISignals.retry_level_pressed.connect(_on_retry_level_pressed)
	UISignals.resign_level.connect(_on_resign_level)
	UISignals.start_level_button_pressed.connect(_on_start_level_pressed)
	UISignals.start_game.connect(_on_start_new_game)
	UISignals.continue_last_save.connect(_on_continue_game)
	UISignals.slower_speed_pressed.connect(_on_slower_speed_pressed)
	UISignals.faster_speed_pressed.connect(_on_faster_speed_pressed)


func _on_start_level_pressed(level_number : int, mode : Utils.LevelMode) -> void:
	scene_manager.unload_scene_by_name(ui.GAME_WORLD_MAP_SCENE_NAME, scene_manager.SceneType.UI)
	scene_manager.load_level_by_number(level_number, self, mode)


func _on_continue_game() -> void:
	PlayerProgress.load_last_progress_data()
	ui.load_game_world_map(true)


func _on_start_new_game() -> void:
	PlayerProgress.new_game()
	ui.load_game_world_map(true)


func _on_continue_next_level_pressed() -> void:
	ui.load_game_world_map(false)


func _on_retry_level_pressed() -> void:
	var level_number : int = scene_manager.current_level_number
	var mode : Utils.LevelMode = scene_manager.current_level_mode
	var old_level : Node = scene_manager.current_level
	ui.unload_level()

	#the old level emits game_stop when it leaves the tree, which would unhook the new level's builder
	if is_instance_valid(old_level) and old_level.is_inside_tree():
		await old_level.tree_exited

	scene_manager.load_level_by_number(level_number, self, mode)


func _on_level_loaded(level : Level) -> void:
	reset_time_scale()
	survival_level = level if level.mode == Utils.LevelMode.Survival else null


func _on_level_completed(level : Level) -> void:
	reset_time_scale()
	#unlocks the level after the cleared one; replaying an earlier level never lowers or skips progress
	PlayerProgress.level_progress = scene_manager.current_level_number + 1
	PlayerProgress.record_level_talent_points(scene_manager.current_level_number, TalentRules.points_for_level(level), level.mode)
	PlayerProgress.save_progress()


func _on_lose_level() -> void:
	reset_time_scale()
	pause_game(true)
	#Survival ends here when the lives run out: its points come from the waves cleared before that
	if survival_level != null:
		#the wave the lives ran out in is never cleared, even when its last enemy took the last life
		var cleared : int = maxi(survival_level.wave_runner.wave_number - 1, 0)
		var is_new_best : bool = _record_survival_run(cleared)
		#deferred: the lose menu is loaded by another lose_game listener
		GameSignals.survival_run_ended.emit.call_deferred(cleared, PlayerProgress.get_survival_best_waves(scene_manager.current_level_number), is_new_best)


#quitting a Survival run from the pause menu ends it too, with the waves cleared so far
func _on_resign_level() -> void:
	if survival_level != null:
		_record_survival_run(_get_survival_waves_cleared())


#quitting in the break after a wave (nothing spawning, nothing alive) counts that wave as cleared
func _get_survival_waves_cleared() -> int:
	var runner : WaveRunner = survival_level.wave_runner
	var is_in_break : bool = not runner.is_spawning and survival_level.existing_enemies.is_empty()
	return runner.wave_number if is_in_break else maxi(runner.wave_number - 1, 0)


## Records the running Survival run once (talent points and the best score); true when it beat the record.
func _record_survival_run(cleared : int) -> bool:
	var level_number : int = scene_manager.current_level_number
	PlayerProgress.record_level_talent_points(level_number, SurvivalRules.points_for_waves(cleared), Utils.LevelMode.Survival)
	var is_new_best : bool = PlayerProgress.record_survival_waves(level_number, cleared)
	PlayerProgress.save_progress()
	survival_level = null
	return is_new_best


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
