extends RefCounted

## The Spike Field (2026-11-25): a cheap trap that strikes every enemy on it at once, slows them a little and never
## breaks; tunnel rats run under it, flyers pass over.


func _place_field(kit : TestKit) -> Trap:
	var route : PackedVector2Array = kit.level.get_routes()[0]
	for point in kit.level.grid.find_path(route[0], route[1]).slice(4):
		var cell : Vector2i = kit.level.grid.world_position_to_grid(point)
		if kit.level.grid.is_position_buildable(point) and not kit.level.grid.has_building_in_cell_position(cell):
			return await kit.place("spike_field", cell)
	return null


func _enemy_on(kit : TestKit, field : Trap, scene_name : String) -> Enemy:
	var enemy : Enemy = kit.spawn_enemy(scene_name)
	await kit.frames(1)
	enemy.global_position = field.global_position
	for stat_type in [Utils.StatType.MaxHealth, Utils.StatType.Health]:
		enemy.stats.get_stat(stat_type).value = 500.0
	return enemy


func test_spike_field_basics(kit : TestKit) -> void:
	await kit.load_level(5)
	var field : Trap = await _place_field(kit)
	kit.check(field != null, "a Spike Field goes on the road")
	kit.check(field.skill is SpikeStrike and field.astar_weight == 1.0, "a trap the enemies walk over, with spikes")
	kit.check(TalentEffect.get_building_flag(field) == TalentEffect.SPIKE_FIELD, "talents see it as a Spike Field, not a Leopard Trap")


func test_spikes_strike_everything_on_the_field(kit : TestKit) -> void:
	await kit.load_level(5)
	var field : Trap = await _place_field(kit)
	var first : Enemy = await _enemy_on(kit, field, "weakling")
	var second : Enemy = await _enemy_on(kit, field, "weakling")
	var rat : Enemy = await _enemy_on(kit, field, "tunnel_rat")
	for enemy in [first, second, rat]:
		enemy.freeze_for(5.0)
	await kit.run_until(func() -> bool: return first.stats.get_stat_value(Utils.StatType.Health) < 500.0 \
		and second.stats.get_stat_value(Utils.StatType.Health) < 500.0, 4.0)
	kit.check(first.stats.get_stat_value(Utils.StatType.Health) < 500.0, "the first enemy is struck")
	kit.check(second.stats.get_stat_value(Utils.StatType.Health) < 500.0, "and the second at the same time")
	kit.check_near(rat.stats.get_stat_value(Utils.StatType.Health), 500.0, "the tunnel rat runs under it")
	kit.check(first.has_node(SpikeSlow.NAME), "a struck enemy is slowed")
	var health : float = field.stats.get_stat_value(Utils.StatType.Health)
	await kit.run_until(func() -> bool: return false, 3.0)
	kit.check(first.stats.get_stat_value(Utils.StatType.Health) < 500.0 - field.skill.stats.get_stat_value(Utils.StatType.Damage) * 1.5,
		"it strikes again and again")
	kit.check_near(field.stats.get_stat_value(Utils.StatType.Health), health, "and never wears out")
