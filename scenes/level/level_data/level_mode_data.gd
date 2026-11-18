class_name LevelModeData
extends Resource

## How a mode changes a level: enemy scaling, bigger waves and extra waves after the level's own.
## modes/hard_mode.tres is the default Hard; a level can set its own in LevelData.hard_mode.

## Enemy max health.
@export var health_multiplier : float = 1.0
## Enemy move speed (a Multiply modifier, so slows still stack on top).
@export var speed_multiplier : float = 1.0
## Enemies per spawn group, rounded up.
@export var count_multiplier : float = 1.0
## Seconds between spawns in a group (below 1 = denser groups).
@export var interval_multiplier : float = 1.0
## Kill XP (the mode's tougher enemies give no extra XP by their health, so the mode sets it here).
@export var xp_multiplier : float = 1.0
## Played after the level's own waves.
@export var extra_waves : Array[WaveData] = []
## Groups mixed into the level's own waves, by wave (the first entry's groups go into wave 1, ...): Hard can bring in
## enemies of other factions, with other weaknesses, so one element is not enough (2026-11-17).
@export var added_groups : Array[WaveData] = []
## The share of the bonuses above in the first wave; it grows evenly to last_wave_share in the last
## wave, so the mode presses the late game (where gold piles up) more than the opener.
@export var first_wave_share : float = 1.0
@export var last_wave_share : float = 1.0


## The level's waves plus the extra ones, each a copy with the group counts and intervals scaled;
## the shared wave .tres files are never changed.
func get_waves(level_waves : Array[WaveData]) -> Array[WaveData]:
	var waves : Array[WaveData] = []
	var all_waves : Array[WaveData] = level_waves.duplicate()
	all_waves.append_array(extra_waves)

	for wave_index in all_waves.size():
		var wave : WaveData = all_waves[wave_index]
		var share : float = get_share(wave_index, all_waves.size())
		var copy : WaveData = wave.duplicate()
		var groups : Array[SpawnGroupData] = []

		var wave_groups : Array[SpawnGroupData] = wave.spawn_groups.duplicate()
		if wave_index < added_groups.size() and added_groups[wave_index] != null:
			wave_groups.append_array(added_groups[wave_index].spawn_groups)
		for group in wave_groups:
			var group_copy : SpawnGroupData = group.duplicate()
			#a lone enemy stays alone: a boss group of one must not become two bosses
			group_copy.count = group.count if group.count <= 1 else scaled_count(group.count, ramped(count_multiplier, share))
			group_copy.interval = group.interval * ramped(interval_multiplier, share)
			groups.append(group_copy)

		copy.spawn_groups = groups
		waves.append(copy)

	return waves


## Raises a newly spawned enemy's max health and speed for the wave it came in; it starts at full health.
func apply_to_enemy(enemy : Enemy, wave_index : int, wave_count : int) -> void:
	var share : float = get_share(wave_index, wave_count)
	var health : float = ramped(health_multiplier, share)
	var speed : float = ramped(speed_multiplier, share)

	scale_health(enemy, health)

	if not is_equal_approx(speed, 1.0):
		enemy.modifier_manager.add_modifier(_multiply(Utils.StatType.Speed, speed))


## The share of the bonuses in a wave (0-based), from first_wave_share to last_wave_share.
func get_share(wave_index : int, wave_count : int) -> float:
	if wave_count <= 1:
		return last_wave_share
	return lerpf(first_wave_share, last_wave_share, clampf(float(wave_index) / (wave_count - 1), 0.0, 1.0))


## A multiplier with only share of its bonus: ramped(1.5, 0.5) = 1.25.
static func ramped(multiplier : float, share : float) -> float:
	return 1.0 + (multiplier - 1.0) * share


## Multiplies an enemy's max health (a Multiply modifier) and fills it up.
static func scale_health(enemy : Enemy, multiplier : float) -> void:
	if is_equal_approx(multiplier, 1.0):
		return
	enemy.modifier_manager.add_modifier(_multiply(Utils.StatType.MaxHealth, multiplier))
	enemy.stats.get_stat(Utils.StatType.Health).value = enemy.stats.get_stat_value(Utils.StatType.MaxHealth)


static func scaled_count(count : int, multiplier : float) -> int:
	return ceili(count * multiplier - 0.0001)


static func _multiply(stat_type : Utils.StatType, multiplier : float) -> ModifierData:
	var modifier : ModifierData = ModifierData.new()
	modifier.modifier_type = Utils.ModifierType.StatModifier
	modifier.calculate_type = Utils.ModifyType.Multiply
	modifier.stat_type = stat_type
	modifier.value = multiplier - 1.0
	return modifier
