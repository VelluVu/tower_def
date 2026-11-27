extends RefCounted

## The Buffer (2026-11-24): a support tower that buffs the towers and traps in its aura with the pips bought on its
## tracks; several Buffers never stack, its element rides on buffed hits, T2 weakens enemies in the aura.


func _buildable(kit : TestKit, taken : Array[Vector2i]) -> Vector2i:
	return kit.find_cell(func(c : Vector2i) -> bool:
		return not taken.has(c) and kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))


#a buildable cell this many cells to the right of from (or Vector2i.MAX)
func _cell_beside(kit : TestKit, from : Vector2i, max_distance : int, min_distance : int, taken : Array[Vector2i]) -> Vector2i:
	return kit.find_cell(func(c : Vector2i) -> bool:
		var distance : float = Vector2(c - from).length()
		return not taken.has(c) and distance <= max_distance and distance >= min_distance \
			and kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))


func _damage_additive(building : Building) -> float:
	var total : float = 0.0
	for data in building.stats.get_stat(Utils.StatType.Damage).additive_modifiers:
		total += data.value
	return total


func _settle(kit : TestKit) -> void:
	await kit.frames(2)


func test_buffer_is_support(kit : TestKit) -> void:
	await kit.load_level(1)
	var buffer : Buffer = await kit.place("puffe_buffer", _buildable(kit, []))
	kit.check(buffer.skill.skill_type == Utils.SkillType.Support, "its skill is a passive aura")
	kit.check(TalentEffect.get_building_flag(buffer) == TalentEffect.BUFFER, "talents see it as a Buffer")
	kit.check(buffer.radius > Utils.TILE_SIZE, "its aura reaches past its own cell")
	var card : EvolveResource = load("res://scenes/unit/evolve_tree/evolve_resources/damage.tres")
	kit.check(not UpgradeRules.fits_tower(card, buffer.skill, Utils.Element.Physical, 99), "no card fits a Buffer")
	var list : BuildingListElement = load("res://scenes/unit/building/buildings/puffe_buffer.tres")
	kit.check(list.unlock_level == 27, "it unlocks on level 27")


func test_pips_budget_and_tracks(kit : TestKit) -> void:
	await kit.load_level(1)
	var buffer : Buffer = await kit.place("puffe_buffer", _buildable(kit, []))
	for i in Buffer.MAX_PIPS + 2:
		buffer.add_pip(Utils.StatType.Damage)
	kit.check(buffer.get_pips(Utils.StatType.Damage) == Buffer.MAX_PIPS, "a track stops at %d" % Buffer.MAX_PIPS)
	for i in 10:
		buffer.add_pip(Utils.StatType.AttackSpeed)
	kit.check(buffer.total_pips == Buffer.PIP_BUDGET, "the budget stops at %d pips (%d)" % [Buffer.PIP_BUDGET, buffer.total_pips])
	kit.check_near(buffer.get_buff(Utils.StatType.Damage), Buffer.MAX_PIPS * 0.06, "five damage pips")


func test_aura_buffs_towers_in_reach_and_takes_the_strongest(kit : TestKit) -> void:
	await kit.load_level(1)
	var taken : Array[Vector2i] = []
	var buffer_cell : Vector2i = _buildable(kit, taken)
	taken.append(buffer_cell)
	var buffer : Buffer = await kit.place("puffe_buffer", buffer_cell)
	var near_cell : Vector2i = _cell_beside(kit, buffer_cell, 1, 1, taken)
	taken.append(near_cell)
	var near : Building = await kit.place("puffe_bolter", near_cell)
	var far_cell : Vector2i = _cell_beside(kit, buffer_cell, 99, 6, taken)
	taken.append(far_cell)
	var far : Building = await kit.place("puffe_bolter", far_cell)
	var base_near : float = _damage_additive(near)
	buffer.add_pip(Utils.StatType.Damage)
	buffer.add_pip(Utils.StatType.Damage)
	#a Buffer throws its buffs (2026-11-26): one throw reaches the one tower in reach
	buffer.throw_buff()
	await _settle(kit)
	kit.check_near(_damage_additive(near) - base_near, 0.12, "two damage pips on the tower in reach")
	kit.check_near(_damage_additive(far), 0.0, "nothing on the tower out of reach")

	var second_cell : Vector2i = _cell_beside(kit, near_cell, 1, 1, taken)
	taken.append(second_cell)
	var second : Buffer = await kit.place("puffe_buffer", second_cell)
	second.add_pip(Utils.StatType.Damage)
	second.throw_buff()
	await _settle(kit)
	kit.check_near(_damage_additive(near) - base_near, 0.12, "a weaker second Buffer adds nothing")
	for i in 3:
		second.add_pip(Utils.StatType.Damage)
	await _settle(kit)
	kit.check_near(_damage_additive(near) - base_near, 0.24, "the stronger one counts, never the sum")

	GameSignals.sell_building.emit(second)
	GameSignals.sell_building.emit(buffer)
	await _settle(kit)
	kit.check_near(_damage_additive(near) - base_near, 0.0, "selling the Buffers takes their buffs away")


func test_buffer_buttons(kit : TestKit) -> void:
	await kit.load_level(1)
	var buffer : Buffer = await kit.place("puffe_buffer", _buildable(kit, []))
	kit.level.player_stats.gold = 999
	var upgrades : BuildingTypeUpgrades = kit.level.building_type_upgrades
	upgrades._on_unit_selected(buffer)
	kit.check(upgrades.options.size() == Buffer.TRACKS.size(), "one button per track (%d)" % upgrades.options.size())
	kit.check(upgrades.options.all(func(o : GoldUpgradeOption) -> bool: return o.buffer_stat >= 0), "every button is a pip")
	var first_price : float = upgrades.options[0].cost
	UISignals.gold_upgrade_pressed.emit(0)
	kit.check(buffer.get_pips(Buffer.TRACKS[0]) == 1, "a press buys a pip on its track")
	kit.check(upgrades.options[0].cost >= first_price, "the next pip costs at least as much")
	UISignals.gold_upgrade_pressed.emit(1)
	var elements : int = upgrades.options.filter(func(o : GoldUpgradeOption) -> bool: return o.is_evolve).size()
	kit.check(elements == 4, "after 2 pips the four elements show beside the tracks (%d)" % elements)
	for i in upgrades.options.size():
		if str(upgrades.options[i].element_leaf_path).ends_with("FireElementEvolveLeaf"):
			UISignals.gold_upgrade_pressed.emit(i)
			break
	kit.check(buffer.element == Utils.Element.Fire and buffer.tier == 1, "the Fire element is bought")
	kit.check(buffer.get_pass_chance() > 0.0, "a Fire Buffer passes its element on")


func test_element_rides_on_buffed_hits(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await kit.place("puffe_bolter", _buildable(kit, []))
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	kit.level.buffer_auras.pass_on[bolter.get_instance_id()] = {Utils.Element.Fire: 1.0}
	kit.level.buffer_auras.on_direct_hit(enemy, bolter, 5.0)
	var stacks : Array[OvertimeEffect] = enemy.overtime_effect_handler.get_active_stacks(Utils.DamageType.Fire)
	kit.check(not stacks.is_empty(), "a buffed hit set the enemy burning")
	kit.check(not stacks.is_empty() and stacks[0].source == bolter, "the burn counts as the buffed tower's")


func test_t2_weakens_enemies_in_the_aura(kit : TestKit) -> void:
	await kit.load_level(1)
	var buffer : Buffer = await kit.place("puffe_buffer", _buildable(kit, []))
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	enemy.global_position = buffer.global_position + Vector2(8.0, 0.0)
	await _settle(kit)
	kit.check_near(kit.level.buffer_auras.get_weakness(enemy), 0.0, "no weakening before T2")
	buffer.evolve_tree.tier = 2
	await _settle(kit)
	kit.check_near(kit.level.buffer_auras.get_weakness(enemy), Buffer.WEAKEN_SHARE, "T2 weakens the enemy in its aura")
	enemy.global_position = buffer.global_position + Vector2(buffer.radius * 3.0, 0.0)
	kit.check_near(kit.level.buffer_auras.get_weakness(enemy), 0.0, "not outside it")


func test_talents_grow_the_budget_and_the_buffs(kit : TestKit) -> void:
	await kit.load_level(1)
	var buffer : Buffer = await kit.place("puffe_buffer", _buildable(kit, []))
	var budget : TalentEffect = TalentEffect.new()
	budget.kind = TalentEffect.Kind.BufferBudget
	var fire_strength : TalentEffect = TalentEffect.new()
	fire_strength.kind = TalentEffect.Kind.BufferStrength
	fire_strength.elements = Utils.Element.Fire
	kit.level.talents.conditional.append([budget, 2.0])
	kit.level.talents.conditional.append([fire_strength, 0.5])
	kit.check(buffer.pip_budget == Buffer.PIP_BUDGET + 2, "Deep Reserve: two more pips (%d)" % buffer.pip_budget)
	buffer.add_pip(Utils.StatType.Damage)
	kit.check_near(buffer.get_buff(Utils.StatType.Damage), 0.06, "a Fire talent does nothing for a Buffer without Fire")
	buffer.evolve_tree.choose_element(Utils.Element.Fire)
	kit.check_near(buffer.get_buff(Utils.StatType.Damage), 0.09, "and makes a Fire Buffer's buffs stronger")
	kit.level.talents.conditional.clear()


## The throws (2026-11-26): a throw holds for BUFF_SECONDS, the next goes to the tower with the least time left, and a
## radius pip reaches further.
func test_buffer_throws_timed_buffs(kit : TestKit) -> void:
	await kit.load_level(1)
	var taken : Array[Vector2i] = []
	var buffer_cell : Vector2i = _buildable(kit, taken)
	taken.append(buffer_cell)
	var buffer : Buffer = await kit.place("puffe_buffer", buffer_cell)
	var first_cell : Vector2i = _cell_beside(kit, buffer_cell, 2, 1, taken)
	taken.append(first_cell)
	var first : Building = await kit.place("puffe_bolter", first_cell)
	var second_cell : Vector2i = _cell_beside(kit, buffer_cell, 2, 1, taken)
	kit.check(first_cell != Vector2i.MAX and second_cell != Vector2i.MAX, "two cells in reach")
	taken.append(second_cell)
	var second : Building = await kit.place("puffe_bolter", second_cell)
	var auras : BufferAuras = kit.level.buffer_auras
	buffer.add_pip(Utils.StatType.Damage)
	buffer.throw_buff()
	buffer.throw_buff()
	kit.check(auras.get_hold(first, buffer) > 0.0 and auras.get_hold(second, buffer) > 0.0, "two throws, two towers: the least held goes next")
	await _settle(kit)
	kit.check_near(_damage_additive(first) - _damage_additive(second), 0.0, "both buffed alike")
	auras._process(Buffer.BUFF_SECONDS + 0.1)
	await _settle(kit)
	kit.check(auras.get_hold(first, buffer) == 0.0, "the buff runs out")
	kit.check(auras.get_buffs(first).is_empty(), "and its modifiers come off")
	var radius : float = buffer.radius
	buffer.add_pip(Utils.StatType.AuraRadius)
	kit.check_near(buffer.radius - radius, 0.5 * Utils.TILE_SIZE, "a radius pip reaches half a tile further")
	kit.check_near(buffer.get_buff(Utils.StatType.AuraRadius), 0.0, "radius is no buff on the towers")


#Mend track (2026-11-27): walls in the aura heal at a fixed rate, towers and traps a quarter of it, the strongest
#covering Buffer only, half while a siege attacker hits the wall
func test_mend_heals_walls_in_the_aura(kit : TestKit) -> void:
	await kit.load_level(1)
	var taken : Array[Vector2i] = []
	var buffer_cell : Vector2i = _buildable(kit, taken)
	taken.append(buffer_cell)
	var buffer : Buffer = await kit.place("puffe_buffer", buffer_cell)
	var wall_cell : Vector2i = _cell_beside(kit, buffer_cell, 1, 1, taken)
	taken.append(wall_cell)
	var wall : Wall = await kit.place("wall", wall_cell)
	var tower_cell : Vector2i = _cell_beside(kit, buffer_cell, 2, 1, taken)
	taken.append(tower_cell)
	var tower : Building = await kit.place("puffe_bolter", tower_cell)
	await _settle(kit)
	var wall_health : Stat = wall.stats.get_stat(Utils.StatType.Health)
	var wall_max : float = wall.stats.get_stat_value(Utils.StatType.MaxHealth)
	var tower_health : Stat = tower.stats.get_stat(Utils.StatType.Health)
	var tower_max : float = tower.stats.get_stat_value(Utils.StatType.MaxHealth)
	kit.check(buffer.get_buff(Utils.StatType.WallMend) == 0.0, "mend is no buff on the towers")

	wall_health.value = wall_max * 0.5
	buffer.mend()
	kit.check_near(wall_health.value, wall_max * 0.5, "no Mend pips, no healing")

	for i in 4:
		buffer.add_pip(Utils.StatType.WallMend)
	kit.check_near(buffer.get_mend_rate(), 0.04, "four pips mend 4% a second")
	buffer.mend()
	kit.check_near(wall_health.value, wall_max * 0.54, "a wall heals the full rate")
	tower_health.value = tower_max * 0.5
	buffer.mend()
	kit.check_near(tower_health.value, tower_max * 0.51, "a tower heals a quarter of it")

	#a second, weaker Buffer covering the same wall adds nothing
	var second_cell : Vector2i = _cell_beside(kit, wall_cell, 2, 1, taken)
	taken.append(second_cell)
	var second : Buffer = await kit.place("puffe_buffer", second_cell)
	second.add_pip(Utils.StatType.WallMend)
	await _settle(kit)
	wall_health.value = wall_max * 0.5
	second.mend()
	kit.check_near(wall_health.value, wall_max * 0.5, "a weaker mender leaves the wall to the strongest")
	buffer.mend()
	kit.check_near(wall_health.value, wall_max * 0.54, "the strongest mender heals it")

	#a battering ram's hit halves the mend
	var ram : Enemy = kit.spawn_enemy("battering_ram", 0)
	kit.level.buffer_auras.on_building_hit(wall, ram)
	wall_health.value = wall_max * 0.5
	buffer.mend()
	kit.check_near(wall_health.value, wall_max * 0.52, "under siege the wall heals half")
	await kit.run_until(func() -> bool: return not kit.level.buffer_auras.is_sieged(wall), BufferAuras.SIEGE_SECONDS + 1.0)
	kit.check(not kit.level.buffer_auras.is_sieged(wall), "the siege wears off")
	wall_health.value = wall_max
	buffer.mend()
	kit.check_near(wall_health.value, wall_max, "never past max health")
