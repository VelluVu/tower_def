extends RefCounted

## Polish round 8 (2026-11-22): tray slot prices, the XP bar, the speed shown as a multiplier.


func test_tray_slots_show_their_price(kit : TestKit) -> void:
	await kit.load_level(6)
	var builder : Builder = Builder.new()
	kit.root.add_child(builder)
	builder.level = kit.level
	builder.available_buildings = builder.buildings.slice(0, 3)
	var prices : Dictionary[int, float] = {}
	var on_price : Callable = func(index : int, price : float) -> void: prices[index] = price
	UISignals.building_option_price.connect(on_price)
	builder.emit_tray_prices()
	var first : Dictionary[int, float] = prices.duplicate()
	kit.check(first.size() == 3, "a price per slot (%s)" % [first])
	var tower_slot : int = -1
	for i in builder.available_buildings.size():
		if Builder.get_base_price_and_step(builder.available_buildings[i]).y > 0.0:
			tower_slot = i
			break
	var cell : Vector2i = kit.find_cell(func(_cell : Vector2i) -> bool: return true)
	await kit.place("puffe_bolter", cell)
	builder.emit_tray_prices()
	UISignals.building_option_price.disconnect(on_price)
	kit.check(tower_slot >= 0 and prices[tower_slot] > first[tower_slot], "a tower on the map raises a stepped slot's price (%s -> %s)" % [first.get(tower_slot), prices.get(tower_slot)])
	builder.queue_free()


func test_slot_price_turns_red_when_too_dear(kit : TestKit) -> void:
	var bottom : Node = (load("res://scenes/ui/bottom_panel/bottom_panel.tscn") as PackedScene).instantiate()
	kit.root.add_child(bottom)
	await kit.frames(1)
	var option : BuildingOption = bottom.find_children("*", "BuildingOption", true, false)[0] as BuildingOption
	GameSignals.resource_change.emit(10, 0)
	UISignals.building_option_price.emit(option.building_index, 6.0)
	kit.check(option.price_label.visible and option.price_label.text == "6", "the price shows: %s" % option.price_label.text)
	kit.check(option.price_label.get_theme_color(&"font_color") == BuildingOption.AFFORDABLE_COLOR, "gold while it can be paid")
	GameSignals.resource_change.emit(4, 0)
	kit.check(option.price_label.get_theme_color(&"font_color") == BuildingOption.TOO_DEAR_COLOR, "red when the gold falls short")
	bottom.queue_free()


func test_xp_bar_fills_and_levels_up(kit : TestKit) -> void:
	var bar : XpBar = XpBar.new()
	kit.root.add_child(bar)
	bar.set_xp(50.0, 100.0, 1)
	await kit.frames(30)
	kit.check(is_equal_approx(bar.shown_ratio, 0.5), "half way (%.2f)" % bar.shown_ratio)
	bar.set_xp(10.0, 170.0, 2)
	await kit.frames(3)
	kit.check(bar.is_level_up_flash, "a level-up flashes gold")
	await kit.frames(90)
	kit.check(not bar.is_level_up_flash and is_equal_approx(bar.shown_ratio, 10.0 / 170.0), "then refills from empty (%.3f)" % bar.shown_ratio)
	bar.queue_free()


func test_speed_reads_as_a_multiplier(kit : TestKit) -> void:
	kit.check(SpeedControlPanel.format_speed(1.0) == "×1" and SpeedControlPanel.format_speed(1.5) == "×1.5" and SpeedControlPanel.format_speed(3.0) == "×3", "×1, ×1.5, ×3")
