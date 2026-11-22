extends RefCounted

## Polish round 5 (2026-11-22, "big polish"): screen fades, dimmed menus, the wave-cleared banner,
## the title screen, card frames and rich tooltips on the options rows.


func test_screen_fade_covers_then_clears(kit : TestKit) -> void:
	var fade : ScreenFade = ScreenFade.new()
	kit.root.add_child(fade)
	kit.check(not fade.cover.visible, "clear until a screen appears")
	fade.fade_in()
	kit.check(fade.cover.visible, "a new screen starts covered")
	await kit.frames(int(ScreenFade.FADE_SECONDS * 60.0) + 10)
	kit.check(not fade.cover.visible, "and clears after %.1f s" % ScreenFade.FADE_SECONDS)
	fade.queue_free()


func test_menus_get_a_dim_layer(kit : TestKit) -> void:
	var ui : UI = UI.new()
	kit.root.add_child(ui)
	var menu : Control = Control.new()
	ui.add_child(menu)
	ui.dim_behind(menu)
	var dims : Array[Node] = ui.get_children().filter(func(child : Node) -> bool: return child is ColorRect)
	kit.check(dims.size() == 1 and dims[0].get_index() < menu.get_index(), "a dim layer just under the menu")
	menu.queue_free()
	await kit.frames(2)
	kit.check(ui.get_children().filter(func(child : Node) -> bool: return child is ColorRect).is_empty(), "freed with the menu")
	ui.queue_free()


func test_wave_cleared_banner(kit : TestKit) -> void:
	var banner : WaveBanner = WaveBanner.new()
	kit.root.add_child(banner)
	GameSignals.wave_cleared.emit(3)
	kit.check(banner.title.text == WaveBanner.CLEARED_TEXT % 3 and banner.warning.text == WaveBanner.BREAK_TEXT, "Wave 3 cleared: %s / %s" % [banner.title.text, banner.warning.text])
	kit.check(banner.modulate.a > 0.0, "it shows")
	banner.queue_free()


func test_title_screen(kit : TestKit) -> void:
	var menu : Menu = (load("res://scenes/ui/menu/menu.tscn") as PackedScene).instantiate()
	kit.root.add_child(menu)
	kit.check(menu.backdrop != null and menu.backdrop.size == Menu.MAP.get_size() * Menu.MAP_SCALE, "the world map behind it, at a whole scale")
	kit.check(not menu.title_label.visible, "the logo replaces the text title")
	var start : Vector2 = menu.backdrop.position
	menu._process(Menu.DRIFT_SECONDS / 4.0)
	kit.check(menu.backdrop.position != start and menu.backdrop.position == menu.backdrop.position.round(), "it drifts in whole pixels")
	menu.queue_free()


func test_card_frames_by_rarity(kit : TestKit) -> void:
	var common : Button = Button.new()
	var rare : Button = Button.new()
	LevelUpMenu.apply_frame(common, false)
	LevelUpMenu.apply_frame(rare, true)
	var common_style : StyleBoxTexture = common.get_theme_stylebox(&"normal") as StyleBoxTexture
	var rare_hover : StyleBoxTexture = rare.get_theme_stylebox(&"hover") as StyleBoxTexture
	kit.check(common_style != null and common_style.region_rect.position == Vector2.ZERO, "common: the first row")
	kit.check(rare_hover != null and rare_hover.region_rect.position == Vector2(LevelUpMenu.FRAME_CELL, LevelUpMenu.FRAME_CELL), "rare hover: second row, second cell")
	common.free()
	rare.free()


func test_option_rows_have_rich_tooltips(kit : TestKit) -> void:
	var options : Control = (load("res://scenes/ui/menu/options/options.tscn") as PackedScene).instantiate()
	kit.root.add_child(options)
	await kit.frames(2)
	var rows : Array[Node] = options.find_children("*", "RichTooltipBox", true, false)
	var with_tooltip : Array[Node] = rows.filter(func(row : Node) -> bool: return not (row as Control).tooltip_text.is_empty())
	kit.check(not with_tooltip.is_empty(), "rows with tooltips (%d of %d)" % [with_tooltip.size(), rows.size()])
	for row : Node in with_tooltip:
		for child : Node in row.get_children():
			kit.check((child as Control).tooltip_text.is_empty() and (child as Control).mouse_filter == Control.MOUSE_FILTER_PASS, "%s: the row owns the tooltip" % (row as Control).tooltip_text.get_slice("\n", 0))
			break
	options.queue_free()
