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

@onready var title_label : Label = %TitleLabel
@onready var card_container : HBoxContainer = %CardContainer


func show_cards(new_level : int, cards : Array[UpgradeCard]) -> void:
	for child in card_container.get_children():
		child.queue_free()

	title_label.text = TITLE_TEXT % new_level

	for index in cards.size():
		card_container.add_child(_create_card_button(cards[index], index))


#Button can't stack its icon above wrapped text, so the card lays out its own icon and label
func _create_card_button(card : UpgradeCard, index : int) -> Button:
	var button : Button = Button.new()
	button.custom_minimum_size = CARD_MIN_SIZE
	button.pressed.connect(_on_card_pressed.bind(index))

	var margin : MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, CARD_MARGIN)
	button.add_child(margin)

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
