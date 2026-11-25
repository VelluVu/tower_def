extends RefCounted

## The synergies' worth for the smart player (smart_play.gd; rules in Synergies and the design doc's Synergies
## section, 2026-11-25). Every function takes the smart player (`play`) and returns damage per second times route
## cells, the same unit as its actions' gain, so a synergy is weighed like any other gain. Static, so the player
## and this script never hold each other.
## The shares are rough guesses of how often a synergy fires, to be checked against the bot's synergy counts.

## Pinned: the spikes' share of hits that land on an enemy the Leopard snapped (the hit counts double).
const PINNED_SHARE : float = 0.5
## Shrapnel bed: an extra spike strike every egg blast, as a share of the spikes' work.
const SHRAPNEL_SHARE : float = 0.2
## Bait: the egg lit by snaps, sooner and on enemies that would not set it off.
const BAIT_SHARE : float = 0.2
## Pushed onto spikes: a trap set off again by knocked-back enemies.
const PUSH_SHARE : float = 0.25
## Grounded on a trap: a harpooned flyer caught by a trap (times the wave's flyer share).
const GROUNDED_SHARE : float = 0.5
## Hold the line: guards hold enemies on the trap, which keeps hitting them.
const HOLD_TRAP_SHARE : float = 0.5
## Cold feet: +0.3 attack speed on the spikes while chilled enemies stand on them, most of the time.
const COLD_FEET_SHARE : float = 0.2
## Spotted shells: the Mortar's misses (TRAITS accuracy 0.6) gone on the marked share of its targets.
const SPOTTED_SHARE : float = 0.4
## Chance a Spotter marks before its element is chosen (three elements of four mark).
const MARK_CHANCE : float = 0.75
## Pinned target: tethered enemies take a blast's full hit instead of the falloff.
const PINNED_TARGET_SHARE : float = 0.1
## War cry: a second breath in some waves.
const WAR_CRY_SHARE : float = 0.5
## Harmony: an element stack is worth about half a hit.
const HARMONY_SHARE : float = 0.5
## Firebreath corridor: a burn stack on every enemy of a gust.
const FIREBREATH_SHARE : float = 0.3
## Ground reactions: a burst (Fire and Poison patches), a steam blind (Fire and Frost), of both towers' work there.
const BURST_SHARE : float = 0.15
const STEAM_SHARE : float = 0.05
const TRAP_KINDS : Dictionary[String, StringName] = {"leopard_trap": Synergies.LEOPARD, "egg_bomb": Synergies.EGG, "spike_field": Synergies.SPIKES}


# --- a new trap ---

## A new trap of this scene on this cell: Trap line, Pinned, Shrapnel bed, Bait with the traps beside it, and the
## towers that set it off or hold enemies on it.
static func trap_gain(play : RefCounted, level : Level, trap_scene : String, cell : Vector2i, threat : Dictionary) -> float:
	var kind : StringName = TRAP_KINDS.get(trap_scene, Synergies.LEOPARD)
	var own : float = play._new_unit_dps(level, trap_scene) * play.TRAP_CELLS
	var gain : float = 0.0
	var kinds : Dictionary[StringName, bool] = {}
	for unit in _units(play):
		if not unit is Trap or not _is_beside(unit.grid_position, cell):
			continue
		var other_kind : StringName = Synergies.trap_kind(unit)
		if other_kind == kind:
			continue
		kinds[other_kind] = true
		var other : float = play._unit_dps(unit) * play.TRAP_CELLS
		#the trap beside gains a kind too, unless it has this kind beside it already or is full
		var its_kinds : Dictionary[StringName, bool] = _kinds_beside(play, unit)
		if not its_kinds.has(kind) and its_kinds.size() < Synergies.TRAP_LINE_MOST:
			gain += other * Synergies.TRAP_LINE_BONUS
		gain += _pair_worth(kind, own, other_kind, other)
	gain += own * Synergies.TRAP_LINE_BONUS * mini(kinds.size(), Synergies.TRAP_LINE_MOST)
	gain += own * _trap_helpers(play, level, cell, kind, threat)
	return gain


## The share more a trap on this cell does from the towers around it.
static func _trap_helpers(play : RefCounted, level : Level, cell : Vector2i, kind : StringName, threat : Dictionary) -> float:
	var share : float = 0.0
	var is_pushed : bool = false
	var is_grounded : bool = false
	var is_held : bool = false
	var is_chilled : bool = kind == Synergies.SPIKES and _has_frost_wall_beside(level, cell)
	for unit in _units(play):
		if unit is Trap:
			continue
		var reach : float = _reach(play, unit)
		var distance : float = Vector2(unit.grid_position - cell).length()
		if distance <= reach and play._stat(unit, Utils.StatType.Knockback) > 0.0:
			is_pushed = true
		if _key(play, unit) == "PuffeHarpooner" and distance <= reach + Synergies.GROUND_ON_TRAP_TILES:
			is_grounded = true
		if unit is Hatchery and distance <= reach:
			is_held = true
		if kind == Synergies.SPIKES and distance <= reach and unit.evolve_tree != null and unit.evolve_tree.is_element_chosen and play._element_name(unit) == "Frost":
			is_chilled = true
	if is_pushed:
		share += PUSH_SHARE
	if is_grounded:
		share += GROUNDED_SHARE * threat.flyers
	if is_held:
		share += HOLD_TRAP_SHARE * (1.0 - threat.flyers)
	if is_chilled:
		share += COLD_FEET_SHARE
	return share


static func _pair_worth(kind : StringName, own : float, other_kind : StringName, other : float) -> float:
	var pair : Dictionary[StringName, float] = {kind: own, other_kind: other}
	if pair.has(Synergies.LEOPARD) and pair.has(Synergies.SPIKES):
		return pair[Synergies.SPIKES] * PINNED_SHARE
	if pair.has(Synergies.EGG) and pair.has(Synergies.SPIKES):
		return pair[Synergies.SPIKES] * SHRAPNEL_SHARE
	if pair.has(Synergies.LEOPARD) and pair.has(Synergies.EGG):
		return pair[Synergies.EGG] * BAIT_SHARE
	return 0.0


# --- a new tower ---

## A new tower of this type on this cell, with what stands around it: Spotted shells and Pinned target with the
## Mortars, Hoard Guardian and War cry for an Elder, Hold the line, Firebreath corridor, Torn and marked.
static func tower_gain(play : RefCounted, level : Level, scene_name : String, cell : Vector2i, range_tiles : float, routes : Array[Vector2i], threat : Dictionary) -> float:
	var key : String = play._key_of_scene(scene_name)
	var reach_cells : Dictionary[Vector2i, bool] = play._cells_in_reach(routes, cell, range_tiles)
	var own : float = play._new_unit_dps(level, scene_name) * play._fit(key, threat) * play._covered(routes, cell, range_tiles)
	var gain : float = 0.0
	match key:
		"PuffeSpotter":
			var mark_chance : float = 0.0 if play.bot.build.get("leaf", "").begins_with("Physical") else MARK_CHANCE
			gain += _blasters_on(play, reach_cells, routes, ["PuffeMortar"]) * SPOTTED_SHARE * mark_chance
		"PuffeHarpooner":
			gain += _blasters_on(play, reach_cells, routes, ["PuffeMortar", "EggBomb"]) * PINNED_TARGET_SHARE
			for unit in _units(play):
				if unit is Trap and Vector2(unit.grid_position - cell).length() <= range_tiles + Synergies.GROUND_ON_TRAP_TILES:
					gain += play._unit_dps(unit) * play.TRAP_CELLS * GROUNDED_SHARE * threat.flyers
		"PuffeMortar":
			var share : float = 0.0
			for unit in _units(play):
				if _marks(play, unit):
					share = maxf(share, SPOTTED_SHARE * _shared(play, unit, reach_cells, routes))
				elif _key(play, unit) == "PuffeHarpooner":
					share = maxf(share, PINNED_TARGET_SHARE * _shared(play, unit, reach_cells, routes))
			gain += own * share
		"PuffeElderDrake":
			gain += own * hoard_share(play, cell)
			if _is_covered_by_roar(play, cell):
				gain += own * WAR_CRY_SHARE
		"PuffeHatchery":
			var best_trap : float = 0.0
			for unit in _units(play):
				if unit is Trap and reach_cells.has(unit.grid_position):
					best_trap = maxf(best_trap, play._unit_dps(unit) * play.TRAP_CELLS)
			gain += best_trap * HOLD_TRAP_SHARE * (1.0 - threat.flyers)
		"PuffeBreather":
			if _has_fire_wall_in(level, cell, range_tiles):
				gain += own * FIREBREATH_SHARE
		"PuffeShredder":
			for unit in _units(play):
				if play._stat(unit, Utils.StatType.ExecuteBelow) > 0.0:
					gain += _torn_worth(play, unit, reach_cells, routes)
	return gain


## Hoard Guardian: the share more an Elder Drake on this cell bites with the Keepers near it.
static func hoard_share(play : RefCounted, cell : Vector2i) -> float:
	var count : int = 0
	for unit in _units(play):
		if unit is HoardKeeper and Vector2(unit.grid_position - cell).length() <= Synergies.HOARD_GUARD_TILES:
			count += 1
	return Synergies.HOARD_GUARD_BONUS * mini(count, Synergies.HOARD_GUARD_MOST)


## A Hoard Keeper on this cell: the Elders it makes bite harder (those that have fewer than the most Keepers).
static func keeper_gain(play : RefCounted, routes : Array[Vector2i], cell : Vector2i) -> float:
	var gain : float = 0.0
	for unit in _units(play):
		if unit is ElderDrake and Vector2(unit.grid_position - cell).length() <= Synergies.HOARD_GUARD_TILES \
				and hoard_share(play, unit.grid_position) < Synergies.HOARD_GUARD_BONUS * Synergies.HOARD_GUARD_MOST - 0.001:
			gain += play._unit_dps(unit) * play._unit_cells(unit, routes) * Synergies.HOARD_GUARD_BONUS
	return gain


# --- a placed unit's element and tiers ---

## The element on a placed unit: Spotted shells (a marking Spotter), Harmony (a Buffer of that element covers it),
## Cold feet (a Frost tower over spikes).
static func element_gain(play : RefCounted, level : Level, unit : Building, element_name : String, routes : Array[Vector2i]) -> float:
	var reach_cells : Dictionary[Vector2i, bool] = play._cells_in_reach(routes, unit.grid_position, _reach(play, unit))
	var value : float = play._unit_dps(unit) * play._unit_cells(unit, routes)
	var gain : float = 0.0
	if _key(play, unit) == "PuffeSpotter" and element_name != "Physical":
		gain += _blasters_on(play, reach_cells, routes, ["PuffeMortar"]) * SPOTTED_SHARE
	var element : Utils.Element = play.ELEMENTS[element_name]
	var chance : float = 0.0
	for buffer in _units(play):
		if buffer is Buffer and buffer.element == element and buffer.covers(unit.global_position):
			chance = maxf(chance, buffer.get_pass_chance())
	gain += value * minf(chance, 1.0 - chance) * HARMONY_SHARE
	if element_name == "Frost" and not unit is Trap:
		for spikes in _units(play):
			if Synergies.trap_kind(spikes) == Synergies.SPIKES and reach_cells.has(spikes.grid_position) and not _is_chilled_spot(play, level, spikes, unit):
				gain += play._unit_dps(spikes) * play.TRAP_CELLS * COLD_FEET_SHARE
	return gain


## A Buffer's element: Harmony on the covered towers that already have it.
static func buffer_element_gain(play : RefCounted, buffer : Building, element_name : String, routes : Array[Vector2i]) -> float:
	if element_name == "Physical":
		return 0.0
	var chance : float = Buffer.PASS_CHANCE_BY_TIER[1]
	var gain : float = 0.0
	for unit in play._buffer_covered(buffer.grid_position, buffer):
		if unit.evolve_tree != null and unit.evolve_tree.is_element_chosen and play._element_name(unit) == element_name:
			gain += play._unit_dps(unit) * play._unit_cells(unit, routes) * chance * HARMONY_SHARE
	return gain


## A tier: War cry (a Buffer's T3 over Elders), Pushed onto spikes (a knockback tier over traps), Torn and marked (an
## execute tier beside a Shredder), Ground reactions (a patch tier where patches of a partner element lie).
static func tier_gain(play : RefCounted, unit : Building, option : GoldUpgradeOption, routes : Array[Vector2i]) -> float:
	var gain : float = 0.0
	if unit is Buffer:
		if option.tier == 2:
			for elder in play._buffer_covered(unit.grid_position, unit):
				if elder is ElderDrake:
					gain += play._unit_dps(elder) * play._unit_cells(elder, routes) * WAR_CRY_SHARE
		return gain
	var steps : Array[Utils.StatType] = _tier_steps(unit, option)
	var reach_cells : Dictionary[Vector2i, bool] = play._cells_in_reach(routes, unit.grid_position, _reach(play, unit))
	if steps.has(Utils.StatType.Knockback) and play._stat(unit, Utils.StatType.Knockback) <= 0.0:
		for trap in _units(play):
			if trap is Trap and reach_cells.has(trap.grid_position):
				gain += play._unit_dps(trap) * play.TRAP_CELLS * PUSH_SHARE
	if steps.has(Utils.StatType.ExecuteBelow) and play._stat(unit, Utils.StatType.ExecuteBelow) <= 0.0:
		for shredder in _units(play):
			if shredder is Shredder:
				gain += _torn_worth(play, unit, play._cells_in_reach(routes, shredder.grid_position, _reach(play, shredder)), routes)
	if steps.has(Utils.StatType.PatchDuration) and play._stat(unit, Utils.StatType.PatchDuration) <= 0.0:
		gain += _patch_partner_worth(play, unit, play._element_name(unit), reach_cells, routes)
	return gain


# --- walls ---

## An element on this wall: Cold feet (Frost beside a Spike Field), Firebreath corridor (Fire in a Breather's reach).
static func wall_element_gain(play : RefCounted, level : Level, routes : Array[Vector2i], wall : Wall, element_name : String) -> float:
	var gain : float = 0.0
	for unit in _units(play):
		if element_name == "Frost" and Synergies.trap_kind(unit) == Synergies.SPIKES and _is_next_to(unit.grid_position, wall.grid_position):
			gain += play._unit_dps(unit) * play.TRAP_CELLS * COLD_FEET_SHARE
		elif element_name == "Fire" and _key(play, unit) == "PuffeBreather" and Vector2(unit.grid_position - wall.grid_position).length() <= _reach(play, unit) \
				and not _has_fire_wall_in(level, unit.grid_position, _reach(play, unit)):
			gain += play._unit_dps(unit) * play._unit_cells(unit, routes) * FIREBREATH_SHARE
	return gain


# --- helpers ---

static func _units(play : RefCounted) -> Array[Building]:
	var found : Array[Building] = []
	for unit in play.units:
		if is_instance_valid(unit) and unit.is_placed:
			found.append(unit)
	return found


static func _key(play : RefCounted, unit : Building) -> String:
	return play._key_of(unit)


static func _reach(play : RefCounted, unit : Building) -> float:
	return 0.0 if unit is Trap else play._stat(unit, Utils.StatType.AttackRange)


#one cell apart at most, diagonals too (Synergies.is_beside)
static func _is_beside(a : Vector2i, b : Vector2i) -> bool:
	var gap : Vector2i = (a - b).abs()
	return a != b and maxi(gap.x, gap.y) <= 1


#side by side, no diagonals (LevelGrid.get_maze_walls)
static func _is_next_to(a : Vector2i, b : Vector2i) -> bool:
	var gap : Vector2i = (a - b).abs()
	return gap.x + gap.y == 1


static func _kinds_beside(play : RefCounted, trap : Building) -> Dictionary[StringName, bool]:
	var kinds : Dictionary[StringName, bool] = {}
	var kind : StringName = Synergies.trap_kind(trap)
	for unit in _units(play):
		if unit is Trap and _is_beside(unit.grid_position, trap.grid_position) and Synergies.trap_kind(unit) != kind:
			kinds[Synergies.trap_kind(unit)] = true
	return kinds


## The share of the unit's route cells that are among these cells.
static func _shared(play : RefCounted, unit : Building, cells : Dictionary[Vector2i, bool], routes : Array[Vector2i]) -> float:
	if unit is Trap:
		return 1.0 if cells.has(unit.grid_position) else 0.0
	var its_cells : Dictionary[Vector2i, bool] = play._cells_in_reach(routes, unit.grid_position, _reach(play, unit))
	if its_cells.is_empty():
		return 0.0
	return play._overlap(unit, cells, routes) / float(its_cells.size())


## The work of these blast towers on the cells, each by its share there.
static func _blasters_on(play : RefCounted, cells : Dictionary[Vector2i, bool], routes : Array[Vector2i], keys : Array[String]) -> float:
	var work : float = 0.0
	for unit in _units(play):
		if _key(play, unit) in keys:
			work += play._unit_dps(unit) * play._unit_cells(unit, routes) * _shared(play, unit, cells, routes)
	return work


static func _marks(play : RefCounted, unit : Building) -> bool:
	return play._stat(unit, Utils.StatType.MarkShare) > 0.0


static func _is_covered_by_roar(play : RefCounted, cell : Vector2i) -> bool:
	for unit in _units(play):
		if unit is Buffer and unit.tier >= 3 and Vector2(unit.grid_position - cell).length() <= play.bot._range_of(play.bot.BUFFER) + 0.25:
			return true
	return false


## Torn and marked: the executing Spotter finishes shredded enemies TORN_EXECUTE sooner, about that share of the
## work of every unit on the shared cells.
static func _torn_worth(play : RefCounted, spotter : Building, shred_cells : Dictionary[Vector2i, bool], routes : Array[Vector2i]) -> float:
	var share : float = _shared(play, spotter, shred_cells, routes)
	if share <= 0.0:
		return 0.0
	var work : float = 0.0
	for unit in _units(play):
		work += play._unit_dps(unit) * play._overlap(unit, shred_cells, routes)
	return work * share * Synergies.TORN_EXECUTE


static func _has_frost_wall_beside(level : Level, cell : Vector2i) -> bool:
	for wall in level.grid.get_maze_walls(cell):
		if wall.element == Utils.Element.Frost:
			return true
	return false


static func _has_fire_wall_in(level : Level, cell : Vector2i, range_tiles : float) -> bool:
	for building in level.all_buildings:
		if is_instance_valid(building) and building is Wall and building.is_placed and building.element == Utils.Element.Fire \
				and Vector2(building.grid_position - cell).length() <= range_tiles:
			return true
	return false


#the spikes are chilled already without this unit (a Frost wall or another Frost tower)
static func _is_chilled_spot(play : RefCounted, level : Level, spikes : Building, without : Building) -> bool:
	if _has_frost_wall_beside(level, spikes.grid_position):
		return true
	for unit in _units(play):
		if unit != without and not unit is Trap and unit.evolve_tree != null and unit.evolve_tree.is_element_chosen \
				and play._element_name(unit) == "Frost" and Vector2(unit.grid_position - spikes.grid_position).length() <= _reach(play, unit):
			return true
	return false


## The stat types a tier option's steps raise.
static func _tier_steps(unit : Building, option : GoldUpgradeOption) -> Array[Utils.StatType]:
	var steps : Array[Utils.StatType] = []
	if option.tier <= 0:
		return steps
	var leaf : ElementEvolveLeaf = unit.get_node_or_null(option.element_leaf_path) as ElementEvolveLeaf
	if leaf == null or option.tier - 1 >= leaf.tiers.size():
		return steps
	for resource in leaf.tiers[option.tier - 1].upgrade_resources:
		steps.append(resource.modify_stat_type)
	return steps


## Ground reactions: patches of this element over these cells meet the patches of the other patch towers there.
static func _patch_partner_worth(play : RefCounted, unit : Building, element_name : String, cells : Dictionary[Vector2i, bool], routes : Array[Vector2i]) -> float:
	var gain : float = 0.0
	for other in _units(play):
		if other == unit or play._stat(other, Utils.StatType.PatchDuration) <= 0.0:
			continue
		var pair : Array[String] = [element_name, play._element_name(other)]
		var share : float = 0.0
		if pair.has("Fire") and pair.has("Poison"):
			share = BURST_SHARE
		elif pair.has("Fire") and pair.has("Frost"):
			share = STEAM_SHARE
		if share > 0.0:
			var overlap : float = _shared(play, other, cells, routes)
			gain += (play._unit_dps(unit) * play._unit_cells(unit, routes) + play._unit_dps(other) * play._unit_cells(other, routes)) * share * overlap
	return gain
