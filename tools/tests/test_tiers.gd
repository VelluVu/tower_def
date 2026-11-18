extends RefCounted

## The tower evolve tiers T2 and T3: the step rhythm, the talent lock, the stat steps and the sprite swap.
## Ranks are set straight in the loaded progress (like test_talents.gd), so no test saves.

const FIRE_LEAF_NAME : String = "FireElementEvolveLeaf"
const PHYSICAL_LEAF_NAME : String = "PhysicalElementEvolveLeaf"


func test_tier_rhythm(kit : TestKit) -> void:
	var data : BuildingUpgradeData = load("res://scenes/upgrades/building_upgrades/nova_upgrade_data.tres")
	kit.check(data.upgrades_before_tier(0) == 2, "T1 after Up 2")
	kit.check(data.upgrades_before_tier(1) == 3 and data.upgrades_before_tier(2) == 3, "T2 and T3 after Up 3")
	var walls : BuildingUpgradeData = load("res://scenes/upgrades/building_upgrades/wall_upgrade_data.tres")
	kit.check(walls.upgrades_before_tier(1) == 2 * walls.upgrades_per_tier, "no tier list: the old rhythm")


func test_tier_waits_for_its_talent(kit : TestKit) -> void:
	var saved : Dictionary[StringName, Dictionary] = _set_ranks({})
	await kit.load_level(3)
	var nova : Building = await _to_up_3(kit, "puffe_nova", FIRE_LEAF_NAME)
	var options : Array[GoldUpgradeOption] = kit.level.building_type_upgrades.options
	kit.check(options.size() == 1 and options[0].tier == 1, "after Up 3 comes T2")
	kit.check(options[0].is_locked and not options[0].is_affordable, "locked without Nova T2 in the Fire tree")
	kit.check(options[0].title.contains("Nova T2"), "the button names the talent: %s" % options[0].title)
	var gold : float = kit.level.player_stats.gold
	_buy(kit, 0)
	kit.check(kit.level.player_stats.gold == gold, "a locked tier is never bought")
	kit.check(_extra_chance(nova) == 0.0, "and gives nothing")
	_set_ranks(saved)


func test_fire_nova_tiers(kit : TestKit) -> void:
	var saved : Dictionary[StringName, Dictionary] = _set_ranks({&"fire": {&"nova_t2": 1, &"nova_t3": 1}})
	await kit.load_level(3)
	var nova : Building = await _to_up_3(kit, "puffe_nova", FIRE_LEAF_NAME)
	var damage_before : float = nova.skill.stats.get_stat_value(Utils.StatType.Damage)
	var frames_before : SpriteFrames = nova.animation_control.sprite_frames
	_buy(kit, 0)
	kit.check(_extra_chance(nova) >= 1.0, "T2: bursts always ignite (chance +%.1f)" % _extra_chance(nova))
	kit.check(nova.skill.stats.get_stat_value(Utils.StatType.Damage) > damage_before, "T2: its stat step")
	kit.check(nova.animation_control.sprite_frames != frames_before, "T2: the tier sprite")
	var options : Array[GoldUpgradeOption] = kit.level.building_type_upgrades.options
	kit.check(options.size() == 1 and options[0].tier == 2 and not options[0].is_locked, "then T3")
	_buy(kit, 0)
	kit.check(roundi(nova.stats.get_stat_value(Utils.StatType.ExtraShots)) == 1, "T3: a second burst")
	kit.check(kit.level.building_type_upgrades.options.is_empty(), "nothing after T3")
	_set_ranks(saved)


func test_physical_beamer_t2_chains(kit : TestKit) -> void:
	var saved : Dictionary[StringName, Dictionary] = _set_ranks({&"building": {&"phys_t2": 1}})
	await kit.load_level(3)
	var beamer : Building = await _to_up_3(kit, "puffe_beamer", PHYSICAL_LEAF_NAME)
	_buy(kit, 0)
	kit.check(roundi(beamer.stats.get_stat_value(Utils.StatType.ChainTargets)) == 1, "the beam chains to a second enemy")
	kit.check(kit.level.building_type_upgrades.options[0].is_locked, "T3 waits for Physical T3")
	_set_ranks(saved)


## Places a tower and buys Up 1-2, the element and Up 3 with free gold.
func _to_up_3(kit : TestKit, building_name : String, leaf_name : String) -> Building:
	var cell : Vector2i = kit.find_cell(func(c : Vector2i) -> bool: return kit.level.grid.is_position_buildable(kit.level.grid.grid_position_to_world(c)))
	var building : Building = await kit.place(building_name, cell)
	kit.level.player_stats.gold = 999
	kit.level.building_type_upgrades._on_unit_selected(building)
	_buy(kit, 0)
	_buy(kit, 0)
	var options : Array[GoldUpgradeOption] = kit.level.building_type_upgrades.options
	for i in options.size():
		if str(options[i].element_leaf_path).ends_with(leaf_name):
			_buy(kit, i)
			break
	_buy(kit, 0)
	return building


func _buy(kit : TestKit, index : int) -> void:
	kit.level.building_type_upgrades._on_gold_upgrade_pressed(index)


func _extra_chance(building : Building) -> float:
	return building.stats.get_stat_value(Utils.StatType.EffectChance)


func _set_ranks(ranks : Dictionary) -> Dictionary[StringName, Dictionary]:
	var progress : ProgressData = PlayerProgress._save.progress
	var saved : Dictionary[StringName, Dictionary] = progress.talent_ranks
	var typed : Dictionary[StringName, Dictionary] = {}
	for tree_id in ranks:
		typed[tree_id] = ranks[tree_id]
	progress.talent_ranks = typed
	return saved
