@tool
class_name UseAbilities
extends ActionLeaf

## Runs the actor's EnemyAbilities: holds it still while one is active or starting.
## Fails for enemies without abilities, so the tree walks on.


func tick(actor : Node, _blackboard : Blackboard) -> int:
	if actor.abilities == null or not actor.abilities.tick():
		return FAILURE

	actor.linear_velocity = Vector2.ZERO
	return RUNNING
