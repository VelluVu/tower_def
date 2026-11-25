extends RefCounted

## The sixteen enemies of 2026-11-25 (tools/units_2026_11_25.py) and their mechanics.

const NAMES : PackedStringArray = [
	"cave_shaman", "wall_crawler", "spore_carrier", "glow_moth",
	"bog_witch", "snapping_turtle", "mosquito", "leech_mother",
	"shieldbearer", "battering_ram", "war_drummer", "crossbow_sniper",
	"sand_wurm", "bone_vulture", "mummy_priest", "ash_harpy",
	"tunnel_rat", "bog_lurker", "standard_bearer", "ash_wraith",
]


func test_every_new_enemy_spawns_and_moves(kit : TestKit) -> void:
	await kit.load_level(14)
	for enemy_name in NAMES:
		var enemy : Enemy = kit.spawn_enemy(enemy_name)
		var start : Vector2 = enemy.global_position
		await kit.run_until(func() -> bool: return enemy.global_position.distance_to(start) > Utils.TILE_SIZE, 8.0)
		kit.check(enemy.global_position.distance_to(start) > Utils.TILE_SIZE, "%s moves" % enemy_name)
		kit.check(enemy.icon != null and enemy.animation_control.sprite_frames.has_animation(GlobalAnimationNames.WALK_ANIMATION), "%s has its art" % enemy_name)
		enemy.remove_without_reward()


func test_shieldbearer_covers_against_bolts_only(kit : TestKit) -> void:
	await kit.load_level(14)
	var bolter : Building = await kit.place("puffe_bolter", _buildable_cell(kit))
	var bearer : Enemy = kit.spawn_enemy("shieldbearer")
	var soldier : Enemy = kit.spawn_enemy("soldier")
	await kit.frames(1)
	soldier.global_position = bearer.global_position + Vector2(Utils.TILE_SIZE, 0)
	var hit : DamageData = DamageData.new()
	hit.damage = 10.0
	hit.source = bolter
	kit.check_near(ShieldAura.get_factor(soldier, hit), 0.6, "a bolt near the shield loses 40%")
	soldier.global_position = bearer.global_position + Vector2(Utils.TILE_SIZE * 4, 0)
	kit.check_near(ShieldAura.get_factor(soldier, hit), 1.0, "out of its reach the bolt lands in full")
	hit.source = null
	kit.check_near(ShieldAura.get_factor(bearer, hit), 1.0, "a hit without a tower is not covered")
	hit.free()


func test_war_drummer_speeds_up_its_neighbours(kit : TestKit) -> void:
	await kit.load_level(14)
	var drummer : Enemy = kit.spawn_enemy("war_drummer")
	var soldier : Enemy = kit.spawn_enemy("soldier")
	await kit.frames(1)
	var base_speed : float = soldier.stats.get_stat_value(Utils.StatType.Speed)
	soldier.global_position = drummer.global_position
	await kit.run_until(func() -> bool: return soldier.stats.get_stat_value(Utils.StatType.Speed) > base_speed, 2.0)
	kit.check_near(soldier.stats.get_stat_value(Utils.StatType.Speed), base_speed * 1.25, "25% faster to the beat", 0.01)
	_kill(drummer)
	await kit.frames(2)
	kit.check_near(soldier.stats.get_stat_value(Utils.StatType.Speed), base_speed, "back to its pace when the drummer falls", 0.01)


func test_spore_carrier_leaves_a_healing_cloud(kit : TestKit) -> void:
	await kit.load_level(14)
	var carrier : Enemy = kit.spawn_enemy("spore_carrier")
	var soldier : Enemy = kit.spawn_enemy("soldier")
	await kit.frames(1)
	soldier.global_position = carrier.global_position
	soldier.stats.get_stat(Utils.StatType.Health).value = 5.0
	_kill(carrier)
	await kit.run_until(func() -> bool: return soldier.stats.get_stat_value(Utils.StatType.Health) > 5.0, 2.0)
	kit.check(soldier.stats.get_stat_value(Utils.StatType.Health) > 5.0, "the spores heal the soldier")


func test_wall_crawler_paths_over_walls(kit : TestKit) -> void:
	await kit.load_level(14)
	var crawler : Enemy = kit.spawn_enemy("wall_crawler")
	await kit.run_until(func() -> bool: return crawler.has_path and crawler.point_path.size() > 8, 4.0)
	var grid : LevelGrid = kit.level.grid
	#a straight stretch of road: over a wall there is one step, round it at least three
	var index : int = -1
	for i in range(3, crawler.point_path.size() - 2):
		if (crawler.point_path[i] - crawler.point_path[i - 1]).is_equal_approx(crawler.point_path[i + 1] - crawler.point_path[i]):
			index = i
			break
	kit.check(index > 0, "a straight stretch on the road")
	var road_cell : Vector2i = grid.world_position_to_grid(crawler.point_path[index])
	var before : Vector2 = crawler.point_path[index - 1]
	var after : Vector2 = crawler.point_path[index + 1]
	var wall : Building = await kit.place("wall", road_cell)
	kit.check(wall != null, "a wall on the road")
	await kit.frames(2)
	var climbed : Array[Vector2i] = []
	for point in grid.find_path_with_wall_weight(before, after, crawler.wall_path_weight):
		climbed.append(grid.world_position_to_grid(point))
	var walked : Array[Vector2i] = []
	for point in grid.find_path(before, after):
		walked.append(grid.world_position_to_grid(point))
	kit.check(crawler.climbs_walls and climbed.has(road_cell), "the crawler's way goes over the wall")
	kit.check(not walked.has(road_cell), "everyone else's goes round it")
	crawler.next_waypoint = grid.grid_position_to_world(road_cell)
	kit.check(crawler.get_building_in_next_waypoint() == null, "a wall does not block it")
	kit.check_near(grid.astar_grid.get_point_weight_scale(road_cell), wall.astar_weight, "the wall's weight is back for the others")


func test_snapping_turtle_shells_after_a_big_hit(kit : TestKit) -> void:
	await kit.load_level(14)
	var turtle : Enemy = kit.spawn_enemy("snapping_turtle")
	await kit.frames(1)
	var hit : DamageData = DamageData.new()
	hit.damage = 2.0
	turtle.take_damage(hit)
	kit.check_near(turtle.damage_taken_factor, 1.0, "a small hit does not close the shell")
	hit.damage = 20.0
	turtle.take_damage(hit)
	hit.free()
	kit.check_near(turtle.damage_taken_factor, 0.3, "a big hit does")
	kit.check(turtle.walk_animation == GlobalAnimationNames.SHELL_ANIMATION, "it crawls in its shell")
	await kit.run_until(func() -> bool: return is_equal_approx(turtle.damage_taken_factor, 1.0), 4.0)
	kit.check_near(turtle.damage_taken_factor, 1.0, "and comes out again")


func test_bog_witch_curses_towers(kit : TestKit) -> void:
	await kit.load_level(14)
	var tower : Building = await kit.place("puffe_bolter", _buildable_cell(kit))
	var before : float = tower.skill.stats.get_stat_value(Utils.StatType.AttackSpeed)
	var witch : Enemy = kit.spawn_enemy("bog_witch")
	var hex : EnemyAbility = witch.abilities.get_node("Hex")
	await kit.frames(1)
	#she may walk out of reach before her first hex is ready: bring her back with it ready
	hex.cooldown_timer.stop()
	witch.global_position = tower.global_position + Vector2(Utils.TILE_SIZE, 0)
	await kit.run_until(func() -> bool: return hex.use_count > 0 and not hex.is_active, 6.0)
	kit.check(tower.has_node(TowerCurse.NAME), "the tower is cursed")
	kit.check(tower.skill.stats.get_stat_value(Utils.StatType.AttackSpeed) < before, "and attacks slower")
	witch.remove_without_reward()
	await kit.run_until(func() -> bool: return not tower.has_node(TowerCurse.NAME), 7.0)
	kit.check_near(tower.skill.stats.get_stat_value(Utils.StatType.AttackSpeed), before, "the curse wears off")


func test_leech_mother_drops_leechlings(kit : TestKit) -> void:
	await kit.load_level(14)
	var mother : Enemy = kit.spawn_enemy("leech_mother")
	var brood : EnemyAbility = mother.abilities.get_node("Brood")
	await kit.run_until(func() -> bool: return brood.use_count > 0 and not brood.is_active, 8.0)
	var leeches : int = kit.level.existing_enemies.filter(func(e) -> bool: return is_instance_valid(e) and e.scene_file_path.ends_with("leechling.tscn")).size()
	kit.check(leeches >= 1, "a leechling crawls out")


func test_crossbow_sniper_aims_at_the_longest_reach(kit : TestKit) -> void:
	await kit.load_level(14)
	var first : Vector2i = _buildable_cell(kit)
	var near_tower : Building = await kit.place("puffe_bolter", first)
	var second : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return c != first and kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)) \
			and Vector2(c - first).length() <= 3.0 and Vector2(c - first).length() >= 2.0)
	var far_tower : Building = await kit.place("puffe_bolter", second)
	var reach : ModifierData = ModifierData.new()
	reach.calculate_type = Utils.ModifyType.Flat
	reach.stat_type = Utils.StatType.AttackRange
	reach.value = 2.0
	far_tower.modifier_manager.add_modifier(reach)
	var sniper : Enemy = kit.spawn_enemy("crossbow_sniper")
	await kit.frames(1)
	sniper.global_position = near_tower.global_position
	var snipe : RangedShotAbility = sniper.abilities.get_node("Snipe")
	kit.check(snipe._pick_target() == far_tower, "it aims at the tower that reaches farthest")
	snipe.target = far_tower
	snipe._fire()
	await kit.run_until(func() -> bool: return far_tower.is_silenced, 3.0)
	kit.check(far_tower.is_silenced, "the bolt stuns it")


func test_mummy_priest_silences_on_death(kit : TestKit) -> void:
	await kit.load_level(14)
	var tower : Building = await kit.place("puffe_bolter", _buildable_cell(kit))
	var mummy : Enemy = kit.spawn_enemy("mummy_priest")
	await kit.frames(1)
	mummy.global_position = tower.global_position + Vector2(Utils.TILE_SIZE, 0)
	var health : float = tower.stats.get_stat_value(Utils.StatType.Health)
	_kill(mummy)
	await kit.frames(1)
	kit.check(tower.is_silenced, "its curse silences the tower")
	kit.check_near(tower.stats.get_stat_value(Utils.StatType.Health), health, "without hurting it")


func test_bone_vulture_falls_and_walks_on(kit : TestKit) -> void:
	await kit.load_level(14)
	var vulture : Enemy = kit.spawn_enemy("bone_vulture")
	await kit.frames(2)
	kit.check(vulture.is_flying, "it flies")
	var count : int = kit.level.existing_enemies.size()
	_kill(vulture)
	await kit.frames(3)
	var bones : Array = kit.level.existing_enemies.filter(func(e) -> bool:
		return is_instance_valid(e) and e != vulture and e.scene_file_path.ends_with("bone_vulture.tscn"))
	kit.check(bones.size() == 1, "its bones come back")
	kit.check(not bones.is_empty() and not bones[0].is_flying, "on the ground")
	kit.check(kit.level.existing_enemies.size() >= count - 1, "and keep walking")


func test_battering_ram_and_crawler_pass_the_guards(kit : TestKit) -> void:
	await kit.load_level(14)
	var ram : Enemy = kit.spawn_enemy("battering_ram")
	var crawler : Enemy = kit.spawn_enemy("wall_crawler")
	await kit.frames(1)
	kit.check(not ram.can_be_held and not crawler.can_be_held, "no Hatchery guard holds them")
	kit.check(ram.wall_path_weight > 0.0 and ram.wall_path_weight < 100.0, "the ram would rather break a wall than walk the maze")


func test_ash_harpy_dives_at_a_tower(kit : TestKit) -> void:
	await kit.load_level(14)
	var tower : Building = await kit.place("puffe_bolter", _buildable_cell(kit))
	var health : float = tower.stats.get_stat_value(Utils.StatType.Health)
	var harpy : Enemy = kit.spawn_enemy("ash_harpy")
	var dive : EnemyAbility = harpy.abilities.get_node("Dive")
	await kit.frames(1)
	#it flies past the spawn's tower long before its first dive is ready: bring it back with the dive ready
	dive.cooldown_timer.stop()
	harpy.global_position = tower.global_position + Vector2(Utils.TILE_SIZE, 0)
	await kit.run_until(func() -> bool: return dive.use_count > 0 and not dive.is_active, 6.0)
	kit.check(not is_instance_valid(tower) or tower.stats.get_stat_value(Utils.StatType.Health) < health, "the dive burns the tower")


func test_cave_shaman_gives_stone_skin(kit : TestKit) -> void:
	await kit.load_level(5)
	var shaman : Enemy = kit.spawn_enemy("cave_shaman")
	var ward : EnemyAbility = shaman.abilities.get_node("StoneSkin")
	await kit.run_until(func() -> bool: return ward.use_count > 0 and not ward.is_active, 10.0)
	kit.check(shaman.fire_ward != null, "a stone skin soaks the next hit")


func test_sand_wurm_dives_far_ahead(kit : TestKit) -> void:
	await kit.load_level(14)
	var wurm : Enemy = kit.spawn_enemy("sand_wurm")
	var dive : EnemyAbility = wurm.abilities.get_node("Dive")
	await kit.run_until(func() -> bool: return dive.use_count > 0 and not dive.is_active, 16.0)
	kit.check(dive.use_count > 0 and not wurm.is_burrowed, "it dives and comes up again")


func test_tunnel_rats_run_under_traps(kit : TestKit) -> void:
	await kit.load_level(14)
	var trap : Building = await kit.place("leopard_trap", _buildable_cell(kit))
	var rat : Enemy = kit.spawn_enemy("tunnel_rat")
	await kit.frames(1)
	kit.check(rat.ignores_traps, "a tunnel rat ignores traps")
	trap._on_range_area_body_entered(rat)
	kit.check(not trap.targets.has(rat), "the trap never takes it as a target")


func test_bog_lurker_is_out_of_reach_of_bolts(kit : TestKit) -> void:
	await kit.load_level(14)
	var lurker : Enemy = kit.spawn_enemy("bog_lurker")
	await kit.frames(2)
	kit.check(lurker.is_submerged, "it swims submerged")
	var candidates : Array[Node2D] = [lurker]
	kit.check(TargetPicker.pick(Utils.TargetTactic.First, candidates, Vector2.ZERO, false) == null, "a bolt tower cannot pick it")
	kit.check(TargetPicker.pick(Utils.TargetTactic.First, candidates, Vector2.ZERO, true) == lurker, "an area tower can")
	kit.check(EnemyQuery.closest_enemy(kit.level.get_tree(), lurker.body_center, 64.0, []) != lurker, "ricochets pass it by")


func test_standard_bearer_stops_slows_and_freezes(kit : TestKit) -> void:
	await kit.load_level(14)
	var bearer : Enemy = kit.spawn_enemy("standard_bearer")
	var soldier : Enemy = kit.spawn_enemy("soldier")
	await kit.frames(1)
	soldier.global_position = bearer.global_position
	var base_speed : float = soldier.stats.get_stat_value(Utils.StatType.Speed)
	await kit.run_until(func() -> bool: return soldier.is_steadfast, 2.0)
	kit.check(soldier.is_steadfast, "the banner covers the soldier")
	var slow : ModifierData = Elite.multiply(Utils.StatType.Speed, 0.5)
	soldier.modifier_manager.add_modifier(slow)
	kit.check_near(soldier.stats.get_stat_value(Utils.StatType.Speed), base_speed, "a slow does nothing", 0.01)
	soldier.freeze_for(2.0)
	kit.check(not soldier.is_frozen, "nor does a freeze")
	_kill(bearer)
	await kit.frames(2)
	kit.check(not soldier.is_steadfast, "without the bearer it is plain again")
	kit.check_near(soldier.stats.get_stat_value(Utils.StatType.Speed), base_speed * 0.5, "and the slow bites", 0.01)


func test_ash_wraith_fades_out(kit : TestKit) -> void:
	await kit.load_level(14)
	var wraith : Enemy = kit.spawn_enemy("ash_wraith")
	await kit.run_until(func() -> bool: return wraith.is_phased, 6.0)
	kit.check(wraith.is_phased, "it fades out")
	var health : float = wraith.stats.get_stat_value(Utils.StatType.Health)
	var hit : DamageData = DamageData.new()
	hit.damage = 5.0
	wraith.take_damage(hit)
	hit.free()
	kit.check_near(wraith.stats.get_stat_value(Utils.StatType.Health), health, "a hit passes through it")
	var candidates : Array[Node2D] = [wraith]
	kit.check(TargetPicker.pick(Utils.TargetTactic.First, candidates, Vector2.ZERO) == null, "no tower picks it")
	await kit.run_until(func() -> bool: return not wraith.is_phased, 2.0)
	kit.check(not wraith.is_phased, "and comes back")


func _kill(enemy : Enemy) -> void:
	var hit : DamageData = DamageData.new()
	hit.damage = 99999.0
	enemy.take_damage(hit)
	hit.free()


#a buildable cell within reach of the first spawner, so the enemies there are near a tower placed on it
func _buildable_cell(kit : TestKit) -> Vector2i:
	var spawn : Vector2 = kit.level.get_spawners()[0].global_position
	return kit.find_cell(func(c : Vector2i) -> bool:
		var world : Vector2 = kit.level.grid.grid_position_to_world(c)
		return kit.level.grid.is_position_buildable(world) and world.distance_to(spawn) <= Utils.TILE_SIZE * 1.6)
