extends RefCounted

## The variant enemies of 2026-11-16: leaper frog, bloater, sapper, burrower, crystal brute.

const NAMES : PackedStringArray = ["leaper_frog", "bloater", "sapper", "burrower", "crystal_brute"]


func test_every_new_enemy_spawns_and_walks(kit : TestKit) -> void:
	await kit.load_level(14)
	for enemy_name in NAMES:
		var enemy : Enemy = kit.spawn_enemy(enemy_name)
		var start : Vector2 = enemy.global_position
		await kit.run_until(func() -> bool: return enemy.global_position.distance_to(start) > Utils.TILE_SIZE, 6.0)
		kit.check(enemy.global_position.distance_to(start) > Utils.TILE_SIZE, "%s walks" % enemy_name)
		kit.check(enemy.icon != null and enemy.animation_control.sprite_frames.has_animation(GlobalAnimationNames.WALK_ANIMATION), "%s has its art" % enemy_name)


func test_bloater_bursts_on_nearby_towers(kit : TestKit) -> void:
	await kit.load_level(14)
	#these tests want towers right by the spawn so its enemies reach them at once, not the spawn mouth rule
	kit.level.grid.spawn_clear_cells.clear()
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		var world : Vector2 = kit.level.grid.grid_position_to_world(c)
		return kit.level.grid.is_position_buildable(world) and world.distance_to(spawn) <= Utils.TILE_SIZE * 1.4)
	kit.check(cell != Vector2i.MAX, "a cell next to the spawn")
	var tower : Building = await kit.place("puffe_beamer", cell)
	var bloater : Enemy = kit.spawn_enemy("bloater")
	await kit.frames(1)
	bloater.global_position = tower.global_position + Vector2(Utils.TILE_SIZE, 0)
	var before : float = tower.stats.get_stat_value(Utils.StatType.Health)
	var hit : DamageData = DamageData.new()
	hit.damage = 9999.0
	bloater.take_damage(hit)
	hit.free()
	await kit.frames(2)
	kit.check(not is_instance_valid(tower) or tower.stats.get_stat_value(Utils.StatType.Health) < before, "the burst hurts the tower next to it")


func test_burrower_digs_ahead(kit : TestKit) -> void:
	await kit.load_level(5)
	var burrower : Enemy = kit.spawn_enemy("burrower")
	await kit.run_until(func() -> bool: return burrower.has_path and burrower.current_waypoint_index > 1, 10.0)
	var dig : EnemyAbility = burrower.abilities.get_node("Dig")
	await kit.run_until(func() -> bool: return dig.use_count > 0 and not dig.is_active, 15.0)
	kit.check(dig.use_count > 0, "it digs")
	kit.check(not burrower.is_burrowed and burrower.visible, "and comes up again")


func test_crystal_brute_turns_plain_hits(kit : TestKit) -> void:
	await kit.load_level(5)
	var brute : Enemy = kit.spawn_enemy("crystal_brute")
	await kit.frames(1)
	var hit : DamageData = DamageData.new()
	hit.damage = 10.0
	kit.check_near(brute.get_resistance_factor(hit), 0.5, "half of a physical hit gets through")
	hit.damage_type = Utils.DamageType.Fire
	kit.check_near(brute.get_resistance_factor(hit), 0.75, "three quarters of a fire hit")
	hit.free()
