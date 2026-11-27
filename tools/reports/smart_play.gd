extends RefCounted

## The soak bot's smart player (`play=smart`): every action it can take (a new tower of each type at its
## best cell, each building's next upgrade or element, a wall, a trap) is valued as the damage per second
## it adds on the routes, times the route cells it covers, per gold; it buys the best one, or saves for it
## when it is worth clearly more than what it can afford now. Gains come from the game's own modifier maths
## run on the extra modifiers (nothing is applied to try), and each building's estimate is corrected by the
## damage it really deals, so area hits, chains, resistances and overkill are learned during the run.
## It also reads the coming wave (flyers, swarms, resistances), picks the card with the biggest gain and
## starts waves early only while the last one never got halfway.

## Dps at Base in real games: tower_sheet.gd's single-target dps against a parked weakling (2026-11-25, before the
## small numbers) times the median of what each kind really dealt over that promise in 48 bot games (SOAK smart
## learned, 2026-11-26: Bolter 0.11, Nova 0.47 (a burst hits many walkers), Beamer 0.18, Breather 0.17, Spotter 0.15,
## Mortar 0.13 (its shells miss walkers), Elder 0.19, Shredder 0.57; traps 0.01-0.02, since a trap counts as busy
## all wave but hits only when stepped on). Hatchery: no data, half the Bolter. Harpooner 0.3: it dealt 1.0-1.4 times
## a first guess of 0.24 in six frost games once the bot knew its tether (2026-11-26); 0.19 since it throws as
## slowly as the Spotter (4.5 s a throw, was 2.9 s).
## A second round of 48 games set them closer (their medians: Nova 1.0, Breather 0.63, Mortar 0.33, Elder 1.83,
## Spotter 0.65, Bolter 0.42, Beamer 0.51, Leopard 0.1). These are averages over crowds: _fit moves a kind up or
## down from a usual crowd (TYPICAL_SWARM), so the crowds are not counted twice.
## Spotter 1.0 since 2026-11-27: its base hit went 1.75 -> 3 (x1.7) and its +50% maze bonus went away.
## The Hoard Keeper and the Buffer deal none: their worth is gold and the buffed towers (_hoard_gain, _buffer_gain).
const SHEET_BASE_DPS : Dictionary[String, float] = {"PuffeBolter": 0.42, "PuffeNova": 1.0, "PuffeBeamer": 0.51, "PuffeMortar": 0.33,
	"PuffeBreather": 0.63, "PuffeSpotter": 1.0, "PuffeHarpooner": 0.19, "PuffeHatchery": 0.25, "PuffeShredder": 0.14, "PuffeElderDrake": 1.83,
	"LeopardTrap": 0.1, "EggBomb": 0.12, "SpikeField": 0.06, "PuffeHoardKeeper": 0.0, "PuffeBuffer": 0.0}
## The swarm share of an average wave's health, which the measured SHEET_BASE_DPS already has in.
const TYPICAL_SWARM : float = 0.5
## A tower that cannot reach flyers weighs the flyers of the waves still to come at this share (a level of Novas
## lost its flyer waves, 2026-11-26).
const LATER_FLYERS_SHARE : float = 0.75
## A wall's niche worth for one unit stops growing past about this many route cells' worth (the maze value counts every
## cell in reach: a 6-tile Spotter made 30 walls beat a third tower on level 26, 2026-11-26).
const NICHE_CELLS : float = 7.5
## A Harpooner's tether (HarpoonTether): the share of the enemies in its reach that one harpoon keeps chained at a time
## (2 s chains against a usual crowd), how much of a boss's time a tether slows it (a land boss is slowed at full
## strength, the chain pierces the boss nerf; a flying one is held 3 s in 10), and how much of a grounded flyer's
## worth the ground-only towers in its reach get (it walks the maze from where it lands).
const TETHER_SHARE : float = 0.25
const TETHER_BOSS_SHARE : float = 0.5
#(0.8 since grounded flyers crash: 2 s stunned, then 60% speed for good, HarpoonTether.GROUNDED_STUN_SECONDS)
const GROUNDED_SHARE : float = 0.8
## Each element's T1 dps over Up 2 (tower_sheet.gd); Frost's slow is not in it (FROST_SLOW_VALUE).
const ELEMENT_GAIN : Dictionary[String, Dictionary] = {
	"PuffeBolter": {"Physical": 1.53, "Fire": 1.4, "Frost": 1.24, "Poison": 1.67},
	"PuffeNova": {"Physical": 1.29, "Fire": 1.29, "Frost": 1.07, "Poison": 1.63},
	"PuffeBeamer": {"Physical": 1.45, "Fire": 1.49, "Frost": 1.11, "Poison": 1.58},
	"PuffeMortar": {"Physical": 1.11, "Fire": 1.51, "Frost": 0.96, "Poison": 1.8},
	"PuffeBreather": {"Physical": 1.17, "Fire": 1.51, "Frost": 1.07, "Poison": 1.45},
	"PuffeSpotter": {"Physical": 1.07, "Fire": 1.33, "Frost": 1.0, "Poison": 1.84},
	"PuffeHarpooner": {"Physical": 1.07, "Fire": 1.2, "Frost": 0.89, "Poison": 1.51},
	"PuffeHatchery": {"Physical": 1.17, "Fire": 1.29, "Frost": 1.01, "Poison": 1.62},
	"PuffeShredder": {"Physical": 1.33, "Fire": 1.33, "Frost": 1.17, "Poison": 1.5},
	"PuffeElderDrake": {"Physical": 1.48, "Fire": 1.47, "Frost": 1.02, "Poison": 1.57},
	"LeopardTrap": {"Physical": 1.34, "Fire": 2.12, "Frost": 0.9, "Poison": 1.68},
	"SpikeField": {"Physical": 1.25, "Fire": 1.07, "Frost": 0.81, "Poison": 1.32},
}
## What a tower type is good at, for _fit: reaches flyers (false: never, "tier2": from its T2), extra hits on a
## swarm (how many more enemies a hit lands on, roughly), and bonuses against flyers and elites.
const TRAITS : Dictionary[String, Dictionary] = {
	#the Mortar's misses on walking enemies are in its SHEET_BASE_DPS now (measured in games)
	"PuffeNova": {"air": "tier2", "swarm": 1.5}, "PuffeMortar": {"air": false, "swarm": 1.5},
	"PuffeBreather": {"swarm": 1.5}, "PuffeShredder": {"swarm": 1.0}, "PuffeElderDrake": {"swarm": 0.5},
	"PuffeHatchery": {"air": false}, "PuffeHarpooner": {"flyers": 1.0}, "PuffeSpotter": {"elites": 1.0},
	"LeopardTrap": {"air": "tier2"}, "SpikeField": {"air": false, "swarm": 1.0}, "EggBomb": {"swarm": 2.0},
}
## Route cells in reach count fully up to about this many, then less and less (_covered).
const REACH_CELLS : float = 15.0
## Economy (the Hoard Keeper) only once this many damage towers stand and the last wave leaked nothing.
const ECONOMY_MIN_TOWERS : int = 3
## Gold to come is worth this share of gold now (it arrives wave by wave).
const GOLD_LATER : float = 0.5
## A Buffer's element and tiers: this share of the covered towers' worth (a chance of the element, T2 weakening,
## T3 roar).
const BUFFER_EVOLVE_SHARE : float = 0.08
## The three traps, the order the smart player looks at them.
const TRAP_SCENES : Array[String] = ["leopard_trap", "egg_bomb", "spike_field"]
## Scenes whose root node is named other than their file (keys are root names).
const SCENE_KEYS : Dictionary[String, String] = {"puffe_elder": "PuffeElderDrake", "puffe_hoard": "PuffeHoardKeeper"}
## A Shredder's three stacks take this much off every resistance (Shredder.SHRED_PER_STACK x MAX_STACKS).
const SHRED_MOST : float = 0.45
## The share of the other towers' work on the rally cells that held enemies add (guards stop them there).
const HOLD_VALUE : float = 0.15
## Waves a Survival run counts ahead for gold (it has no end).
const SURVIVAL_WAVES_AHEAD : int = 8
## An element wall's maze effect: Frost slows enemies beside it (LevelGrid), Fire and Poison hurt them a second
## (MazeElements); Physical (Fortress) slows a little.
const WALL_SLOW : Dictionary[String, float] = {"Frost": 0.12, "Physical": 0.06}
#MazeElements.GROUND_DAMAGE a second (2.0 and 1.0 before the small numbers)
const WALL_DPS : Dictionary[String, float] = {"Fire": 0.25, "Poison": 0.125}
## The wall line's Up 1 and Up 2 open the elements: their worth is a share of what an element wall would add.
const WALL_LINE_SHARE : float = 0.5
const DEFAULT_ELEMENT_GAIN : float = 1.25
#the slow keeps every other tower on the enemies longer
const FROST_SLOW_VALUE : float = 0.2
#T2 and T3 (placeholder steps: +25% damage; +40% damage and +0.15 attack speed, plus a mechanic)
const TIER_GAINS : Array[float] = [1.3, 1.45]
const ELEMENT_NAMES : Array[String] = ["Physical", "Fire", "Frost", "Poison"]
const ELEMENTS : Dictionary[String, Utils.Element] = {"Physical": Utils.Element.Physical, "Fire": Utils.Element.Fire, "Frost": Utils.Element.Frost, "Poison": Utils.Element.Poison}
const DAMAGE_TYPES : Dictionary[String, Utils.DamageType] = {"Physical": Utils.DamageType.Physical, "Fire": Utils.DamageType.Fire, "Frost": Utils.DamageType.Frost, "Poison": Utils.DamageType.Poison}
#a group this big is a swarm (area towers hit many of it, TRAITS)
const SWARM_COUNT : int = 8
#a trap reaches its own cell and the enemies stepping on and off it
const TRAP_CELLS : float = 2.0
#save for the best action when it is worth this much more per gold than the best affordable one
const SAVE_RATIO : float = 1.6
#and only when it costs at most this many times the gold on hand
const SAVE_REACH : float = 2.5
const REPLAN_SECONDS : float = 1.0
#measured damage counts fully after this many seconds with a target
const LEARN_SECONDS : float = 10.0
const LEARN_MIN : float = 0.3
const LEARN_MAX : float = 4.0
#start the next wave early only while the last one never got this far along its route
const EARLY_PROGRESS : float = 0.5
#a wall's route length counts a little, so ties go to the longer maze
const WALL_LENGTH_VALUE : float = 0.02
## The synergies' worth (Synergies, 2026-11-25).
const SYNERGY = preload("res://tools/reports/smart_synergies.gd")
## The towers' niches (TowerNiches): corridors, corners, the maze, slow cells, by tower kind.
const NICHES = preload("res://tools/reports/bot_niches.gd")
## A Shredder's stacks double on pinned enemies and its shred lasts longer on elites and bosses: worth this much more
## per share of its cells where enemies go slow, and per share of the wave's health in elites.
const SHRED_PINNED_VALUE : float = 0.5
const SHRED_TOUGH_VALUE : float = 0.5
## A trap cell beside another trap is a candidate while at least this share of the best cell's towers reach it.
const TRAP_SIDE_REACH : float = 0.5
## Hold the line: a trap cell is worth this many towers more as a rally cell.
const RALLY_TRAP_WORKERS : int = 3

enum Kind { Tower, Upgrade, Wall, Trap }

var bot : RefCounted = null
#towers and traps this player placed, upgrades go to these
var units : Array[Building] = []
var damage : Dictionary[Building, float] = {}
var expected : Dictionary[Building, float] = {}
var active_time : Dictionary[Building, float] = {}
var base_power : Dictionary[String, float] = {}
var enemy_info : Dictionary[String, Dictionary] = {}
var plan : Dictionary = {}
var plan_age : float = INF
var is_dirty : bool = true
var is_idle : bool = false
var wave_progress : float = 0.0
var last_wave_progress : float = 1.0
var last_wave_leaks : int = 0
var wave_leaks : int = 0
var tracked_wave : int = 0
var bought : Dictionary[String, int] = {}
#Twin Harpoons: the Harpooner's throws times this (1 + TalentEffect.Kind.HarpoonMultiplier), read every tick
var harpoon_multiplier : float = 1.0


func _init(soak : RefCounted) -> void:
	bot = soak
	GameSignals.astar_grid_updated.connect(func() -> void: is_dirty = true)
	GameSignals.enemy_reached_end_point.connect(func(_enemy : Enemy) -> void: wave_leaks += 1)


## Every frame: game seconds pass, the measured damage is weighed against what the stats promise.
func tick(level : Level, seconds : float) -> void:
	plan_age += seconds
	harpoon_multiplier = 1.0 + (level.talents.get_total(TalentEffect.Kind.HarpoonMultiplier) if level.talents != null else 0.0)
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if _is_active(level, unit):
			active_time[unit] = active_time.get(unit, 0.0) + seconds
			expected[unit] = expected.get(unit, 0.0) + _stat_dps(unit) * seconds
	#how far the furthest enemy of this wave got
	if level.wave_runner.wave_number != tracked_wave:
		tracked_wave = level.wave_runner.wave_number
		last_wave_progress = wave_progress
		last_wave_leaks = wave_leaks
		wave_progress = 0.0
		wave_leaks = 0
	for enemy in level.existing_enemies:
		if is_instance_valid(enemy) and enemy.point_path.size() > 0:
			wave_progress = maxf(wave_progress, float(enemy.current_waypoint_index) / enemy.point_path.size())


func on_hit(hit : DamageData) -> void:
	var source : Building = hit.source as Building
	if source != null and units.has(source):
		damage[source] = damage.get(source, 0.0) + hit.damage


## Starts the coming wave early: the last one never got far and leaked nothing, and this one has not either.
func wants_early(level : Level) -> bool:
	return level.wave_runner.wave_number > 0 and last_wave_leaks == 0 and wave_leaks == 0 \
		and last_wave_progress < EARLY_PROGRESS and wave_progress < EARLY_PROGRESS * 0.5


## One action a frame at most: replans when something changed, buys the best action when it can.
func step(kit : TestKit, level : Level) -> void:
	if is_dirty or plan_age >= REPLAN_SECONDS:
		_set_tactics(level)
		plan = _make_plan(level)
		plan_age = 0.0
		is_dirty = false
	if plan.is_empty():
		is_idle = true
		return
	var action : Dictionary = plan.get("buy", {})
	if action.is_empty() or not level.player_stats.has_enough_gold(action.cost):
		#nothing to buy now: the wave may start (its kills bring the gold it is saving for)
		is_idle = true
		return
	is_idle = false
	await _execute(kit, level, action)
	is_dirty = true


## The action to buy now: the best value per gold it can afford, unless a dearer one is worth saving for.
func _make_plan(level : Level) -> Dictionary:
	var actions : Array[Dictionary] = _actions(level)
	if actions.is_empty():
		return {}
	var gold : float = level.player_stats.gold
	var best : Dictionary = {}
	var best_affordable : Dictionary = {}
	for action in actions:
		if action.gain <= 0.0:
			continue
		action.ratio = action.gain / maxf(action.cost, 0.5)
		if best.is_empty() or action.ratio > best.ratio:
			best = action
		if action.cost <= gold and (best_affordable.is_empty() or action.ratio > best_affordable.ratio):
			best_affordable = action
	if best.is_empty():
		return {}
	if best_affordable.is_empty() or (best != best_affordable and best.ratio > best_affordable.ratio * SAVE_RATIO and best.cost <= gold * SAVE_REACH + 1.0):
		return {"buy": best, "saving": true, "best_ratio": best.ratio}
	return {"buy": best_affordable, "saving": false, "best_ratio": best.ratio}


func _actions(level : Level) -> Array[Dictionary]:
	var actions : Array[Dictionary] = []
	var threat : Dictionary = _threat(level)
	var routes : Array[Vector2i] = bot._route_cells(level)

	#a new tower of each type at its best cell
	if bot.towers.size() < int(bot.options.towers):
		for scene_name in bot._tower_types():
			var range_tiles : float = bot._range_of(scene_name)
			var key : String = _key_of_scene(scene_name)
			var cell : Vector2i = Vector2i.MAX
			var gain : float = 0.0
			var gold : float = -1.0
			if scene_name == bot.BUFFER:
				cell = bot._best_buffer_cell(level)
				if cell != Vector2i.MAX:
					gain = _buffer_gain(level, cell, routes, {Utils.StatType.Damage: 1})
			elif scene_name == bot.HOARD:
				cell = bot._keeper_cell(level)
				if cell != Vector2i.MAX:
					gold = _hoard_gold(level, HoardKeeper.BASE_PAY * (1.0 if _hoard_count() < HoardKeeper.FULL_PAY_KEEPERS else HoardKeeper.PARTIAL_SHARE))
			else:
				cell = bot._best_tower_cell(level, range_tiles, bot._min_range_of(scene_name), scene_name)
				if cell != Vector2i.MAX:
					var covered : float = _covered(routes, cell, range_tiles, _niches_for(level, key, bot._build_element_name(), routes))
					gain = _new_unit_dps(level, scene_name, routes) * _fit(key, threat) * covered
					if key == "PuffeShredder":
						gain += _shred_gain(cell, range_tiles, routes, threat, level)
					elif key == "PuffeHatchery":
						gain += _hold_gain(cell, range_tiles, routes, threat)
					elif key == "PuffeHarpooner":
						gain += _tether_gain(cell, range_tiles, routes, threat, 1)
					gain += SYNERGY.tower_gain(self, level, scene_name, cell, range_tiles, routes, threat)
			if cell == Vector2i.MAX:
				continue
			var action : Dictionary = {"kind": Kind.Tower, "scene": scene_name, "cell": cell, "cost": bot._placement_price(level, scene_name), "gain": gain}
			if gold >= 0.0:
				action.gold = gold
				#Hoard Guardian: the Elders it stands by bite harder, worth as much now as later
				action.synergy = SYNERGY.keeper_gain(self, routes, cell)
			actions.append(action)

	if bot.traps < int(bot.options.traps):
		var trap_cells : Array[Vector2i] = _trap_cells(level)
		for trap_scene in TRAP_SCENES:
			if trap_cells.is_empty() or not bot._is_unlocked(trap_scene):
				continue
			var trap_key : String = _key_of_scene(trap_scene)
			var base_gain : float = _new_unit_dps(level, trap_scene, routes) * _fit(trap_key, threat) * TRAP_CELLS
			#the cell where its synergies and the maze (TowerNiches) add the most (the first is the cell the most towers reach)
			var maze : Dictionary[Vector2i, bool] = bot._maze_cells(level)
			var best_cell : Vector2i = trap_cells[0]
			var best_total : float = -1.0
			for trap_cell in trap_cells:
				var total : float = base_gain * NICHES.cell_factor(level.grid, trap_key, trap_cell, maze) + SYNERGY.trap_gain(self, level, trap_scene, trap_cell, threat)
				if total > best_total:
					best_total = total
					best_cell = trap_cell
			actions.append({"kind": Kind.Trap, "scene": trap_scene, "cell": best_cell, "cost": bot._placement_price(level, trap_scene), "gain": best_total})

	for unit in units:
		if is_instance_valid(unit):
			var upgrade : Dictionary = _upgrade_action(level, unit, routes, threat)
			if not upgrade.is_empty():
				actions.append(upgrade)
	#the walls' line and elements (bought per wall once the line has its Up 2)
	if bot.walls > 0:
		var wall_upgrade : Dictionary = _wall_upgrade_action(level, routes)
		if not wall_upgrade.is_empty():
			actions.append(wall_upgrade)
	#gold (the Hoard Keeper) is worth what the best damage buy does with it, a little less since it comes later
	var damage_ratio : float = 0.0
	for action in actions:
		if not action.has("gold"):
			damage_ratio = maxf(damage_ratio, action.gain / maxf(action.cost, 0.5))
	#economy waits for a defence that holds: some damage towers and a last wave without leaks
	var is_safe : bool = _damage_tower_count() >= ECONOMY_MIN_TOWERS and last_wave_leaks == 0 and level.wave_runner.wave_number > 0
	for action in actions:
		if action.has("gold"):
			action.gain = (action.gold * damage_ratio * GOLD_LATER if is_safe else 0.0) + action.get("synergy", 0.0)

	if float(bot.options.walls) > 0.0 and not bot.is_wall_exhausted and _tower_count() > 0:
		var wall : Dictionary = _wall_action(level)
		if wall.is_empty():
			bot.is_wall_exhausted = true
		else:
			actions.append(wall)
	return actions


## The unit's next gold step: an upgrade (its modifiers' gain), the element that fits the coming wave
## best, or the next tier.
func _upgrade_action(level : Level, unit : Building, routes : Array[Vector2i], threat : Dictionary) -> Dictionary:
	var upgrades : BuildingTypeUpgrades = level.building_type_upgrades
	upgrades._on_unit_selected(unit)
	var options : Array[GoldUpgradeOption] = upgrades.options
	if options.is_empty():
		return {}
	var value : float = _unit_dps(unit) * _unit_cells(unit, routes)
	var best_index : int = -1
	var best_gain : float = 0.0
	for index in options.size():
		var option : GoldUpgradeOption = options[index]
		if option.is_locked:
			continue
		#the towers that deal no damage: every Hoard Keeper step pays a gold more a wave; a Buffer pip lifts its
		#track on every tower in the aura, its element and tiers a little of everything there
		if unit is HoardKeeper or unit is Buffer:
			if bot.build.has("leaf") and not option.element_leaf_path.is_empty() and not unit.evolve_tree.is_element_chosen \
					and not str(option.element_leaf_path).ends_with(bot.build.leaf):
				continue
			var special : float = 0.0
			if unit is HoardKeeper:
				special = _hoard_gold(level, HoardKeeper.PAY_PER_STEP * (1.0 if unit.get_rank(level) < HoardKeeper.FULL_PAY_KEEPERS else HoardKeeper.PARTIAL_SHARE))
			elif option.buffer_stat >= 0:
				special = _buffer_gain(level, unit.grid_position, routes, {option.buffer_stat: 1}, unit)
			else:
				special = _buffer_covered_value(level, unit.grid_position, routes, unit) * BUFFER_EVOLVE_SHARE
				#Harmony with the covered towers of its element, War cry over Elders at T3
				if option.tier == 0:
					special += SYNERGY.buffer_element_gain(self, unit, _leaf_element(option.element_leaf_path), routes)
				else:
					special += SYNERGY.tier_gain(self, unit, option, routes)
			if best_index < 0 or special > best_gain:
				best_index = index
				best_gain = special
			continue
		var factor : float = 1.0
		var synergy : float = 0.0
		if not option.is_evolve:
			factor = _power(unit, _upgrade_modifiers(unit)) / maxf(_power(unit), 0.001)
		elif not option.element_leaf_path.is_empty() and not unit.evolve_tree.is_element_chosen:
			var element_name : String = _leaf_element(option.element_leaf_path)
			if bot.build.has("leaf") and not str(option.element_leaf_path).ends_with(bot.build.leaf):
				continue
			factor = _element_factor(_key_of(unit), element_name, threat)
			synergy = SYNERGY.element_gain(self, level, unit, element_name, routes)
			#the element brings the Harpooner its second harpoon; a Frost Nova or Mortar chills its own targets (TowerNiches)
			factor *= _evolve_niche_factor(level, unit, element_name, 1, routes)
			if _key_of(unit) == "PuffeHarpooner":
				synergy += _tether_gain(unit.grid_position, _stat(unit, Utils.StatType.AttackRange), routes, threat, 2, unit) \
					- _tether_gain(unit.grid_position, _stat(unit, Utils.StatType.AttackRange), routes, threat, 1, unit)
		else:
			#option.tier: 1 = T2, 2 = T3
			factor = TIER_GAINS[clampi(option.tier - 1, 0, TIER_GAINS.size() - 1)]
			synergy = SYNERGY.tier_gain(self, unit, option, routes)
			factor *= _evolve_niche_factor(level, unit, _element_name(unit), option.tier + 1, routes)
			if _key_of(unit) == "PuffeHarpooner":
				var tier : int = option.tier + 1
				synergy += _tether_gain(unit.grid_position, _stat(unit, Utils.StatType.AttackRange), routes, threat, tier + 1, unit) \
					- _tether_gain(unit.grid_position, _stat(unit, Utils.StatType.AttackRange), routes, threat, tier, unit)
		var gain : float = value * (factor - 1.0) + synergy
		if best_index < 0 or gain > best_gain:
			best_index = index
			best_gain = gain
	if best_index < 0:
		return {}
	var upgrade : Dictionary = {"kind": Kind.Upgrade, "unit": unit, "index": best_index, "title": options[best_index].title, "cost": options[best_index].cost, "gain": best_gain}
	if unit is HoardKeeper:
		upgrade.gold = best_gain
	return upgrade


## The route cell that adds the most tower damage on the routes as a wall, without closing a route.
func _wall_action(level : Level) -> Dictionary:
	var niche_cache : Dictionary = {}
	var before : float = _maze_value(bot._open_routes(level), bot._maze_cells(level), bot._maze_hold(level), level, Vector2i.MAX, niche_cache)
	var ends : Dictionary[Vector2i, bool] = {}
	for spawner in level.get_spawners():
		ends[level.grid.world_position_to_grid(spawner.global_position)] = true
		ends[level.grid.world_position_to_grid(spawner.end_point.global_position)] = true
	var best_cell : Vector2i = Vector2i.MAX
	var best_value : float = before
	for cell in bot._route_cells(level):
		if ends.has(cell) or not bot._is_free_to_build(level, cell):
			continue
		level.grid.set_cell_weight(cell, bot.BLOCKED_WEIGHT)
		var routes : Array[Array] = bot._open_routes(level)
		level.grid.set_cell_weight(cell, 1.0)
		if routes.is_empty():
			continue
		var value : float = _maze_value(routes, bot._maze_cells(level, [cell]), bot._maze_hold(level), level, cell, niche_cache)
		if value > best_value:
			best_value = value
			best_cell = cell
	if best_cell == Vector2i.MAX:
		return {}
	return {"kind": Kind.Wall, "scene": bot.WALL, "cell": best_cell, "cost": bot._placement_price(level, bot.WALL), "gain": best_value - before}


#every unit's damage per second times the route cells it reaches, plus a little for the length; a maze cell
#(slowed: beside a wall or a tower touching one) counts hold times, the enemies stay that much longer
#
#the niches too (TowerNiches): a wall that makes a corridor for a Breather or a corner for a Nova, or brings a Spotter's
#cells or a trap into the maze, is worth what that tower gains there. Only cells near the weighed wall can change, so
#the rest come from niche_cache.
func _maze_value(routes : Array[Array], maze : Dictionary[Vector2i, bool] = {}, hold : float = 1.0, level : Level = null,
		wall_cell : Vector2i = Vector2i.MAX, niche_cache : Dictionary = {}) -> float:
	var value : float = 0.0
	var total_dps : float = 0.0
	var length : int = 0
	for unit in units:
		if not is_instance_valid(unit):
			continue
		var key : String = _key_of(unit)
		var has_niche : bool = level != null and NICHES.has_cell_niche(key)
		var element : String = _chosen_element(unit)
		if unit is Trap:
			if has_niche:
				value += _unit_dps(unit) * TRAP_CELLS * _niche_at(level, key, element, unit.grid_position, maze, wall_cell, niche_cache)
			continue
		var dps : float = _unit_dps(unit)
		var reach : float = _stat(unit, Utils.StatType.AttackRange) ** 2
		total_dps += dps
		var excess : float = 0.0
		for route in routes:
			for cell in route:
				if Vector2(unit.grid_position - cell).length_squared() <= reach:
					var cell_hold : float = hold if maze.has(cell) else 1.0
					value += dps * cell_hold
					if has_niche:
						excess += cell_hold * (_niche_at(level, key, element, cell, maze, wall_cell, niche_cache) - 1.0)
		#the niche part grows less and less (NICHE_CELLS)
		value += dps * NICHE_CELLS * (1.0 - exp(-excess / NICHE_CELLS))
	for route in routes:
		length += route.size()
	return value + length * total_dps * WALL_LENGTH_VALUE


func _execute(kit : TestKit, level : Level, action : Dictionary) -> void:
	match action.kind:
		Kind.Tower, Kind.Trap:
			var unit : Building = await bot._place(kit, level, action.scene, action.cell)
			if unit == null:
				return
			units.append(unit)
			bot.purchases[unit] = 0
			if action.kind == Kind.Tower:
				unit.set_meta(bot.RANGE_META, bot._range_of(action.scene))
				bot.towers.append(unit)
			else:
				bot.traps += 1
			_count(action.scene)
		Kind.Wall:
			await bot._place(kit, level, action.scene, action.cell)
			bot.walls += 1
			_count("wall")
		Kind.Upgrade:
			var unit : Building = action.unit
			var upgrades : BuildingTypeUpgrades = level.building_type_upgrades
			upgrades._on_unit_selected(unit)
			if action.index >= upgrades.options.size():
				return
			var gold_before : float = level.player_stats.gold
			upgrades._on_gold_upgrade_pressed(action.index)
			if level.player_stats.gold < gold_before:
				bot.gold_spent += gold_before - level.player_stats.gold
				bot.purchases[unit] = bot.purchases.get(unit, 0) + 1
				_count("upgrade")


func _count(what : String) -> void:
	bought[what] = bought.get(what, 0) + 1


## The offer with the biggest gain: stat cards by what-if on every unit they fit, gold at the best
## action's value per gold, the rest at a small share.
func pick_card(level : Level, offered : Array[UpgradeCard]) -> int:
	var routes : Array[Vector2i] = bot._route_cells(level)
	var total : float = 0.0
	for unit in units:
		if is_instance_valid(unit):
			total += _unit_dps(unit) * _unit_cells(unit, routes)
	var best_ratio : float = plan.get("best_ratio", 1.0)
	var best : int = 0
	var best_gain : float = -INF
	for index in offered.size():
		var card : UpgradeCard = offered[index]
		var resource : EvolveResource = card.resource
		var gain : float = 0.0
		match resource.card_target:
			EvolveResource.CardTarget.Gold:
				gain = card.value * best_ratio
			EvolveResource.CardTarget.Xp:
				gain = total * 0.03
			EvolveResource.CardTarget.MazeDamage, EvolveResource.CardTarget.MazeSlow:
				gain = total * card.value * 0.5 if bot.walls > 0 else 0.0
			_:
				var modifiers : Array[ModifierData] = [card.get_modifier_data()]
				if resource.has_drawback:
					modifiers.append(resource.get_drawback_modifier_data())
				for unit in units:
					if is_instance_valid(unit) and level.upgrades._fits(resource, unit, level.upgrades.upgrade_level):
						var cells : float = _unit_cells(unit, routes)
						var dps : float = _unit_dps(unit)
						var after_power : float = _power(unit, modifiers) / maxf(_power(unit), 0.001)
						var after_cells : float = cells
						if modifiers.any(func(m : ModifierData) -> bool: return m.stat_type == Utils.StatType.AttackRange):
							after_cells = _covered(routes, unit.grid_position, _stat(unit, Utils.StatType.AttackRange, modifiers)) * (TRAP_CELLS if unit is Trap else 1.0)
						gain += dps * (after_power * after_cells - cells)
				if card.is_past_soft_cap:
					gain *= 0.5
		if gain > best_gain:
			best_gain = gain
			best = index
	return best


## The trap cells worth a look: the route cell the most towers reach first, then the free route cells beside the
## placed traps that enough towers reach (Trap line and the trap pairs, SYNERGY.trap_gain).
func _trap_cells(level : Level) -> Array[Vector2i]:
	var cells : Array[Vector2i] = []
	var best : Vector2i = bot._best_trap_cell(level)
	if best == Vector2i.MAX:
		return cells
	cells.append(best)
	var least : float = bot._trap_cell_score(best) * TRAP_SIDE_REACH
	var on_route : Dictionary[Vector2i, bool] = {}
	for route_cell in bot._route_cells(level):
		on_route[route_cell] = true
	for unit in units:
		if not is_instance_valid(unit) or not unit is Trap:
			continue
		for x in range(-1, 2):
			for y in range(-1, 2):
				var cell : Vector2i = unit.grid_position + Vector2i(x, y)
				if on_route.has(cell) and not cells.has(cell) and bot._is_free_to_build(level, cell) and bot._trap_cell_score(cell) >= least:
					cells.append(cell)
	return cells


# --- a player's other choices ---

## The Target setting and the Hatchery rally, as a player sets them for the coming wave: against a boss the
## Bolter and Beamer go for the Strongest (the boss), otherwise First; the Spotter (Elite) and the Harpooner
## (Flyers) keep their own defaults. A Hatchery rallies its guards on the cell in reach the most towers work on.
func _set_tactics(level : Level) -> void:
	var threat : Dictionary = _threat(level)
	var routes : Array[Vector2i] = []
	for unit in units:
		if not is_instance_valid(unit) or not unit.is_placed:
			continue
		if unit is Tower and unit.can_choose_target and _key_of(unit) in ["PuffeBolter", "PuffeBeamer"]:
			unit.target_tactic = Utils.TargetTactic.Strongest if threat.get("boss", false) else Utils.TargetTactic.First
		elif unit is Tower and _key_of(unit) == "PuffeHarpooner":
			#flyers when the wave has them (it drags them down), else it slows the ground
			unit.target_tactic = Utils.TargetTactic.Flyers if threat.flyers > 0.0 else Utils.TargetTactic.Ground
		elif unit is Hatchery and is_dirty:
			if routes.is_empty():
				routes = bot._route_cells(level)
			_set_rally(unit, routes)


func _set_rally(hatchery : Hatchery, routes : Array[Vector2i]) -> void:
	#how many towers work on each route cell
	var workers : Dictionary[Vector2i, int] = {}
	for unit in units:
		if not is_instance_valid(unit) or unit == hatchery or unit is Buffer or unit is HoardKeeper:
			continue
		#a literal {} is an untyped Dictionary: fill a typed one instead
		var reached : Dictionary[Vector2i, bool] = {}
		if unit is Trap:
			reached[unit.grid_position] = true
		else:
			reached = _cells_in_reach(routes, unit.grid_position, _stat(unit, Utils.StatType.AttackRange))
		for route_cell in reached:
			workers[route_cell] = workers.get(route_cell, 0) + 1
	#Hold the line: a held enemy stands on the trap, so a trap's cell counts as RALLY_TRAP_WORKERS more towers
	for unit in units:
		if is_instance_valid(unit) and unit is Trap and workers.has(unit.grid_position):
			workers[unit.grid_position] += RALLY_TRAP_WORKERS
	var best : Vector2i = Utils.BAD_CELL
	var best_count : int = 0
	for route_cell in workers:
		if workers[route_cell] > best_count and hatchery.is_valid_rally_cell(route_cell):
			best = route_cell
			best_count = workers[route_cell]
	if best != Utils.BAD_CELL and best != hatchery.rally_cell:
		hatchery.set_manual_rally(best)


# --- the towers that do more than damage ---

## Gold a pay of this much a cleared wave brings over the waves still to clear (the last clear ends the level).
func _hoard_gold(level : Level, pay_per_wave : float) -> float:
	var runner : WaveRunner = level.wave_runner
	var waves_left : int = SURVIVAL_WAVES_AHEAD if runner.is_endless else maxi(runner.waves.size() - runner.wave_number - 1, 0)
	return pay_per_wave * waves_left


func _damage_tower_count() -> int:
	return units.filter(func(unit) -> bool: return is_instance_valid(unit) and not unit is Trap and not unit is HoardKeeper and not unit is Buffer).size()


func _hoard_count() -> int:
	return units.filter(func(unit) -> bool: return is_instance_valid(unit) and unit is HoardKeeper).size()


## The towers and traps a Buffer on this cell would cover (Buffer.covers: its aura reach, its Radius pips in, plus
## extra_tiles).
func _buffer_covered(cell : Vector2i, buffer : Building = null, extra_tiles : float = 0.0) -> Array[Building]:
	var covered : Array[Building] = []
	var reach : float = (buffer.radius / Utils.TILE_SIZE if buffer is Buffer else bot._range_of(bot.BUFFER)) + 0.25 + extra_tiles
	for unit in units:
		if not is_instance_valid(unit) or unit == buffer or unit is Buffer or unit is HoardKeeper:
			continue
		if Vector2(unit.grid_position - cell).length() <= reach:
			covered.append(unit)
	return covered


func _buffer_covered_value(_level : Level, cell : Vector2i, routes : Array[Vector2i], buffer : Building = null) -> float:
	var value : float = 0.0
	var covered : Array[Building] = _buffer_covered(cell, buffer)
	for unit in covered:
		value += _unit_dps(unit) * _unit_cells(unit, routes)
	return value * NICHES.buffer_uptime(covered.size())


## What these pips (stat -> how many) add to every tower the Buffer covers, by the same what-if as the cards.
#
#its throws go round the covered buildings (BufferAuras.throw_from): past BUFFER_HELD of them each is buffed only part
#of the time. A Radius pip is worth the Buffer's present pips on the buildings it brings in, less the thinner spread.
func _buffer_gain(_level : Level, cell : Vector2i, routes : Array[Vector2i], pips : Dictionary, buffer : Building = null) -> float:
	if pips.has(Utils.StatType.AuraRadius):
		if not buffer is Buffer:
			return 0.0
		var present : Dictionary = {}
		for stat in buffer.pips:
			if stat != Utils.StatType.AuraRadius and buffer.pips[stat] > 0:
				present[stat] = buffer.pips[stat]
		if present.is_empty():
			return 0.0
		var extra_tiles : float = float(Buffer.PIP_VALUES[Utils.StatType.AuraRadius][1]) * pips[Utils.StatType.AuraRadius]
		return _buffer_pips_value(_buffer_covered(cell, buffer, extra_tiles), routes, present) - _buffer_pips_value(_buffer_covered(cell, buffer), routes, present)
	return _buffer_pips_value(_buffer_covered(cell, buffer), routes, pips)


## What these pips add on these buildings, times the share of the time each is buffed.
func _buffer_pips_value(covered : Array[Building], routes : Array[Vector2i], pips : Dictionary) -> float:
	var modifiers : Array[ModifierData] = []
	for stat in pips:
		var modifier : ModifierData = ModifierData.new()
		modifier.stat_type = stat
		modifier.calculate_type = Buffer.PIP_VALUES[stat][0]
		modifier.value = float(Buffer.PIP_VALUES[stat][1]) * pips[stat]
		modifiers.append(modifier)
	var gain : float = 0.0
	for unit in covered:
		var cells : float = _unit_cells(unit, routes)
		var after_cells : float = cells
		if pips.has(Utils.StatType.AttackRange) and not unit is Trap:
			after_cells = _covered(routes, unit.grid_position, _stat(unit, Utils.StatType.AttackRange, modifiers))
		gain += _unit_dps(unit) * (_power(unit, modifiers) / maxf(_power(unit), 0.001) * after_cells - cells)
	return gain * NICHES.buffer_uptime(covered.size())


## A Shredder's torn armour: every tower working the same route cells hits harder through the resistances of the
## coming wave (up to SHRED_MOST off each), in its own element.
func _shred_gain(cell : Vector2i, range_tiles : float, routes : Array[Vector2i], threat : Dictionary, level : Level = null) -> float:
	var shred_cells : Dictionary[Vector2i, bool] = _cells_in_reach(routes, cell, range_tiles)
	var gain : float = 0.0
	for unit in units:
		if not is_instance_valid(unit) or unit is Shredder or unit is Buffer or unit is HoardKeeper:
			continue
		var through : float = clampf(threat.through.get(_element_name(unit), 1.0), 0.25, 1.0)
		var shred : float = minf(1.0 - through, SHRED_MOST)
		gain += _unit_dps(unit) * _overlap(unit, shred_cells, routes) * shred / through
	#its stacks double on pinned enemies, its shred lasts on elites and bosses (TowerHitEffects, TowerNiches)
	if level != null and not shred_cells.is_empty():
		var maze : Dictionary[Vector2i, bool] = bot._maze_cells(level)
		var pinned : int = 0
		for shred_cell in shred_cells:
			if NICHES.is_slowed(level.grid, shred_cell, maze):
				pinned += 1
		gain *= 1.0 + SHRED_PINNED_VALUE * pinned / shred_cells.size()
	return gain * (1.0 + SHRED_TOUGH_VALUE * threat.get("elites", 0.0))


## A Hatchery's guards hold ground enemies at the start of its reach: the towers working those cells get them
## longer.
func _hold_gain(cell : Vector2i, range_tiles : float, routes : Array[Vector2i], threat : Dictionary) -> float:
	var hold_cells : Dictionary[Vector2i, bool] = _cells_in_reach(routes, cell, range_tiles)
	var gain : float = 0.0
	for unit in units:
		if is_instance_valid(unit) and not unit is Buffer and not unit is HoardKeeper:
			gain += _unit_dps(unit) * _overlap(unit, hold_cells, routes)
	return gain * HOLD_VALUE * (1.0 - threat.flyers)


## A Harpooner's chains (HarpoonTether) at an evolve tier (harpoons = NICHES.harpoon_hits): every tower working its
## cells gets the slowed enemies longer (half speed: twice the time), a boss slowed or held, and the ground-only towers
## get the flyers it drags down. Its own damage and bleeds are in its measured dps.
func _tether_gain(cell : Vector2i, range_tiles : float, routes : Array[Vector2i], threat : Dictionary, tier : int, harpooner : Building = null) -> float:
	var cells : Dictionary[Vector2i, bool] = _cells_in_reach(routes, cell, range_tiles)
	if cells.is_empty():
		return 0.0
	var slow : float = 0.5
	if harpooner != null:
		slow = clampf(_stat(harpooner, Utils.StatType.TetherSlow), 0.0, 0.9)
	var hits : float = NICHES.harpoon_hits(tier, harpoon_multiplier)
	var chained : float = minf(TETHER_SHARE * hits, 1.0)
	#on the ground; a boss is chained more of the time (it is what the tower aims at while it lives)
	var ground : float = (1.0 - threat.flyers) * (chained + (TETHER_BOSS_SHARE if threat.get("boss", false) else 0.0))
	var gain : float = 0.0
	for unit in units:
		if not is_instance_valid(unit) or unit == harpooner or unit is Buffer or unit is HoardKeeper:
			continue
		var overlap : float = _overlap(unit, cells, routes)
		if overlap <= 0.0:
			continue
		var dps : float = _unit_dps(unit)
		gain += dps * overlap * ground * slow / (1.0 - slow)
		#a ground-only tower: the grounded flyers walk into it
		if TRAITS.get(_key_of(unit), {}).has("air"):
			gain += dps * overlap * threat.flyers * minf(hits * GROUNDED_SHARE, 1.0)
	return gain


## A tower within a placed Harpooner's reach of its own cells (they share route cells).
func _is_by_harpooner(unit : Building) -> bool:
	for other in units:
		if is_instance_valid(other) and other != unit and _key_of(other) == "PuffeHarpooner":
			var reach : float = _stat(other, Utils.StatType.AttackRange) + _stat(unit, Utils.StatType.AttackRange)
			if Vector2(other.grid_position - unit.grid_position).length() <= reach:
				return true
	return false


func _cells_in_reach(routes : Array[Vector2i], cell : Vector2i, range_tiles : float) -> Dictionary[Vector2i, bool]:
	var found : Dictionary[Vector2i, bool] = {}
	var reach : float = range_tiles * range_tiles
	for route_cell in routes:
		if Vector2(route_cell - cell).length_squared() <= reach:
			found[route_cell] = true
	return found


## How many of these cells the unit works on (a trap only its own).
func _overlap(unit : Building, cells : Dictionary[Vector2i, bool], routes : Array[Vector2i]) -> float:
	if unit is Trap:
		return 1.0 if cells.has(unit.grid_position) else 0.0
	var count : int = 0
	for route_cell in _cells_in_reach(routes, unit.grid_position, _stat(unit, Utils.StatType.AttackRange)):
		if cells.has(route_cell):
			count += 1
	return float(count)


func _element_name(unit : Building) -> String:
	if unit.evolve_tree == null or not unit.evolve_tree.is_element_chosen:
		return "Physical"
	for element_name in ELEMENTS:
		if ELEMENTS[element_name] == unit.evolve_tree.evolve_element:
			return element_name
	return "Physical"


## The walls: the shared line's Up 1-2 (they open the elements), then an element for the plain wall it does the
## most on: Frost (and Fortress) slow the enemies beside it for the towers working there, Fire and Poison hurt them.
func _wall_upgrade_action(level : Level, routes : Array[Vector2i]) -> Dictionary:
	var upgrades : BuildingTypeUpgrades = level.building_type_upgrades
	var route_set : Dictionary[Vector2i, bool] = {}
	for route_cell in routes:
		route_set[route_cell] = true
	var best : Dictionary = {}
	var line_option : Dictionary = {}
	for building in level.all_buildings:
		if not is_instance_valid(building) or not building is Wall or not building.is_placed or building.is_dead:
			continue
		var wall : Wall = building
		upgrades._on_unit_selected(wall)
		var options : Array[GoldUpgradeOption] = upgrades.options
		for index in options.size():
			var option : GoldUpgradeOption = options[index]
			if option.is_locked:
				continue
			if option.wall_element != Utils.Element.None:
				var gain : float = _wall_element_gain(wall, option.wall_element, route_set, routes)
				if best.is_empty() or gain > best.gain:
					best = {"kind": Kind.Upgrade, "unit": wall, "index": index, "title": option.title, "cost": option.cost, "gain": gain}
			elif line_option.is_empty() and not option.is_evolve and upgrades.get_upgrade_steps(wall) < BuildingTypeUpgrades.WALL_ELEMENT_MIN_UPGRADES:
				line_option = {"kind": Kind.Upgrade, "unit": wall, "index": index, "title": option.title, "cost": option.cost}
		#the line's options are the same on every wall: one look is enough while no element is on offer yet
		if not line_option.is_empty() and best.is_empty():
			break
	if not best.is_empty():
		return best
	if line_option.is_empty():
		return {}
	#the line opens the elements: worth a share of the best element on the best wall
	var best_element : float = 0.0
	for building in level.all_buildings:
		if is_instance_valid(building) and building is Wall and building.is_placed and building.element == Utils.Element.None:
			best_element = maxf(best_element, _wall_element_gain(building, Utils.Element.Frost, route_set, routes))
	line_option.gain = best_element * WALL_LINE_SHARE
	return line_option


func _wall_element_gain(wall : Wall, element : Utils.Element, route_set : Dictionary[Vector2i, bool], routes : Array[Vector2i]) -> float:
	var beside : Dictionary[Vector2i, bool] = {}
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var cell : Vector2i = wall.grid_position + offset
		if route_set.has(cell):
			beside[cell] = true
	if beside.is_empty():
		return 0.0
	var element_name : String = ELEMENT_NAMES[ELEMENTS.values().find(element)] if ELEMENTS.values().has(element) else "Physical"
	#Cold feet and Firebreath corridor
	var synergy : float = SYNERGY.wall_element_gain(self, wall.level, routes, wall, element_name)
	if WALL_DPS.has(element_name):
		return WALL_DPS[element_name] * beside.size() + synergy
	var slow : float = WALL_SLOW.get(element_name, 0.0)
	var gain : float = 0.0
	for unit in units:
		if is_instance_valid(unit) and not unit is Buffer and not unit is HoardKeeper:
			gain += _unit_dps(unit) * _overlap(unit, beside, routes)
	return gain * slow / (1.0 - slow) + synergy


# --- value model ---

## The stats' damage per second with a target, corrected by what the unit really dealt.
func _unit_dps(unit : Building) -> float:
	return _stat_dps(unit) * _learned(unit)


func _stat_dps(unit : Building) -> float:
	var key : String = _key_of(unit)
	return _power(unit) * SHEET_BASE_DPS.get(key, 0.4) / maxf(_base_power(key, unit), 0.001)


#measured over expected, trusted more the longer the unit has had a target
func _learned(unit : Building) -> float:
	var promised : float = expected.get(unit, 0.0)
	if promised <= 0.0:
		return 1.0
	var ratio : float = clampf(damage.get(unit, 0.0) / promised, LEARN_MIN, LEARN_MAX)
	var trust : float = clampf(active_time.get(unit, 0.0) / LEARN_SECONDS, 0.0, 1.0)
	return lerpf(1.0, ratio, trust)


## A new unit of the type: its scene's power with the card and talent modifiers a placed unit of the
## same type carries (any type when none is placed), times what that type has been learned to do.
func _new_unit_dps(level : Level, scene_name : String, routes : Array[Vector2i] = []) -> float:
	var key : String = _key_of_scene(scene_name)
	var model : Building = null
	for unit in units:
		if is_instance_valid(unit) and (model == null or _key_of(unit) == key):
			model = unit
	if model == null:
		return SHEET_BASE_DPS.get(key, 0.4)
	var modifiers : Array[ModifierData] = []
	for source in [level.upgrades.applied_modifiers, level.talents.applied_modifiers if level.talents != null else {}]:
		for modifier in source.get(model, []):
			modifiers.append(modifier)
	var learned : float = _learned(model) if _key_of(model) == key else 1.0
	#what the model really dealt has its niche in: the new tower's niche is counted at its own cell
	if _key_of(model) == key and not routes.is_empty():
		learned /= _niche_share(level, model, routes)
	return SHEET_BASE_DPS.get(key, 0.4) * _bases_power(_scene_bases(scene_name), modifiers) / maxf(_base_power(key, null, scene_name), 0.001) * learned


## How well a new tower of the type fits the coming wave (TRAITS): the share it cannot reach (flyers, for the
## ground-only ones; a T1 Nova or Leopard Trap too), more hits on swarms, and the Harpooner's and the Spotter's
## favourite targets.
func _fit(key : String, threat : Dictionary) -> float:
	var traits : Dictionary = TRAITS.get(key, {})
	var fit : float = 1.0
	if traits.has("air"):
		fit *= 1.0 - maxf(threat.flyers, threat.get("later_flyers", 0.0) * LATER_FLYERS_SHARE)
	else:
		#a flyer wave still to come that the towers placed cannot meet: what reaches the air is worth more
		fit *= 1.0 + threat.get("air_gap", 0.0)
	fit *= (1.0 + float(traits.get("swarm", 0.0)) * threat.swarm) / (1.0 + float(traits.get("swarm", 0.0)) * TYPICAL_SWARM)
	fit *= 1.0 + float(traits.get("flyers", 0.0)) * threat.flyers
	fit *= 1.0 + float(traits.get("elites", 0.0)) * threat.get("elites", 0.0)
	fit *= 1.0 + float(traits.get("fast", 0.0)) * threat.get("fast", 0.0)
	return fit * float(traits.get("accuracy", 1.0))


func _element_factor(key : String, element_name : String, threat : Dictionary) -> float:
	var gain : float = ELEMENT_GAIN.get(key, {}).get(element_name, DEFAULT_ELEMENT_GAIN)
	gain *= threat.through.get(element_name, 1.0) / maxf(threat.through.get("Physical", 1.0), 0.05)
	if element_name == "Frost" and _tower_count() > 1:
		gain += FROST_SLOW_VALUE
	return gain


## The coming wave: its flyer and swarm share of the health, and the share of each element's hits that
## gets through the resistances, health-weighted.
func _threat(level : Level) -> Dictionary:
	var runner : WaveRunner = level.wave_runner
	var index : int = runner.current_wave_index if runner.is_spawning or not level.existing_enemies.is_empty() else runner.current_wave_index + 1
	index = clampi(index, 0, runner.waves.size() - 1)
	var health : float = 0.0
	var flyers : float = 0.0
	var later : Vector2 = _later_flyers(runner, index) if not runner.waves.is_empty() else Vector2.ZERO
	var swarm : float = 0.0
	var elites : float = 0.0
	var fast : float = 0.0
	var has_boss : bool = false
	var through : Dictionary[String, float] = {}
	if runner.waves.is_empty():
		return {"flyers": 0.0, "swarm": 0.0, "elites": 0.0, "boss": false, "through": through}
	for group in runner.waves[index].spawn_groups:
		if group.enemy_scene == null:
			continue
		var info : Dictionary = _enemy_info(group.enemy_scene)
		var group_health : float = info.health * group.count
		health += group_health
		if info.flying:
			flyers += group_health
		if group.count >= SWARM_COUNT:
			swarm += group_health
		#the Harpooner's prey on foot (TowerNiches.is_fast)
		if not info.flying and info.speed >= TowerNiches.FAST_SPEED:
			fast += group_health
		#bosses and elites: the Spotter's targets
		if info.boss:
			has_boss = true
			elites += group_health
		elif group.elites > 0:
			elites += info.health * mini(group.elites, group.count)
		for element_name in ELEMENT_NAMES:
			through[element_name] = through.get(element_name, 0.0) + group_health * (1.0 - info.resist.get(element_name, 0.0))
	if health <= 0.0:
		return {"flyers": 0.0, "swarm": 0.0, "elites": 0.0, "boss": false, "through": through}
	for element_name in through:
		through[element_name] /= health
	return {"flyers": flyers / health, "swarm": swarm / health, "elites": elites / health, "fast": fast / health, "boss": has_boss, "through": through,
		"later_flyers": later.x, "air_gap": maxf(maxf(later.y, flyers / health) - _anti_air_share(), 0.0)}


## The flyer share of the health of the waves after this one (x: over all of them, y: the most in one wave).
func _later_flyers(runner : WaveRunner, index : int) -> Vector2:
	var health : float = 0.0
	var flyers : float = 0.0
	var peak : float = 0.0
	for later in range(index + 1, runner.waves.size()):
		var wave_health : float = 0.0
		var wave_flyers : float = 0.0
		for group in runner.waves[later].spawn_groups:
			if group.enemy_scene == null:
				continue
			var info : Dictionary = _enemy_info(group.enemy_scene)
			wave_health += info.health * group.count
			if info.flying:
				wave_flyers += info.health * group.count
		health += wave_health
		flyers += wave_flyers
		if wave_health > 0.0:
			peak = maxf(peak, wave_flyers / wave_health)
	return Vector2(flyers / health if health > 0.0 else 0.0, peak)


## The share of the placed units' damage that reaches flyers (TRAITS air: never, or from T2).
func _anti_air_share() -> float:
	var total : float = 0.0
	var air : float = 0.0
	for unit in units:
		if not is_instance_valid(unit) or unit is Buffer or unit is HoardKeeper:
			continue
		var dps : float = _unit_dps(unit)
		total += dps
		var reach : Variant = TRAITS.get(_key_of(unit), {}).get("air", true)
		if reach is bool and reach or reach is String and unit.evolve_tree != null and unit.evolve_tree.tier >= 2:
			air += dps
		elif _is_by_harpooner(unit):
			#a Harpooner drags the flyers down into its reach (HarpoonTether)
			air += dps * GROUNDED_SHARE
	return air / total if total > 0.0 else 0.0


func _enemy_info(scene : PackedScene) -> Dictionary:
	if enemy_info.has(scene.resource_path):
		return enemy_info[scene.resource_path]
	var instance : Node = scene.instantiate()
	var health : float = 0.0
	var speed : float = 0.0
	for stat in instance.find_children("*", "Stat", true, false):
		if stat.type == Utils.StatType.MaxHealth:
			health = maxf(health, stat.base_value)
		elif stat.type == Utils.StatType.Speed:
			speed = maxf(speed, stat.base_value)
	var resist : Dictionary[String, float] = {}
	var resistances : EnemyResistances = instance.get("resistances")
	if resistances != null:
		for element_name in ELEMENT_NAMES:
			resist[element_name] = resistances.get_element(DAMAGE_TYPES[element_name])
	var info : Dictionary = {"health": maxf(health, 1.0), "speed": speed, "flying": not instance.find_children("*", "FlightMovement", true, false).is_empty(), "resist": resist,
		"boss": instance is Enemy and instance.is_boss}
	instance.free()
	enemy_info[scene.resource_path] = info
	return info


# --- stats ---

## Relative damage output from the stats: damage, attack speed, crits, extra hits and effect potency.
## Used as a ratio (before and after a step), so the weights only need to be about right.
func _power(unit : Building, extra : Array[ModifierData] = []) -> float:
	var get_value : Callable = func(type : Utils.StatType) -> float: return _stat(unit, type, extra)
	return _power_of(get_value)


func _bases_power(bases : Dictionary, extra : Array[ModifierData]) -> float:
	var none : Array[ModifierData] = []
	var get_value : Callable = func(type : Utils.StatType) -> float:
		return _combine(bases.get(type, 0.0), none, none, none, extra, type, bases.has(type))
	return _power_of(get_value)


func _power_of(get_value : Callable) -> float:
	var hit : float = get_value.call(Utils.StatType.Damage)
	var speed : float = 1.0 + get_value.call(Utils.StatType.AttackSpeed)
	var crit : float = 1.0 + clampf(get_value.call(Utils.StatType.CriticalChance), 0.0, 1.0) * maxf(get_value.call(Utils.StatType.CriticalMultiplier) - 1.0, 0.0)
	var extra_hits : float = 1.0 + 0.6 * get_value.call(Utils.StatType.Ricochet) + 0.8 * get_value.call(Utils.StatType.ExtraShots) \
		+ 0.6 * get_value.call(Utils.StatType.ChainTargets) + 0.5 * get_value.call(Utils.StatType.Pierce) + 0.5 * get_value.call(Utils.StatType.SplashRadius)
	var effects : float = 1.0 + 0.3 * get_value.call(Utils.StatType.EffectPotency)
	return maxf(hit, 0.0) * maxf(speed, 0.1) * crit * extra_hits * effects


## The stat as ModifierManager.calculate_modifier would make it with the extra modifiers added.
func _stat(unit : Building, type : Utils.StatType, extra : Array[ModifierData] = []) -> float:
	var main_stat : Stat = unit.stats.get_stat(type)
	var skill_stat : Stat = unit.skill.stats.get_stat(type) if unit.skill != null and unit.skill.stats != null else null
	if main_stat == null and skill_stat == null:
		return 0.0
	var base : float = 0.0
	var flat : Array[ModifierData] = []
	var additive : Array[ModifierData] = []
	var multiply : Array[ModifierData] = []
	for stat in [main_stat, skill_stat]:
		if stat == null:
			continue
		base += stat.base_value
		flat.append_array(stat.flat_modifiers)
		flat.append_array(stat.global_flat_modifiers)
		additive.append_array(stat.additive_modifiers)
		additive.append_array(stat.global_additive_modifiers)
		multiply.append_array(stat.multiply_modifiers)
		multiply.append_array(stat.global_multiply_modifiers)
	return _combine(base, flat, additive, multiply, extra, type, true)


func _combine(base : float, flat : Array[ModifierData], additive : Array[ModifierData], multiply : Array[ModifierData], extra : Array[ModifierData], type : Utils.StatType, has_stat : bool) -> float:
	if not has_stat:
		return 0.0
	var flats : Array[ModifierData] = flat.duplicate()
	var adds : Array[ModifierData] = additive.duplicate()
	var mults : Array[ModifierData] = multiply.duplicate()
	for modifier in extra:
		if modifier.stat_type != type:
			continue
		match modifier.calculate_type:
			Utils.ModifyType.Flat:
				flats.append(modifier)
			Utils.ModifyType.Additive:
				adds.append(modifier)
			_:
				mults.append(modifier)
	return ModifierManager.combine(base, flats, adds, mults)


func _upgrade_modifiers(unit : Building) -> Array[ModifierData]:
	var modifiers : Array[ModifierData] = []
	var data : BuildingUpgradeData = unit.evolve_tree.upgrade_data
	for resource in data.upgrade_resources:
		modifiers.append(resource.get_modifier_data())
	if unit.evolve_tree.is_element_chosen:
		for resource in data.evolved_upgrade_resources:
			modifiers.append(resource.get_modifier_data())
	return modifiers


#the base stats of a type with nothing on them, from its scene (unit and skill stats summed per type)
func _base_power(key : String, unit : Building = null, scene_name : String = "") -> float:
	if base_power.has(key):
		return base_power[key]
	if scene_name.is_empty():
		scene_name = unit.scene_file_path.get_file().get_basename()
	base_power[key] = _bases_power(_scene_bases(scene_name), [])
	return base_power[key]


func _scene_bases(scene_name : String) -> Dictionary:
	var instance : Node = load(TestKit.BUILDING_PATH % scene_name).instantiate()
	var bases : Dictionary = {}
	for stat in instance.find_children("*", "Stat", true, false):
		#only the unit's and its skill's stats, not a projectile's
		var owner_stats : Node = stat.get_parent()
		if owner_stats.get_parent() == instance or owner_stats.get_parent() is Skill:
			bases[stat.type] = bases.get(stat.type, 0.0) + stat.base_value
	instance.free()
	return bases


# --- niches (TowerNiches) ---

## The route cells' niche factors for a new tower of this kind with this element (NICHES.route_factors).
func _niches_for(level : Level, key : String, element : String, routes : Array[Vector2i]) -> Dictionary[Vector2i, float]:
	return NICHES.route_factors(level.grid, key, routes, bot._maze_cells(level), element)


## A placed unit's niche: its covered route cells' average factor (1 for a kind without cell niches).
func _niche_share(level : Level, unit : Building, routes : Array[Vector2i]) -> float:
	var key : String = _key_of(unit)
	if not NICHES.has_cell_niche(key):
		return 1.0
	var maze : Dictionary[Vector2i, bool] = bot._maze_cells(level)
	var element : String = _chosen_element(unit)
	if unit is Trap:
		return NICHES.cell_factor(level.grid, key, unit.grid_position, maze, {}, element)
	var cells : Dictionary[Vector2i, bool] = _cells_in_reach(routes, unit.grid_position, _stat(unit, Utils.StatType.AttackRange))
	if cells.is_empty():
		return 1.0
	var total : float = 0.0
	for cell in cells:
		total += NICHES.cell_factor(level.grid, key, cell, maze, {}, element)
	return total / cells.size()


## A route cell's niche factor while a wall on wall_cell is weighed: cells near it are looked at with it, the rest
## once per wall search (cache).
func _niche_at(level : Level, key : String, element : String, cell : Vector2i, maze : Dictionary[Vector2i, bool], wall_cell : Vector2i, cache : Dictionary) -> float:
	if wall_cell != Vector2i.MAX and maxi(absi(cell.x - wall_cell.x), absi(cell.y - wall_cell.y)) <= 2:
		return NICHES.cell_factor(level.grid, key, cell, maze, {wall_cell: true}, element)
	var cache_key : String = key + element
	var cells : Dictionary = cache.get_or_add(cache_key, {})
	if not cells.has(cell):
		cells[cell] = NICHES.cell_factor(level.grid, key, cell, maze, {}, element)
	return cells[cell]


## How much an evolve (the element: tier 1, then 2 and 3) does through the niches: the Harpooner's harpoon more, and
## a Frost Nova's or Mortar's own chill making every target its niche.
func _evolve_niche_factor(level : Level, unit : Building, element_name : String, to_tier : int, routes : Array[Vector2i]) -> float:
	var key : String = _key_of(unit)
	if key == "PuffeHarpooner":
		return NICHES.harpoon_hits(to_tier, harpoon_multiplier) / NICHES.harpoon_hits(to_tier - 1, harpoon_multiplier)
	return 1.0


## The unit's element by name once it has one, else "" (the niches read Frost only from a chosen element).
func _chosen_element(unit : Building) -> String:
	if unit.evolve_tree == null or not unit.evolve_tree.is_element_chosen:
		return ""
	return _element_name(unit)


## Each tower kind's measured damage over what its stats promised, over all its units (calibrates SHEET_BASE_DPS
## against walking enemies; printed by soak_level as SOAK smart learned).
func learned_report() -> Dictionary[String, float]:
	var dealt : Dictionary[String, float] = {}
	var promised : Dictionary[String, float] = {}
	#units, not damage's keys: a typed Dictionary errors on stepping onto a sold (freed) key
	for unit in units:
		if not is_instance_valid(unit) or not damage.has(unit):
			continue
		var key : String = _key_of(unit)
		dealt[key] = dealt.get(key, 0.0) + damage[unit]
		promised[key] = promised.get(key, 0.0) + expected.get(unit, 0.0)
	var report : Dictionary[String, float] = {}
	for key in dealt:
		if promised[key] > 0.0:
			report[key] = snappedf(dealt[key] / promised[key], 0.01)
	return report


# --- cells ---

## The route cells in reach, as worth: a single-target tower shoots one enemy at a time, so past REACH_CELLS more
## reach adds less and less (a 6-tile Spotter no longer looks three times a 3.5-tile Bolter, 2026-11-25).
#niches: route cell -> factor (NICHES.route_factors); the worth of the count is scaled by their average
func _covered(routes : Array[Vector2i], cell : Vector2i, range_tiles : float, niches : Dictionary[Vector2i, float] = {}) -> float:
	var reach : float = range_tiles * range_tiles
	var covered : int = 0
	var weighted : float = 0.0
	for route_cell in routes:
		if Vector2(route_cell - cell).length_squared() <= reach:
			covered += 1
			weighted += niches.get(route_cell, 1.0)
	if covered == 0:
		return 0.0
	return REACH_CELLS * (1.0 - exp(-covered / REACH_CELLS)) * weighted / covered


func _unit_cells(unit : Building, routes : Array[Vector2i]) -> float:
	if unit is Trap:
		return TRAP_CELLS
	return maxf(_covered(routes, unit.grid_position, _stat(unit, Utils.StatType.AttackRange)), 1.0)


func _is_active(level : Level, unit : Building) -> bool:
	if unit is Tower:
		return unit.has_target
	return not level.existing_enemies.is_empty()


func _tower_count() -> int:
	return units.filter(func(unit) -> bool: return is_instance_valid(unit) and not unit is Trap).size()


func _key_of(unit : Node) -> String:
	return String(unit.name).rstrip(bot.DIGITS)


func _key_of_scene(scene_name : String) -> String:
	return SCENE_KEYS.get(scene_name, scene_name.to_pascal_case())


func _leaf_element(leaf_path : NodePath) -> String:
	var leaf_name : String = str(leaf_path).get_file()
	for element_name in ELEMENT_NAMES:
		if leaf_name.begins_with(element_name):
			return element_name
	return "Physical"
