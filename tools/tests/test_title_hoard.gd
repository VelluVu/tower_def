extends RefCounted

## The title screen's hoard (2026-11-23): the eggs hatch, the hatchlings walk the open floor, fly off and the
## eggs come back; the brood carries on between the menu and Options.


func test_title_screen(kit : TestKit) -> void:
	var menu : Menu = (load("res://scenes/ui/menu/menu.tscn") as PackedScene).instantiate()
	kit.root.add_child(menu)
	var backdrop : HoardBackdrop = menu.backdrop
	kit.check(backdrop != null and backdrop.get_parent() == menu, "the hoard behind the menu")
	kit.check(backdrop.stage.scale == Vector2.ONE * HoardBackdrop.ART_SCALE, "drawn at a whole scale")
	kit.check(backdrop.eggs.size() == HoardBackdrop.EGG_SPOTS.size(), "an egg on every spot: %d" % backdrop.eggs.size())
	kit.check(not menu.title_label.visible, "the logo replaces the text title")
	menu.queue_free()
	await kit.frames(1)


func test_the_brood_hatches_flies_off_and_comes_back(kit : TestKit) -> void:
	var backdrop : HoardBackdrop = HoardBackdrop.new()
	kit.root.add_child(backdrop)
	for egg in backdrop.eggs:
		_hatch(egg)
	kit.check(backdrop.hatchlings.size() == backdrop.eggs.size(), "a hatchling from every egg: %d" % backdrop.hatchlings.size())
	kit.check(backdrop.hatchlings.all(func(each : HoardHatchling) -> bool: return each.state == HoardHatchling.State.HOP), "each hops down from its egg")
	kit.check(backdrop.phase == HoardBackdrop.Phase.LINGERING, "all hatched: they wander for a while")

	backdrop._process(HoardBackdrop.LINGER_TIME + 0.1)
	for i in backdrop.eggs.size():
		backdrop._process(HoardBackdrop.FLY_OFF_GAP + 0.1)
	var flying : Array[HoardHatchling] = backdrop.hatchlings.duplicate()
	kit.check(flying.all(func(each : HoardHatchling) -> bool: return each.state == HoardHatchling.State.FLY), "then fly off one by one")
	for hatchling in flying:
		hatchling._process(10.0)
	kit.check(backdrop.hatchlings.is_empty() and backdrop.phase == HoardBackdrop.Phase.RENEWING, "all gone")

	backdrop._process(HoardBackdrop.RENEW_DELAY + 0.1)
	kit.check(backdrop.phase == HoardBackdrop.Phase.HATCHING, "a new brood")
	kit.check(backdrop.eggs.all(func(each : HoardEgg) -> bool: return not each.is_hatched and each.animation == GlobalAnimationNames.IDLE_ANIMATION), "the eggs are whole again")
	backdrop.queue_free()
	await kit.frames(1)


func test_hatchlings_keep_off_the_pile(kit : TestKit) -> void:
	var backdrop : HoardBackdrop = HoardBackdrop.new()
	kit.root.add_child(backdrop)
	var from : Vector2 = Vector2(150, 168)
	kit.check(HoardBackdrop.is_walkable(from), "the floor left of the pile is open")
	kit.check(not HoardBackdrop.is_walkable(HoardBackdrop.PILE_FOOT), "the pile is not")
	kit.check(not HoardBackdrop.is_walkable(Vector2(HoardBackdrop.PILE_FOOT.x, 130)), "nor behind it")
	var all_open : bool = true
	for i in 60:
		var target : Vector2 = backdrop.pick_walk_target(from)
		all_open = all_open and HoardBackdrop.is_walkable(target)
		from = target
	kit.check(all_open, "every walk ends on open floor")
	backdrop.queue_free()
	await kit.frames(1)


func test_the_brood_carries_on_into_options_and_back(kit : TestKit) -> void:
	var menu : Menu = (load("res://scenes/ui/menu/menu.tscn") as PackedScene).instantiate()
	kit.root.add_child(menu)
	var playing : HoardBackdrop = HoardBackdrop.new()
	kit.root.add_child(playing)
	_hatch(playing.eggs[0])
	var fresh : HoardBackdrop = menu.backdrop
	menu.adopt_backdrop(playing)
	kit.check(menu.backdrop == playing and playing.get_parent() == menu, "the menu takes over the playing hoard")
	kit.check(playing.eggs[0].is_hatched and playing.hatchlings.size() == 1, "with its hatchling")
	kit.check(fresh.is_queued_for_deletion(), "its own new one goes")
	menu.queue_free()
	await kit.frames(1)


## Runs an egg to its last hatching step and finishes it.
func _hatch(egg : HoardEgg) -> void:
	egg.start_hatching()
	egg.play(GlobalAnimationNames.HATCH_ANIMATION)
	egg.animation_finished.emit()
