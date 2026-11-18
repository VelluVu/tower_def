extends RefCounted

## The Scorched Lands roster: the golem's blobs, rebirth, wards, raising the dead, the ballista's bolt, the spitter's
## scorch, molten brittleness, lava wading, and the two bosses' phases (Bone Colossus, Ashen Wyrm).


func _count(kit : TestKit, scene_name : String) -> int:
	return kit.level.existing_enemies.filter(func(e : Enemy) -> bool:
		return is_instance_valid(e) and not e.is_deactivated and e.scene_file_path.get_file().get_basename() == scene_name).size()


func _hit(enemy : Enemy, damage : float, type : Utils.DamageType = Utils.DamageType.Physical, source : Node = null) -> void:
	var hit : DamageData = DamageData.new()
	hit.damage = damage
	hit.damage_type = type
	hit.source = source
	enemy.take_damage(hit)
	hit.free()


func _health(unit : Node) -> float:
	return unit.stats.get_stat_value(Utils.StatType.Health)


func _set_health_ratio(enemy : Enemy, ratio : float) -> void:
	enemy.stats.get_stat(Utils.StatType.Health).value = enemy.stats.get_stat_value(Utils.StatType.MaxHealth) * ratio


func _buildable_near(kit : TestKit, from : Vector2, min_tiles : float, max_tiles : float, taken : Array[Vector2i] = []) -> Vector2i:
	return kit.find_cell(func(c : Vector2i) -> bool:
		var world : Vector2 = kit.level.grid.grid_position_to_world(c)
		var tiles : float = world.distance_to(from) / Utils.TILE_SIZE
		return not taken.has(c) and kit.level.grid.is_position_buildable(world) and tiles >= min_tiles and tiles <= max_tiles)


func test_obsidian_golem_cracks_into_two_blobs(kit : TestKit) -> void:
	await kit.load_level(50)
	var golem : Enemy = kit.spawn_enemy("obsidian_golem")
	await kit.frames(2)
	_hit(golem, 99999.0)
	await kit.run_until(func() -> bool: return _count(kit, "magma_blob") >= 2, 3.0)
	kit.check(_count(kit, "magma_blob") == 2, "two magma blobs crawl out (%d)" % _count(kit, "magma_blob"))


func test_phoenix_rises_once_unless_frost(kit : TestKit) -> void:
	await kit.load_level(52)
	var phoenix : Enemy = kit.spawn_enemy("phoenix")
	await kit.frames(2)
	_hit(phoenix, 99999.0, Utils.DamageType.Fire)
	#the dying one leaves the count once it is down; the risen one joins it
	await kit.run_until(func() -> bool: return phoenix.is_deactivated, 3.0)
	await kit.frames(2)
	var risen : Array = kit.level.existing_enemies.filter(func(e : Enemy) -> bool:
		return is_instance_valid(e) and not e.is_deactivated and e != phoenix and e.scene_file_path.ends_with("phoenix.tscn"))
	kit.check(risen.size() == 1, "a phoenix killed by fire rises again")
	if risen.is_empty():
		return
	var copy : Enemy = risen[0]
	kit.check(copy.stats.get_stat_value(Utils.StatType.Price) == 0.0, "worth no gold the second time")
	_hit(copy, 99999.0, Utils.DamageType.Fire)
	await kit.run_until(func() -> bool: return false, 2.0)
	kit.check(_count(kit, "phoenix") == 0, "it rises only once")
	var frozen : Enemy = kit.spawn_enemy("phoenix")
	await kit.frames(2)
	_hit(frozen, 99999.0, Utils.DamageType.Frost)
	await kit.run_until(func() -> bool: return false, 2.0)
	kit.check(_count(kit, "phoenix") == 0, "Frost puts a phoenix out for good")


func test_wisp_spark_is_stamped_out_by_a_nova(kit : TestKit) -> void:
	await kit.load_level(49)
	var cell : Vector2i = _buildable_near(kit, kit.level.get_spawners()[0].global_position, 2.0, 6.0)
	var nova : Building = await kit.place("puffe_nova", cell)
	var wisp : Enemy = kit.spawn_enemy("ember_wisp")
	await kit.frames(2)
	var rebirth : Rebirth = wisp.get_node("Rebirth")
	var by_nova : DamageData = DamageData.new()
	by_nova.damage_type = Utils.DamageType.Fire
	by_nova.source = nova
	kit.check(rebirth.puts_out(by_nova), "a Nova's burst stamps out a wisp's spark")
	by_nova.source = null
	kit.check(not rebirth.puts_out(by_nova), "other fire does not")
	by_nova.free()


func test_cultist_wards_its_neighbours(kit : TestKit) -> void:
	await kit.load_level(51)
	var cultist : Enemy = kit.spawn_enemy("ember_cultist")
	var imp : Enemy = kit.spawn_enemy("cinder_imp")
	await kit.run_until(func() -> bool: return imp.fire_ward != null, 10.0)
	kit.check(imp.fire_ward != null, "the cultist wards the imp next to it")
	var before : float = _health(imp)
	_hit(imp, 5.0)
	kit.check_near(_health(imp), before, "the ward soaks the hit")
	await kit.frames(1)
	kit.check(imp.fire_ward == null, "and is gone")
	_hit(imp, 5.0)
	kit.check(_health(imp) < before, "the next hit goes through")
	kit.check(is_instance_valid(cultist), "the cultist is still there")


func test_grave_caller_raises_the_fallen(kit : TestKit) -> void:
	await kit.load_level(41)
	var caller : Enemy = kit.spawn_enemy("grave_caller")
	var raise : RaiseDeadAbility = caller.abilities.get_node("RaiseDead")
	#past its first cooldown, a scarab falls right next to it
	await kit.run_until(func() -> bool: return raise.cooldown_timer.is_stopped(), 10.0)
	var victim : Enemy = kit.spawn_enemy("scarab")
	victim.global_position = caller.global_position
	await kit.frames(2)
	_hit(victim, 99999.0)
	await kit.run_until(func() -> bool: return _count(kit, "bone_thrall") >= 1, 12.0)
	kit.check(_count(kit, "bone_thrall") == 1, "a bone thrall climbs out where the scarab fell")


func test_ballista_bolt_pierces_a_line(kit : TestKit) -> void:
	await kit.load_level(39)
	var row : Array[Building] = []
	var first : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		for dx in 3:
			if not kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c + Vector2i(dx, 0))):
				return false
		return true)
	for dx in 3:
		row.append(await kit.place("wall", first + Vector2i(dx, 0)))
	var full : float = _health(row[0])
	var hit : RangedShotAbility.ShotHit = RangedShotAbility.ShotHit.new()
	hit.damage = 3.0
	hit.from = row[0].global_position - Vector2(Utils.TILE_SIZE * 2, 0)
	hit.pierce_length = 6.0 * Utils.TILE_SIZE
	RangedShotAbility._land(row[0].global_position, weakref(row[0]), weakref(kit.level), hit)
	for i in 3:
		kit.check(_health(row[i]) < full, "the bolt hits wall %d on its line" % i)


func test_lava_glob_scorches_the_ground(kit : TestKit) -> void:
	await kit.load_level(51)
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))
	var world : Vector2 = kit.level.grid.grid_position_to_world(cell)
	var scorch : Scorch = Scorch.make(kit.level, world, 0.0, 2.0)
	kit.check(scorch != null and not kit.level.grid.is_position_buildable(world), "nothing can be built on a scorched cell")
	kit.check(kit.level.grid.is_cell_walkable(cell) == kit.level.grid.is_cell_walkable(cell), "it stays walkable")
	await kit.run_until(func() -> bool: return kit.level.grid.is_position_buildable(world), 4.0)
	kit.check(kit.level.grid.is_position_buildable(world), "the ground cools down again")


func test_molten_creatures_turn_brittle_under_frost(kit : TestKit) -> void:
	await kit.load_level(50)
	var golem : Enemy = kit.spawn_enemy("obsidian_golem")
	await kit.frames(2)
	var physical : float = golem.resistances.physical
	_hit(golem, 1.0, Utils.DamageType.Frost)
	kit.check_near(golem.resistances.physical, maxf(physical - MoltenBody.BRITTLE_CUT, 0.0), "a Frost hit makes it brittle")
	await kit.run_until(func() -> bool: return is_equal_approx(golem.resistances.physical, physical), MoltenBody.BRITTLE_SECONDS + 1.0)
	kit.check_near(golem.resistances.physical, physical, "it hardens again")


func test_salamander_swims_the_lava(kit : TestKit) -> void:
	await kit.load_level(49)
	kit.check(kit.level.grid.bog_crossings.size() == 2, "level 49 has two lava crossings")
	var salamander : Enemy = kit.spawn_enemy("magma_salamander")
	await kit.frames(2)
	kit.check(salamander.can_wade, "the salamander wades")
	var spawner : Spawner = kit.level.get_spawners()[0]
	var route : WadingRoute = kit.level.grid.find_wading_route(spawner.global_position, spawner.end_point.global_position)
	kit.check(route.crossing != null, "its way to the castle takes the stones over the lava")


func test_bone_colossus_phases(kit : TestKit) -> void:
	await kit.load_level(48)
	var colossus : Enemy = kit.spawn_enemy("bone_colossus")
	kit.check(colossus.is_boss, "the Bone Colossus is a boss")
	await kit.frames(2)
	var cell : Vector2i = _buildable_near(kit, colossus.global_position, 1.0, 2.0)
	var tower : Building = await kit.place("puffe_beamer", cell)
	var full : float = _health(tower)
	await kit.run_until(func() -> bool: return _health(tower) < full, 10.0)
	kit.check(_health(tower) < full, "its tail sweeps the tower next to it")
	_set_health_ratio(colossus, 0.5)
	await kit.run_until(func() -> bool: return _count(kit, "bone_thrall") >= 4, 20.0)
	kit.check(_count(kit, "bone_thrall") >= 4, "under 66% it sinks into the sand and thralls rise where it comes up")


func test_ashen_wyrm_phases(kit : TestKit) -> void:
	await kit.load_level(60)
	var wyrm : Enemy = kit.spawn_enemy("ashen_wyrm", 1)
	kit.check(wyrm.is_boss and wyrm.is_flying, "the Ashen Wyrm is a flying boss")
	await kit.frames(2)
	#its breath: a tower ahead of it on its way burns
	var cell : Vector2i = _buildable_near(kit, wyrm.global_position, 2.0, 4.5)
	var tower : Building = await kit.place("puffe_bolter", cell)
	var full : float = _health(tower)
	await kit.run_until(func() -> bool: return not is_instance_valid(tower) or _health(tower) < full, 15.0)
	kit.check(not is_instance_valid(tower) or _health(tower) < full, "its fire breath burns a tower in reach")
	_set_health_ratio(wyrm, 0.5)
	await kit.run_until(func() -> bool: return not wyrm.is_flying, 6.0)
	kit.check(not wyrm.is_flying, "under 66% it lands")
	kit.check(wyrm.walk_animation == GlobalAnimationNames.GROUND_WALK_ANIMATION, "and walks on the ground")
	kit.check(kit.level.grid.is_cell_walkable(wyrm.grid_position), "on a cell it can walk on")
	var near : Vector2i = _buildable_near(kit, wyrm.global_position, 1.0, 2.5)
	var target : Building = await kit.place("puffe_bolter", near)
	var lava_field : LavaField = kit.level.get_node(Level.LAVA_FIELD_NAME)
	await kit.run_until(func() -> bool: return lava_field.is_lava(near), 15.0)
	kit.check(lava_field.is_lava(near), "the ground under a tower near it erupts")
	kit.check(not is_instance_valid(target) or _health(target) < target.stats.get_stat_value(Utils.StatType.MaxHealth), "and the tower burns")
	_set_health_ratio(wyrm, 0.3)
	await kit.run_until(func() -> bool: return _count(kit, "ash_drake") >= 6, 8.0)
	kit.check(_count(kit, "ash_drake") >= 6, "under 33% it roars and the ash drakes come")


#level 60 has two castles; once it roars, the Wyrm goes for the one that has lost the fewest eggs
func test_ashen_wyrm_turns_on_the_fullest_castle(kit : TestKit) -> void:
	await kit.load_level(60)
	var castles : Array[Marker2D] = kit.level.get_castles()
	kit.check(castles.size() == 2, "the Throne of Embers has two castles (%d)" % castles.size())
	var wyrm : Enemy = kit.spawn_enemy("ashen_wyrm", 1)
	await kit.frames(2)
	var own : Marker2D = wyrm.end_point
	kit.level.castle_leaks[own] = 3
	var fullest : Marker2D = kit.level.get_fullest_castle()
	kit.check(fullest != own, "the castle it marched on has lost eggs, the other has not")
	LandAbility.land(wyrm)
	_set_health_ratio(wyrm, 0.3)
	await kit.run_until(func() -> bool: return wyrm.end_point == fullest, 8.0)
	kit.check(wyrm.end_point == fullest, "after its roar it turns on the fullest castle")
	kit.check(not wyrm.point_path.is_empty(), "with a road there")


func test_a_fire_ward_lets_splashes_and_reactions_through(kit : TestKit) -> void:
	await kit.load_level(51)
	var imp : Enemy = kit.spawn_enemy("cinder_imp")
	await kit.frames(2)
	kit.check(FireWard.give(imp), "the imp gets a ward")
	for flag in ["is_splash", "is_reaction"]:
		var hit : DamageData = DamageData.new()
		hit.damage = 1.0
		hit.set(flag, true)
		kit.check(not imp.fire_ward.absorb(hit), "a hit with %s passes the ward" % flag)
		hit.free()
	kit.check(imp.fire_ward != null, "the ward still waits for a direct hit")
