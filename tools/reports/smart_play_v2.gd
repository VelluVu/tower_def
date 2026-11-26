extends "res://tools/reports/smart_play.gd"

## The smart player, round 2 (`play=smart smart=smart_play_v2`; plan in docs/design/playtesting.md, 2026-11-20):
## 1. Walls in pairs: when no single wall adds tower damage on the routes, it tries every pair of route
##    cells in the towers' reach, since a detour around a tower usually takes two walls to open.
## 2. A knapsack per decision: the set of actions with the most gain the gold on hand buys (a small dynamic
##    programme over whole gold), bought best value per gold first, instead of the save-or-spend guess.
##    It still saves when nothing is affordable, or when the coming wave's kill gold buys a set worth
##    clearly more (SAVE_RATIO) and the field is quiet.
## 3. Sell and rebuild: in a build break, a tower without upgrades whose route cells in reach fell under
##    half of what it had when placed is sold (full refund) and the gold planned again.

#a pair is searched over at most this many cells (the route cells most towers reach)
const PAIR_CANDIDATES : int = 24
const SELL_SHARE : float = 0.5
const COVER_META : StringName = &"smart_cover"
#the wave's kill gold counts this much while planning to save for it (it arrives over the wave)
const INCOME_SHARE : float = 0.5

var pending_walls : Array[Vector2i] = []
#each part can be switched for comparisons: v2_pairs=0 v2_sell=0, v2_knapsack=1 (off by default: it lost levels
#10 and 11 that the greedy plan wins, 2026-11-20; a set's summed gains overrate cheap actions bought one by one)
var use_pairs : bool = true
var use_knapsack : bool = false
var use_sell : bool = true
var sold : int = 0
var enemy_prices : Dictionary[String, float] = {}


func _init(soak : RefCounted) -> void:
	super(soak)
	use_pairs = bot.options.get("v2_pairs", "1") == "1"
	use_knapsack = bot.options.get("v2_knapsack", "0") == "1"
	use_sell = bot.options.get("v2_sell", "1") == "1"


func step(kit : TestKit, level : Level) -> void:
	if not pending_walls.is_empty() and level.player_stats.has_enough_gold(bot._placement_price(level, bot.WALL)):
		var cell : Vector2i = pending_walls.pop_front()
		if bot._is_free_to_build(level, cell):
			level.grid.set_cell_weight(cell, bot.BLOCKED_WEIGHT)
			var is_open : bool = not bot._open_routes(level).is_empty()
			level.grid.set_cell_weight(cell, 1.0)
			if is_open:
				await bot._place(kit, level, bot.WALL, cell)
				bot.walls += 1
				_count("wall")
				is_dirty = true
				return
		pending_walls.clear()
	if use_sell and _is_build_break(level) and _sell_stranded(level):
		is_dirty = true
		return
	await super(kit, level)


func _is_build_break(level : Level) -> bool:
	return level.existing_enemies.is_empty() and not level.wave_runner.is_spawning


## Sells one tower the route has walked away from. True when it sold.
func _sell_stranded(level : Level) -> bool:
	var routes : Array[Vector2i] = bot._route_cells(level)
	for unit in units:
		if not is_instance_valid(unit) or unit is Trap or bot.purchases.get(unit, 0) > 0 or not unit.has_meta(COVER_META):
			continue
		var now : float = _covered(routes, unit.grid_position, _stat(unit, Utils.StatType.AttackRange))
		if now < float(unit.get_meta(COVER_META)) * SELL_SHARE:
			units.erase(unit)
			bot.towers.erase(unit)
			GameSignals.sell_building.emit(unit)
			sold += 1
			_count("sold")
			return true
	return false


func _execute(kit : TestKit, level : Level, action : Dictionary) -> void:
	if action.kind == Kind.Wall and action.has("cells"):
		var cells : Array = action.cells
		await bot._place(kit, level, bot.WALL, cells[0])
		bot.walls += 1
		_count("wall")
		for index in range(1, cells.size()):
			pending_walls.append(cells[index])
		return
	await super(kit, level, action)
	if action.kind == Kind.Tower and not units.is_empty():
		var unit : Building = units[-1]
		unit.set_meta(COVER_META, _covered(bot._route_cells(level), unit.grid_position, _stat(unit, Utils.StatType.AttackRange)))


func _make_plan(level : Level) -> Dictionary:
	if not use_knapsack:
		return super(level)
	var actions : Array[Dictionary] = []
	actions.assign(_actions(level).filter(func(action : Dictionary) -> bool: return action.gain > 0.0))
	if actions.is_empty():
		return {}
	var gold : float = level.player_stats.gold
	for action in actions:
		action.ratio = action.gain / maxf(action.cost, 0.5)
	var best_ratio : float = 0.0
	for action in actions:
		best_ratio = maxf(best_ratio, action.ratio)

	var now : Dictionary = _knapsack(actions, gold)
	var later : Dictionary = _knapsack(actions, gold + _wave_income(level) * INCOME_SHARE) if _is_build_break(level) else now
	if now.items.is_empty():
		#nothing affordable: save for the best of what the wave's gold buys
		var target : Dictionary = _best_of(later.items if not later.items.is_empty() else actions)
		return {"buy": target, "saving": true, "best_ratio": best_ratio}
	#a quiet field and a clearly better set a little later: wait for its first item
	if later.value > now.value * SAVE_RATIO:
		var waiting : Dictionary = _best_of(later.items.filter(func(action : Dictionary) -> bool: return action.cost > gold))
		if not waiting.is_empty():
			return {"buy": waiting, "saving": true, "best_ratio": best_ratio}
	return {"buy": _best_of(now.items), "saving": false, "best_ratio": best_ratio}


func _best_of(items : Array) -> Dictionary:
	var best : Dictionary = {}
	for action in items:
		if best.is_empty() or action.ratio > best.ratio:
			best = action
	return best


## The most total gain within the gold: 0/1 knapsack over whole gold (prices are small whole numbers).
func _knapsack(actions : Array[Dictionary], gold : float) -> Dictionary:
	var budget : int = int(floor(gold))
	if budget <= 0:
		return {"items": [], "value": 0.0}
	var best : PackedFloat64Array = PackedFloat64Array()
	best.resize(budget + 1)
	best.fill(0.0)
	var keep : Array[PackedByteArray] = []
	for index in actions.size():
		var cost : int = maxi(int(ceil(actions[index].cost)), 1)
		var row : PackedByteArray = PackedByteArray()
		row.resize(budget + 1)
		row.fill(0)
		for g in range(budget, cost - 1, -1):
			var with_it : float = best[g - cost] + actions[index].gain
			if with_it > best[g]:
				best[g] = with_it
				row[g] = 1
		keep.append(row)
	var items : Array = []
	var g : int = budget
	for index in range(actions.size() - 1, -1, -1):
		if keep[index][g] == 1:
			items.append(actions[index])
			g -= maxi(int(ceil(actions[index].cost)), 1)
	return {"items": items, "value": best[budget]}


## The coming wave's kill gold (the enemies' Price), 0 when the next wave is unknown.
func _wave_income(level : Level) -> float:
	var runner : WaveRunner = level.wave_runner
	var index : int = runner.current_wave_index + 1
	if index < 0 or index >= runner.waves.size():
		return 0.0
	var income : float = 0.0
	for group in runner.waves[index].spawn_groups:
		if group.enemy_scene != null:
			income += _enemy_price(group.enemy_scene) * group.count
	return income


func _enemy_price(scene : PackedScene) -> float:
	if not enemy_prices.has(scene.resource_path):
		var instance : Node = scene.instantiate()
		var price : float = 0.0
		for stat in instance.find_children("*", "Stat", true, false):
			if stat.type == Utils.StatType.Price and stat.get_parent().get_parent() == instance:
				price = stat.base_value
		instance.free()
		enemy_prices[scene.resource_path] = price
	return enemy_prices[scene.resource_path]


## The single best wall, or else the best pair of walls (placed one after the other).
func _wall_action(level : Level) -> Dictionary:
	var single : Dictionary = super(level)
	if not single.is_empty() or not use_pairs:
		return single
	var hold : float = bot._maze_hold(level)
	var before : float = _maze_value(bot._open_routes(level), bot._maze_cells(level), hold)
	var candidates : Array[Vector2i] = _pair_candidates(level)
	var best_pair : Array[Vector2i] = []
	var best_value : float = before
	for a in candidates.size():
		level.grid.set_cell_weight(candidates[a], bot.BLOCKED_WEIGHT)
		if bot._open_routes(level).is_empty():
			level.grid.set_cell_weight(candidates[a], 1.0)
			continue
		for b in range(a + 1, candidates.size()):
			level.grid.set_cell_weight(candidates[b], bot.BLOCKED_WEIGHT)
			var routes : Array[Array] = bot._open_routes(level)
			level.grid.set_cell_weight(candidates[b], 1.0)
			if routes.is_empty():
				continue
			var value : float = _maze_value(routes, bot._maze_cells(level, [candidates[a], candidates[b]]), hold)
			if value > best_value:
				best_value = value
				best_pair = [candidates[a], candidates[b]]
		level.grid.set_cell_weight(candidates[a], 1.0)
	if best_pair.is_empty():
		return {}
	var price : float = bot._placement_price(level, bot.WALL)
	return {"kind": Kind.Wall, "scene": bot.WALL, "cell": best_pair[0], "cells": best_pair, "cost": price * 2.0, "gain": best_value - before}


#free route cells and their free neighbours, the ones the most towers reach first
func _pair_candidates(level : Level) -> Array[Vector2i]:
	var ends : Dictionary[Vector2i, bool] = {}
	for spawner in level.get_spawners():
		ends[level.grid.world_position_to_grid(spawner.global_position)] = true
		ends[level.grid.world_position_to_grid(spawner.end_point.global_position)] = true
	var scored : Dictionary[Vector2i, float] = {}
	for cell in bot._route_cells(level):
		for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var candidate : Vector2i = cell + offset
			if scored.has(candidate) or ends.has(candidate) or not bot._is_free_to_build(level, candidate):
				continue
			var score : float = 0.0
			for unit in units:
				if is_instance_valid(unit) and not unit is Trap:
					var reach : float = _stat(unit, Utils.StatType.AttackRange) + 1.0
					if Vector2(unit.grid_position - candidate).length_squared() <= reach * reach:
						score += _unit_dps(unit)
			if score > 0.0:
				scored[candidate] = score
	var cells : Array[Vector2i] = scored.keys()
	cells.sort_custom(func(a : Vector2i, b : Vector2i) -> bool: return scored[a] > scored[b])
	return cells.slice(0, PAIR_CANDIDATES)
