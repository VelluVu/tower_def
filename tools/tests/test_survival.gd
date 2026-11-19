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


func test_best_waves_keep_the_record(kit : TestKit) -> void:
	const LEVEL : int = 999
	PlayerProgress._save.progress.survival_best_waves.erase(LEVEL)
	kit.check(PlayerProgress.get_survival_best_waves(LEVEL) == 0, "no record before the first run")
	kit.check(PlayerProgress.record_survival_waves(LEVEL, 12), "the first run is a record")
	kit.check(not PlayerProgress.record_survival_waves(LEVEL, 8), "a shorter run is not")
	kit.check(not PlayerProgress.record_survival_waves(LEVEL, 12), "nor an equal one")
	kit.check(PlayerProgress.get_survival_best_waves(LEVEL) == 12, "the record stays at 12")
	kit.check(PlayerProgress.record_survival_waves(LEVEL, 15) and PlayerProgress.get_survival_best_waves(LEVEL) == 15, "a longer run beats it")
	PlayerProgress._save.progress.survival_best_waves.erase(LEVEL)


func test_lose_menu_shows_the_run(kit : TestKit) -> void:
	var menu : LoseGameMenu = load("res://scenes/ui/lose_game_menu/lose_game_menu.tscn").instantiate()
	kit.root.add_child(menu)
	var label : Label = menu.get_node("MarginContainer/VBoxContainer/SurvivalLabel")
	kit.check(not label.visible, "hidden after a Normal loss")
	GameSignals.survival_run_ended.emit(14, 20, false)
	kit.check(label.visible and label.text == "Survived 14 waves\nBest: 20 waves", "the run and the record: " + label.text.c_escape())
	GameSignals.survival_run_ended.emit(21, 21, true)
	kit.check(label.text == "Survived 21 waves\nNew best!", "a record says so: " + label.text.c_escape())
	menu.queue_free()


## Through the real Main: quitting in the break after wave 1 records 1 wave; a loss in wave 2 keeps the record at 1.
func test_quit_and_loss_record_the_run(kit : TestKit) -> void:
	PlayerProgress._save.progress.survival_best_waves.erase(1)
	var main : Main = load("res://scenes/main.tscn").instantiate()
	kit.root.add_child(main)
	await kit.frames(2)
	UISignals.start_level_button_pressed.emit(1, Utils.LevelMode.Survival)
	await kit.run_until(func() -> bool: return main.scene_manager.current_level is Level and main.scene_manager.current_level.is_node_ready(), 10.0)
	var level : Level = main.scene_manager.current_level
	kit.check(main.survival_level == level, "Main follows the Survival level")

	UISignals.start_wave_pressed.emit()
	await kit.run_until(func() -> bool: return not level.wave_runner.is_spawning, 60.0)
	for enemy in level.existing_enemies.duplicate():
		var hit : DamageData = DamageData.new()
		hit.damage = 99999.0
		enemy.take_damage(hit)
		hit.free()
	#the kills earn a level-up whose cards pause the game
	await kit.run_until(func() -> bool:
		main.pause_game(false)
		return level.existing_enemies.is_empty(), 5.0)
	UISignals.resign_level.emit()
	kit.check(PlayerProgress.get_survival_best_waves(1) == 1, "quitting in the break after wave 1 records it (%d)" % PlayerProgress.get_survival_best_waves(1))
	kit.check(main.survival_level == null, "the run is recorded once")

	var ended : Array[int] = []
	var on_ended : Callable = func(cleared : int, best : int, is_new_best : bool) -> void: ended.assign([cleared, best, int(is_new_best)])
	GameSignals.survival_run_ended.connect(on_ended)
	#the old level is freed by now: compare ids, a freed capture turns into null
	var old_id : int = level.get_instance_id()
	await kit.frames(2)
	UISignals.start_level_button_pressed.emit(1, Utils.LevelMode.Survival)
	await kit.run_until(func() -> bool: return main.scene_manager.current_level is Level and main.scene_manager.current_level.get_instance_id() != old_id \
		and main.scene_manager.current_level.is_node_ready(), 10.0)
	level = main.scene_manager.current_level
	UISignals.start_wave_pressed.emit()
	await kit.frames(2)
	GameSignals.lose_game.emit()
	await kit.frames(2)
	kit.check(ended == [0, 1, 0], "a loss in wave 1 reports 0 cleared, the record 1, no new best: %s" % [ended])
	GameSignals.survival_run_ended.disconnect(on_ended)
	main.pause_game(false)
	main.queue_free()
	await kit.frames(2)
	PlayerProgress._save.progress.survival_best_waves.erase(1)
