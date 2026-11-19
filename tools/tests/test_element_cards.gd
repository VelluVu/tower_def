extends RefCounted

## Element cards from the talent trees (tools/element_cards.py): offered once their tree has enough ranks, and only
## to towers of their element.

const TOWER_CELL : Vector2i = Vector2i(12, 6)
const WILDFIRE : String = "fire_wildfire"
const KINDLED_FURY : String = "fire_kindled_fury"


func test_cards_wait_for_their_tree(kit : TestKit) -> void:
	var saved : Dictionary = PlayerProgress._save.progress.talent_ranks
	PlayerProgress._save.progress.talent_ranks = {}
	await kit.load_level(1)
	var bolter : Building = await kit.place("puffe_bolter", TOWER_CELL)
	bolter.evolve_tree.choose_element(Utils.Element.Fire)
	var fury : EvolveResource = load(TestKit.CARD_PATH % KINDLED_FURY)
	var wildfire : EvolveResource = load(TestKit.CARD_PATH % WILDFIRE)
	kit.check(not kit.level.upgrades._can_offer(fury, 2), "no Fire ranks: no Fire cards")

	PlayerProgress._save.progress.talent_ranks = {&"fire": {&"kindling": 3, &"searing_heat": 2}}
	kit.check(LevelTalents.get_tree_ranks(&"fire") == 5, "5 Fire ranks")
	kit.check(kit.level.upgrades._can_offer(fury, 2), "the common card at 5 ranks")
	kit.check(not kit.level.upgrades._can_offer(wildfire, 2), "the rare one waits for 15")

	PlayerProgress._save.progress.talent_ranks = {&"fire": {&"kindling": 15}}
	kit.check(kit.level.upgrades._can_offer(wildfire, 2), "the rare card at 15 ranks")
	bolter.evolve_tree.choose_element(Utils.Element.Frost)
	kit.check(not kit.level.upgrades._can_offer(fury, 2), "no Fire tower on the map: no Fire card")
	PlayerProgress._save.progress.talent_ranks = saved


func test_card_texts_show_their_values(kit : TestKit) -> void:
	var glacier : EvolveResource = load(TestKit.CARD_PATH % "frost_glacier_heart")
	var ignition : EvolveResource = load(TestKit.CARD_PATH % "fire_ignition")
	var glacier_text : String = UpgradeCard.from_resource(glacier, UpgradeRules.roll_value(glacier, 0.5)).get_text()
	var ignition_text : String = UpgradeCard.from_resource(ignition, UpgradeRules.roll_value(ignition, 0.5)).get_text()
	kit.check(glacier_text.contains("40%"), "Glacier Heart names its 40%%: %s" % glacier_text.c_escape())
	kit.check(ignition_text.contains("50%"), "Ignition names its 50%%: %s" % ignition_text.c_escape())


func test_wildfire_gives_fire_towers_splash(kit : TestKit) -> void:
	var saved : Dictionary = PlayerProgress._save.progress.talent_ranks
	PlayerProgress._save.progress.talent_ranks = {&"fire": {&"kindling": 15}}
	await kit.load_level(1)
	var bolter : Building = await kit.place("puffe_bolter", TOWER_CELL)
	bolter.evolve_tree.choose_element(Utils.Element.Fire)
	kit.pick_card(WILDFIRE)
	kit.check_near(bolter.stats.get_stat_value(Utils.StatType.SplashRadius), 1.0, "Wildfire: a tile of splash")
	PlayerProgress._save.progress.talent_ranks = saved
