extends RefCounted

## The world map: only cleared levels and the next one show, completion rings, the newest level pops in once.

const MAP_SCENE : String = "res://scenes/ui/game_world_map/game_world_map.tscn"


func test_ring_tiers(kit : TestKit) -> void:
	kit.check(CompletionRing.tier_for(false, 0, 15) == CompletionRing.Tier.NONE, "not cleared: no ring")
	kit.check(CompletionRing.tier_for(true, 1, 15) == CompletionRing.Tier.BRONZE, "Normal cleared: bronze")
	kit.check(CompletionRing.tier_for(true, 9, 15) == CompletionRing.Tier.BRONZE, "9 points: still bronze")
	kit.check(CompletionRing.tier_for(true, 10, 15) == CompletionRing.Tier.SILVER, "10 points: silver")
	kit.check(CompletionRing.tier_for(true, 15, 15) == CompletionRing.Tier.GOLD, "all 15: gold")


func test_token_rows(kit : TestKit) -> void:
	kit.check(MapLevelElement.token_row(1) == 0 and MapLevelElement.token_row(12) == 0, "caves 1-12")
	kit.check(MapLevelElement.token_row(13) == 1 and MapLevelElement.token_row(25) == 2, "swamp from 13, Wasted Lands from 25")
	kit.check(MapLevelElement.token_row(37) == 3 and MapLevelElement.token_row(59) == 4, "desert from 37, volcano to 59 (57 is the Magma Titan)")
	for boss in [8, 24, 36, 48, 57, 60]:
		kit.check(MapLevelElement.token_row(boss) == MapLevelElement.BOSS_ROW, "level %d has the boss token" % boss)
	var rows : int = floori(MapLevelElement.TOKEN_SHEET.get_height() / float(MapLevelElement.TOKEN_CELL))
	kit.check(rows == MapLevelElement.BOSS_ROW + 1, "the sheet has every row")


func test_map_shows_cleared_and_next(kit : TestKit) -> void:
	var saved : ProgressData = PlayerProgress._save.progress
	var progress : ProgressData = ProgressData.new()
	progress.level_progress = 4
	progress.map_revealed_level = 3
	progress.level_talent_points = {1: 5, 2: 1, 3: 3}
	progress.mode_talent_points = {Utils.LevelMode.Hard: {1: 5, 3: 5}, Utils.LevelMode.Survival: {1: 5, 3: 2}}
	PlayerProgress._save.progress = progress

	var map : GameWorldMap = load(MAP_SCENE).instantiate()
	kit.root.add_child(map)
	await kit.frames(2)
	var by_number : Dictionary[int, MapLevelElement] = {}
	for element in map.map_level_elements:
		by_number[element.level_number] = element

	kit.check(by_number[4].visible and not by_number[5].visible and not by_number[60].visible, "level 4 is next, 5 and later hidden")
	kit.check(MapLevelElement.area_of(12) == 0 and MapLevelElement.area_of(13) == 1 and MapLevelElement.area_of(60) == 4, "twelve levels to an area")
	var banner : TextureRect = by_number[13].name_label.get_parent().get_child(by_number[13].name_label.get_index() + 1) as TextureRect
	kit.check(banner != null and banner.texture == MapLevelElement.AREA_BANNERS[1], "the swamp picture under a swamp level's name")
	kit.check(by_number[4].is_next_to_play() and not by_number[3].is_next_to_play(), "only level 4 is next to play")
	kit.check(by_number[1].completion_ring.tier == CompletionRing.Tier.GOLD, "15 points: gold")
	kit.check(by_number[2].completion_ring.tier == CompletionRing.Tier.BRONZE, "1 point: bronze")
	kit.check(by_number[3].completion_ring.tier == CompletionRing.Tier.SILVER, "10 points: silver")
	kit.check(by_number[4].next_arrow != null and by_number[3].next_arrow == null, "the arrow is over the next level only")
	kit.check(by_number[4].start_label == null, "no Start here once a level is cleared")
	by_number[4].tooltip.visible = true
	kit.check(not by_number[4].next_arrow.visible, "the arrow hides while the level's panel is open")
	by_number[4].tooltip.visible = false
	kit.check(by_number[4].next_arrow.visible, "and comes back when it closes")
	kit.check(by_number[4].completion_ring.tier == CompletionRing.Tier.NONE and not by_number[4].completion_ring.visible, "next level: no ring")
	#Godot keeps a scale a hair above zero
	kit.check(by_number[4].select_button.scale.x < 0.01, "level 4 is new since the map was last shown: it pops in")
	kit.check(PlayerProgress.map_revealed_level == 4, "and only once")
	map.queue_free()
	await kit.frames(1)

	var again : GameWorldMap = load(MAP_SCENE).instantiate()
	kit.root.add_child(again)
	await kit.frames(2)
	for element in again.map_level_elements:
		if element.level_number == 4:
			kit.check(element.select_button.scale == Vector2.ONE, "the second time it is just there")
	again.queue_free()
	await kit.frames(1)

	#a new game: level 1 gets the arrow and the Start here label
	PlayerProgress._save.progress = ProgressData.new()
	var fresh : GameWorldMap = load(MAP_SCENE).instantiate()
	kit.root.add_child(fresh)
	await kit.frames(2)
	for element in fresh.map_level_elements:
		if element.level_number == 1:
			kit.check(element.next_arrow != null and element.start_label != null, "new game: arrow and Start here on level 1")
	fresh.queue_free()
	await kit.frames(1)
	PlayerProgress._save.progress = saved


#(the user, 2026-11-23): the next-level arrow (z 1) showed through the talent screen
func test_map_hides_under_the_talent_screen(kit : TestKit) -> void:
	var map : GameWorldMap = load(MAP_SCENE).instantiate()
	kit.root.add_child(map)
	await kit.frames(1)
	kit.check(map.visible, "the map shows")
	UISignals.talents.emit(true)
	kit.check(not map.visible, "hidden while the talent screen is open")
	UISignals.talents.emit(false)
	kit.check(map.visible, "back when it closes")
	map.queue_free()
