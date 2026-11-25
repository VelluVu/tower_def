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
	kit.check(list.unlock_level == 25, "it unlocks on level 25")


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
	await _settle(kit)
	kit.check_near(_damage_additive(near) - base_near, 0.12, "two damage pips on the tower in reach")
	kit.check_near(_damage_additive(far), 0.0, "nothing on the tower out of reach")

	var second_cell : Vector2i = _cell_beside(kit, near_cell, 1, 1, taken)
	taken.append(second_cell)
	var second : Buffer = await kit.place("puffe_buffer", second_cell)
	second.add_pip(Utils.StatType.Damage)
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
