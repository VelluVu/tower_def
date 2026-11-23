extends RefCounted

## The boss intro card (2026-11-23).


func test_a_boss_gets_its_card(kit : TestKit) -> void:
	kit.load_level(8)
	var intro : BossIntro = (load("res://scenes/ui/boss_intro/boss_intro.tscn") as PackedScene).instantiate()
	kit.root.add_child(intro)
	kit.spawn_enemy("weakling")
	kit.check(not intro.card.visible, "an ordinary enemy gets no card")
	var boss : Enemy = kit.spawn_enemy("broodmother")
	kit.check(intro.card.visible, "the Broodmother does")
	kit.check(intro.name_label.text == "Broodmother" and intro.title_label.text == "Queen of the Deep Caves", "with her name and title: %s, %s" % [intro.name_label.text, intro.title_label.text])
	kit.check(intro.card.texture.resource_path.ends_with("boss_card_broodmother.png"), "on her own card")
	kit.check(intro.portrait.sprite_frames != null and intro.portrait.is_playing(), "her own frames walk in the window")
	intro.tween.custom_step(BossIntro.SLIDE_IN_TIME + BossIntro.HOLD_TIME + BossIntro.SLIDE_OUT_TIME + 0.1)
	kit.check(not intro.card.visible, "and the card sweeps away")
	boss.queue_free()
	intro.queue_free()
	kit.free_level()
	await kit.frames(1)
