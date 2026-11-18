class_name EnemyAbilities
extends Node

## Holds an enemy's EnemyAbility children. The UseAbilities leaf asks it every tick: keep the
## enemy still while one is active, or start the first ready one (child order is priority).

@onready var enemy : Enemy = get_parent()

var abilities : Array[EnemyAbility] = []

var active_ability : EnemyAbility :
	get:
		for ability in abilities:
			if ability.is_active:
				return ability
		return null


func _ready() -> void:
	for child in get_children():
		if child is EnemyAbility:
			child.setup(enemy)
			abilities.append(child)


## true while an ability holds the enemy (an active one, or one that just started)
func tick() -> bool:
	#gone (died, hatched, leaked): hold it still, so no walk or idle animation replaces the one it ends on
	if enemy.is_deactivated:
		interrupt()
		return true
	#dead but not gone yet: let go, so the tree reaches AmIDead. Its selector resumes a running UseAbilities
	#without checking AmIDead first, and an ability cut off by the death never finishes
	if enemy.is_dead:
		interrupt()
		return false

	if active_ability != null:
		return true

	for ability in abilities:
		if ability.is_ready:
			ability.use()
			return true

	return false


func interrupt() -> void:
	for ability in abilities:
		ability.interrupt()
