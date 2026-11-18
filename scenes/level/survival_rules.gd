class_name SurvivalRules
extends RefCounted

## Survival mode: the level's waves loop with no end, until the lives run out. The first loop is the level as on
## Normal; from then on every wave is tougher, bigger and pays a little more. Talent points come at wave milestones.
## Tuned 2026-11-16 by the bot: scaling from wave 1 made late levels end in their first loop and early ones easy.

## Waves to clear for each of the mode's 5 talent points.
const MILESTONES : Array[int] = [5, 10, 15, 20, 25]
## Seconds between a cleared wave and the next one starting by itself (the player can start it sooner).
const BREAK_SECONDS : float = 8.0


## Waves past the level's first loop (0 during the first loop).
static func waves_past_first_loop(wave_number : int, level_wave_count : int) -> int:
	return maxi(wave_number - level_wave_count, 0)


## Enemy health in a survival wave (1-based), on top of the level's own wave ramp.
static func health_multiplier(wave_number : int, level_wave_count : int) -> float:
	var w : float = waves_past_first_loop(wave_number, level_wave_count)
	return 1.0 + 0.2 * w + 0.02 * w * w


## Enemies added to every spawn group of a survival wave.
static func extra_count(wave_number : int, level_wave_count : int) -> int:
	return floori(waves_past_first_loop(wave_number, level_wave_count) / 3.0)


## Kill gold in a survival wave.
#flat for now: when it grew with the waves (+5%, then +2% a wave) the gold piled up unspent
static func gold_multiplier(_wave_number : int, _level_wave_count : int) -> float:
	return 1.0


## Talent points for the waves cleared before the lives ran out.
static func points_for_waves(waves_cleared : int) -> int:
	return MILESTONES.filter(func(milestone : int) -> bool: return waves_cleared >= milestone).size()


## The level's wave for a survival wave (1-based): the level's waves in a loop, groups grown by extra_count.
static func make_wave(level_waves : Array[WaveData], wave_number : int) -> WaveData:
	var base : WaveData = level_waves[(wave_number - 1) % level_waves.size()]
	var copy : WaveData = base.duplicate()
	var groups : Array[SpawnGroupData] = []
	for group in base.spawn_groups:
		var group_copy : SpawnGroupData = group.duplicate()
		#a lone enemy (a boss) stays alone
		if group.count > 1:
			group_copy.count = group.count + extra_count(wave_number, level_waves.size())
		groups.append(group_copy)
	copy.spawn_groups = groups
	return copy
