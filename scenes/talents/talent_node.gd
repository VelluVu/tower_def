class_name TalentNode
extends Resource

## One node of a talent tree. A node opens when a node linked to it has a rank; a one-way link
## only opens its target (an overall capstone opens nothing back).

enum Kind
{
	Stat,
	Side,
	Evolve,
	Capstone,
}

@export var id : StringName = &""
@export var display_name : String = ""
## What one rank does, shown in the info window.
@export_multiline var description : String = ""
@export var kind : Kind = Kind.Stat
@export var max_rank : int = 1
## Position in the tree's shape, in tree units.
@export var position : Vector2 = Vector2.ZERO
@export var color : Color = Color.WHITE
## Two-way links to other nodes of the same tree.
@export var links : Array[StringName] = []
## Nodes this one opens without being opened by them.
@export var one_way_links : Array[StringName] = []
## A node that must have a rank too, such as the tier before an evolve unlock.
@export var needs : StringName = &""
## Empty until the game has the effect; such a node can be learned but does nothing yet.
@export var effects : Array[TalentEffect] = []

var is_implemented : bool :
	get:
		return not effects.is_empty()
