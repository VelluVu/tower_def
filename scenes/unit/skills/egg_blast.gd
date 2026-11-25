class_name EggBlast
extends Skill

## The Egg Bomb's skill (2026-11-25): its cast is the fuse (START_ATTACK plays over it), its activation the blast
## (EggBomb.detonate), its cooldown the rebuild. Attack speed shortens both, as with every skill.


#the fuse is lit: the egg goes off even when the enemy that lit it is gone
func _on_cast_finished() -> void:
	activate()


func activate() -> void:
	super()
	if actor is EggBomb:
		(actor as EggBomb).detonate()
