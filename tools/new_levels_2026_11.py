"""Writes the LevelData and wave files of the levels added on 2026-11-16 (twelve levels per area): the cave level 10,
the swamp levels 16-23 and the field levels 29-35. Their maps come from swamp_levels.py and field_levels.py.
Change a table here and rerun it; it rewrites those levels' data and wave files (not their maps).

    python tools/new_levels_2026_11.py [level numbers...]

A wave is a list of groups: (count, enemy, interval, spawner id, delay, elites, affix). Spawner ids follow the map
generator: swamp_levels.py numbers its spawn squares in S, D, W, K order (hollow, den, roost, cave) among the ones
the level has; field_levels.py numbers its edge spawners top to bottom. Affixes: Elite.Affix names.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAVE = "res://scenes/level/level_data/waves/level_%03d_wave_%d.tres"
DATA = "res://scenes/level/level_data/level_%03d_data.tres"
AFFIX = {"Random": 0, "Shielded": 1, "Hasted": 2, "Regenerating": 3, "Splitting": 4, "Enraged": 5}
EARLY_BONUS = [0, 1, 2, 2, 3, 3, 3, 3]
# Puffe line triggers (PuffeLine.Trigger)
AFTER_PREVIOUS, WAVE_STARTED, WAVE_CLEARED = 1, 3, 4


def g(count, enemy, interval, spawner=0, delay=0.0, elites=0, affix="Random"):
    return (count, enemy, interval, spawner, delay, elites, affix)


LEVELS = {
    8: dict(name="Crystal Deep", gold=26, health=(1.8, 2.9),
             story="The crystal pond glows blue in a hollow on the way north. The cave folk here dig under walls, and some have grown crystal shells.",
             lines=[(None, 0, "Crystals everywhere. Pretty, but the folk wearing them are hard to crack."),
                    (WAVE_STARTED, 2, "Burrowers! They dig under the maze and come up further on. Keep towers along the whole road."),
                    (WAVE_STARTED, 3, "Crystal brutes. Plain hits glance off; fire, frost and poison bite better.")],
             waves=[[g(12, "weakling", 2.6, 1), g(6, "fastling", 2.0, 1, 6)],
                    [g(6, "burrower", 2.4, 1), g(12, "weakling", 2.2, 1, 4), g(3, "beefling", 4.0, 0)],
                    [g(4, "crystal_brute", 4.0, 0), g(16, "fastling", 1.3, 1), g(8, "burrower", 2.0, 1, 6)],
                    [g(4, "destroyerling", 4.0, 1), g(8, "beefling", 3.0, 0), g(18, "weakling", 1.6, 1, 4)],
                    [g(4, "crystal_brute", 3.8, 0), g(10, "burrower", 1.6, 1), g(3, "destroyerling", 4.0, 1, 6), g(10, "swarmling", 0.3, 1, 10)],
                    [g(5, "crystal_brute", 3.4, 0), g(4, "destroyerling", 3.6, 1), g(12, "burrower", 1.4, 1, 4), g(20, "fastling", 1.0, 1, 6), g(10, "beefling", 2.6, 0, 8)]]),
    16: dict(name="Leech Fen", gold=26, health=(1.3, 3.6),
             story="Deep channels cut the fen. The road goes round them, but the toads and leeches know the old stepping stones.",
             lines=[(None, 0, "Stepping stones over the channels. Only the toads and leeches dare them."),
                    (WAVE_STARTED, 1, "Watch the stones: the waders take the short way. Towers by the far shore!")],
             waves=[[g(10, "swampling", 2.8), g(10, "leechling", 0.4, 0, 8)],
                    [g(12, "swampling", 2.2), g(6, "fastswampling", 1.8, 0, 4), g(10, "leechling", 0.4, 0, 10)],
                    [g(3, "swbeefling", 4.0), g(14, "swampling", 1.8, 0, 4), g(12, "leechling", 0.4, 0, 8)],
                    [g(16, "fastswampling", 1.2), g(3, "plaguepig", 4.0, 0, 6), g(12, "leechling", 0.3, 0, 8)],
                    [g(5, "swbeefling", 3.4), g(18, "swampling", 1.4, 0, 4), g(6, "giant_wasp", 2.0), g(12, "leechling", 0.3, 0, 10)],
                    [g(6, "swbeefling", 3.0), g(4, "plaguepig", 3.6, 0, 6), g(20, "swampling", 1.2, 0, 4), g(20, "fastswampling", 1.0, 0, 6), g(14, "leechling", 0.3, 0, 12)]]),
    17: dict(name="Frog Pools", gold=26, health=(1.3, 3.6),
             story="A fen of deep pools between the tree walls. The frogs here jump further than a drakeling can fly.",
             lines=[(None, 0, "Frogs. Big ones. They hop over half the road."),
                    (WAVE_STARTED, 2, "Wasps from the roost in the north! Towers along their flight.")],
             waves=[[g(8, "swampling", 3.0), g(5, "leaper_frog", 2.6, 0, 6)],
                    [g(10, "leaper_frog", 2.0), g(8, "swampling", 2.2, 0, 4), g(4, "giant_wasp", 2.4, 1)],
                    [g(12, "leaper_frog", 1.8), g(3, "swbeefling", 4.0, 0, 4), g(6, "giant_wasp", 2.0, 1, 6)],
                    [g(14, "fastswampling", 1.2), g(10, "leaper_frog", 1.6, 0, 4), g(12, "leechling", 0.3, 0, 8)],
                    [g(5, "swbeefling", 3.2), g(14, "leaper_frog", 1.4, 0, 4), g(8, "giant_wasp", 1.6, 1)],
                    [g(6, "swbeefling", 3.0), g(4, "plaguepig", 3.6, 0, 6), g(16, "leaper_frog", 1.2, 0, 4), g(10, "giant_wasp", 1.4, 1), g(14, "leechling", 0.3, 0, 10)]]),
    18: dict(name="Rotting Causeway", gold=27, health=(1.3, 3.7),
             story="A lake fills the hollow and one causeway crosses it. Wall it and the swamp breaks through; the bloaters burst on the stones.",
             lines=[(None, 0, "One causeway over the lake. Every one of them has to walk it."),
                    (WAVE_STARTED, 1, "Bloaters! Kill them away from the walls, or they burst all over our work.")],
             waves=[[g(8, "swampling", 3.0), g(2, "bloater", 4.0, 1, 6)],
                    [g(6, "bloater", 3.0, 1), g(12, "fastswampling", 1.6)],
                    [g(4, "swbeefling", 3.6, 1), g(14, "swampling", 1.6), g(12, "leechling", 0.3, 0, 8)],
                    [g(8, "bloater", 2.6, 1), g(12, "leaper_frog", 1.6), g(3, "plaguepig", 4.0, 1, 8)],
                    [g(6, "swbeefling", 3.0, 1), g(8, "bloater", 2.4, 1, 6), g(18, "swampling", 1.3), g(14, "leechling", 0.3, 0, 10)],
                    [g(10, "bloater", 2.2, 1), g(6, "plaguepig", 3.2, 1, 8), g(20, "fastswampling", 1.0), g(14, "leaper_frog", 1.2, 0, 6)]]),
    19: dict(name="Wasp Hollow", gold=27, health=(1.3, 3.7),
             story="A wasp roost hangs over a winding fen road. Some of the swamp folk here are bigger and stranger than the rest.",
             lines=[(None, 0, "The roost hums. Wasps, many wasps."),
                    (WAVE_STARTED, 3, "That brute is glowing. An elite! Tougher, and it has a trick of its own."),
                    (WAVE_CLEARED, 6, "The roost is quiet. Only the Drowning Deep and the Hydra's mire are left.")],
             waves=[[g(8, "swampling", 3.0), g(4, "giant_wasp", 2.8, 1)],
                    [g(10, "giant_wasp", 2.0, 1), g(12, "leechling", 0.3), g(5, "fastswampling", 2.2, 0, 4)],
                    [g(4, "swbeefling", 4.0, 0, 0, 1, "Regenerating"), g(12, "giant_wasp", 1.8, 1), g(12, "swampling", 1.8, 0, 6)],
                    [g(14, "leaper_frog", 1.4, 0, 0, 2, "Hasted"), g(12, "giant_wasp", 1.6, 1), g(4, "bloater", 3.0, 0, 6)],
                    [g(6, "swbeefling", 3.0, 0, 0, 2), g(14, "giant_wasp", 1.4, 1), g(18, "swampling", 1.3, 0, 6)],
                    [g(8, "swbeefling", 2.6, 0, 0, 2), g(4, "plaguepig", 3.6, 0, 6), g(16, "giant_wasp", 1.2, 1, 0, 2), g(16, "fastswampling", 1.0, 0, 6), g(14, "leechling", 0.3, 0, 10)]]),
    20: dict(name="Sunken Village", gold=28, health=(1.4, 3.8),
             story="A human village the swamp swallowed long ago. A canal splits it; the old stepping stones still cross it.",
             lines=[(None, 0, "Humans built here once. The swamp took it back."),
                    (WAVE_STARTED, 4, "Splitting elites: kill one and two smaller ones crawl out.")],
             waves=[[g(8, "swampling", 3.0), g(2, "swbeefling", 4.0, 1)],
                    [g(14, "swampling", 2.0), g(12, "leechling", 0.3, 0, 8), g(4, "bloater", 3.4, 1)],
                    [g(12, "fastswampling", 1.4), g(5, "swbeefling", 3.4, 1, 0, 1), g(12, "leaper_frog", 1.6, 0, 6)],
                    [g(18, "swampling", 1.4, 0, 0, 2, "Splitting"), g(6, "bloater", 2.6, 1), g(14, "leechling", 0.3, 0, 10)],
                    [g(4, "plaguepig", 3.6, 1), g(6, "swbeefling", 3.0, 1, 6), g(16, "leaper_frog", 1.2), g(8, "giant_wasp", 1.6)],
                    [g(8, "swbeefling", 2.6, 1, 0, 2), g(6, "plaguepig", 3.0, 1, 8), g(22, "swampling", 1.1, 0, 0, 3), g(16, "leechling", 0.3, 0, 12), g(10, "giant_wasp", 1.4)]]),
    21: dict(name="Plague Marsh", gold=28, health=(1.4, 3.8),
             story="Dry mud flats where the plague boars root. Poison does almost nothing here; frost and fire do.",
             lines=[(None, 0, "It smells like a sick boar's breakfast. Poison will not help here."),
                    (WAVE_STARTED, 3, "Shielded elites. Their shell eats part of every hit; focus them.")],
             waves=[[g(8, "swampling", 3.0), g(1, "plaguepig", 5.0, 1)],
                    [g(4, "plaguepig", 3.6, 1), g(6, "bloater", 3.0, 1, 6), g(12, "fastswampling", 1.6)],
                    [g(5, "plaguepig", 3.2, 1, 0, 1, "Shielded"), g(14, "swampling", 1.6), g(12, "leechling", 0.3, 0, 8)],
                    [g(8, "bloater", 2.4, 1), g(4, "swbeefling", 3.4, 1, 6), g(16, "leaper_frog", 1.3)],
                    [g(6, "plaguepig", 3.0, 1, 0, 2, "Shielded"), g(8, "bloater", 2.2, 1, 6), g(18, "fastswampling", 1.0), g(8, "giant_wasp", 1.6)],
                    [g(8, "plaguepig", 2.6, 1, 0, 2), g(10, "bloater", 2.0, 1, 6), g(6, "swbeefling", 3.0, 1, 10), g(22, "swampling", 1.0, 0, 0, 2), g(16, "leechling", 0.3, 0, 12)]]),
    22: dict(name="Mirewood", gold=29, health=(1.4, 3.9),
             story="A drowned wood: the longest road in the swamp, seven turns between the trees. The waders cut it short.",
             lines=[(None, 0, "Seven turns of road. Lovely. Two of them have stepping stones."),
                    (WAVE_CLEARED, 6, "Through the wood. The Drowning Deep is next.")],
             waves=[[g(8, "swampling", 3.0), g(8, "leechling", 0.4, 0, 8)],
                    [g(14, "leaper_frog", 1.8), g(10, "fastswampling", 1.6, 0, 6)],
                    [g(5, "swbeefling", 3.4, 0, 0, 1), g(16, "swampling", 1.6, 0, 4), g(14, "leechling", 0.3, 0, 10)],
                    [g(6, "bloater", 2.6), g(4, "plaguepig", 3.6, 0, 6), g(16, "leaper_frog", 1.3, 0, 4)],
                    [g(8, "swbeefling", 2.8, 0, 0, 2), g(20, "swampling", 1.2, 0, 4, 2), g(10, "giant_wasp", 1.6), g(14, "leechling", 0.3, 0, 12)],
                    [g(8, "plaguepig", 2.6, 0, 0, 2), g(8, "bloater", 2.2, 0, 6), g(22, "fastswampling", 0.9, 0, 4), g(18, "leaper_frog", 1.1, 0, 8, 2), g(16, "leechling", 0.3, 0, 14)]]),
    23: dict(name="The Drowning Deep", gold=29, health=(1.4, 3.9),
             story="The last mire before the Hydra's home. Two long canals, and every creature of the swamp on the move.",
             lines=[(None, 0, "Everything in the swamp is coming. The Hydra must be close."),
                    (WAVE_CLEARED, 6, "The deep is ours. Now, the Hydra.")],
             waves=[[g(6, "swampling", 3.4), g(4, "leechling", 0.5, 0, 10)],
                    [g(10, "leechling", 0.4), g(8, "leaper_frog", 2.2, 0, 4), g(3, "bloater", 3.8, 1), g(5, "giant_wasp", 2.4, 2)],
                    [g(5, "swbeefling", 3.2, 1, 0, 1), g(4, "plaguepig", 3.6, 1, 8), g(16, "fastswampling", 1.2), g(8, "giant_wasp", 1.8, 2)],
                    [g(8, "bloater", 2.4, 1), g(18, "swampling", 1.3, 0, 0, 2), g(10, "giant_wasp", 1.6, 2, 0, 1), g(14, "leechling", 0.3, 0, 10)],
                    [g(6, "plaguepig", 3.0, 1, 0, 2), g(8, "swbeefling", 2.8, 1, 6), g(18, "leaper_frog", 1.1), g(12, "giant_wasp", 1.4, 2), g(16, "leechling", 0.3, 0, 12)],
                    [g(8, "swbeefling", 2.6, 1, 0, 3), g(6, "plaguepig", 3.0, 1, 8), g(10, "bloater", 2.0, 1, 14), g(24, "swampling", 1.0, 0, 0, 3), g(20, "fastswampling", 0.9, 0, 8), g(14, "giant_wasp", 1.2, 2, 0, 2)]]),
    29: dict(name="Sapper's Trench", gold=28, health=(1.7, 4.6),
             story="The humans dig trenches across the fields and send sappers ahead with charges for our towers and walls.",
             lines=[(None, 0, "Trenches. The humans are digging in."),
                    (WAVE_STARTED, 2, "Sappers! They blow up whatever stands next to the road, walls too. Shoot them first.")],
             waves=[[g(12, "soldier", 2.6), g(6, "scout", 2.0, 1)],
                    [g(4, "sapper", 3.4), g(12, "soldier", 2.2, 1), g(10, "assault_dog", 0.3, 0, 6)],
                    [g(6, "sapper", 3.0, 1), g(6, "archer", 2.6), g(14, "soldier", 1.8, 0, 4)],
                    [g(3, "armored_knight", 4.0), g(8, "sapper", 2.4, 1), g(12, "scout", 1.2, 0, 4)],
                    [g(4, "cavalry", 3.4, 1), g(8, "sapper", 2.2), g(18, "soldier", 1.4, 1, 4), g(12, "assault_dog", 0.3, 0, 10)],
                    [g(5, "armored_knight", 3.2), g(10, "sapper", 2.0, 1), g(6, "cavalry", 3.0, 0, 6), g(20, "soldier", 1.2, 1, 4), g(8, "archer", 2.0, 0, 10)],
                    [g(6, "armored_knight", 3.0, 1), g(12, "sapper", 1.8), g(8, "cavalry", 2.6, 1, 6), g(22, "soldier", 1.1, 0, 4), g(12, "assault_dog", 0.3, 1, 12)]]),
    30: dict(name="Old Mill Hill", gold=29, health=(1.5, 4.5),
             story="A mill race runs over the hill with two fords. The humans send their champions now: bigger, tougher, each with a trick.",
             lines=[(None, 0, "Two fords over the mill race. They will use both."),
                    (WAVE_STARTED, 3, "A human champion, an elite. Shielded, hasted, healing: watch its colour.")],
             waves=[[g(12, "soldier", 2.6), g(8, "scout", 1.8, 1)],
                    [g(2, "wizard", 4.0), g(14, "soldier", 2.0, 1), g(3, "sapper", 3.6, 0, 6)],
                    [g(3, "armored_knight", 4.0, 1, 0, 1, "Shielded"), g(8, "archer", 2.4), g(12, "scout", 1.4, 1, 4)],
                    [g(5, "cavalry", 3.2, 0, 0, 1, "Hasted"), g(3, "priest", 5.0, 1), g(16, "soldier", 1.6, 1, 4)],
                    [g(4, "armored_knight", 3.4, 1, 0, 1), g(5, "wizard", 3.0), g(7, "sapper", 2.4, 0, 6), g(12, "assault_dog", 0.3, 1, 10)],
                    [g(6, "cavalry", 2.8, 0, 0, 1), g(3, "priest", 4.8, 1), g(20, "soldier", 1.1, 1, 0, 2), g(10, "archer", 1.8, 0, 6)],
                    [g(4, "armored_knight", 3.4, 1, 0, 1), g(3, "priest", 4.4, 1, 4), g(6, "cavalry", 3.0, 0, 0, 1), g(5, "wizard", 2.6, 0, 6), g(18, "soldier", 1.1, 1, 6)]]),
    31: dict(name="Orchard Wall", gold=29, health=(1.5, 4.5),
             story="An apple orchard behind dry-stone walls. The road weaves between the rows, and eagles nest in the old trees.",
             lines=[(None, 0, "Apples! Later. First the humans."),
                    (WAVE_STARTED, 3, "Eagles over the orchard. They do not care about the walls.")],
             waves=[[g(14, "soldier", 2.4), g(10, "assault_dog", 0.3, 1, 4)],
                    [g(8, "archer", 2.4, 1), g(12, "scout", 1.4), g(4, "sapper", 3.2, 1, 6)],
                    [g(6, "giant_eagle", 2.2), g(4, "armored_knight", 3.8, 1), g(14, "soldier", 1.6, 0, 4)],
                    [g(6, "cavalry", 3.0, 1, 0, 1), g(8, "sapper", 2.2), g(3, "priest", 5.0, 1, 6)],
                    [g(8, "giant_eagle", 1.8), g(6, "armored_knight", 3.0, 1, 0, 2, "Regenerating"), g(18, "scout", 1.0, 0, 4)],
                    [g(8, "cavalry", 2.4, 1), g(6, "wizard", 2.6), g(4, "priest", 4.5, 0, 4), g(22, "soldier", 1.1, 1, 0, 2), g(12, "assault_dog", 0.3, 0, 10)],
                    [g(8, "armored_knight", 2.8, 0, 0, 2), g(10, "giant_eagle", 1.6, 1, 0, 2), g(10, "sapper", 1.8, 1, 6), g(24, "soldier", 1.0, 0, 6)]]),
    32: dict(name="Bridgehead Camp", gold=30, health=(1.5, 4.6),
             story="The humans hold the only bridge over the river. Everything they have crosses it, then winds round two hedgerows.",
             lines=[(None, 0, "One bridge. Everything comes over it. That is where we hold them."),
                    (WAVE_STARTED, 4, "An enraged champion: hurt it and it runs faster. Finish it fast.")],
             waves=[[g(12, "soldier", 2.4), g(8, "scout", 1.8, 1)],
                    [g(6, "sapper", 3.0, 1), g(4, "cavalry", 3.6), g(12, "soldier", 2.0, 0, 6)],
                    [g(3, "armored_knight", 4.0, 1), g(2, "wizard", 3.6), g(12, "soldier", 1.8, 0, 6)],
                    [g(8, "cavalry", 2.6, 0, 0, 1, "Enraged"), g(10, "archer", 2.0, 1), g(12, "assault_dog", 0.3, 0, 8)],
                    [g(3, "armored_knight", 3.6, 1, 0, 1, "Shielded"), g(3, "priest", 4.5, 1), g(8, "sapper", 2.2), g(18, "soldier", 1.2, 0, 4)],
                    [g(7, "cavalry", 2.6, 0, 0, 2), g(5, "wizard", 2.8, 1), g(18, "scout", 1.0, 1, 4), g(8, "archer", 2.0, 0, 8)],
                    [g(5, "armored_knight", 3.2, 1, 0, 2), g(4, "priest", 4.2, 1, 4), g(6, "cavalry", 2.6, 0, 0, 2), g(12, "sapper", 1.8, 0, 6), g(24, "soldier", 1.0, 1, 6)]]),
    33: dict(name="Watchtower Fields", gold=30, health=(1.6, 4.7),
             story="Wide fields under the humans' watchtowers. Archers shoot from the road and giant eagles circle overhead.",
             lines=[(None, 0, "Watchtowers. They can see us coming. Good: let them watch."),
                    (WAVE_STARTED, 2, "Archers and eagles together. Walls do not stop arrows; towers out of their reach do.")],
             waves=[[g(12, "soldier", 2.4, 1), g(6, "archer", 2.6)],
                    [g(6, "giant_eagle", 2.2, 1), g(10, "archer", 2.0, 2), g(10, "assault_dog", 0.3, 0, 6)],
                    [g(8, "giant_eagle", 2.0, 1), g(4, "armored_knight", 3.8), g(3, "priest", 5.0, 0, 4), g(14, "soldier", 1.6, 2)],
                    [g(6, "cavalry", 3.0, 2, 0, 1), g(12, "archer", 1.8), g(8, "giant_eagle", 1.8, 1, 6)],
                    [g(10, "giant_eagle", 1.6, 1, 0, 2, "Hasted"), g(6, "armored_knight", 3.0), g(6, "wizard", 2.6, 2), g(18, "scout", 1.0, 2, 6)],
                    [g(8, "cavalry", 2.4, 0, 0, 2), g(4, "priest", 4.5, 1), g(12, "archer", 1.6, 2), g(22, "soldier", 1.1, 1, 0, 2), g(10, "giant_eagle", 1.4, 1, 8)],
                    [g(8, "armored_knight", 2.8, 0, 0, 2), g(5, "priest", 4.0, 0, 4), g(12, "giant_eagle", 1.3, 1, 0, 2), g(10, "cavalry", 2.2, 2, 0, 2), g(24, "soldier", 1.0, 2, 6)]]),
    34: dict(name="Siege Lines", gold=31, health=(1.6, 4.7),
             story="Three barricade lines across the field: the humans' siege works. The road doubles back on itself, and the sappers lead.",
             lines=[(None, 0, "Barricades. The road goes back and forth three times. Plenty of room for towers."),
                    (WAVE_CLEARED, 7, "Their siege lines are broken. One more road, then their camp.")],
             waves=[[g(14, "soldier", 2.2), g(8, "sapper", 2.8, 1)],
                    [g(10, "sapper", 2.2), g(4, "armored_knight", 3.8, 1), g(12, "assault_dog", 0.3, 1, 6)],
                    [g(6, "archer", 2.4), g(2, "wizard", 3.6, 1), g(12, "soldier", 1.8, 0, 4)],
                    [g(5, "cavalry", 3.0, 1, 0, 1), g(10, "sapper", 2.0), g(4, "armored_knight", 3.4, 1, 6)],
                    [g(5, "armored_knight", 3.2, 0, 0, 1, "Shielded"), g(4, "priest", 4.5), g(12, "sapper", 1.8, 1), g(20, "scout", 1.0, 0, 6)],
                    [g(10, "cavalry", 2.4, 1, 0, 2), g(8, "wizard", 2.4), g(24, "soldier", 1.0, 0, 0, 3), g(12, "assault_dog", 0.3, 1, 8)],
                    [g(9, "armored_knight", 2.6, 0, 0, 3), g(5, "priest", 4.0, 0, 4), g(12, "cavalry", 2.0, 1, 0, 2), g(16, "sapper", 1.4, 1, 6), g(26, "soldier", 1.0, 0, 6)]]),
    35: dict(name="Banner Road", gold=31, health=(1.6, 4.8),
             story="The road to the humans' war camp, a banner on every bend. Every kind of human marches here, their champions with them.",
             lines=[(None, 0, "Banners on every bend. Their camp is at the end of this road."),
                    (WAVE_CLEARED, 7, "The road is ours. Next: the Dragonslayer's camp.")],
             waves=[[g(12, "soldier", 2.4, 1), g(8, "scout", 1.8), g(6, "archer", 2.6, 2)],
                    [g(4, "wizard", 3.2), g(3, "priest", 5.0, 0, 4), g(6, "giant_eagle", 2.2, 1), g(12, "assault_dog", 0.3, 2)],
                    [g(5, "armored_knight", 3.4, 1, 0, 1), g(6, "cavalry", 3.0, 2), g(8, "sapper", 2.4)],
                    [g(10, "giant_eagle", 1.8, 1, 0, 1), g(10, "archer", 1.8), g(4, "priest", 4.5, 2), g(18, "soldier", 1.4, 2, 4)],
                    [g(5, "armored_knight", 3.2, 0, 0, 2), g(6, "cavalry", 2.8, 2, 0, 1), g(5, "wizard", 2.6, 1), g(10, "sapper", 2.0, 1, 6)],
                    [g(7, "cavalry", 2.4, 2, 0, 2), g(4, "priest", 4.2), g(10, "giant_eagle", 1.5, 1, 0, 2), g(20, "soldier", 1.0, 0, 0, 2), g(12, "assault_dog", 0.3, 2, 8)],
                    [g(7, "armored_knight", 2.8, 1, 0, 2), g(5, "priest", 3.8, 1, 4), g(9, "cavalry", 2.2, 2, 0, 2), g(14, "giant_eagle", 1.2, 0, 0, 2), g(8, "wizard", 2.2, 0, 6), g(26, "soldier", 0.9, 2, 6)]]),
}


def res(path):
    return os.path.join(ROOT, path.replace("res://", "").replace("/", os.sep))


def write_wave(level, number, groups, bonus):
    enemies = sorted(set(group[1] for group in groups))
    out = ['[gd_resource type="Resource" script_class="WaveData" format=3]', '',
           '[ext_resource type="Script" uid="uid://cpw7ia3ek2yvs" path="res://scenes/level/level_data/wave_data.gd" id="1_wave"]',
           '[ext_resource type="Script" uid="uid://bbhd3iyjav4h2" path="res://scenes/level/level_data/spawn_group_data.gd" id="2_group"]']
    out += ['[ext_resource type="PackedScene" path="res://scenes/unit/enemy/enemies/%s.tscn" id="e_%s"]' % (e, e) for e in enemies]
    out.append('')
    ids = []
    for i, (count, enemy, interval, spawner, delay, elites, affix) in enumerate(groups, 1):
        ids.append('SubResource("Resource_group%d")' % i)
        out += ['[sub_resource type="Resource" id="Resource_group%d"]' % i, 'script = ExtResource("2_group")',
                'enemy_scene = ExtResource("e_%s")' % enemy, 'count = %d' % count, 'interval = %s' % float(interval)]
        if delay:
            out.append('delay = %s' % float(delay))
        if spawner:
            out.append('spawner_id = %d' % spawner)
        if elites:
            out.append('elites = %d' % elites)
            if AFFIX[affix]:
                out.append('elite_affix = %d' % AFFIX[affix])
        out.append('')
    out += ['[resource]', 'script = ExtResource("1_wave")', 'spawn_groups = Array[ExtResource("2_group")]([%s])' % ', '.join(ids)]
    if bonus:
        out.append('early_start_bonus = %s' % float(bonus))
    with open(res(WAVE % (level, number)), "w", encoding="utf8", newline="\n") as f:
        f.write('\n'.join(out) + '\n')


def write_level(level, spec):
    waves = spec["waves"]
    for n, groups in enumerate(waves, 1):
        write_wave(level, n, groups, EARLY_BONUS[n - 1])
    out = ['[gd_resource type="Resource" script_class="LevelData" format=3]', '',
           '[ext_resource type="Script" uid="uid://cpw7ia3ek2yvs" path="res://scenes/level/level_data/wave_data.gd" id="0_wave"]',
           '[ext_resource type="Script" uid="uid://c0cehaxum4b45" path="res://scenes/level/level_data/level_data.gd" id="1_level"]',
           '[ext_resource type="Script" uid="uid://bu8xwv71c6bbj" path="res://scenes/level/level_data/puffe_line.gd" id="9_line"]']
    out += ['[ext_resource type="Resource" path="%s" id="w%d"]' % (WAVE % (level, n), n) for n in range(1, len(waves) + 1)]
    out.append('')
    for i, (trigger, wave_number, text) in enumerate(spec["lines"], 1):
        out += ['[sub_resource type="Resource" id="PuffeLine_%d"]' % i, 'script = ExtResource("9_line")']
        if trigger is not None:
            out.append('trigger = %d' % trigger)
        if wave_number:
            out.append('wave_number = %d' % wave_number)
        out += ['text = "%s"' % text, '']
    out += ['[resource]', 'script = ExtResource("1_level")', 'level_name = "%s"' % spec["name"],
            'story_text = "%s"' % spec["story"], 'starting_gold = %s' % float(spec["gold"]),
            'waves = Array[ExtResource("0_wave")]([%s])' % ', '.join('ExtResource("w%d")' % n for n in range(1, len(waves) + 1)),
            'puffe_lines = Array[ExtResource("9_line")]([%s])' % ', '.join('SubResource("PuffeLine_%d")' % i for i in range(1, len(spec["lines"]) + 1)),
            'first_wave_health = %s' % spec["health"][0], 'last_wave_health = %s' % spec["health"][1]]
    with open(res(DATA % level), "w", encoding="utf8", newline="\n") as f:
        f.write('\n'.join(out) + '\n')
    print("level %d data: %d waves" % (level, len(waves)))


if __name__ == "__main__":
    for number in [int(a) for a in sys.argv[1:]] or sorted(LEVELS):
        write_level(number, LEVELS[number])
