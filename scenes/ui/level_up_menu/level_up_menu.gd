class_name LevelUpMenu
extends Control

## Shows the cards of one level-up; the UI opens and closes it, LevelUpgrades applies the pick.

const TITLE_TEXT : String = "Level %d: choose an upgrade for all towers"
const CARD_MIN_SIZE : Vector2 = Vector2(96, 112)
const CARD_ICON_SIZE : Vector2 = Vector2(32, 32)
const CARD_MARGIN : int = 6
const RARE_TEXT : String = "Rare"
const TREE_TEXT : String = "%s tree"
const FONT_COLOR : StringName = &"font_color"
#coin gold (Endesga 32), the theme's accent colour
const RARE_COLOR : Color = Color("feae34")
## Card frames (tools/art/card_frames.py): rows common and rare, columns normal, hover, pressed.
const FRAMES : Texture2D = preload("res://assets/art/ui/cards/card_frames.png")
const FRAME_CELL : int = 24
## The frame's corner size in the sheet; the rest stretches.
const FRAME_MARGIN : float = 7.0
const FRAME_STATES : Array[StringName] = [&"normal", &"hover", &"pressed"]
const EMPTY_STYLES : Array[StringName] = [&"focus"]
## The card's content rises this many pixels while the mouse is on it.
const HOVER_LIFT : float = 2.0

@onready var title_label : Label = %TitleLabel
@onready var card_container : HBoxContainer = %CardContainer


func show_cards(new_level : int, cards : Array[UpgradeCard]) -> void:
	for child in card_container.get_children():
		child.queue_free()

	title_label.text = TITLE_TEXT % new_level

	for index in cards.size():
		card_container.add_child(_create_card_button(cards[index], index))


## The card's frame for its rarity, one sheet cell per button state.
static func apply_frame(button : Button, is_rare : bool) -> void:
	for state in FRAME_STATES.size():
		var style : StyleBoxTexture = StyleBoxTexture.new()
		style.texture = FRAMES
		style.region_rect = Rect2(state * FRAME_CELL, (1 if is_rare else 0) * FRAME_CELL, FRAME_CELL, FRAME_CELL)
		style.set_texture_margin_all(FRAME_MARGIN)
		button.add_theme_stylebox_override(FRAME_STATES[state], style)
	for style_name in EMPTY_STYLES:
		button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())


## Lifts the card's content (the frame lights up by itself) and ticks on the way in.
func _on_card_hovered(content : Control, is_on : bool) -> void:
	content.offset_top = -HOVER_LIFT if is_on else 0.0
	content.offset_bottom = -HOVER_LIFT if is_on else 0.0
	if is_on:
		UISignals.upgrade_card_hovered.emit()


#Button can't stack its icon above wrapped text, so the card lays out its own icon and label
func _create_card_button(card : UpgradeCard, index : int) -> Button:
	var button : Button = Button.new()
	button.custom_minimum_size = CARD_MIN_SIZE
	apply_frame(button, card.resource.rarity == EvolveResource.Rarity.Rare)
	button.pressed.connect(_on_card_pressed.bind(index))

	var margin : MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, CARD_MARGIN)
	button.add_child(margin)
	button.mouse_entered.connect(_on_card_hovered.bind(margin, true))
	button.mouse_exited.connect(_on_card_hovered.bind(margin, false))

	var column : VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	if card.resource.rarity == EvolveResource.Rarity.Rare:
		var rare_label : Label = Label.new()
		rare_label.text = RARE_TEXT
		rare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rare_label.add_theme_color_override(FONT_COLOR, RARE_COLOR)
		rare_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(rare_label)

	#an element card names its talent tree, in the tree's accent colour
	var tree : TalentTree = LevelTalents.get_talent_tree(card.resource.talent_tree) if card.resource.talent_ranks > 0 else null
	if tree != null:
		var tree_label : Label = Label.new()
		tree_label.text = TREE_TEXT % tree.display_name
		tree_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tree_label.add_theme_color_override(FONT_COLOR, tree.accent)
		tree_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(tree_label)

	var icon_rect : TextureRect = TextureRect.new()
	icon_rect.texture = card.icon
	icon_rect.custom_minimum_size = CARD_ICON_SIZE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon_rect)

	var label : Label = Label.new()
	label.text = card.get_text()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)

	return button


func _on_card_pressed(index : int) -> void:
	#a second click before the old cards free would pick blind from the next level-up's offer
	for button in card_container.get_children():
		(button as Button).disabled = true
	UISignals.upgrade_card_selected.emit(index)


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)


#the menu frees while hovered, so release the builder's GUI block
func _exit_tree() -> void:
	UISignals.mouse_on_gui.emit(false)
