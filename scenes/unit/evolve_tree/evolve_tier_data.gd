class_name EvolveTierData
extends Resource

## One evolve tier after the element (T2, T3) of an ElementEvolveLeaf, bought in the selection panel
## once its talent node is learned. Gives its stat steps and swaps the tower's sprite frames.

## Shown on the button and as its tooltip.
@export var title : String = ""
@export_multiline var info : String = ""
@export var icon : Texture2D = null
## The talent node that unlocks it (TalentTree.id and TalentNode.id); empty = always open.
@export var talent_tree : StringName = &""
@export var talent_node : StringName = &""
## Applied once each, with modify_value as is (no roll), like the gold upgrades.
@export var upgrade_resources : Array[EvolveResource] = []
## The tier's sprite; null keeps the current one.
@export var sprite_frames : SpriteFrames = null


func is_unlocked() -> bool:
	if talent_node == &"":
		return true
	return PlayerProgress.get_talent_ranks(talent_tree).get(talent_node, 0) > 0
