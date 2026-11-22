extends RefCounted

## Polish round 6 (2026-11-22): feedback for a click without the gold, the sell refund number,
## the upgrade flash and the fade-out before a screen switch.


func test_build_click_without_gold_says_so(kit : TestKit) -> void:
	await kit.load_level(1)
	var builder : Builder = Builder.new()
	kit.root.add_child(builder)
	builder.level = kit.level
	builder.available_buildings = builder.buildings.slice(0, 2)
	builder.is_ready_to_build = true
	InputManager.shortcut_pressed.emit(InputManager.ACTION_BUILD_SLOTS[1])
	kit.check(builder.is_placing_building, "placing the second tray slot")
	kit.level.player_stats.gold = 0.0
	var prices : Array[float] = []
	var on_short : Callable = func(_position : Vector2, price : float) -> void: prices.append(price)
	GameSignals.not_enough_gold.connect(on_short)
	builder._place_building(1)
	GameSignals.not_enough_gold.disconnect(on_short)
	kit.check(prices.size() == 1 and prices[0] > 0.0, "one not_enough_gold with the price (%s)" % [prices])
	kit.check(kit.level.all_buildings.is_empty(), "nothing was built")
	builder.queue_free()


func test_selling_shows_the_refund(kit : TestKit) -> void:
	await kit.load_level(1)
	var cell : Vector2i = kit.find_cell(func(_cell : Vector2i) -> bool: return true)
	var tower : Building = await kit.place("puffe_bolter", cell)
	var refunds : Array[float] = []
	var on_gold : Callable = func(_position : Vector2, amount : float) -> void: refunds.append(amount)
	GameSignals.gold_earned.connect(on_gold)
	GameSignals.sell_building.emit(tower)
	GameSignals.gold_earned.disconnect(on_gold)
	kit.check(refunds.size() == 1 and refunds[0] > 0.0, "a gold +N for the refund (%s)" % [refunds])


func test_fade_out_is_instant_headless(kit : TestKit) -> void:
	var fade : ScreenFade = ScreenFade.new()
	kit.root.add_child(fade)
	var start : int = Time.get_ticks_msec()
	await fade.fade_out()
	kit.check(Time.get_ticks_msec() - start < 100, "a headless run never waits on the fade")
	fade.queue_free()


func test_flyer_badge_is_7x7(kit : TestKit) -> void:
	kit.check(WavePreview.FLYER_BADGE.get_size() == Vector2(7, 7), "the redrawn wing keeps its size")
