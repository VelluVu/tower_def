class_name TalentMenu
extends Control

## The talent screen: a tab per tree, the tree view, and the info window of the selected node.
## Ranks are progress, so the menu changes them through PlayerProgress, which saves them.

const TALENT_BOOK : TalentBook = preload("res://scenes/talents/talent_book.tres")
const CLOSE_ACTION : String = "Escape"
const POINTS_TEXT : String = "Points %d / %d"
const RANK_TEXT : String = "Rank %d / %d"
const INFO_TINT : float = 0.35
const TITLE_COLOR_NAME : StringName = &"font_color"
const RESET_TEXT : String = "Reset"
const RESET_CONFIRM_TEXT : String = "Sure?"
const KIND_TEXTS : Dictionary[TalentNode.Kind, String] = {
	TalentNode.Kind.Stat: "Talent",
	TalentNode.Kind.Side: "Side talent",
	TalentNode.Kind.Evolve: "Evolve unlock",
	TalentNode.Kind.Capstone: "Capstone",
}
const NOT_BUILT_TEXT : String = "Not in the game yet: learning it does nothing for now."
const NEEDS_TEXT : String = "Needs %s first."
const CLOSED_TEXT : String = "Learn a linked talent first."
const NO_POINTS_TEXT : String = "No points left. Clear levels to earn more."
const HELD_TEXT : String = "Other talents depend on this one."
#reaction, shared points / unlock points, both trees' points
const REACTION_TEXT : String = "%s %d/%d (%s %d, %s %d)"

@onready var tabs : HBoxContainer = %Tabs
@onready var points_label : Label = %PointsLabel
@onready var reset_button : Button = %ResetButton
@onready var back_button : Button = %BackButton
@onready var tree_view : TalentTreeView = %TreeView
@onready var name_label : Label = %NameLabel
@onready var kind_label : Label = %KindLabel
@onready var rank_label : Label = %RankLabel
@onready var description_label : Label = %DescriptionLabel
@onready var status_label : Label = %StatusLabel
@onready var reactions_label : Label = %ReactionsLabel
@onready var add_button : Button = %AddButton
@onready var info_panel : PanelContainer = %Info
@onready var remove_button : Button = %RemoveButton

var tree : TalentTree = null
var selected : TalentNode = null
var _is_reset_armed : bool = false


func _ready() -> void:
	var group : ButtonGroup = ButtonGroup.new()

	for book_tree in TALENT_BOOK.trees:
		var tab : Button = Button.new()
		tab.text = book_tree.display_name
		tab.toggle_mode = true
		tab.button_group = group
		tab.pressed.connect(_show_tree.bind(book_tree))
		tabs.add_child(tab)

	tree_view.node_selected.connect(_on_node_selected)
	add_button.pressed.connect(_on_add_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_close)
	PlayerProgress.talents_changed.connect(_refresh)

	if not TALENT_BOOK.trees.is_empty():
		(tabs.get_child(0) as Button).button_pressed = true
		_show_tree(TALENT_BOOK.trees[0])


func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed(CLOSE_ACTION):
		get_viewport().set_input_as_handled()
		_close()


func _show_tree(new_tree : TalentTree) -> void:
	tree = new_tree
	tree_view.show_tree(tree)
	_apply_theme()
	selected = tree.get_node_by_id(tree.start_id)
	_disarm_reset()
	_refresh()


## The info window takes the tree's element colours: a tinted frame and an accent title.
func _apply_theme() -> void:
	info_panel.self_modulate = Color.WHITE.lerp(tree.accent, INFO_TINT)
	name_label.add_theme_color_override(TITLE_COLOR_NAME, tree.accent)


func _refresh() -> void:
	if tree == null:
		return

	points_label.text = POINTS_TEXT % [PlayerProgress.get_talent_points_unspent(), PlayerProgress.get_talent_points_earned()]
	tree_view.refresh(PlayerProgress.get_talent_ranks(tree.id), PlayerProgress.get_talent_points_unspent())
	_show_reactions()
	_show_info()


## The reactions of this tree's element with their shared points (the lower tree counts).
func _show_reactions() -> void:
	var lines : PackedStringArray = []

	for reaction in ElementReactions.REACTIONS:
		if reaction.first_tree != tree.id and reaction.second_tree != tree.id:
			continue

		var first : TalentTree = TALENT_BOOK.get_tree_by_id(reaction.first_tree)
		var second : TalentTree = TALENT_BOOK.get_tree_by_id(reaction.second_tree)
		var first_spent : int = TalentRules.get_spent(PlayerProgress.get_talent_ranks(reaction.first_tree))
		var second_spent : int = TalentRules.get_spent(PlayerProgress.get_talent_ranks(reaction.second_tree))
		lines.append(REACTION_TEXT % [reaction.display_name, ElementReaction.shared_points_of(first_spent, second_spent), reaction.unlock_points, first.display_name, first_spent, second.display_name, second_spent])

	reactions_label.text = "\n".join(lines)
	reactions_label.visible = not lines.is_empty()


func _show_info() -> void:
	if selected == null:
		return

	var ranks : Dictionary = PlayerProgress.get_talent_ranks(tree.id)
	var rank : int = TalentRules.get_rank(ranks, selected.id)
	var can_add : bool = TalentRules.can_add(tree, ranks, selected, PlayerProgress.get_talent_points_unspent())
	var can_remove : bool = TalentRules.can_remove(tree, ranks, selected)

	name_label.text = selected.display_name
	kind_label.text = KIND_TEXTS[selected.kind]
	rank_label.text = RANK_TEXT % [rank, selected.max_rank]
	description_label.text = selected.description
	add_button.disabled = not can_add
	remove_button.disabled = not can_remove

	var status : PackedStringArray = []
	if not selected.is_implemented:
		status.append(NOT_BUILT_TEXT)
	if rank < selected.max_rank and not can_add:
		status.append(_get_closed_reason(ranks))
	elif rank == 1 and not can_remove:
		status.append(HELD_TEXT)
	status_label.text = "\n".join(status)


func _get_closed_reason(ranks : Dictionary) -> String:
	if selected.needs != &"" and TalentRules.get_rank(ranks, selected.needs) == 0:
		var needed : TalentNode = tree.get_node_by_id(selected.needs)
		return NEEDS_TEXT % (needed.display_name if needed != null else String(selected.needs))

	if not TalentRules.is_open(tree, ranks, selected):
		return CLOSED_TEXT

	return NO_POINTS_TEXT


func _on_node_selected(node : TalentNode) -> void:
	selected = node
	_show_info()


func _on_add_pressed() -> void:
	var ranks : Dictionary = PlayerProgress.get_talent_ranks(tree.id)

	if TalentRules.can_add(tree, ranks, selected, PlayerProgress.get_talent_points_unspent()):
		PlayerProgress.set_talent_rank(tree.id, selected.id, TalentRules.get_rank(ranks, selected.id) + 1)


func _on_remove_pressed() -> void:
	var ranks : Dictionary = PlayerProgress.get_talent_ranks(tree.id)

	if TalentRules.can_remove(tree, ranks, selected):
		PlayerProgress.set_talent_rank(tree.id, selected.id, TalentRules.get_rank(ranks, selected.id) - 1)


#the first press arms the reset, the second resets the tree
func _on_reset_pressed() -> void:
	if not _is_reset_armed:
		_is_reset_armed = true
		reset_button.text = RESET_CONFIRM_TEXT
		return

	_disarm_reset()
	PlayerProgress.reset_talent_tree(tree.id)


func _disarm_reset() -> void:
	_is_reset_armed = false
	reset_button.text = RESET_TEXT


func _close() -> void:
	UISignals.talents.emit(false)
