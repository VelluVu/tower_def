extends RefCounted

## The synergies (design doc "Synergies", 2026-11-25): each rule on its own, mostly called straight on the level's
## Synergies node so the numbers are exact.


## Free buildable route cells along the first route, in walking order.
func _route_cells(kit : TestKit) -> Array[Vector2i]:
	var cells : Array[Vector2i] = []
	var route : PackedVector2Array = kit.level.get_routes()[0]
	for point in kit.level.grid.find_path(route[0], route[1]).slice(4):
		var cell : Vector2i = kit.level.grid.world_position_to_grid(point)
		if kit.level.grid.is_position_buildable(point) and not kit.level.grid.has_building_in_cell_position(cell):
			cells.append(cell)
	return cells


## Three route cells in a row (each beside the next).
func _row(kit : TestKit) -> Array[Vector2i]:
	var cells : Array[Vector2i] = _route_cells(kit)
	for i in cells.size() - 2:
		if _is_beside(cells[i], cells[i + 1]) and _is_beside(cells[i + 1], cells[i + 2]):
			return [cells[i], cells[i + 1], cells[i + 2]]
	return []


func _is_beside(a : Vector2i, b : Vector2i) -> bool:
	var gap : Vector2i = (a - b).abs()
	return maxi(gap.x, gap.y) <= 1 and a != b


## A free buildable cell off the routes within reach tiles of near.
func _cell_near(kit : TestKit, near : Vector2i, reach : float) -> Vector2i:
	var on_route : Dictionary = {}
	for route in kit.level.get_routes():
		for point in kit.level.grid.find_path(route[0], route[1]):
			on_route[kit.level.grid.world_position_to_grid(point)] = true
	return kit.find_cell(func(cell : Vector2i) -> bool:
		return not on_route.has(cell) and cell != near and Vector2(cell - near).length() <= reach \
			and kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(cell)) \
			and not kit.level.grid.has_building_in_cell_position(cell))


func _enemy_at(kit : TestKit, at : Vector2) -> Enemy:
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	enemy.global_position = at
	for stat_type in [Utils.StatType.MaxHealth, Utils.StatType.Health]:
		enemy.stats.get_stat(stat_type).value = 500.0
	return enemy


func _hit_from(source : Building, damage : float) -> DamageData:
	var hit : DamageData = DamageData.new()
	hit.source = source
	hit.damage = damage
	return hit


func test_trap_line(kit : TestKit) -> void:
	await kit.load_level(8)
	var row : Array[Vector2i] = _row(kit)
	kit.check(row.size() == 3, "three route cells in a row")
	var spikes : Building = await kit.place("spike_field", row[0])
	var leopard : Building = await kit.place("leopard_trap", row[1])
	var egg : Building = await kit.place("egg_bomb", row[2])
	await kit.frames(2)
	var synergies : Synergies = kit.level.synergies
	kit.check_near(synergies.get_bonus(leopard, &"trap_line"), 0.2, "the Leopard has two other kinds beside it")
	kit.check(synergies.get_bonus(spikes, &"trap_line") >= 0.1, "the spikes have at least the Leopard")
	GameSignals.sell_building.emit(egg)
	await kit.frames(3)
	kit.check_near(synergies.get_bonus(leopard, &"trap_line"), 0.1, "the egg sold: one kind left")


func test_hoard_guardian(kit : TestKit) -> void:
	await kit.load_level(37)
	var route : Array[Vector2i] = _route_cells(kit)
	var elder_cell : Vector2i = _cell_near(kit, route[3], 2.0)
	var elder : Building = await kit.place("puffe_elder", elder_cell)
	var keeper : Building = await kit.place("puffe_hoard", _cell_near(kit, elder_cell, 2.0))
	await kit.frames(2)
	kit.check(keeper.is_placed, "a Hoard Keeper beside the Elder Drake")
	kit.check_near(kit.level.synergies.get_bonus(elder, &"hoard"), 0.1, "the Elder guards its hoard: +10% damage")


func test_pinned_doubles_the_spikes(kit : TestKit) -> void:
	await kit.load_level(8)
	var row : Array[Vector2i] = _row(kit)
	var spikes : Building = await kit.place("spike_field", row[0])
	var leopard : Building = await kit.place("leopard_trap", row[1])
	var enemy : Enemy = await _enemy_at(kit, spikes.global_position)
	var synergies : Synergies = kit.level.synergies
	var spike_hit : DamageData = _hit_from(spikes, 3.0)
	kit.check_near(synergies.get_damage_factor(enemy, spike_hit), 1.0, "spikes alone hit as usual")
	var snap : DamageData = _hit_from(leopard, 5.0)
	synergies._on_enemy_hit(enemy, snap)
	kit.check_near(synergies.get_damage_factor(enemy, spike_hit), Synergies.PINNED_FACTOR, "a snapped enemy takes double from the spikes")
	synergies.game_time += Synergies.SNAP_SECONDS + 0.1
	kit.check_near(synergies.get_damage_factor(enemy, spike_hit), 1.0, "and only while the snap holds")
	snap.free()
	spike_hit.free()


func test_bait_lights_the_egg(kit : TestKit) -> void:
	await kit.load_level(8)
	var row : Array[Vector2i] = _row(kit)
	var leopard : Building = await kit.place("leopard_trap", row[0])
	var egg : EggBomb = await kit.place("egg_bomb", row[1])
	var enemy : Enemy = await _enemy_at(kit, leopard.global_position)
	kit.check(egg.skill.is_ready, "the egg waits")
	var snap : DamageData = _hit_from(leopard, 5.0)
	kit.level.synergies._on_enemy_hit(enemy, snap)
	snap.free()
	kit.check(not egg.skill.is_ready, "the Leopard's snap lit its fuse")


func test_shrapnel_bed_and_pushed_onto_spikes(kit : TestKit) -> void:
	await kit.load_level(8)
	var row : Array[Vector2i] = _row(kit)
	var spikes : Trap = await kit.place("spike_field", row[0])
	var egg : EggBomb = await kit.place("egg_bomb", row[1])
	spikes.skill.is_ready = false
	spikes.skill.cooldown_timer.start()
	kit.level.synergies.on_egg_blast(egg)
	kit.check(spikes.skill.is_ready, "the blast beside it re-arms the spikes at once")
	spikes.skill.is_ready = false
	spikes.skill.cooldown_timer.start()
	var enemy : Enemy = await _enemy_at(kit, spikes.global_position)
	kit.level.synergies.on_knocked_back(enemy)
	kit.check(spikes.is_dead or spikes.skill.is_ready or not spikes.skill.cast_timer.is_stopped(), "an enemy pushed onto the spikes sets them off")


func test_torn_and_marked(kit : TestKit) -> void:
	await kit.load_level(8)
	var enemy : Enemy = await _enemy_at(kit, kit.level.get_spawners()[0].global_position)
	kit.check_near(Synergies.get_execute_bonus(enemy), 0.0, "no shred, no bonus")
	for i in Shredder.MAX_STACKS:
		ResistanceShred.give(enemy, Shredder.SHRED_PER_STACK, Shredder.MAX_STACKS, Shredder.SHRED_SECONDS)
	kit.check_near(Synergies.get_execute_bonus(enemy), Synergies.TORN_EXECUTE, "three stacks: the execute reaches 8 points higher")


func test_pinned_target_and_grounded(kit : TestKit) -> void:
	await kit.load_level(19)
	var route : Array[Vector2i] = _route_cells(kit)
	var harpooner : Building = await kit.place("puffe_harpooner", _cell_near(kit, route[2], 2.0))
	var trap : Building = await kit.place("leopard_trap", route[2])
	var enemy : Enemy = await _enemy_at(kit, kit.level.grid.grid_position_to_world(route[0]))
	var synergies : Synergies = kit.level.synergies
	kit.check_near(synergies.get_blast_share(enemy, 0.6), 0.6, "an untethered enemy keeps its falloff")
	HarpoonTether.attach(enemy, harpooner, 2.0, 0.5)
	kit.check_near(synergies.get_blast_share(enemy, 0.6), 1.0, "a tethered one takes the full blast")
	enemy.global_position = trap.global_position + Vector2(Utils.TILE_SIZE, 0)
	synergies.on_grounded(enemy)
	kit.check(enemy.global_position.distance_to(trap.global_position) < 1.0, "a grounded enemy lands on the nearest trap")


func test_spotted_shells_follow_the_path(kit : TestKit) -> void:
	await kit.load_level(8)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.run_until(func() -> bool: return enemy.linear_velocity.length() > 1.0, 3.0)
	EnemyMarks.mark(enemy, Utils.DamageType.Fire, 0.1)
	var predicted : Vector2 = Synergies.predict_on_path(enemy, MortarShell.FLIGHT_SECONDS)
	kit.check(predicted.distance_to(enemy.global_position) > 1.0, "a marked walker is read ahead along its path")
	kit.check(MortarShell.get_landing_position(enemy, Vector2.ZERO).distance_to(predicted) < 0.01, "and the shell lands there")


func test_ground_reactions(kit : TestKit) -> void:
	await kit.load_level(8)
	var route : Array[Vector2i] = _route_cells(kit)
	var bolter : Building = await kit.place("puffe_bolter", _cell_near(kit, route[3], 2.0))
	var at : Vector2 = kit.level.grid.grid_position_to_world(route[3])
	var enemy : Enemy = await _enemy_at(kit, at)
	enemy.freeze_for(5.0)
	var poison : GroundPatch = GroundPatch.make(at, bolter, Utils.DamageType.Poison, 10.0, 0.2, 3.0)
	await kit.frames(1)
	GroundPatch.make(at, bolter, Utils.DamageType.Fire, 10.0, 0.2, 3.0)
	kit.check(enemy.stats.get_stat_value(Utils.StatType.Health) < 500.0, "fire meeting poison bursts")
	kit.check(poison.is_queued_for_deletion(), "and both patches burn out")
	GroundPatch.make(at, bolter, Utils.DamageType.Frost, 10.0, 0.2, 3.0)
	await kit.frames(1)
	GroundPatch.make(at, bolter, Utils.DamageType.Fire, 10.0, 0.2, 3.0)
	kit.check(enemy.is_numb, "fire meeting a chill patch makes steam: the enemy cannot attack")
	#a Frostplague numb at the same time outlasts the steam (bug 2026-11-25: the steam's end lifted it)
	enemy.add_numb()
	kit.level.synergies.game_time += Synergies.STEAM_SECONDS + 0.1
	await kit.frames(2)
	kit.check(enemy.is_numb, "the steam clears but the other numb holds")
	enemy.remove_numb()
	kit.check(not enemy.is_numb, "and then it can attack again")


func test_cold_feet(kit : TestKit) -> void:
	await kit.load_level(8)
	var spikes : Trap = await kit.place("spike_field", _route_cells(kit)[2])
	#attack speed lands on the skill's own stat (ModifierManager writes the result there)
	var speed : float = spikes.skill.stats.get_stat_value(Utils.StatType.AttackSpeed)
	kit.level.synergies.update_cold_feet(spikes, true)
	kit.check_near(spikes.skill.stats.get_stat_value(Utils.StatType.AttackSpeed), speed + Synergies.COLD_FEET_ATTACK_SPEED, "chilled feet: faster spikes")
	kit.level.synergies.update_cold_feet(spikes, false)
	kit.check_near(spikes.skill.stats.get_stat_value(Utils.StatType.AttackSpeed), speed, "and back once nothing chilled stands there")


func test_hold_the_line(kit : TestKit) -> void:
	await kit.load_level(11)
	var route : Array[Vector2i] = _route_cells(kit)
	# past the bridge: the humans' barricade (2026-11-25) stands by the route's first cells
	var hatchery : Hatchery = await kit.place("puffe_hatchery", _cell_near(kit, route[14], 1.5))
	var trap_cell : Vector2i = Utils.BAD_CELL
	for cell in route:
		if hatchery.is_valid_rally_cell(cell) and cell != hatchery.find_auto_rally_cell():
			trap_cell = cell
			break
	kit.check(trap_cell != Utils.BAD_CELL, "a second route cell in the Hatchery's reach")
	await kit.place("leopard_trap", trap_cell)
	kit.check(hatchery.find_auto_rally_cell() == trap_cell, "the guards rally on the trap")


func test_war_cry(kit : TestKit) -> void:
	await kit.load_level(37)
	var route : Array[Vector2i] = _route_cells(kit)
	var elder_cell : Vector2i = _cell_near(kit, route[3], 2.0)
	var elder : ElderDrake = await kit.place("puffe_elder", elder_cell)
	var buffer : Buffer = await kit.place("puffe_buffer", _cell_near(kit, elder_cell, 1.5))
	elder.is_breath_ready = false
	kit.level.synergies.on_roar(buffer)
	kit.check(elder.is_breath_ready, "the roar readies the Elder's breath")
	elder.is_breath_ready = false
	kit.level.synergies.on_roar(buffer)
	kit.check(not elder.is_breath_ready, "once a wave")
	GameSignals.wave_started.emit(2)
	kit.level.synergies.on_roar(buffer)
	kit.check(elder.is_breath_ready, "a new wave, a new war cry")


func test_firebreath_corridor(kit : TestKit) -> void:
	await kit.load_level(14)
	var route : Array[Vector2i] = _route_cells(kit)
	var breather : Building = await kit.place("puffe_breather", _cell_near(kit, route[4], 1.5))
	var wall : Wall = await kit.place("wall", _cell_near(kit, kit.level.grid.world_position_to_grid(breather.global_position), 1.5))
	var breath : Breath = breather.skill as Breath
	breath.direction = breather.global_position.direction_to(wall.global_position)
	kit.check(not kit.level.synergies.is_fire_corridor(breath), "a plain wall is no corridor")
	wall.set_element(Utils.Element.Fire)
	kit.check(kit.level.synergies.is_fire_corridor(breath), "a Fire wall in the cone is")
	var enemy : Enemy = await _enemy_at(kit, breather.global_position)
	kit.level.synergies.corridor_burn(enemy, breather, 10.0)
	kit.check(not enemy.overtime_effect_handler.get_active_stacks(Utils.DamageType.Fire).is_empty(), "the gust sets it burning")


func test_harmony_doubles_the_buffer_element(kit : TestKit) -> void:
	await kit.load_level(27)
	var route : Array[Vector2i] = _route_cells(kit)
	var bolter_cell : Vector2i = _cell_near(kit, route[3], 2.0)
	var bolter : Building = await kit.place("puffe_bolter", bolter_cell)
	var buffer : Buffer = await kit.place("puffe_buffer", _cell_near(kit, bolter_cell, 1.5))
	kit.level.player_stats.gold = 999
	_buy_element(kit, buffer, "FireElementEvolveLeaf")
	await kit.frames(2)
	var chance : float = buffer.get_pass_chance()
	kit.check(chance > 0.0, "a Fire Buffer passes its element on")
	kit.check_near(kit.level.buffer_auras.pass_on.get(bolter.get_instance_id(), {}).get(Utils.Element.Fire, 0.0), chance,
		"to a Bolter without an element at its own chance")
	_buy_element(kit, bolter, "FireElementEvolveLeaf")
	kit.level.buffer_auras.refresh()
	kit.check_near(kit.level.buffer_auras.pass_on.get(bolter.get_instance_id(), {}).get(Utils.Element.Fire, 0.0), minf(chance * 2.0, 1.0),
		"a Fire Bolter gets twice the chance")


## Buys upgrades on the building until its element leaf is on offer, then that leaf.
func _buy_element(kit : TestKit, building : Building, leaf_name : String) -> void:
	var upgrades : BuildingTypeUpgrades = kit.level.building_type_upgrades
	upgrades._on_unit_selected(building)
	for step in 8:
		var options : Array[GoldUpgradeOption] = upgrades.options
		for i in options.size():
			if str(options[i].element_leaf_path).ends_with(leaf_name):
				upgrades._on_gold_upgrade_pressed(i)
				return
		if options.is_empty():
			return
		upgrades._on_gold_upgrade_pressed(0)
