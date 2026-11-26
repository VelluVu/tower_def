extends RefCounted

## Trade-off cards (a bonus with an uncapped drawback) and the maze cards (Killing Ground, Tangled Maze).

const TOWER_CELL : Vector2i = Vector2i(12, 6)
const WALL_CELL : Vector2i = Vector2i(12, 6)
const HIT_DAMAGE : float = 0.5


func test_overcharge_trades_range_for_damage(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await kit.place("puffe_bolter", TOWER_CELL)
	var damage : float = bolter.skill.stats.get_stat_value(Utils.StatType.Damage)
	var attack_range : float = bolter.skill.stats.get_stat_value(Utils.StatType.AttackRange)
	var card : UpgradeCard = kit.pick_card("overcharge")
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.Damage), damage * 1.3, "+30% damage")
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.AttackRange), attack_range * 0.8, "-20% range")
	kit.check(card.get_text() == "Overcharge\n+30% Damage\n-20% Attack Range", "card text: %s" % card.get_text().c_escape())


func test_drawback_comes_after_the_caps(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await kit.place("puffe_bolter", TOWER_CELL)
	var damage : float = bolter.skill.stats.get_stat_value(Utils.StatType.Damage)
	#+2.5 of cards: past the +75% soft cap at half, so +1.625, held at the +150% hard cap
	for i in 10:
		kit.pick_card("damage", 0.25)
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.Damage), damage * 2.5, "damage cards at the hard cap")
	kit.pick_card("frenzy")
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.Damage), damage * 2.35, "the drawback still counts past the cap")
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.AttackSpeed), 0.3, "Frenzy's attack speed")


func test_heavy_blows_slows_attacks(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await kit.place("puffe_bolter", TOWER_CELL)
	kit.pick_card("heavy_blows")
	kit.check_near(bolter.skill.stats.get_stat_value(Utils.StatType.AttackSpeed), -0.2, "-20% attack speed")


func test_range_trade_offs_skip_traps(kit : TestKit) -> void:
	await kit.load_level(1)
	var trap : Building = await kit.place("leopard_trap", TOWER_CELL)
	for card_name in ["overcharge", "long_sight"]:
		kit.check(not kit.level.upgrades._fits(load(TestKit.CARD_PATH % card_name), trap, 2), "%s skips the trap" % card_name)
	kit.check(kit.level.upgrades._fits(load(TestKit.CARD_PATH % "heavy_blows"), trap, 2), "Heavy Blows fits the trap")


func test_maze_cards_wait_for_a_wall(kit : TestKit) -> void:
	await kit.load_level(1)
	var killing_ground : EvolveResource = load(TestKit.CARD_PATH % "killing_ground")
	await kit.place("puffe_bolter", Vector2i(16, 6))
	kit.check(not kit.level.upgrades._can_offer(killing_ground, 2), "no wall, no maze card")
	await kit.place("wall", WALL_CELL)
	kit.check(kit.level.upgrades._can_offer(killing_ground, 2), "offered once a wall stands")


func test_killing_ground_hits_enemies_in_the_maze(kit : TestKit) -> void:
	await kit.load_level(1)
	var bolter : Building = await kit.place("puffe_bolter", Vector2i(16, 6))
	await kit.place("wall", WALL_CELL)
	var card : UpgradeCard = kit.pick_card("killing_ground")
	kit.check(card.get_text().contains("+15% damage"), "the value is in the text: %s" % card.get_text().c_escape())

	var maze_cell : Vector2i = kit.level.grid.get_walkable_surrounding_cells(WALL_CELL)[0]
	var open_cell : Vector2i = kit.find_cell(func(cell : Vector2i) -> bool: return not kit.level.grid.is_maze_cell(cell))
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(1)
	enemy.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	enemy.freeze = true

	kit.check_near(_hit_at(kit, enemy, bolter, maze_cell), HIT_DAMAGE * 1.15, "+15% in the maze")
	kit.check_near(_hit_at(kit, enemy, bolter, open_cell), HIT_DAMAGE, "no bonus outside it")


func test_tangled_maze_slows_the_maze(kit : TestKit) -> void:
	await kit.load_level(1)
	await kit.place("wall", WALL_CELL)
	var maze_cell : Vector2i = kit.level.grid.get_walkable_surrounding_cells(WALL_CELL)[0]
	var before : float = kit.level.grid.get_move_speed_factor(maze_cell)
	kit.pick_card("tangled_maze")
	kit.check_near(kit.level.grid.get_move_speed_factor(maze_cell), before * 0.9, "10% slower in the maze")


#the health an enemy standing in cell loses to one hit from the tower
func _hit_at(kit : TestKit, enemy : Enemy, source : Building, cell : Vector2i) -> float:
	enemy.global_position = kit.level.grid.grid_position_to_world(cell)
	var health : float = enemy.stats.get_stat_value(Utils.StatType.Health)
	var damage_data : DamageData = DamageData.new()
	damage_data.damage = HIT_DAMAGE
	damage_data.source = source
	enemy.take_damage(damage_data)
	damage_data.free()
	return health - enemy.stats.get_stat_value(Utils.StatType.Health)
