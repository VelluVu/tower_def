extends RefCounted

## The Scorched Lands' mechanics: lava cooling next to Frost (LavaField), fissures erupting (Fissure), sandstorms
## (Sandstorm).


func _lava_field(kit : TestKit) -> LavaField:
	return kit.level.get_node(Level.LAVA_FIELD_NAME)


func _range(tower : Building) -> float:
	return tower.stats.get_stat_value(Utils.StatType.AttackRange)


func test_volcano_levels_have_lava_that_cools(kit : TestKit) -> void:
	await kit.load_level(49)
	var lava_field : LavaField = _lava_field(kit)
	kit.check(lava_field != null, "level 49 has a lava field")
	var lava : Array[Vector2i] = kit.level.tiles.water_layer.get_used_cells()
	kit.check(not lava.is_empty(), "level 49 has lava")
	#a buildable cell next to lava, for the tower
	var spot : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)) \
			and LavaField.NEIGHBOURS.any(func(o : Vector2i) -> bool: return lava_field.is_lava(c + o)))
	kit.check(spot != Vector2i.MAX, "a buildable cell next to the lava")
	var tower : Building = await kit.place("puffe_beamer", spot)
	var target : Vector2i = spot + LavaField.NEIGHBOURS.filter(func(o : Vector2i) -> bool: return lava_field.is_lava(spot + o))[0]
	await kit.run_until(func() -> bool: return false, 3.0)
	kit.check(lava_field.is_lava(target), "a Physical tower does not cool lava")
	tower.evolve_tree.choose_element(Utils.Element.Frost)
	await kit.run_until(func() -> bool: return not lava_field.is_lava(target), LavaField.COOL_SECONDS + 3.0)
	kit.check(not lava_field.is_lava(target), "a Frost tower cools the lava next to it")
	var world : Vector2 = kit.level.grid.grid_position_to_world(target)
	kit.check(kit.level.grid.is_position_buildable(world) and not kit.level.grid.is_cell_walkable(target),
		"a cooled river is obsidian: buildable, not walkable")


func test_fissure_warns_erupts_burns_and_sets(kit : TestKit) -> void:
	await kit.load_level(52)
	var fissure : Fissure = kit.level.get_node("Fissure1")
	var lava_field : LavaField = _lava_field(kit)
	kit.check(fissure != null and lava_field != null, "level 52 has a fissure and a lava field")
	var cell : Vector2i = fissure.cells[0]
	var wall : Building = await kit.place("wall", cell)
	var full : float = wall.stats.get_stat_value(Utils.StatType.Health)
	GameSignals.wave_cleared.emit(2)
	kit.check(fissure.is_warning, "the wave before its eruption the fissure cracks")
	GameSignals.wave_started.emit(3)
	kit.check(not fissure.is_warning, "the warning goes when it erupts")
	kit.check(lava_field.is_lava(cell) and not kit.level.grid.is_cell_walkable(cell), "lava floods the cell")
	kit.check(not is_instance_valid(wall) or wall.is_dead or wall.stats.get_stat_value(Utils.StatType.Health) < full,
		"the wall on it burns")
	for spawner in kit.level.get_spawners():
		kit.check(kit.level.grid.reaches(spawner.global_position, spawner.end_point.global_position),
			"the road stays open from spawner %d" % spawner.id)
	GameSignals.wave_cleared.emit(3)
	GameSignals.wave_cleared.emit(4)
	kit.check(not lava_field.is_lava(cell) and kit.level.grid.is_cell_walkable(cell), "after its waves the lava sets into ground again")


func test_an_eruption_never_closes_every_road(kit : TestKit) -> void:
	await kit.load_level(52)
	var lava_field : LavaField = _lava_field(kit)
	#a whole column of the map: lava there would cut the map in two
	var column : Array[Vector2i] = []
	var middle : Vector2i = kit.level.grid.world_position_to_grid(kit.level.grid.get_playfield_rect().get_center())
	for y in range(-10, 11):
		column.append(Vector2i(middle.x + 2, middle.y + y))
	lava_field.erupt(column)
	for spawner in kit.level.get_spawners():
		kit.check(kit.level.grid.reaches(spawner.global_position, spawner.end_point.global_position),
			"spawner %d still has a road" % spawner.id)


#level 59's two fissures sit behind the only two gaps of its gate: both erupting at once must leave one open
#(found 2026-11-18: the road check took a partial path as open, the gate closed and the wave never ended)
func test_both_gate_fissures_leave_a_way_through(kit : TestKit) -> void:
	await kit.load_level(59)
	var lava_field : LavaField = _lava_field(kit)
	for child in kit.level.get_children():
		if child is Fissure:
			lava_field.erupt(child.cells)
	for spawner in kit.level.get_spawners():
		kit.check(kit.level.grid.reaches(spawner.global_position, spawner.end_point.global_position),
			"spawner %d still reaches the castle" % spawner.id)


func test_sandstorm_cuts_range_and_hides_flyers(kit : TestKit) -> void:
	await kit.load_level(38)
	var storm : Sandstorm = kit.level.get_node(Level.SANDSTORM_NAME)
	kit.check(storm != null and is_equal_approx(storm.every, 70.0), "level 38 has sandstorms every 70 s")
	var spot : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))
	var tower : Building = await kit.place("puffe_bolter", spot)
	var full_range : float = _range(tower)
	var drake : Enemy = kit.spawn_enemy("ash_drake")
	await kit.frames(1)
	storm.start()
	storm.band_x = tower.global_position.x - storm.band_width * 0.5
	drake.global_position = Vector2(tower.global_position.x, drake.global_position.y)
	storm._update_cover()
	kit.check_near(_range(tower), full_range * (1.0 + Sandstorm.RANGE_CUT), "a tower inside the storm sees 35% less far")
	kit.check(drake.is_concealed, "a flyer inside the storm is hidden")
	var picked : Node2D = TargetPicker.pick(Utils.TargetTactic.First, [drake] as Array[Node2D], tower.global_position)
	kit.check(picked == null, "and towers cannot pick it")
	storm._stop()
	kit.check_near(_range(tower), full_range, "the range comes back when the storm has passed")
	kit.check(not drake.is_concealed, "and the flyer shows again")


#a tower destroyed or sold inside the band broke the storm's cleanup (found by the 2026-11-21 sweep, levels 40 and 47)
func test_sandstorm_survives_a_freed_tower(kit : TestKit) -> void:
	await kit.load_level(38)
	var storm : Sandstorm = kit.level.get_node(Level.SANDSTORM_NAME)
	var spot : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))
	var tower : Building = await kit.place("puffe_bolter", spot)
	storm.start()
	storm.band_x = tower.global_position.x - storm.band_width * 0.5
	storm._update_cover()
	kit.check(storm.covered.size() == 1, "the tower is covered")
	tower.free()
	storm._stop()
	kit.check(storm.covered.is_empty(), "the storm lets go of a freed tower")
	kit.check(not storm.is_blowing, "and stops")


#Normal never locks the player into one element; Hard mixes in a faction with another weakness (2026-11-17)
func test_hard_mixes_in_other_factions(kit : TestKit) -> void:
	var data : LevelData = kit.level_data(40)
	var hard : LevelModeData = data.get_mode_data(Utils.LevelMode.Hard)
	kit.check(hard != null and not hard.added_groups.is_empty(), "level 40 has its own Hard with added groups")
	var names : Callable = func(waves : Array[WaveData], index : int) -> Array:
		return waves[index].spawn_groups.map(func(group : SpawnGroupData) -> String: return group.enemy_scene.resource_path.get_file().get_basename())
	var normal_wave : Array = names.call(data.waves, 1)
	var hard_wave : Array = names.call(hard.get_waves(data.waves), 1)
	kit.check(not normal_wave.has("cinder_imp"), "Normal wave 2 is the desert's own")
	kit.check(hard_wave.has("cinder_imp") and hard_wave.size() == normal_wave.size() + 1, "Hard wave 2 adds the volcano's imps (%s)" % str(hard_wave))
	kit.check(hard.get_waves(data.waves).size() == data.waves.size(), "and no waves are added")


func test_survival_fissures_erupt_every_loop(kit : TestKit) -> void:
	await kit.load_level(52)
	var fissure : Fissure = kit.level.get_node("Fissure1")
	var lava_field : LavaField = _lava_field(kit)
	var runner : WaveRunner = kit.level.wave_runner
	runner.is_endless = true
	var looped : int = runner.waves.size() + fissure.erupt_waves[0]
	var cell : Vector2i = fissure.cells[0]
	GameSignals.wave_cleared.emit(looped - 1)
	kit.check(fissure.is_warning, "the second loop warns before the same wave")
	GameSignals.wave_started.emit(looped)
	kit.check(lava_field.is_lava(cell), "and erupts again in Survival's second loop (wave %d)" % looped)


#(review, 2026-11-23): an early start never clears the wave it overtakes, and the warning and the settle hung on clears
func test_fissure_warns_and_sets_through_early_starts(kit : TestKit) -> void:
	await kit.load_level(52)
	var fissure : Fissure = kit.level.get_node("Fissure1")
	var lava_field : LavaField = _lava_field(kit)
	var erupts : int = fissure.erupt_waves[0]
	var cell : Vector2i = fissure.cells[0]
	GameSignals.wave_started.emit(erupts - 1)
	kit.check(fissure.is_warning, "the wave before warns from its start, no clear needed")
	GameSignals.wave_started.emit(erupts)
	kit.check(lava_field.is_lava(cell), "it erupts")
	#one wave short of the settle, then the settle's own wave: a second eruption on that wave would flood it again
	fissure.erupt_waves = [erupts]
	for wave in range(erupts + 1, erupts + fissure.lava_waves):
		GameSignals.wave_started.emit(wave)
	kit.check(lava_field.is_lava(cell), "still lava one wave short")
	GameSignals.wave_started.emit(erupts + fissure.lava_waves)
	kit.check(not lava_field.is_lava(cell), "the lava sets after lava_waves waves, all started early")


#(review, 2026-11-23): an eruption on cooled river rock left plain ground behind, a new road over the river
func test_erupted_obsidian_stays_obsidian(kit : TestKit) -> void:
	await kit.load_level(49)
	var lava_field : LavaField = _lava_field(kit)
	var river : Array[Vector2i] = kit.level.tiles.water_layer.get_used_cells()
	var cell : Vector2i = river[0]
	lava_field.cool(cell)
	kit.check(kit.level.grid.cell_overrides.get(cell, -1) == Utils.TileType.OnlyBuildable, "cooled river rock is build-only")
	lava_field.erupt([cell] as Array[Vector2i])
	if lava_field.is_lava(cell):
		lava_field.cool(cell)
	kit.check(kit.level.grid.cell_overrides.get(cell, -1) == Utils.TileType.OnlyBuildable, "and is again after an eruption cools")
	kit.check(not kit.level.grid.is_cell_walkable(cell), "no road over the river")
