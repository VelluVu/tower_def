extends RefCounted

## The soak bot's smart player (`play=smart`): every action it can take (a new tower of each type at its
## best cell, each building's next upgrade or element, a wall, a trap) is valued as the damage per second
## it adds on the routes, times the route cells it covers, per gold; it buys the best one, or saves for it
## when it is worth clearly more than what it can afford now. Gains come from the game's own modifier maths
## run on the extra modifiers (nothing is applied to try), and each building's estimate is corrected by the
## damage it really deals, so area hits, chains, resistances and overkill are learned during the run.
## It also reads the coming wave (flyers, swarms, resistances), picks the card with the biggest gain and
## starts waves early only while the last one never got halfway.

## Measured single-target dps at Base against a weakling (tower_sheet.gd, 2026-11-20).
const SHEET_BASE_DPS : Dictionary[String, float] = {"PuffeBolter": 4.0, "PuffeNova": 2.7, "PuffeBeamer": 3.3, "LeopardTrap": 3.0}
## Each element's T1 dps over Up 2 (tower_sheet.gd); Frost's slow is not in it (FROST_SLOW_VALUE).
const ELEMENT_GAIN : Dictionary[String, Dictionary] = {
	"PuffeBolter": {"Physical": 1.07, "Fire": 1.34, "Frost": 0.99, "Poison": 1.33},
	"PuffeNova": {"Physical": 1.47, "Fire": 1.28, "Frost": 1.09, "Poison": 1.53},
	"PuffeBeamer": {"Physical": 1.32, "Fire": 1.43, "Frost": 1.11, "Poison": 1.57},
	"LeopardTrap": {"Physical": 1.3, "Fire": 1.3, "Frost": 1.1, "Poison": 1.3},
}
const DEFAULT_ELEMENT_GAIN : float = 1.25
#the slow keeps every other tower on the enemies longer
const FROST_SLOW_VALUE : float = 0.2
#T2 and T3 (placeholder steps: +25% damage; +40% damage and +0.15 attack speed, plus a mechanic)
const TIER_GAINS : Array[float] = [1.3, 1.45]
const ELEMENT_NAMES : Array[String] = ["Physical", "Fire", "Frost", "Poison"]
const ELEMENTS : Dictionary[String, Utils.Element] = {"Physical": Utils.Element.Physical, "Fire": Utils.Element.Fire, "Frost": Utils.Element.Frost, "Poison": Utils.Element.Poison}
const DAMAGE_TYPES : Dictionary[String, Utils.DamageType] = {"Physical": Utils.DamageType.Physical, "Fire": Utils.DamageType.Fire, "Frost": Utils.DamageType.Frost, "Poison": Utils.DamageType.Poison}
#a group this big is a swarm (Nova pulses hit many of it)
const SWARM_COUNT : int = 8
const NOVA_SWARM_HITS : float = 1.5
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


func _init(soak : RefCounted) -> void:
	bot = soak
	GameSignals.astar_grid_updated.connect(func() -> void: is_dirty = true)
	GameSignals.enemy_reached_end_point.connect(func(_enemy : Enemy) -> void: wave_leaks += 1)


## Every frame: game seconds pass, the measured damage is weighed against what the stats promise.
func tick(level : Level, seconds : float) -> void:
	plan_age += seconds
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
			var cell : Vector2i = bot._best_tower_cell(level, range_tiles)
			if cell == Vector2i.MAX:
				continue
			var covered : float = _covered(routes, cell, range_tiles)
			var gain : float = _new_unit_dps(level, scene_name) * _fit(_key_of_scene(scene_name), threat) * covered
			actions.append({"kind": Kind.Tower, "scene": scene_name, "cell": cell, "cost": bot._placement_price(level, scene_name), "gain": gain})

	if bot.traps < int(bot.options.traps) and bot._is_unlocked(bot.TRAP):
		var trap_cell : Vector2i = bot._best_trap_cell(level)
		if trap_cell != Vector2i.MAX:
			var gain : float = _new_unit_dps(level, bot.TRAP) * _fit("LeopardTrap", threat) * TRAP_CELLS
			actions.append({"kind": Kind.Trap, "scene": bot.TRAP, "cell": trap_cell, "cost": bot._placement_price(level, bot.TRAP), "gain": gain})

	for unit in units:
		if is_instance_valid(unit):
			var upgrade : Dictionary = _upgrade_action(level, unit, routes, threat)
			if not upgrade.is_empty():
				actions.append(upgrade)

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
		var factor : float = 1.0
		if not option.is_evolve:
			factor = _power(unit, _upgrade_modifiers(unit)) / maxf(_power(unit), 0.001)
		elif not option.element_leaf_path.is_empty() and not unit.evolve_tree.is_element_chosen:
			var element_name : String = _leaf_element(option.element_leaf_path)
			if bot.build.has("leaf") and not str(option.element_leaf_path).ends_with(bot.build.leaf):
				continue
			factor = _element_factor(_key_of(unit), element_name, threat)
		else:
			factor = TIER_GAINS[clampi(option.tier, 0, TIER_GAINS.size() - 1)]
		var gain : float = value * (factor - 1.0)
		if best_index < 0 or gain > best_gain:
			best_index = index
			best_gain = gain
	if best_index < 0:
		return {}
	return {"kind": Kind.Upgrade, "unit": unit, "index": best_index, "title": options[best_index].title, "cost": options[best_index].cost, "gain": best_gain}


## The route cell that adds the most tower damage on the routes as a wall, without closing a route.
func _wall_action(level : Level) -> Dictionary:
	var before : float = _maze_value(bot._open_routes(level))
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
		var value : float = _maze_value(routes)
		if value > best_value:
			best_value = value
			best_cell = cell
	if best_cell == Vector2i.MAX:
		return {}
	return {"kind": Kind.Wall, "scene": bot.WALL, "cell": best_cell, "cost": bot._placement_price(level, bot.WALL), "gain": best_value - before}


#every unit's damage per second times the route cells it reaches, plus a little for the length
func _maze_value(routes : Array[Array]) -> float:
	var value : float = 0.0
	var total_dps : float = 0.0
	var length : int = 0
	for unit in units:
		if is_instance_valid(unit) and not unit is Trap:
			var dps : float = _unit_dps(unit)
			var reach : float = _stat(unit, Utils.StatType.AttackRange) ** 2
			total_dps += dps
			for route in routes:
				for cell in route:
					if Vector2(unit.grid_position - cell).length_squared() <= reach:
						value += dps
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


# --- value model ---

## The stats' damage per second with a target, corrected by what the unit really dealt.
func _unit_dps(unit : Building) -> float:
	return _stat_dps(unit) * _learned(unit)


func _stat_dps(unit : Building) -> float:
	var key : String = _key_of(unit)
	return _power(unit) * SHEET_BASE_DPS.get(key, 3.0) / maxf(_base_power(key, unit), 0.001)


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
func _new_unit_dps(level : Level, scene_name : String) -> float:
	var key : String = _key_of_scene(scene_name)
	var model : Building = null
	for unit in units:
		if is_instance_valid(unit) and (model == null or _key_of(unit) == key):
			model = unit
	if model == null:
		return SHEET_BASE_DPS.get(key, 3.0)
	var modifiers : Array[ModifierData] = []
	for source in [level.upgrades.applied_modifiers, level.talents.applied_modifiers if level.talents != null else {}]:
		for modifier in source.get(model, []):
			modifiers.append(modifier)
	var learned : float = _learned(model) if _key_of(model) == key else 1.0
	return SHEET_BASE_DPS.get(key, 3.0) * _bases_power(_scene_bases(scene_name), modifiers) / maxf(_base_power(key, null, scene_name), 0.001) * learned


## How well a tower type fits the coming wave: Nova and traps never hit flyers, Nova pulses hit swarms.
func _fit(key : String, threat : Dictionary) -> float:
	var fit : float = 1.0
	if key == "PuffeNova" or key == "LeopardTrap":
		fit *= 1.0 - threat.flyers
	if key == "PuffeNova":
		fit *= 1.0 + NOVA_SWARM_HITS * threat.swarm
	return fit


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
	var swarm : float = 0.0
	var through : Dictionary[String, float] = {}
	if runner.waves.is_empty():
		return {"flyers": 0.0, "swarm": 0.0, "through": through}
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
		for element_name in ELEMENT_NAMES:
			through[element_name] = through.get(element_name, 0.0) + group_health * (1.0 - info.resist.get(element_name, 0.0))
	if health <= 0.0:
		return {"flyers": 0.0, "swarm": 0.0, "through": through}
	for element_name in through:
		through[element_name] /= health
	return {"flyers": flyers / health, "swarm": swarm / health, "through": through}


func _enemy_info(scene : PackedScene) -> Dictionary:
	if enemy_info.has(scene.resource_path):
		return enemy_info[scene.resource_path]
	var instance : Node = scene.instantiate()
	var health : float = 0.0
	for stat in instance.find_children("*", "Stat", true, false):
		if stat.type == Utils.StatType.MaxHealth:
			health = maxf(health, stat.base_value)
	var resist : Dictionary[String, float] = {}
	var resistances : EnemyResistances = instance.get("resistances")
	if resistances != null:
		for element_name in ELEMENT_NAMES:
			resist[element_name] = resistances.get_element(DAMAGE_TYPES[element_name])
	var info : Dictionary = {"health": maxf(health, 1.0), "flying": not instance.find_children("*", "FlightMovement", true, false).is_empty(), "resist": resist}
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


# --- cells ---

func _covered(routes : Array[Vector2i], cell : Vector2i, range_tiles : float) -> float:
	var reach : float = range_tiles * range_tiles
	var covered : int = 0
	for route_cell in routes:
		if Vector2(route_cell - cell).length_squared() <= reach:
			covered += 1
	return float(covered)


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
	return scene_name.to_pascal_case()


func _leaf_element(leaf_path : NodePath) -> String:
	var leaf_name : String = str(leaf_path).get_file()
	for element_name in ELEMENT_NAMES:
		if leaf_name.begins_with(element_name):
			return element_name
	return "Physical"
