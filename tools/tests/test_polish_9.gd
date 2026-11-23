extends RefCounted

## Polish round 9 (2026-11-22, "do a big upgrade"): talent node icons, bevels, rank pips and the tree emblem.

const BOOK : TalentBook = preload("res://scenes/talents/talent_book.tres")


func test_every_working_node_has_an_icon(kit : TestKit) -> void:
	var missing : PackedStringArray = []
	var with_effects : int = 0
	for tree in BOOK.trees:
		for node in tree.nodes:
			if node.effects.is_empty():
				continue
			with_effects += 1
			if TalentNodeIcons.for_node(node) == null:
				missing.append("%s/%s" % [tree.id, node.id])
	kit.check(with_effects > 0 and missing.is_empty(), "every node with an effect has an icon (%d nodes; missing: %s)" % [with_effects, ", ".join(missing)])


func test_icon_choice(kit : TestKit) -> void:
	var damage : TalentEffect = TalentEffect.new()
	damage.stat_type = Utils.StatType.Damage
	var gold : TalentEffect = TalentEffect.new()
	gold.kind = TalentEffect.Kind.WaveGold
	var tier : TalentEffect = TalentEffect.new()
	tier.kind = TalentEffect.Kind.UnlockTier
	kit.check(TalentNodeIcons.for_effect(damage) == TalentNodeIcons.DAMAGE, "damage: the sword")
	kit.check(TalentNodeIcons.for_effect(gold) == TalentNodeIcons.GOLD, "wave gold: the coin")
	kit.check(TalentNodeIcons.for_effect(tier) == TalentNodeIcons.TIER, "a tier unlock: the chevron")
	kit.check(TalentNodeIcons.for_node(TalentNode.new()) == null, "a node without effects: no icon")


func test_tree_view_draws_at_every_zoom(kit : TestKit) -> void:
	var view : TalentTreeView = TalentTreeView.new()
	view.size = Vector2(440, 300)
	kit.root.add_child(view)
	for tree in BOOK.trees:
		view.show_tree(tree)
		view.refresh({tree.start_id: 1}, 3)
		for zoom in TalentTreeView.UNIT_SIZES.size():
			view.zoom_index = zoom
			view.queue_redraw()
			await kit.frames(1)
	kit.check(true, "drew all four trees at %d zooms without an error" % TalentTreeView.UNIT_SIZES.size())
	view.queue_free()


#(the user, 2026-11-23): a drag far away lost the tree out of the view
func test_tree_cannot_be_dragged_out_of_view(kit : TestKit) -> void:
	var view : TalentTreeView = TalentTreeView.new()
	view.size = Vector2(440, 300)
	kit.root.add_child(view)
	view.show_tree(BOOK.trees[0])
	var view_rect : Rect2 = Rect2(Vector2.ZERO, view.size)
	for zoom in TalentTreeView.UNIT_SIZES.size():
		view.zoom_index = zoom
		for far in [Vector2(-100000, 0), Vector2(100000, 0), Vector2(0, -100000), Vector2(0, 100000), Vector2(-90000, 90000)]:
			view.origin = view._clamp_origin(view.origin + far)
			var bounds : Rect2 = view._get_bounds()
			var unit : float = TalentTreeView.UNIT_SIZES[zoom]
			var on_screen : Rect2 = Rect2(view.origin + bounds.position * unit, bounds.size * unit)
			var overlap : Rect2 = on_screen.intersection(view_rect)
			kit.check(overlap.size.x >= TalentTreeView.KEEP_IN_VIEW - 1.0 and overlap.size.y >= TalentTreeView.KEEP_IN_VIEW - 1.0,
					"zoom %d, drag %s: the tree stays in view (%s)" % [zoom, far, overlap.size])
	#zooming in at a corner cannot throw it out either
	view.fit_tree()
	view._zoom(2, Vector2.ZERO)
	var unit_after : float = TalentTreeView.UNIT_SIZES[view.zoom_index]
	var shown : Rect2 = Rect2(view.origin + view._get_bounds().position * unit_after, view._get_bounds().size * unit_after)
	kit.check(shown.intersects(view_rect), "a corner zoom keeps it in view")
	view.queue_free()
