class_name AttackClosestBuilding
extends ActionLeaf


func tick(actor : Node, _blackboard : Blackboard) -> int:
	actor._attack()
	return SUCCESS
