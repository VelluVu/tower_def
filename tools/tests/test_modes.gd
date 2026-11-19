extends RefCounted

## Level modes: Hard scales the waves and enemies from its LevelModeData and saves its own talent points.


func test_hard_scales_wave_copies(kit : TestKit) -> void:
	var data : LevelData = kit.level_data(3)
	var hard : LevelModeData = data.get_mode_data(Utils.LevelMode.Hard)
	kit.check(hard != null and data.get_mode_data(Utils.LevelMode.Normal) == null, "Hard has data, Normal none")
	var group : SpawnGroupData = data.waves[0].spawn_groups[0]
	var count : int = group.count
	var interval : float = group.interval
	var waves : Array[WaveData] = hard.get_waves(data.waves)
	kit.check(waves.size() == data.waves.size() + hard.extra_waves.size(), "the level's waves plus the extra ones")
	var share : float = hard.first_wave_share
	kit.check(waves[0].spawn_groups[0].count == LevelModeData.scaled_count(count, LevelModeData.ramped(hard.count_multiplier, share)), "group counts scale by the first wave's share")
	kit.check_near(waves[0].spawn_groups[0].interval, interval * LevelModeData.ramped(hard.interval_multiplier, share), "intervals scale")
	var last : SpawnGroupData = data.waves[-1].spawn_groups[0]
	kit.check(waves[-1].spawn_groups[0].count == LevelModeData.scaled_count(last.count, LevelModeData.ramped(hard.count_multiplier, hard.last_wave_share)), "the last wave gets the last share")
	kit.check(group.count == count and is_equal_approx(group.interval, interval), "the shared wave files stay unchanged")
	kit.check(LevelModeData.scaled_count(8, 1.25) == 10 and LevelModeData.scaled_count(5, 1.25) == 7, "counts round up")
	kit.check_near(LevelModeData.ramped(1.5, 0.5), 1.25, "half the share is half the bonus")
	kit.check_near(hard.get_share(0, 5), hard.first_wave_share, "wave 1 has the first share")
	kit.check_near(hard.get_share(4, 5), hard.last_wave_share, "the last wave has the last share")


func test_hard_level_scales_enemies(kit : TestKit) -> void:
	await kit.load_level(1, Utils.LevelMode.Hard)
	var hard : LevelModeData = kit.level.mode_data
	kit.check(hard != null, "a Hard level has its mode data")
	var first_group : SpawnGroupData = kit.level_data(1).waves[0].spawn_groups[0]
	var share : float = hard.first_wave_share
	kit.check(kit.level.wave_runner.waves[0].spawn_groups[0].count == LevelModeData.scaled_count(first_group.count, LevelModeData.ramped(hard.count_multiplier, share)), "the wave runner gets the scaled waves")

	var weakling : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	var base : Enemy = load("res://scenes/unit/enemy/enemies/weakling.tscn").instantiate()
	var base_health : float = base.get_node("Stats").get_stat_value(Utils.StatType.MaxHealth)
	var base_speed : float = base.get_node("Stats").get_stat_value(Utils.StatType.Speed)
	base.free()
	#Hard scales on top of the level's own wave health
	var health : float = base_health * kit.level.level_data.get_wave_health(0, kit.level.wave_runner.wave_count) * LevelModeData.ramped(hard.health_multiplier, share)
	kit.check_near(weakling.stats.get_stat_value(Utils.StatType.MaxHealth), health, "max health scales for wave 1")
	kit.check_near(weakling.stats.get_stat_value(Utils.StatType.Health), health, "it starts at full health")
	kit.check_near(weakling.stats.get_stat_value(Utils.StatType.Speed), base_speed * LevelModeData.ramped(hard.speed_multiplier, share), "speed scales")


func test_normal_wave_health_ramp(kit : TestKit) -> void:
	await kit.load_level(1)
	kit.check(kit.level.mode_data == null, "Normal has no mode data")
	var data : LevelData = LevelData.new()
	data.first_wave_health = 1.0
	data.last_wave_health = 2.0
	kit.check_near(data.get_wave_health(0, 5), 1.0, "wave 1 at the first health")
	kit.check_near(data.get_wave_health(2, 5), 1.5, "the middle wave halfway")
	kit.check_near(data.get_wave_health(4, 5), 2.0, "the last wave at the last health")
	var weakling : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	kit.check_near(weakling.stats.get_stat_value(Utils.StatType.MaxHealth), 15.0 * kit.level.level_data.first_wave_health, "a wave 1 weakling gets the level's first wave health")


func test_boss_skips_the_wave_ramp(kit : TestKit) -> void:
	await kit.load_level(8)
	kit.level.wave_runner.current_wave_index = kit.level.wave_runner.wave_count - 1
	var boss : Enemy = kit.spawn_enemy("broodmother")
	await kit.frames(1)
	kit.check(boss.is_boss, "the Broodmother is a boss")
	#the level's tuning knob (health_scale) applies to bosses too, the wave ramp does not
	var expected : float = boss.stats.get_stat(Utils.StatType.MaxHealth).base_value * kit.level.level_data.health_scale
	kit.check_near(boss.stats.get_stat_value(Utils.StatType.MaxHealth), expected, "her hand-set health times the level's scale, not the last wave's ramp")


func test_kill_xp_ignores_health_scaling(kit : TestKit) -> void:
	await kit.load_level(1)
	var weakling : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	LevelModeData.scale_health(weakling, 3.0)
	var xp : float = kit.level.upgrades.xp
	weakling.die()
	await kit.frames(2)
	kit.check_near(kit.level.upgrades.xp - xp, UpgradeRules.kill_xp(15.0, 1.0), "XP from the base health, not the scaled one")


func test_points_per_mode(kit : TestKit) -> void:
	var progress : ProgressData = PlayerProgress._save.progress
	var saved_normal : Dictionary[int, int] = progress.level_talent_points
	var saved_modes : Dictionary[int, Dictionary] = progress.mode_talent_points
	progress.level_talent_points = {2: 3}
	progress.mode_talent_points = {}

	kit.check(PlayerProgress.record_level_talent_points(2, 2, Utils.LevelMode.Hard) == 2, "Hard earns its own points")
	kit.check(PlayerProgress.get_level_mode_talent_points(2, Utils.LevelMode.Normal) == 3, "Normal's points stay")
	kit.check(PlayerProgress.get_level_mode_talent_points(2, Utils.LevelMode.Hard) == 2, "Hard's points are kept")
	kit.check(PlayerProgress.record_level_talent_points(2, 4, Utils.LevelMode.Hard) == 2, "a better Hard run adds the difference")
	kit.check(PlayerProgress.get_talent_points_earned() == 7, "both modes count toward the total")

	progress.level_talent_points = saved_normal
	progress.mode_talent_points = saved_modes


func test_hard_never_doubles_a_boss(kit : TestKit) -> void:
	var mode : LevelModeData = load("res://scenes/level/level_data/modes/hard_mode.tres")
	var waves : Array[WaveData] = mode.get_waves(kit.level_data(24).waves)
	var hydras : int = 0
	for wave in waves:
		for group in wave.spawn_groups:
			if group.enemy_scene.resource_path.ends_with("bog_hydra.tscn"):
				hydras += group.count
	kit.check(hydras == 1, "one Bog Hydra on Hard (%d)" % hydras)


func test_hard_elite_share_makes_late_elites(kit : TestKit) -> void:
	var mode : LevelModeData = load("res://scenes/level/level_data/modes/hard_mode.tres").duplicate()
	mode.elite_share = 0.5
	mode.first_wave_share = 0.0
	mode.last_wave_share = 1.0
	var group : SpawnGroupData = SpawnGroupData.new()
	group.count = 10
	kit.check(mode.get_elites(group, 0.0) == 0, "no elites at no share")
	kit.check(mode.get_elites(group, 1.0) == 5, "half the group at the full share")
	group.elites = 7
	kit.check(mode.get_elites(group, 1.0) == 7, "a group keeps its own elites when they are more")
	group.count = 1
	group.elites = 0
	kit.check(mode.get_elites(group, 1.0) == 0, "a lone enemy (a boss) never turns elite")
	var waves : Array[WaveData] = mode.get_waves(kit.level_data(3).waves)
	var last_elites : int = 0
	for wave_group in waves[-1].spawn_groups:
		last_elites += wave_group.elites
	kit.check(last_elites > 0 and waves[0].spawn_groups[0].elites == kit.level_data(3).waves[0].spawn_groups[0].elites, "elites in the last wave, wave 1 as it was")
