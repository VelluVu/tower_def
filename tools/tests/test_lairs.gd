extends RefCounted

## Boss lairs (2026-11-24): the Brood Cavern's castle sits under its rock until the boss spawns, then the rock
## crumbles away and the camouflage frees itself.

const BROOD_LAIR_LEVEL : int = 12
const CAMOUFLAGE_NODE : String = "CastleCamouflage"
const REVEAL_SECONDS : float = 3.0
const MIRE_LAIR_LEVEL : int = 24
const SPAWN_ART_NODE : String = "Art"
const LIGHTING_NODE : String = "LairLighting"


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


## Hydra's Mire (2026-11-24): the overgrown castle tears free and the Hydra's pool boils when she comes, and the lair
## sets its own teal fog.
func test_mire_reveals_and_boils_on_boss(kit : TestKit) -> void:
	await kit.load_level(MIRE_LAIR_LEVEL)
	var camouflage : CastleCamouflage = kit.level.get_node_or_null(CAMOUFLAGE_NODE) as CastleCamouflage
	kit.check(camouflage != null, "the mire has a castle camouflage")
	var pool_art : BossSpawnArt = null
	for spawner in kit.level.get_spawners():
		var art : BossSpawnArt = spawner.get_node_or_null(SPAWN_ART_NODE) as BossSpawnArt
		if art != null:
			pool_art = art
	kit.check(pool_art != null, "one of the mire's spawns is the Hydra's pool")
	var fog : LevelEdgeFog = kit.level.get_node_or_null(Level.EDGE_FOG_NAME) as LevelEdgeFog
	var lighting : LairLighting = kit.level.get_node_or_null(LIGHTING_NODE) as LairLighting
	if fog != null and lighting != null:
		var fog_color : Color = (fog.material as ShaderMaterial).get_shader_parameter(LairLighting.FOG_COLOR_PARAMETER)
		kit.check(fog_color.is_equal_approx(lighting.fog_color), "the mire's fog takes the lair's colour")
	if camouflage == null or pool_art == null:
		return
	var boss : Enemy = kit.spawn_enemy("bog_hydra")
	await kit.frames(2)
	kit.check(camouflage.is_revealing, "the Hydra tears the vines off the castle")
	kit.check(pool_art.animation == GlobalAnimationNames.BOIL_ANIMATION, "the Hydra's pool boils when she comes")
	boss.die()
	await kit.frames(2)
