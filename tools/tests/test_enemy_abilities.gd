extends RefCounted

## The ranged enemies' shots (archer, wizard, destroyerling), the priest's heal and the bosses' strikes.

const MAGMA_BLOB_FILE : String = "magma_blob.tscn"


func _cell_near(kit : TestKit, from : Vector2, min_tiles : float, max_tiles : float, taken : Array[Vector2i] = []) -> Vector2i:
	#these tests want towers right by the spawn so its enemies reach them at once, not the spawn mouth rule
	kit.level.grid.spawn_clear_cells.clear()
	return kit.find_cell(func(c : Vector2i) -> bool:
		var world : Vector2 = kit.level.grid.grid_position_to_world(c)
		var tiles : float = world.distance_to(from) / Utils.TILE_SIZE
		return not taken.has(c) and kit.level.grid.is_position_buildable(world) and tiles >= min_tiles and tiles <= max_tiles)


func _health(unit : Node) -> float:
	return unit.stats.get_stat_value(Utils.StatType.Health)


func test_archer_shoots_a_building(kit : TestKit) -> void:
	await kit.load_level(14)
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var cell : Vector2i = _cell_near(kit, spawn, 1.5, 3.0)
	kit.check(cell != Vector2i.MAX, "a buildable cell near the spawn")
	var tower : Building = await kit.place("puffe_beamer", cell)
	var full : float = _health(tower)
	kit.spawn_enemy("archer")
	await kit.run_until(func() -> bool: return _health(tower) < full, 8.0)
	kit.check(_health(tower) < full, "an arrow hits the tower (%.0f -> %.0f)" % [full, _health(tower)])


func test_wizard_casts_at_towers_not_walls(kit : TestKit) -> void:
	await kit.load_level(14)
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var wall_cell : Vector2i = _cell_near(kit, spawn, 1.5, 2.5)
	var wall : Building = await kit.place("wall", wall_cell)
	var wizard : Enemy = kit.spawn_enemy("wizard")
	await kit.run_until(func() -> bool: return false, 3.0)
	kit.check(_health(wall) == 25.0, "the wizard leaves walls alone (%.0f)" % _health(wall))
	var tower_cell : Vector2i = _cell_near(kit, wizard.global_position, 1.0, 3.0, [wall_cell])
	var tower : Building = await kit.place("puffe_beamer", tower_cell)
	var full : float = _health(tower)
	await kit.run_until(func() -> bool: return _health(tower) < full, 8.0)
	kit.check(_health(tower) < full, "a spell hits the tower (%.0f -> %.0f)" % [full, _health(tower)])


func test_destroyerling_throws_at_the_farthest_tower(kit : TestKit) -> void:
	await kit.load_level(14)
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var near_cell : Vector2i = _cell_near(kit, spawn, 1.0, 2.0)
	var far_cell : Vector2i = _cell_near(kit, spawn, 3.5, 4.5, [near_cell])
	var near : Building = await kit.place("puffe_beamer", near_cell)
	var far : Building = await kit.place("puffe_beamer", far_cell)
	kit.check(near.global_position.distance_to(far.global_position) > 1.5 * Utils.TILE_SIZE, "the towers stand apart")
	var full : float = _health(far)
	kit.spawn_enemy("destroyerling")
	await kit.run_until(func() -> bool: return _health(far) < full, 10.0)
	kit.check(_health(far) < full, "the rock lands on the farthest tower (%.0f -> %.0f)" % [full, _health(far)])
	kit.check(_health(near) == full, "the near tower, outside the rock's area, is not hit")


func test_priest_heals_a_hurt_ally(kit : TestKit) -> void:
	await kit.load_level(14)
	var priest : Enemy = kit.spawn_enemy("priest")
	var hurt : Enemy = kit.spawn_enemy("swbeefling")
	await kit.frames(2)
	hurt.stats.get_stat(Utils.StatType.Health).value = hurt.stats.get_stat_value(Utils.StatType.MaxHealth) * 0.3
	var before : float = _health(hurt)
	await kit.run_until(func() -> bool: return _health(hurt) > before + 1.0, 6.0)
	kit.check(_health(hurt) > before + 1.0, "the priest heals it (%.0f -> %.0f)" % [before, _health(hurt)])
	kit.check(priest.abilities.get_node("Heal").use_count > 0, "the heal was used")


func test_bog_hydra_strikes_three_towers_at_once(kit : TestKit) -> void:
	await kit.load_level(24)
	#towers first: a hydra already there would strike the first one alone
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var taken : Array[Vector2i] = []
	var towers : Array[Building] = []
	for i in 4:
		var cell : Vector2i = _cell_near(kit, spawn, 1.0, 2.3, taken)
		if cell == Vector2i.MAX:
			break
		taken.append(cell)
		towers.append(await kit.place("puffe_beamer", cell))
	kit.check(towers.size() == 4, "four towers around the hydra (%d)" % towers.size())
	var hydra : Enemy = kit.spawn_enemy("bog_hydra")
	var strike : EnemyAbility = hydra.abilities.get_node("HeadStrike")
	await kit.run_until(func() -> bool: return strike.use_count > 0 and not strike.is_active, 8.0)
	var hit : int = towers.filter(func(t : Building) -> bool: return _health(t) < 10.0).size()
	kit.check(strike.use_count > 0, "the heads strike")
	kit.check(hit >= 3, "one strike hits three towers, one per head (%d)" % hit)


func test_dragonslayer_cleaves_the_most_upgraded_tower(kit : TestKit) -> void:
	await kit.load_level(36)
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var first_cell : Vector2i = _cell_near(kit, spawn, 0.8, 1.9)
	var second_cell : Vector2i = _cell_near(kit, spawn, 0.8, 1.9, [first_cell])
	kit.check(second_cell != Vector2i.MAX, "two cells in reach")
	var near : Building = await kit.place("puffe_beamer", first_cell)
	var far : Building = await kit.place("puffe_beamer", second_cell)
	if far.global_position.distance_to(spawn) < near.global_position.distance_to(spawn):
		var swap : Building = near
		near = far
		far = swap
	#two gold upgrades on the farther tower
	var state : BuildingTypeUpgrades.UpgradeState = BuildingTypeUpgrades.UpgradeState.new()
	state.upgrades_bought = 2
	kit.level.building_type_upgrades.building_states[far] = state
	kit.check(kit.level.building_type_upgrades.get_upgrade_steps(far) == 2, "the far tower has two upgrades")
	var slayer : Enemy = kit.spawn_enemy("dragonslayer")
	var cleave : EnemyAbility = slayer.abilities.get_node("DragonbaneCleave")
	await kit.run_until(func() -> bool: return cleave.use_count > 0 and not cleave.is_active, 8.0)
	kit.check(cleave.use_count > 0, "the Dragonslayer cleaves")
	kit.check(is_instance_valid(far) and not far.is_dead and _health(far) < 10.0, "the upgraded tower is hurt, not killed")
	kit.check(is_instance_valid(far) and far.silence_timer != null and not far.silence_timer.is_stopped(), "and silenced")
	kit.check(is_instance_valid(near) and _health(near) >= 10.0, "the nearer, plain tower is not")


func test_dragonslayer_oath_and_sweep(kit : TestKit) -> void:
	await kit.load_level(36)
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var taken : Array[Vector2i] = []
	var towers : Array[Building] = []
	for i in 3:
		var cell : Vector2i = _cell_near(kit, spawn, 0.8, 1.9, taken)
		if cell == Vector2i.MAX:
			break
		taken.append(cell)
		towers.append(await kit.place("puffe_beamer", cell))
	kit.check(towers.size() == 3, "three towers around the Dragonslayer (%d)" % towers.size())
	var slayer : Enemy = kit.spawn_enemy("dragonslayer")
	var max_health : float = slayer.stats.get_stat_value(Utils.StatType.MaxHealth)
	slayer.stats.get_stat(Utils.StatType.Health).value = max_health * 0.3
	var oath : EnemyAbility = slayer.abilities.get_node("SlayersOath")
	var sweep : EnemyAbility = slayer.abilities.get_node("Sweep")
	await kit.run_until(func() -> bool: return oath.use_count > 0 and not oath.is_active, 8.0)
	kit.check(oath.use_count > 0, "he swears the oath first")
	kit.check(is_equal_approx(slayer.damage_taken_factor, 0.5), "and takes half damage")
	#the oath alone, without his armour
	slayer.resistances = null
	var before : float = _health(slayer)
	var damage_data : DamageData = DamageData.new()
	damage_data.damage = 100.0
	slayer.take_damage(damage_data)
	damage_data.free()
	kit.check(is_equal_approx(before - _health(slayer), 50.0), "a 100 hit takes 50 (%.1f)" % (before - _health(slayer)))
	await kit.run_until(func() -> bool: return sweep.use_count > 0 and not sweep.is_active, 8.0)
	var hit : int = towers.filter(func(t : Building) -> bool: return not is_instance_valid(t) or t.is_dead or _health(t) < 10.0).size()
	kit.check(sweep.use_count > 0 and hit == towers.size(), "the sweep hits every tower around him (%d)" % hit)
	await kit.run_until(func() -> bool: return is_equal_approx(slayer.damage_taken_factor, 1.0), 6.0)
	kit.check(is_equal_approx(slayer.damage_taken_factor, 1.0), "the oath wears off")


func test_an_archer_killed_mid_shot_dies(kit : TestKit) -> void:
	await kit.load_level(14)
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var cell : Vector2i = _cell_near(kit, spawn, 1.5, 3.0)
	await kit.place("puffe_beamer", cell)
	var archer : Enemy = kit.spawn_enemy("archer")
	var shoot : EnemyAbility = archer.abilities.get_node("Shoot")
	await kit.run_until(func() -> bool: return shoot.is_active, 8.0)
	kit.check(shoot.is_active, "the archer is shooting")
	var damage_data : DamageData = DamageData.new()
	damage_data.damage = 999.0
	archer.take_damage(damage_data)
	damage_data.free()
	await kit.run_until(func() -> bool: return not is_instance_valid(archer) or archer.is_deactivated, 3.0)
	kit.check(not is_instance_valid(archer) or archer.is_deactivated, "it dies instead of staying in its shot forever")


#the archer reaches the castle (freed at once) while its arrow flies: the arrow still lands
func test_a_shot_lands_after_its_shooter_is_gone(kit : TestKit) -> void:
	await kit.load_level(14)
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var cell : Vector2i = _cell_near(kit, spawn, 3.0, 4.0)
	var tower : Building = await kit.place("puffe_beamer", cell)
	var full : float = _health(tower)
	var archer : Enemy = kit.spawn_enemy("archer")
	var shots_before : int = kit.level.get_children().filter(func(n : Node) -> bool: return n is EnemyShot).size()
	await kit.run_until(func() -> bool:
		return kit.level.get_children().filter(func(n : Node) -> bool: return n is EnemyShot).size() > shots_before, 8.0)
	kit.check(kit.level.get_children().any(func(n : Node) -> bool: return n is EnemyShot), "an arrow is in the air")
	archer.free()
	await kit.run_until(func() -> bool: return _health(tower) < full, 3.0)
	kit.check(_health(tower) < full, "the arrow lands on the tower (%.0f -> %.0f)" % [full, _health(tower)])


func test_magma_titan_slams_then_calls_the_magma(kit : TestKit) -> void:
	await kit.load_level(57)
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	var taken : Array[Vector2i] = []
	var towers : Array[Building] = []
	for i in 3:
		var cell : Vector2i = _cell_near(kit, spawn, 1.0, 1.9, taken)
		if cell == Vector2i.MAX:
			break
		taken.append(cell)
		towers.append(await kit.place("puffe_beamer", cell))
	kit.check(towers.size() == 3, "three towers by the titan (%d)" % towers.size())
	var titan : Enemy = kit.spawn_enemy("magma_titan")
	kit.check(titan.is_boss, "the titan is a boss")
	var slam : EnemyAbility = titan.abilities.get_node("MagmaSlam")
	await kit.run_until(func() -> bool: return slam.use_count > 0 and not slam.is_active, 10.0)
	kit.check(slam.use_count > 0, "it slams")
	kit.check(towers.any(func(t : Building) -> bool: return _health(t) < 10.0), "the slam hurts a tower")

	#under a third of its health: Magma Call, once
	var blobs : Array[int] = [0]
	var count_blob : Callable = func(enemy : Enemy) -> void:
		if enemy.scene_file_path.ends_with(MAGMA_BLOB_FILE):
			blobs[0] += 1
	GameSignals.enemy_spawned.connect(count_blob)
	titan.stats.get_stat(Utils.StatType.Health).value = titan.stats.get_stat_value(Utils.StatType.MaxHealth) * 0.3
	var magma_call : EnemyAbility = titan.abilities.get_node("MagmaCall")
	await kit.run_until(func() -> bool: return magma_call.use_count > 0 and not magma_call.is_active, 10.0)
	GameSignals.enemy_spawned.disconnect(count_blob)
	kit.check(magma_call.use_count == 1, "Magma Call under 33%")
	kit.check(blobs[0] == 6, "six magma blobs rise (%d)" % blobs[0])


#(review, 2026-11-23): near the castle the Broodmother's Dig Up came up behind herself, or on the castle
func test_weak_spot_dig_never_goes_back_or_onto_the_castle(kit : TestKit) -> void:
	await kit.load_level(12)
	var brood : Enemy = kit.spawn_enemy("broodmother")
	var burrow : BurrowAbility = brood.find_children("*", "BurrowAbility", true, false).front() as BurrowAbility
	kit.check(burrow != null and burrow.seeks_weak_spot, "the Broodmother digs to a weak spot")
	var here : Vector2 = kit.level.grid.snap_position_to_grid(brood.global_position)
	var step : Vector2 = Vector2(Utils.TILE_SIZE, 0)
	brood.point_path = PackedVector2Array([here - step * 2, here - step, here, here + step])
	brood.current_waypoint_index = 2
	kit.check(burrow._get_weak_spot() == here, "within the castle margin: up where she is (%s)" % burrow._get_weak_spot())
	brood.queue_free()
