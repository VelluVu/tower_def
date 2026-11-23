@tool
class_name TalentTree
extends Resource

## A talent tree: its nodes, their links and the tree's colours. Node positions are set by hand in
## the editor's Talents screen (addons/talent_layout).

@export var id : StringName = &""
@export var display_name : String = ""
@export var start_id : StringName = &""
## The element this tree belongs to (None for the Building tree). The element tree with the most ranks learned is the
## one towers lean to before they pick an element (LevelTalents.get_leaning_element).
@export var element : Utils.Element = Utils.Element.None
@export var nodes : Array[TalentNode] = []
## The tree's theme, after its element. The background stays dark so the learned path stands out.
@export var background : Color = Color("0c1814")
## Links between learned nodes.
@export var link_lit : Color = Color("c9f2dc")
## The tree's title colour in the info window.
@export var accent : Color = Color("f2c14e")

var _nodes_by_id : Dictionary[StringName, TalentNode] = {}


func get_node_by_id(node_id : StringName) -> TalentNode:
	#rebuilt when the list changed size: the editor's Talents screen adds and removes nodes on a live tree
	if _nodes_by_id.size() != nodes.size():
		_nodes_by_id.clear()
		for node in nodes:
			_nodes_by_id[node.id] = node

	return _nodes_by_id.get(node_id, null)
