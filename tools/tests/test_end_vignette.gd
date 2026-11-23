extends RefCounted

## The pictures at the top of the level end screens (2026-11-23).


func test_win_picture_cheers_under_a_gold_rain(kit : TestKit) -> void:
	var menu : LevelCompletedMenu = (load("res://scenes/ui/level_completed_menu/level_completed_menu.tscn") as PackedScene).instantiate()
	kit.root.add_child(menu)
	var picture : EndVignette = menu.label.get_parent().get_child(0) as EndVignette
	kit.check(picture != null and picture.kind == EndVignette.Kind.WIN, "the win picture tops the panel")
	kit.check(picture.jumpers.size() == EndVignette.CHEER_SPOTS.size(), "three drakelings cheer")
	var heights : Array[float] = []
	for step in 8:
		picture._process(0.07)
		heights.append(picture.jumpers[0].position.y)
	kit.check(heights.min() < heights.max(), "and they jump")
	kit.check(picture._bits.size() > 0, "coins fall")
	for step in 60:
		picture._process(0.05)
	kit.check(picture._bits.size() < 40, "and land and go: %d left" % picture._bits.size())
	menu.queue_free()
	await kit.frames(1)


func test_lose_picture_mourns(kit : TestKit) -> void:
	var menu : LoseGameMenu = (load("res://scenes/ui/lose_game_menu/lose_game_menu.tscn") as PackedScene).instantiate()
	kit.root.add_child(menu)
	var picture : EndVignette = menu.survival_label.get_parent().get_child(0) as EndVignette
	kit.check(picture != null and picture.kind == EndVignette.Kind.LOSE, "the lose picture tops the panel")
	var sad : Array[Node] = picture.stage.get_children().filter(func(child : Node) -> bool: return child is HoardHatchling)
	kit.check(sad.size() == 1 and (sad[0] as HoardHatchling).animation == GlobalAnimationNames.SAD_ANIMATION, "one drakeling sits by the egg")
	picture._process(EndVignette.SMOKE_INTERVAL + 0.01)
	kit.check(picture._bits.size() == 1, "smoke rises from the gate")
	menu.queue_free()
	await kit.frames(1)
