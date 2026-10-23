class_name AudioWiring
extends AudioPlayback

## This project's sounds: the file to edit after copying the audio system. Picks the music
## for the menu, world map, build breaks and waves, and maps GameSignals to AudioBank sounds.

enum Mood { NONE, MENU, WORLD_MAP, BUILD, BATTLE, VICTORY, DEFEAT }

const SKILL_VOLUME_DB: float = -8.0
const ENEMY_DEATH_VOLUME_DB: float = -6.0
const WORLD_VOLUME_DB: float = -3.0
## Varied pitch so a row of the same shot or death doesn't sound identical.
const PITCH_JITTER: float = 0.08
## Three towers firing in the same frame, or a whole group dying to one nova, would
## otherwise stack into one loud burst.
const SAME_SOUND_MIN_GAP_MSEC: int = 50
const ENEMY_DEATH_MIN_GAP_MSEC: int = 70
## building_destroyed comes again with every hit on a building already at zero health.
const BUILDING_DESTROYED_MIN_GAP_MSEC: int = 250
## Test runs by Claude create this (gitignored) file to play silently. Players never have it.
const TEST_MUTE_FLAG_PATH: String = "res://tools/mute_audio.flag"
const MASTER_BUS: StringName = &"Master"

var bank: AudioBank = preload("res://scenes/audio/audio_bank.tres")

var _mood: Mood = Mood.NONE
var _wave_number: int = 0
## AudioStream -> Time.get_ticks_msec() it last played.
var _last_played_msec: Dictionary = {}


func _init() -> void:
	sfx_bus = &"SFX"
	music_bus = &"Music"
	click_stream = bank.ui_click


func _ready() -> void:
	super()
	get_tree().node_added.connect(_on_screen_added)
	GameSignals.level_loaded.connect(_on_level_loaded)
	GameSignals.wave_state_changed.connect(_on_wave_state_changed)
	GameSignals.wave_cleared.connect(_on_wave_cleared)
	GameSignals.level_completed.connect(_on_level_completed)
	GameSignals.lose_game.connect(_on_lose_game)
	GameSignals.enemy_reached_end_point.connect(_on_enemy_reached_end_point)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.sell_building.connect(_on_building_sold)
	GameSignals.building_destroyed.connect(_on_building_destroyed)
	GameSignals.skill_activated.connect(_on_skill_activated)
	GameSignals.upgrade_level_gained.connect(_on_upgrade_level_gained)
	GameSignals.gold_upgrade_bought.connect(_on_gold_upgrade_bought)
	if FileAccess.file_exists(TEST_MUTE_FLAG_PATH):
		# Deferred: SettingsManager applies the saved volumes and mutes in its own _ready().
		AudioServer.set_bus_mute.call_deferred(AudioServer.get_bus_index(MASTER_BUS), true)


## Changes the music only when the mood changes, so an early start during a wave or the
## menu coming back from the options keeps the track going.
func _set_mood(mood: Mood) -> void:
	if mood == _mood:
		return
	_mood = mood
	match mood:
		Mood.MENU:
			play_music_loop(bank.menu_music)
		Mood.WORLD_MAP:
			play_music_loop(bank.world_map_music)
		Mood.BUILD:
			play_playlist(bank.build_music)
		Mood.BATTLE:
			play_playlist(bank.battle_music)
		Mood.VICTORY:
			play_music_once(bank.victory_music)
		Mood.DEFEAT:
			play_music_once(bank.defeat_music)


## The menus are UI scenes swapped under Main, so the scene tree's scene_changed never fires.
func _on_screen_added(node: Node) -> void:
	if node is Menu:
		_set_mood(Mood.MENU)
	elif node is GameWorldMap:
		_set_mood(Mood.WORLD_MAP)


func _on_level_loaded(_level: Level) -> void:
	_wave_number = 0
	# A retry loads the level again while the mood is still BUILD or BATTLE.
	_mood = Mood.NONE
	_set_mood(Mood.BUILD)


func _on_wave_state_changed(wave_number: int, _wave_count: int, _can_start_next: bool, _early_start_bonus: float) -> void:
	if wave_number <= _wave_number:
		return
	_wave_number = wave_number
	play_sfx(bank.wave_start)
	_set_mood(Mood.BATTLE)


func _on_wave_cleared(_wave_number_cleared: int) -> void:
	play_sfx(bank.wave_cleared)
	_set_mood(Mood.BUILD)


func _on_level_completed(_level: Level) -> void:
	_set_mood(Mood.VICTORY)


func _on_lose_game() -> void:
	_set_mood(Mood.DEFEAT)


func _on_enemy_reached_end_point(_enemy: Enemy) -> void:
	play_sfx(bank.castle_hit)


func _on_enemy_destroyed(enemy: Enemy) -> void:
	if bank.enemy_deaths.is_empty():
		return
	# One gap for all the death sounds, they are variations of one sound.
	_play_world(bank.enemy_deaths[0], enemy.global_position, ENEMY_DEATH_VOLUME_DB, ENEMY_DEATH_MIN_GAP_MSEC, bank.enemy_deaths.pick_random())


func _on_building_placed(building: Building) -> void:
	_play_world(bank.building_placed, building.global_position, WORLD_VOLUME_DB)


func _on_building_sold(_building: Building) -> void:
	play_sfx(bank.building_sold)


func _on_building_destroyed(building: Building) -> void:
	_play_world(bank.building_destroyed, building.global_position, WORLD_VOLUME_DB, BUILDING_DESTROYED_MIN_GAP_MSEC)


func _on_skill_activated(skill: Skill) -> void:
	_play_world(skill.activate_sound, skill.global_position, SKILL_VOLUME_DB)


func _on_upgrade_level_gained(_new_level: int, _cards: Array[UpgradeCard]) -> void:
	play_sfx(bank.level_up)


func _on_gold_upgrade_bought(_building: Building, is_evolve: bool) -> void:
	play_sfx(bank.element_chosen if is_evolve else bank.upgrade_bought)


## A world sound with a varied pitch, skipped when the same sound played under
## `min_gap_msec` ago. `stream` is the throttle key; `variant` is what plays, if different.
func _play_world(stream: AudioStream, world_position: Vector2, volume_db: float, min_gap_msec: int = SAME_SOUND_MIN_GAP_MSEC, variant: AudioStream = null) -> void:
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_played_msec.get(stream, -min_gap_msec) < min_gap_msec:
		return
	_last_played_msec[stream] = now
	var pitch := randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	play_sfx_at(variant if variant != null else stream, world_position, volume_db, pitch)
