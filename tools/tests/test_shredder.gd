extends RefCounted

## The Shredder (2026-11-25): a weak, slow pulse; every enemy it hits loses resistance (stacking, for a while).


func test_shredder_tears_armour(kit : TestKit) -> void:
	await kit.load_level(25)
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		var world : Vector2 = kit.level.grid.grid_position_to_world(c)
		return kit.level.grid.is_position_buildable(world) and world.distance_to(spawn) <= Utils.TILE_SIZE * 2.0)
	var shredder : Building = await kit.place("puffe_shredder", cell)
	kit.check(shredder is Shredder, "a Shredder is placed")
	kit.check(TalentEffect.get_building_flag(shredder) == TalentEffect.SHREDDER, "talents see it as a Shredder, not a Nova")
	#its own bursts would land on the stand-in Main, outside the tree: keep it quiet and land the hits by hand
	shredder.silence(60.0)
	var knight : Enemy = kit.spawn_enemy("armored_knight")
	await kit.frames(1)
	knight.global_position = shredder.global_position + Vector2(Utils.TILE_SIZE, 0)
	knight.freeze_for(20.0)
	for stat_type in [Utils.StatType.MaxHealth, Utils.StatType.Health]:
		knight.stats.get_stat(stat_type).value = 5000.0
	var hit : DamageData = DamageData.new()
	hit.damage = 10.0
	var before : float = knight.get_resistance_factor(hit)
	#the pulse's burst lands on the stand-in Main, which a test never puts in the tree: land its hits by hand
	for pulse in Shredder.MAX_STACKS + 1:
		var burst : DamageData = shredder.skill.damage_data
		knight.take_damage(burst)
		burst.free()
		if pulse == 0:
			kit.check_near(ResistanceShred.get_share(knight), Shredder.SHRED_PER_STACK, "a pulse tears a stack")
			kit.check(knight.get_resistance_factor(hit) > before, "so a physical hit gets through better (%.2f > %.2f)" % [knight.get_resistance_factor(hit), before])
	kit.check_near(ResistanceShred.get_share(knight), Shredder.SHRED_PER_STACK * Shredder.MAX_STACKS, "up to three stacks")
	await kit.run_until(func() -> bool: return ResistanceShred.get_share(knight) == 0.0, Shredder.SHRED_SECONDS + 1.0)
	kit.check_near(ResistanceShred.get_share(knight), 0.0, "the armour mends after a while")
	hit.free()
