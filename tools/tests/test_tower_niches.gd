extends RefCounted

## Where the newer towers shine (TowerNiches, 2026-11-26): Spotter and traps in the maze, Breather in tight corridors,
## Mortar on pinned or slowed enemies, Nova at corners and on chilled enemies.


#a free 5x5 block of walkable, buildable ground, its centre returned
func _open_block(kit : TestKit) -> Vector2i:
	var grid : LevelGrid = kit.level.grid
	return kit.find_cell(func(c : Vector2i) -> bool:
		for y in range(-2, 3):
			for x in range(-2, 3):
				var other : Vector2i = c + Vector2i(x, y)
				if not grid.is_cell_walkable(other) or not grid.is_position_buildable(grid.grid_position_to_world(other)) \
						or grid.has_building_in_cell_position(other):
					return false
		return true)


func _factor(enemy : Enemy, tower : Building, cell : Vector2i) -> float:
	enemy.global_position = enemy.level.grid.grid_position_to_world(cell)
	var hit : DamageData = DamageData.new()
	hit.damage = 1.0
	hit.source = tower
	var factor : float = TowerNiches.get_factor(enemy, hit)
	hit.free()
	return factor


func test_corridor_and_corner_cells(kit : TestKit) -> void:
	await kit.load_level(3)
	var grid : LevelGrid = kit.level.grid
	var centre : Vector2i = _open_block(kit)
	kit.check(centre != Vector2i.MAX, "found open ground")
	kit.check(not grid.is_corridor_cell(centre) and not grid.is_corner_cell(centre), "open ground is neither")
	await kit.place("wall", centre + Vector2i.LEFT)
	kit.check(grid.is_corner_cell(centre) == false, "one wall beside it is not a corner")
	await kit.place("wall", centre + Vector2i.UP)
	kit.check(grid.is_corner_cell(centre), "walls on one side and above: a corner")
	await kit.place("wall", centre + Vector2i.RIGHT)
	kit.check(grid.is_corridor_cell(centre) and not grid.is_corner_cell(centre), "walls on both sides: a corridor")


func test_each_tower_shines_in_its_niche(kit : TestKit) -> void:
	await kit.load_level(3)
	var grid : LevelGrid = kit.level.grid
	var centre : Vector2i = _open_block(kit)
	var spotter : Building = await kit.place("puffe_spotter", centre + Vector2i(2, 2))
	var breather : Building = await kit.place("puffe_breather", centre + Vector2i(-2, 2))
	var mortar : Building = await kit.place("puffe_mortar", centre + Vector2i(2, -2))
	var nova : Building = await kit.place("puffe_nova", centre + Vector2i(-2, -2))
	var enemy : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	enemy.resistances = null
	var open : Vector2i = centre + Vector2i(0, 1)
	kit.check_near(_factor(enemy, spotter, open), 1.0, "the Spotter: nothing extra on open ground")
	kit.check_near(_factor(enemy, nova, open), 1.0, "the Nova: nothing extra on open ground")
	kit.check_near(_factor(enemy, breather, open), 1.0, "the Breather: nothing extra on open ground")
	await kit.place("wall", centre + Vector2i.LEFT)
	await kit.place("wall", centre + Vector2i.UP)
	kit.check_near(_factor(enemy, spotter, centre), 1.0 + TowerNiches.SPOTTER_MAZE_BONUS, "the Spotter in the maze")
	kit.check_near(_factor(enemy, nova, centre), 1.0 + TowerNiches.NOVA_CORNER_BONUS, "the Nova at a corner")
	await kit.place("wall", centre + Vector2i.RIGHT)
	kit.check_near(_factor(enemy, breather, centre), 1.0 + TowerNiches.BREATHER_CORRIDOR_BONUS, "the Breather in a corridor")
	#the Mortar: the open cell is beside no building, then the enemy is frozen
	var far : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return grid.is_cell_walkable(c) and grid.get_move_speed_factor(c) == 1.0 and Vector2(c - centre).length() > 6.0)
	kit.check_near(_factor(enemy, mortar, far), 1.0, "the Mortar: nothing extra on a free-walking enemy")
	enemy.freeze_for(1.0)
	kit.check_near(_factor(enemy, mortar, far), 1.0 + TowerNiches.MORTAR_PINNED_BONUS, "the Mortar on a frozen enemy")
	kit.check_near(_factor(enemy, nova, far), 1.0 + TowerNiches.NOVA_CORNER_BONUS, "the Nova on a frozen enemy")


func test_traps_shine_in_the_maze_and_ticks_get_nothing(kit : TestKit) -> void:
	await kit.load_level(3)
	var centre : Vector2i = _open_block(kit)
	var trap : Building = await kit.place("leopard_trap", centre)
	var spotter : Building = await kit.place("puffe_spotter", centre + Vector2i(2, 2))
	var enemy : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	kit.check_near(_factor(enemy, trap, centre), 1.0, "a trap on open ground")
	await kit.place("wall", centre + Vector2i.UP)
	kit.check_near(_factor(enemy, trap, centre), 1.0 + TowerNiches.TRAP_MAZE_BONUS, "a trap in the maze")
	enemy.global_position = kit.level.grid.grid_position_to_world(centre)
	var tick : DamageData = DamageData.new()
	tick.damage = 1.0
	tick.source = spotter
	tick.is_overtime = true
	kit.check_near(TowerNiches.get_factor(enemy, tick), 1.0, "an effect tick gets no niche bonus")
	tick.free()


const FakeProjectile : GDScript = preload("res://tools/test/fake_projectile.gd")


## The Harpooner (the user, 2026-11-26): one more harpoon per tier, each at another enemy.
func test_harpooner_throws_one_more_per_tier(kit : TestKit) -> void:
	await kit.load_level(3)
	var centre : Vector2i = _open_block(kit)
	var harpooner : Tower = await kit.place("puffe_harpooner", centre)
	var skill : LaunchProjectile = harpooner.skill
	skill.projectile_scene = FakeProjectile.packed()
	var enemies : Array[Enemy] = []
	for i in 4:
		enemies.append(kit.spawn_enemy("weakling"))
	await kit.frames(1)
	for enemy in enemies:
		harpooner.targets.append(enemy)
	skill.target = enemies[0]
	for tier in [0, 2, 3]:
		harpooner.evolve_tree.tier = tier
		FakeProjectile.launched_damage.clear()
		skill._launch_extra_harpoons()
		kit.check(FakeProjectile.launched_damage.size() == tier, "tier %d: %d extra harpoons, got %d" % [tier, tier, FakeProjectile.launched_damage.size()])
	#only three other enemies to throw at, even at a higher tier
	harpooner.evolve_tree.tier = 5
	FakeProjectile.launched_damage.clear()
	skill._launch_extra_harpoons()
	kit.check(FakeProjectile.launched_damage.size() == 3, "never two harpoons at one enemy")
	FakeProjectile.launched_damage.clear()


## Twin Harpoons (the Building capstone, the user 2026-11-26): every throw doubles, 2 harpoons at Base, 4 at T1.
func test_twin_harpoons_double_the_throw(kit : TestKit) -> void:
	await kit.load_level(3)
	var centre : Vector2i = _open_block(kit)
	var harpooner : Tower = await kit.place("puffe_harpooner", centre)
	var skill : LaunchProjectile = harpooner.skill
	skill.projectile_scene = FakeProjectile.packed()
	var enemies : Array[Enemy] = []
	for i in 6:
		enemies.append(kit.spawn_enemy("weakling"))
	await kit.frames(1)
	for enemy in enemies:
		harpooner.targets.append(enemy)
	skill.target = enemies[0]
	kit.check(kit.level.talents != null, "the level has its talents")
	if kit.level.talents == null:
		return
	kit.level.talents.totals[TalentEffect.Kind.HarpoonMultiplier] = 1.0
	for tier in [0, 1]:
		harpooner.evolve_tree.tier = tier
		FakeProjectile.launched_damage.clear()
		skill._launch_extra_harpoons()
		var expected : int = (1 + tier) * 2 - 1
		kit.check(FakeProjectile.launched_damage.size() == expected, "tier %d: %d extra harpoons, got %d" % [tier, expected, FakeProjectile.launched_damage.size()])
	kit.level.talents.totals.erase(TalentEffect.Kind.HarpoonMultiplier)
	FakeProjectile.launched_damage.clear()
	var tree : TalentTree = load("res://scenes/talents/trees/building_tree.tres")
	var node : TalentNode = null
	for candidate in tree.nodes:
		if candidate.id == &"harpooner_twin_harpoons":
			node = candidate
	kit.check(node != null and not node.effects.is_empty() and node.effects[0].kind == TalentEffect.Kind.HarpoonMultiplier, "the capstone carries it")


## The extra harpoons land clustered round the main target (the user, 2026-11-26): its neighbour first, an enemy far
## from it never.
func test_extra_harpoons_cluster_round_the_target(kit : TestKit) -> void:
	await kit.load_level(3)
	var centre : Vector2i = _open_block(kit)
	var harpooner : Tower = await kit.place("puffe_harpooner", centre)
	var skill : LaunchProjectile = harpooner.skill
	skill.projectile_scene = FakeProjectile.packed()
	var main : Enemy = kit.spawn_enemy("weakling")
	var neighbour : Enemy = kit.spawn_enemy("weakling")
	var far : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	var at : Vector2 = harpooner.global_position
	for pair in [[main, Vector2(-30, 0)], [neighbour, Vector2(-26, 4)], [far, Vector2(30, 0)]]:
		pair[0].freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		pair[0].freeze = true
		pair[0].global_position = at + pair[1]
		harpooner.targets.append(pair[0])
	skill.target = main
	var aimed : Array[Node2D] = [main]
	kit.check(TargetPicker.pick_cluster(harpooner.targets, aimed) == neighbour, "the second harpoon goes to the main target's neighbour")
	harpooner.evolve_tree.tier = 2
	FakeProjectile.launched_damage.clear()
	skill._launch_extra_harpoons()
	kit.check(FakeProjectile.launched_damage.size() == 1, "and none to the enemy far from it (%d)" % FakeProjectile.launched_damage.size())
	#the area grows with the area stat (and the gold steps): 60 px off is reached at 1.5 + 2.5 tiles
	harpooner.stats.get_stat(Utils.StatType.SplashRadius).value = 2.5
	FakeProjectile.launched_damage.clear()
	skill._launch_extra_harpoons()
	kit.check(FakeProjectile.launched_damage.size() == 2, "a wider area reaches it too (%d)" % FakeProjectile.launched_damage.size())
	FakeProjectile.launched_damage.clear()


## Every harpoon makes its target bleed, and a tethered enemy bleeds harder from every tower.
func test_harpoon_bleeds_and_tears(kit : TestKit) -> void:
	await kit.load_level(3)
	var centre : Vector2i = _open_block(kit)
	var harpooner : Building = await kit.place("puffe_harpooner", centre)
	var enemy : Enemy = kit.spawn_enemy("beefling")
	await kit.frames(1)
	HarpoonTether.bleed(enemy, harpooner, 1.0)
	kit.check(enemy.overtime_effect_handler.get_active_stacks(Utils.DamageType.Physical).size() == 1, "a bleed stack starts")
	var tick : DamageData = DamageData.new()
	tick.damage = 1.0
	tick.is_overtime = true
	tick.damage_type = Utils.DamageType.Physical
	kit.check_near(HarpoonTether.get_bleed_factor(enemy, tick), 1.0, "no tear before a tether")
	HarpoonTether.attach(enemy, harpooner, 2.0, 0.2)
	kit.check_near(HarpoonTether.get_bleed_factor(enemy, tick), 1.0 + HarpoonTether.BLEED_VULNERABILITY, "a tethered enemy bleeds harder")
	tick.damage_type = Utils.DamageType.Fire
	kit.check_near(HarpoonTether.get_bleed_factor(enemy, tick), 1.0, "a burn is no bleed")
	tick.free()


## The Harpooner hunts flyers and fast runners.
func test_harpooner_prey_and_buffer_cluster(kit : TestKit) -> void:
	await kit.load_level(3)
	var centre : Vector2i = _open_block(kit)
	var harpooner : Building = await kit.place("puffe_harpooner", centre)
	var weakling : Enemy = kit.spawn_enemy("weakling")
	var scout : Enemy = kit.spawn_enemy("scout")
	var batling : Enemy = kit.spawn_enemy("batling")
	await kit.frames(1)
	var cell : Vector2i = centre + Vector2i(0, 1)
	kit.check_near(_factor(weakling, harpooner, cell), 1.0, "a slow walker is no prey")
	kit.check(TowerNiches.is_fast(scout), "a scout is fast")
	kit.check_near(_factor(scout, harpooner, cell), 1.0 + TowerNiches.HARPOON_HUNT_BONUS, "a scout is prey")
	kit.check_near(_factor(batling, harpooner, cell), 1.0 + TowerNiches.HARPOON_HUNT_BONUS, "a flyer is prey")
