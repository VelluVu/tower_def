class_name TalentTree
extends Resource

## A talent tree: its nodes and the shape drawn behind them (the tower, the flame, ...).

@export var id : StringName = &""
@export var display_name : String = ""
@export var start_id : StringName = &""
@export var nodes : Array[TalentNode] = []
## Closed outlines of the tree's shape, in tree units.
@export var shapes : Array[PackedVector2Array] = []
## Open lines of the shape, such as a roof.
@export var lines : Array[PackedVector2Array] = []
## The tree's theme, after its element. The shape stays dark so the learned path stands out.
@export var background : Color = Color("0c1814")
@export var shape_fill : Color = Color("102019")
@export var shape_edge : Color = Color("3d4c46")
## Links between learned nodes.
@export var link_lit : Color = Color("c9f2dc")
## The tree's title colour in the info window.
@export var accent : Color = Color("f2c14e")

var _nodes_by_id : Dictionary[StringName, TalentNode] = {}


func get_node_by_id(node_id : StringName) -> TalentNode:
	if _nodes_by_id.is_empty():
		for node in nodes:
			_nodes_by_id[node.id] = node

	return _nodes_by_id.get(node_id, null)
