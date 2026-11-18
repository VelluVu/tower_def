class_name LevelData
extends Resource

const DEFAULT_HARD_MODE_PATH : String = "res://scenes/level/level_data/modes/hard_mode.tres"

#everything about a level that is not the map, the map stays in the level .tscn

## Shown on the world map; empty shows "Level N".
@export var level_name : String = ""
## Shown on the world map above the waves and starting resources.
@export_multiline var story_text : String = ""
@export var starting_gold : float = 6.0
@export var starting_life : float = 10.0
@export var waves : Array[WaveData] = []
## Puffe's lines in this level, in order (the first level's lines are the tutorial).
@export var puffe_lines : Array[PuffeLine] = []
## Enemy max health in every mode: wave 1 at first_wave_health, rising evenly to last_wave_health
## in the last wave; Hard scales on top. Kill XP ignores it (it comes from the enemy's base health).
@export var first_wave_health : float = 1.0
@export var last_wave_health : float = 1.0
## Hard for this level; empty uses the default (modes/hard_mode.tres).
@export var hard_mode : LevelModeData = null
## The level's strength knobs, set by tools/tune_levels.py against the talent budget a player has by this level:
## every enemy's health (bosses too) in every mode, and on top of that in Hard.
@export var health_scale : float = 1.0
@export var hard_health_scale : float = 1.0
@export_group("Scorched Lands")
## Lava (the water layer of a volcano level) next to a Frost tower or wall cools into rock (LavaField).
@export var lava_cools : bool = false
## Seconds between sandstorms sweeping the map (Sandstorm); 0 = none.
@export var sandstorm_every : float = 0.0


## The health multiplier of a wave (0-based) out of wave_count.
func get_wave_health(wave_index : int, wave_count : int) -> float:
	if wave_count <= 1:
		return last_wave_health * health_scale
	return lerpf(first_wave_health, last_wave_health, clampf(float(wave_index) / (wave_count - 1), 0.0, 1.0)) * health_scale


## The mode's changes, or null for Normal.
func get_mode_data(mode : Utils.LevelMode) -> LevelModeData:
	match mode:
		Utils.LevelMode.Hard:
			return hard_mode if hard_mode != null else load(DEFAULT_HARD_MODE_PATH) as LevelModeData
	return null
