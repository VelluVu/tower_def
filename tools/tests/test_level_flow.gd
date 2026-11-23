extends RefCounted

## Level flow and per-instance state (the code review of 2026-11-17): the end check waits for what a death leaves
## behind, a wave clears and a level is lost only once, an enemy caught on an erupted cell walks off it, and towers,
## Nova bursts and walls keep their own state.


func _hit(enemy : Enemy, damage : float) -> void:
	var hit : DamageData = DamageData.new()
	hit.damage = damage
	enemy.take_damage(hit)
	hit.free()


func _buildable(kit : TestKit, taken : Array[Vector2i] = []) -> Vector2i:
	return kit.find_cell(func(c : Vector2i) -> bool:
		return not taken.has(c) and kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))


func _living(kit : TestKit) -> Array[Enemy]:
	return kit.level.existing_enemies.filter(func(e : Enemy) -> bool: return is_instance_valid(e) and not e.is_deactivated)


func test_a_death_spawn_keeps_the_last_wave_going(kit : TestKit) -> void:
	await kit.load_level(50)
	var runner : WaveRunner = kit.level.wave_runner
	runner.current_wave_index = runner.waves.size() - 1
	var completed : Array[int] = [0]
	var on_completed : Callable = func(_level : Level) -> void: completed[0] += 1
	GameSignals.level_completed.connect(on_completed)
	var golem : Enemy = kit.spawn_enemy("obsidian_golem")
	await kit.frames(2)
	_hit(golem, 99999.0)
	await kit.run_until(func() -> bool: return golem.is_deactivated, 3.0)
	await kit.frames(2)
	kit.check(completed[0] == 0, "the level is not won while the golem's blobs crawl out")
	kit.check(_living(kit).size() == 2, "the two blobs count as alive (%d)" % _living(kit).size())
	for blob in _living(kit):
		_hit(blob, 99999.0)
	await kit.run_until(func() -> bool: return completed[0] > 0, 3.0)
	await kit.frames(2)
	kit.check(completed[0] == 1, "the level is won once the blobs are dead, once (%d)" % completed[0])
	GameSignals.level_completed.disconnect(on_completed)


func test_a_wave_clears_once_when_its_last_enemies_go_together(kit : TestKit) -> void:
	await kit.load_level(1)
	kit.level.wave_runner.current_wave_index = 0
	var cleared : Array[int] = [0]
	var on_cleared : Callable = func(_wave : int) -> void: cleared[0] += 1
	GameSignals.wave_cleared.connect(on_cleared)
	var killed : Enemy = kit.spawn_enemy("weakling")
	var leaker : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	#one dies and one reaches the castle in the same frame
	_hit(killed, 99999.0)
	killed.die()
	GameSignals.enemy_reached_end_point.emit(leaker)
	await kit.frames(2)
	kit.check(cleared[0] == 1, "the wave clears once (%d)" % cleared[0])
	GameSignals.wave_cleared.disconnect(on_cleared)


func test_the_level_is_lost_once(kit : TestKit) -> void:
	await kit.load_level(1)
	var lost : Array[int] = [0]
	var on_lost : Callable = func() -> void: lost[0] += 1
	GameSignals.lose_game.connect(on_lost)
	kit.level.player_stats.life = 1.0
	var first : Enemy = kit.spawn_enemy("weakling")
	var second : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	GameSignals.enemy_reached_end_point.emit(first)
	GameSignals.enemy_reached_end_point.emit(second)
	kit.check(lost[0] == 1, "two leaks after the last life lose the level once (%d)" % lost[0])
	GameSignals.lose_game.disconnect(on_lost)


#2026-11-23: a clicked enemy that died kept its card up, and the selection holders kept the freed node
func test_a_selected_enemy_that_dies_is_deselected(kit : TestKit) -> void:
	await kit.load_level(1)
	var selection : UnitSelection = kit.level.get_node("UnitSelection")
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	var deselected : Array[int] = [0]
	var on_deselected : Callable = func() -> void: deselected[0] += 1
	UISignals.deselected_unit.connect(on_deselected)
	GameSignals.forced_selection.emit(enemy)
	kit.check(selection.selected_unit == enemy and enemy.selectable.is_selected, "the enemy is selected")
	_hit(enemy, 10000.0)
	#the behaviour tree's Dead leaf calls die() on its next tick
	await kit.run_until(func() -> bool: return enemy.is_deactivated, 2.0)
	kit.check(selection.selected_unit == null and not enemy.selectable.is_selected, "its death deselects it")
	kit.check(deselected[0] == 1, "and its card closes (%d)" % deselected[0])
	kit.check(kit.level.building_type_upgrades.selected_unit == null, "the upgrades let go of it too")
	UISignals.deselected_unit.disconnect(on_deselected)


func test_an_enemy_caught_by_an_eruption_walks_off_the_lava(kit : TestKit) -> void:
	await kit.load_level(52)
	var lava_field : LavaField = kit.level.get_node(Level.LAVA_FIELD_NAME)
	var enemy : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	var grid : LevelGrid = kit.level.grid
	var caught : Vector2i = Vector2i.MAX
	for i in range(4, enemy.point_path.size() - 4):
		var cell : Vector2i = grid.world_position_to_grid(enemy.point_path[i])
		lava_field.erupt([cell] as Array[Vector2i])
		if lava_field.erupted.has(cell):
			caught = cell
			break
	kit.check(caught != Vector2i.MAX, "a cell on the road erupts")
	if caught == Vector2i.MAX:
		return
	enemy.global_position = grid.grid_position_to_world(caught)
	enemy.path_to(enemy.global_position, enemy.end_point.global_position)
	var path : PackedVector2Array = enemy.point_path
	kit.check(path.size() > 1, "the enemy on the lava gets a road (%d points)" % path.size())
	kit.check(not path.is_empty() and grid.world_position_to_grid(path[path.size() - 1]) == grid.world_position_to_grid(enemy.end_point.global_position),
		"the road reaches the castle")
	kit.check(not path.is_empty() and grid.world_position_to_grid(path[0]) != caught and grid.is_cell_walkable(grid.world_position_to_grid(path[0])),
		"the road starts on open ground next to the lava")


func test_towers_and_traps_keep_their_own_range(kit : TestKit) -> void:
	await kit.load_level(1)
	var taken : Array[Vector2i] = []
	for kind in ["puffe_bolter", "puffe_beamer", "puffe_nova", "leopard_trap"]:
		var cell : Vector2i = _buildable(kit, taken)
		taken.append(cell)
		var other_cell : Vector2i = _buildable(kit, taken)
		taken.append(other_cell)
		var ranged_up : Building = await kit.place(kind, cell)
		var plain : Building = await kit.place(kind, other_cell)
		var plain_radius : float = plain.area_shape.shape.radius
		var more_range : ModifierData = Elite.multiply(Utils.StatType.AttackRange, 2.0)
		ranged_up.modifier_manager.add_modifier(more_range)
		kit.check(ranged_up.area_shape.shape != plain.area_shape.shape, "%s instances have their own range shape" % kind)
		kit.check_near(plain.area_shape.shape.radius, plain_radius, "%s: another's range leaves this one's area alone" % kind)


func test_nova_bursts_keep_their_own_animation(kit : TestKit) -> void:
	await kit.load_level(1)
	var scene : PackedScene = load("res://scenes/unit/skills/projectiles/fire_nova_area_effect.tscn")
	var first : CustomAreaEffect = scene.instantiate()
	var second : CustomAreaEffect = scene.instantiate()
	kit.level.add_child(first)
	kit.level.add_child(second)
	var name : StringName = first.animation_name
	kit.check(first.animation_player.get_animation(name) != second.animation_player.get_animation(name),
		"each burst sizes its own animation")
	first.queue_free()
	second.queue_free()


func test_a_wall_joins_only_its_neighbours(kit : TestKit) -> void:
	await kit.load_level(1)
	var grid : LevelGrid = kit.level.grid
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return grid.is_position_buildable(grid.grid_position_to_world(c)) \
			and grid.is_position_buildable(grid.grid_position_to_world(c + Vector2i.RIGHT)))
	var far : Vector2i = kit.find_cell(func(c : Vector2i) -> bool:
		return grid.is_position_buildable(grid.grid_position_to_world(c)) and Vector2(c - cell).length() > 2.5)
	var wall : Wall = await kit.place("wall", cell)
	await kit.place("wall", cell + Vector2i.RIGHT)
	await kit.place("wall", far)
	kit.check(wall.neighbour_buildings.has(cell + Vector2i.RIGHT), "a wall joins the wall beside it")
	kit.check(not wall.neighbour_buildings.has(far), "a wall far away is not its neighbour")
	kit.check(not wall.neighbour_buildings.has(cell), "a wall is not its own neighbour")
