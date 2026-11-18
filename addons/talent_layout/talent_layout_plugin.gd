@tool
extends EditorPlugin

## The editor's Talents screen: pick a tree, drag its nodes. Every drop is an undoable action and
## saves the tree's .tres, so the game shows the new layout at once.

const SCREEN_NAME : String = "Talents"
const SCREEN_ICON : StringName = &"GraphEdit"
const TALENT_BOOK_PATH : String = "res://scenes/talents/talent_book.tres"
const MOVE_ACTION_NAME : String = "Move talent node"
const SAVE_ERROR : String = "Talent Layout: could not save %s (error %d)"

var _screen : VBoxContainer = null
var _tree_picker : OptionButton = null
var _view : TalentTreeView = null
var _trees : Array[TalentTree] = []


func _enter_tree() -> void:
	_screen = VBoxContainer.new()
	_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen.visible = false

	var bar : HBoxContainer = HBoxContainer.new()
	_tree_picker = OptionButton.new()
	_tree_picker.item_selected.connect(_on_tree_picked)
	bar.add_child(_tree_picker)
	var fit_button : Button = Button.new()
	fit_button.text = "Fit"
	fit_button.pressed.connect(func() -> void: _view.fit_tree())
	bar.add_child(fit_button)
	_screen.add_child(bar)

	_view = TalentTreeView.new()
	_view.edit_mode = true
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.node_moved.connect(_on_node_moved)
	_screen.add_child(_view)

	EditorInterface.get_editor_main_screen().add_child(_screen)
	_load_trees()


func _exit_tree() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible : bool) -> void:
	if _screen == null:
		return

	_screen.visible = visible
	if visible:
		_load_trees()


func _get_plugin_name() -> String:
	return SCREEN_NAME


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(SCREEN_ICON, &"EditorIcons")


#reloads the book each time the screen opens, so a tree added since shows up
func _load_trees() -> void:
	var book : TalentBook = load(TALENT_BOOK_PATH)
	var picked : int = maxi(_tree_picker.selected, 0)

	_trees = book.trees.duplicate() if book != null else []
	_tree_picker.clear()
	for tree in _trees:
		_tree_picker.add_item(tree.display_name if not tree.display_name.is_empty() else String(tree.id))

	if _trees.is_empty():
		return

	picked = mini(picked, _trees.size() - 1)
	_tree_picker.select(picked)
	if _view.tree != _trees[picked]:
		_view.show_tree(_trees[picked])


func _on_tree_picked(index : int) -> void:
	_view.show_tree(_trees[index])


func _on_node_moved(node : TalentNode, from_position : Vector2) -> void:
	var tree : TalentTree = _view.tree
	var undo_redo : EditorUndoRedoManager = get_undo_redo()

	undo_redo.create_action(MOVE_ACTION_NAME)
	undo_redo.add_do_property(node, &"position", node.position)
	undo_redo.add_do_method(self, &"_save_tree", tree)
	undo_redo.add_undo_property(node, &"position", from_position)
	undo_redo.add_undo_method(self, &"_save_tree", tree)
	undo_redo.commit_action()


func _save_tree(tree : TalentTree) -> void:
	var error : Error = ResourceSaver.save(tree, tree.resource_path)

	if error != OK:
		push_error(SAVE_ERROR % [tree.resource_path, error])

	_view.queue_redraw()
