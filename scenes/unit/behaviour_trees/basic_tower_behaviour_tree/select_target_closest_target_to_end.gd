@tool
class_name SelectTarget
extends ActionLeaf

## Picks the tower's target by its targeting tactic (Tower.get_tactic_target; First by default, the
## enemy closest to the castle). The file keeps its old name so the tree scenes keep their reference.


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor.target = actor.get_tactic_target()
	return SUCCESS
