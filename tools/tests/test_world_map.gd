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
	kit.check(MapLevelElement.token_row(1) == 0 and MapLevelElement.token_row(11) == 0, "caves 1-11 (12 is the Broodmother)")
	kit.check(MapLevelElement.token_row(13) == 1 and MapLevelElement.token_row(25) == 2, "swamp from 13, Wasted Lands from 25")
	kit.check(MapLevelElement.token_row(37) == 3 and MapLevelElement.token_row(59) == 4, "desert from 37, volcano to 59 (57 is the Magma Titan)")
	for boss in [12, 24, 36, 48, 57, 60]:
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


#(the user, 2026-11-24): the map is 2x2 screens; it scrolls inside its edges, opens on the newest level, and the
#trail into a newly unlocked level draws in before its node pops up
func test_map_scrolls_and_draws_trails(kit : TestKit) -> void:
	var saved : ProgressData = PlayerProgress._save.progress
	var progress : ProgressData = ProgressData.new()
	progress.level_progress = 30
	progress.map_revealed_level = 29
	PlayerProgress._save.progress = progress
	var map : GameWorldMap = load(MAP_SCENE).instantiate()
	kit.root.add_child(map)
	await kit.frames(3)
	kit.check(map.map.size.x > map.map_view.size.x and map.map.size.y > map.map_view.size.y, "the map is bigger than the screen both ways")
	var newest : MapLevelElement = null
	for element in map.map_level_elements:
		if element.level_number == 30:
			newest = element
	var centre : Vector2 = newest.get_global_rect().get_center()
	kit.check(map.map_view.get_global_rect().has_point(centre), "the view opens with the newest level in it")
	kit.check(map.trails.revealing_level == 30, "the trail into the new level draws in")
	map.scroll_by(Vector2(99999, 99999))
	kit.check(map.map.position == Vector2.ZERO, "scrolling stops at the top left corner")
	map.scroll_by(Vector2(-99999, -99999))
	kit.check(map.map.position == (map.map_view.size - map.map.size).round(), "and at the bottom right")
	var done : Array[bool] = [false]
	map.trails.revealed.connect(func() -> void: done[0] = true)
	await kit.run_until(func() -> bool: return done[0], MapTrails.REVEAL_SECONDS + 1.0)
	kit.check(done[0] and map.trails.reveal_progress == 1.0, "the trail finishes drawing")
	map.queue_free()
	await kit.frames(1)
	PlayerProgress._save.progress = saved


#(the user, 2026-11-24): clouds, swamp mist, lava smoke and sea sparkles find their places on the map picture
func test_map_ambience_finds_its_spots(kit : TestKit) -> void:
	var map : GameWorldMap = load(MAP_SCENE).instantiate()
	kit.root.add_child(map)
	await kit.frames(3)
	var ambience : MapAmbience = map.map.get_node("MapAmbience") as MapAmbience
	kit.check(ambience.clouds.size() == MapAmbience.CLOUD_COUNT, "the clouds are up")
	kit.check(ambience.sparkles.size() > MapAmbience.SPARKLE_COUNT / 2, "sparkles on the sea (%d)" % ambience.sparkles.size())
	kit.check(ambience.vents.size() > 2, "smoke over the lava (%d)" % ambience.vents.size())
	kit.check(ambience.mists.size() > 2, "mist in the swamp (%d)" % ambience.mists.size())
	var before : Vector2 = ambience.clouds[0].at
	await kit.frames(10)
	kit.check(ambience.clouds[0].at.x > before.x, "the clouds drift east")
	map.queue_free()
	await kit.frames(1)


#(the user, 2026-11-24): fog lies over the land not reached yet; the newest level's patch opens with its trail; the
#fog glows over the volcano's lava from the start
func test_fog_lifts_as_levels_are_revealed(kit : TestKit) -> void:
	var saved : ProgressData = PlayerProgress._save.progress
	var progress : ProgressData = ProgressData.new()
	progress.level_progress = 13
	progress.map_revealed_level = 12
	PlayerProgress._save.progress = progress
	var map : GameWorldMap = load(MAP_SCENE).instantiate()
	kit.root.add_child(map)
	await kit.frames(3)
	var centres : Dictionary[int, Vector2] = {}
	for element in map.map_level_elements:
		centres[element.level_number] = element.position + element.size * 0.5
	kit.check(map.fog != null and map.fog.get_index() < map.trails.get_index(), "the fog lies under the trails and the nodes")
	kit.check(map.fog.density_at(centres[1]) == 0.0 and map.fog.density_at(centres[12]) == 0.0, "clear round the levels reached")
	kit.check(map.fog.density_at(centres[13]) > 0.3, "the new level starts in the fog (its neighbour thins it) (%.2f)" % map.fog.density_at(centres[13]))
	kit.check(map.fog.density_at(centres[40]) > 0.9, "the desert is still fogged")
	var lava_texels : int = 0
	for y in map.fog.density.get_height():
		for x in map.fog.density.get_width():
			if map.fog.density.get_pixel(x, y).g >= MapFog.LAVA_GLOW - 0.01 and map.fog.density.get_pixel(x, y).r > 0.9:
				lava_texels += 1
	kit.check(lava_texels > 20, "the fog glows over the lava (%d texels)" % lava_texels)
	await kit.run_until(func() -> bool: return map.fog.reveal_progress >= 1.0, MapFog.REVEAL_SECONDS + 1.0)
	kit.check(map.fog.density_at(centres[13]) == 0.0, "the new level's patch opens")
	var trail : PackedVector2Array = map.trails.trail_points(13)
	kit.check(map.fog.density_at(trail[trail.size() / 2]) == 0.0, "and the trail to it")
	map.queue_free()
	await kit.frames(1)
	PlayerProgress._save.progress = saved


#(the user, 2026-11-25: fog was left in the middle of the map) once an area's boss is beaten, the fog lifts from the
#whole area, the gaps between its levels too; areas not finished keep theirs
func test_finished_area_clears_its_fog(kit : TestKit) -> void:
	var saved : ProgressData = PlayerProgress._save.progress
	var progress : ProgressData = ProgressData.new()
	progress.level_progress = 13
	progress.map_revealed_level = 13
	PlayerProgress._save.progress = progress
	var started : int = Time.get_ticks_msec()
	var map : GameWorldMap = load(MAP_SCENE).instantiate()
	kit.root.add_child(map)
	await kit.frames(3)
	var opened_in : int = Time.get_ticks_msec() - started
	var centres : Dictionary[int, Vector2] = {}
	for element in map.map_level_elements:
		centres[element.level_number] = element.position + element.size * 0.5
	kit.check(map.fog.is_area_finished(0) and not map.fog.is_area_finished(1), "the Caves are finished, the Swamp is not")
	#a spot among the cave levels but far from every node and trail: between levels 9, 10 and the lake
	var between : Vector2 = (centres[7] + centres[9] + centres[11]) / 3.0
	kit.check(map.fog.density_at(between) == 0.0, "the ground between the cave levels clears (%.2f)" % map.fog.density_at(between))
	var swamp_middle : Vector2 = (centres[16] + centres[17] + centres[19]) / 3.0
	kit.check(map.fog.density_at(swamp_middle) > 0.5, "the Swamp's middle stays fogged (%.2f)" % map.fog.density_at(swamp_middle))
	kit.check(map.fog.density_at(Vector2(4, 4)) > 0.9, "the map's far corner stays misty")
	kit.check(opened_in < 1500, "the map still opens quickly (%d ms)" % opened_in)
	map.queue_free()
	await kit.frames(1)
	PlayerProgress._save.progress = saved
