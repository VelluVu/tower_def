extends RefCounted

## Boss lairs (2026-11-24): the Brood Cavern's castle sits under its rock until the boss spawns, then the rock
## crumbles away and the camouflage frees itself.

const BROOD_LAIR_LEVEL : int = 8
const CAMOUFLAGE_NODE : String = "CastleCamouflage"
const REVEAL_SECONDS : float = 3.0


func test_brood_castle_reveals_on_boss(kit : TestKit) -> void:
	await kit.load_level(BROOD_LAIR_LEVEL)
	var camouflage : CastleCamouflage = kit.level.get_node_or_null(CAMOUFLAGE_NODE) as CastleCamouflage
	kit.check(camouflage != null, "the brood lair has a castle camouflage")
	if camouflage == null:
		return
	kit.check(camouflage.animation == GlobalAnimationNames.IDLE_ANIMATION, "the camouflage idles before the boss")
	var weakling : Enemy = kit.spawn_enemy("weakling")
	await kit.frames(2)
	kit.check(not camouflage.is_revealing, "a common enemy leaves the castle hidden")
	weakling.die()
	var boss : Enemy = kit.spawn_enemy("broodmother")
	await kit.frames(2)
	kit.check(camouflage.is_revealing and camouflage.animation == GlobalAnimationNames.REVEAL_ANIMATION, "the boss makes the castle shed its rock")
	#by id: a lambda that captured the node itself would hold a freed object once it is gone
	var camouflage_id : int = camouflage.get_instance_id()
	await kit.run_until(func() -> bool: return not is_instance_id_valid(camouflage_id), REVEAL_SECONDS)
	kit.check(not is_instance_id_valid(camouflage_id), "the camouflage frees itself after the reveal")
	boss.die()
	await kit.frames(2)
