extends RefCounted

## The early start made noticeable (2026-11-25, the user: "when you can start early wave it should be more noticeable"):
## the wave panel's button glows gold while it is open, a notice slides in as it opens, the bonus floats up when it is
## taken, and a counter shows the early starts toward the talent points.

const PANEL_SCENE : String = "res://scenes/ui/wave_panel/wave_panel.tscn"


func test_early_start_is_noticeable(kit : TestKit) -> void:
	await kit.load_level(2)
	var panel : WavePanel = (load(PANEL_SCENE) as PackedScene).instantiate()
	kit.root.add_child(panel)
	await kit.frames(2)
	kit.level.wave_runner.start_next_wave()
	GameSignals.wave_state_changed.emit(1, 5, true, 0.0)
	await kit.frames(2)
	kit.check(not panel.is_early_open and panel.start_wave_button.self_modulate == Color.WHITE, "no glow while the early start is shut")
	kit.check(panel.early_count_label.visible and panel.early_count_label.text == WavePanel.EARLY_COUNT_TEXT % [0, 4],
		"the counter shows the early starts so far: %s" % panel.early_count_label.text)
	GameSignals.wave_state_changed.emit(1, 5, true, 6.0)
	await kit.frames(20)
	kit.check(panel.is_early_open and panel.start_wave_button.text == WavePanel.EARLY_START_TEXT % 6, "the button offers the bonus: %s" % panel.start_wave_button.text)
	kit.check(panel.glow_tween != null and panel.glow_tween.is_running(), "it glows")
	kit.check(panel.early_notice.modulate.a > 0.5 and panel.early_notice_label.text.contains("+6 gold"), "the notice slides in: %s" % panel.early_notice_label.text)
	var children : int = panel.get_child_count()
	panel._on_start_wave_pressed()
	await kit.frames(1)
	kit.check(panel.get_child_count() == children + 1, "the bonus floats up from the button")
	GameSignals.wave_state_changed.emit(2, 5, false, 0.0)
	await kit.frames(2)
	kit.check(not panel.is_early_open and panel.glow_tween == null and panel.start_wave_button.self_modulate == Color.WHITE, "the glow stops when it shuts")
	kit.check(not panel.start_wave_button.has_theme_color_override(&"font_color"), "the button's text is plain again")
	panel.queue_free()
	await kit.frames(2)
