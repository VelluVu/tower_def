extends RefCounted

## Draws many level-up offers for a set of placed buildings and reports how often each card and a rare card shows.
## `python tools/gd.py run tools/reports/card_offers.gd level=2 build=puffe_bolter,puffe_beamer,wall offers=2000 --raw`
##   build=  buildings placed before the draws, on free buildable cells; offers= how many offers are drawn

var options : Dictionary[String, String] = {"level": "2", "build": "puffe_bolter,wall", "offers": "2000"}


func run(kit : TestKit, args : PackedStringArray) -> void:
	for arg in args:
		var parts : PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2:
			options[parts[0]] = parts[1]
	await kit.load_level(int(options.level))
	var used : Dictionary[Vector2i, bool] = {}
	for building_name in options.build.split(",", false):
		var cell : Vector2i = kit.find_cell(func(candidate : Vector2i) -> bool: return not used.has(candidate))
		used[cell] = true
		await kit.place(building_name, cell)
	var upgrades : LevelUpgrades = kit.level.upgrades
	var offers : int = int(options.offers)
	var shown : Dictionary[String, int] = {}
	var with_rare : int = 0
	var pool_size : int = 0
	for resource in RandomEvolveResourceCollection.all_evolve_resources:
		if upgrades._can_offer(resource, 2):
			pool_size += 1
	for i in offers:
		var cards : Array[UpgradeCard] = upgrades._get_stat_cards(2)
		var has_rare : bool = false
		for card in cards:
			var card_name : String = card.resource.resource_path.get_file().get_basename()
			shown[card_name] = shown.get(card_name, 0) + 1
			has_rare = has_rare or card.resource.rarity == EvolveResource.Rarity.Rare
		if has_rare:
			with_rare += 1
	print("CARDS level %s, build %s: pool %d cards, %d offers, %.0f%% with a rare" % [options.level, options.build, pool_size, offers, 100.0 * with_rare / offers])
	var names : Array = shown.keys()
	names.sort_custom(func(a : String, b : String) -> bool: return shown[a] > shown[b])
	for card_name in names:
		print("CARDS   %-22s %3.0f%% of offers" % [card_name, 100.0 * shown[card_name] / offers])
	#the kit's stand-in Main goes when the run ends; a level left ticking then errors on every tower
	kit.free_level()
