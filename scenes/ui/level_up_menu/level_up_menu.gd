class_name LevelUpMenu
extends Control

## Shows the cards of one level-up; the UI opens and closes it, LevelUpgrades applies the pick.

const TITLE_TEXT : String = "Level %d: choose an upgrade for all towers"
const CARD_MIN_SIZE : Vector2 = Vector2(96, 112)
const CARD_ICON_SIZE : Vector2 = Vector2(32, 32)
const CARD_MARGIN : int = 6

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
	UISignals.upgrade_card_selected.emit(index)


func _on_mouse_entered() -> void:
	UISignals.mouse_on_gui.emit(true)


func _on_mouse_exited() -> void:
	UISignals.mouse_on_gui.emit(false)


#the menu frees while hovered, so release the builder's GUI block
func _exit_tree() -> void:
	UISignals.mouse_on_gui.emit(false)
