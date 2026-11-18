extends RefCounted

## Survival mode: endless looping waves that grow, the next one starting by itself, points at milestones.


func test_rules(kit : TestKit) -> void:
	kit.check_near(SurvivalRules.health_multiplier(5, 6), 1.0, "the first loop is the level's own")
	kit.check_near(SurvivalRules.health_multiplier(16, 6), 1.0 + 2.0 + 2.0, "ten waves past it: +2.0 and +2.0")
	kit.check(SurvivalRules.extra_count(6, 6) == 0 and SurvivalRules.extra_count(12, 6) == 2, "two more per group six waves past the loop")
	kit.check(SurvivalRules.points_for_waves(4) == 0 and SurvivalRules.points_for_waves(12) == 2 and SurvivalRules.points_for_waves(40) == 5, "points at 5, 10, 15, 20, 25")


func test_waves_never_end_and_grow(kit : TestKit) -> void:
	await kit.load_level(1, Utils.LevelMode.Survival)
	var runner : WaveRunner = kit.level.wave_runner
	var level_waves : int = runner.waves.size()
	kit.check(runner.is_endless and runner.wave_count == 0, "an endless runner")
	var looped : WaveData = SurvivalRules.make_wave(runner.waves, level_waves + 1)
	var later : WaveData = SurvivalRules.make_wave(runner.waves, level_waves * 3 + 1)
	kit.check(looped.spawn_groups[0].count == runner.waves[0].spawn_groups[0].count, "the second loop starts like the first")
	kit.check(later.spawn_groups[0].count > runner.waves[0].spawn_groups[0].count, "later loops have bigger groups")
	runner.current_wave_index = level_waves + 5
	kit.check(runner.can_start_next_wave and not runner.is_last_wave_started, "past the level's last wave there is still a next one")


func test_next_wave_starts_by_itself(kit : TestKit) -> void:
	await kit.load_level(1, Utils.LevelMode.Survival)
	UISignals.start_wave_pressed.emit()
	await kit.run_until(func() -> bool: return not kit.level.wave_runner.is_spawning, 60.0)
	for enemy in kit.level.existing_enemies.duplicate():
		var hit : DamageData = DamageData.new()
		hit.damage = 99999.0
		enemy.take_damage(hit)
		hit.free()
	await kit.run_until(func() -> bool: return kit.level.wave_runner.wave_number >= 2, SurvivalRules.BREAK_SECONDS + 4.0)
	kit.check(kit.level.wave_runner.wave_number >= 2, "wave 2 started after the break (%d)" % kit.level.wave_runner.wave_number)
