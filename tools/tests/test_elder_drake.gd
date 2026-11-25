extends RefCounted

## The Elder Drake (2026-11-25): heavy bites, and once a wave a breath along the line through the most enemies.


func test_elder_drake_breathes_once_a_wave(kit : TestKit) -> void:
	await kit.load_level(37)
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))
	var drake : Building = await kit.place("puffe_elder", cell)
	kit.check(drake is ElderDrake, "an Elder Drake is placed")
	kit.check(TalentEffect.get_building_flag(drake) == TalentEffect.ELDER_DRAKE, "talents see it as an Elder Drake, not a Bolter")
	drake.silence(60.0)
	var in_line : Array[Enemy] = []
	for i in 3:
		var enemy : Enemy = kit.spawn_enemy("bone_thrall")
		await kit.frames(1)
		enemy.global_position = drake.global_position + Vector2(Utils.TILE_SIZE * (2 + i), 0)
		enemy.freeze_for(20.0)
		for stat_type in [Utils.StatType.MaxHealth, Utils.StatType.Health]:
			enemy.stats.get_stat(stat_type).value = 1000.0
		in_line.append(enemy)
	var aside : Enemy = kit.spawn_enemy("bone_thrall")
	await kit.frames(1)
	aside.global_position = drake.global_position + Vector2(0, -Utils.TILE_SIZE * 4)
	aside.freeze_for(20.0)
	for stat_type in [Utils.StatType.MaxHealth, Utils.StatType.Health]:
		aside.stats.get_stat(stat_type).value = 1000.0
	kit.check(drake.pick_direction().dot(Vector2.RIGHT) > 0.9, "it aims along the row of three")
	kit.check(drake.breathe() == 3, "the breath hits all three")
	for enemy in in_line:
		kit.check(enemy.stats.get_stat_value(Utils.StatType.Health) < 1000.0, "each one burns")
	kit.check_near(aside.stats.get_stat_value(Utils.StatType.Health), 1000.0, "the one off the line is spared")
	kit.check(not drake.is_breath_ready, "one breath a wave")
	GameSignals.wave_started.emit(2)
	kit.check(drake.is_breath_ready, "a new wave readies it again")
