"""Writes the LevelData and wave files of the Scorched Lands, levels 37-60 (the ash desert 37-48, the volcano 49-60).
Their maps come from scorched_levels.py. Change a table here and rerun it; it rewrites those levels' data and wave
files (not their maps). The table format is new_levels_2026_11.py's: a wave is a list of groups
g(count, enemy, interval, spawner id, delay, elites, affix); spawner ids top to bottom as scorched_levels.py
numbers them.

    python tools/scorched_data.py [level numbers...]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from new_levels_2026_11 import g, write_level, AFTER_PREVIOUS, WAVE_STARTED, WAVE_CLEARED

LEVELS = {
    37: dict(name="Ashfall Road", gold=31, health=(1.7, 9.8),
             story="Past the Dragonslayer's camp the green ends. Ash falls like snow on an old road into the desert, and the humans' rearguard still holds it.",
             lines=[(None, 0, "Sand. Ash. More sand. I cannot sleep on sand, it gets everywhere."),
                    (WAVE_STARTED, 3, "Those are not humans. Those are bones. Walking bones."),
                    (WAVE_CLEARED, 6, "The Dragonslayer swore his oath to someone out here. I mean to find out who.")],
             waves=[[g(14, "soldier", 2.2), g(8, "scout", 1.6, 1)],
                    [g(12, "soldier", 1.8, 1), g(6, "archer", 2.4)],
                    [g(14, "bone_thrall", 1.8), g(6, "soldier", 2.2, 1)],
                    [g(12, "bone_thrall", 1.6, 1), g(4, "armored_knight", 3.6), g(10, "assault_dog", 0.3, 1, 6)],
                    [g(16, "bone_thrall", 1.4), g(8, "ash_runner", 1.4, 1), g(4, "priest", 4.0, 0, 6)],
                    [g(20, "bone_thrall", 1.2, 0, 0, 2), g(12, "ash_runner", 1.2, 1), g(5, "armored_knight", 3.2, 1, 6)]]),
    38: dict(name="Bleached Dunes", gold=31, health=(1.7, 10.0),
             story="White salt flats between the dunes, where nothing grows. Scarabs swarm under the salt, and the wind brings storms.",
             lines=[(None, 0, "Salt flats. They slow the walkers down. Good for us."),
                    (WAVE_STARTED, 2, "Scarabs! Lots of little ones. The Nova loves a crowd."),
                    (WAVE_STARTED, 4, "A sandstorm. My towers cannot see far in it. Spread them out.")],
             waves=[[g(12, "bone_thrall", 2.2), g(10, "scarab", 0.3, 1, 4)],
                    [g(12, "scarab", 0.3), g(12, "scarab", 0.3, 2, 6), g(10, "bone_thrall", 1.8, 1)],
                    [g(10, "ash_runner", 1.4, 1), g(14, "bone_thrall", 1.6, 2), g(12, "scarab", 0.3, 0, 8)],
                    [g(16, "bone_thrall", 1.4), g(12, "ash_runner", 1.2, 1), g(14, "scarab", 0.3, 2, 6)],
                    [g(18, "bone_thrall", 1.2, 0, 0, 1), g(14, "scarab", 0.3, 1), g(14, "scarab", 0.3, 2, 8), g(10, "ash_runner", 1.2, 1, 6)],
                    [g(20, "bone_thrall", 1.0, 1, 0, 2), g(16, "ash_runner", 1.0, 2), g(16, "scarab", 0.3, 0, 4), g(16, "scarab", 0.3, 2, 10)]]),
    39: dict(name="Rusted Siege Lines", gold=32, health=(1.7, 10.2),
             story="The siege works of the old war still stand: barricades of rock and wreckage across the sand. The dead soldiers man them again.",
             lines=[(None, 0, "Siege lines from the old war. Older than me. Older than my grandmother."),
                    (WAVE_STARTED, 2, "Revenant knights. Their old plate still turns a blade. Burn them."),
                    (WAVE_STARTED, 4, "A ballista! It shoots straight through a whole row of towers. Do not line them up.")],
             waves=[[g(14, "bone_thrall", 2.0), g(8, "ash_runner", 1.6, 1)],
                    [g(4, "revenant_knight", 3.6), g(14, "bone_thrall", 1.6, 1, 4)],
                    [g(14, "scarab", 0.3), g(5, "revenant_knight", 3.2, 1), g(12, "ash_runner", 1.2, 0, 6)],
                    [g(2, "rusted_ballista", 6.0), g(16, "bone_thrall", 1.4, 1), g(4, "revenant_knight", 3.4, 0, 6)],
                    [g(6, "revenant_knight", 3.0, 0, 0, 1), g(3, "rusted_ballista", 5.0, 1), g(16, "scarab", 0.3, 1, 6), g(14, "ash_runner", 1.0, 0, 8)],
                    [g(8, "revenant_knight", 2.6, 1, 0, 2), g(3, "rusted_ballista", 4.4), g(22, "bone_thrall", 1.0, 0, 0, 2), g(16, "scarab", 0.3, 1, 8)]]),
    40: dict(name="Drakebone Graveyard", gold=32, health=(1.7, 10.4),
             story="Here the dragons of the old war fell, and their bones lie in rows in the sand. Something has woken them.",
             lines=[(None, 0, "Dragon bones. Hundreds of them. We do not talk about this place."),
                    (WAVE_STARTED, 2, "Ash drakes. They were dragons once. Rest now, cousins. Towers along their flight!"),
                    (WAVE_CLEARED, 6, "Whoever raised them knows dragons well. Too well.")],
             waves=[[g(14, "bone_thrall", 2.0), g(10, "scarab", 0.3, 1, 4)],
                    [g(5, "ash_drake", 2.4, 1), g(12, "bone_thrall", 1.6)],
                    [g(4, "revenant_knight", 3.4), g(6, "ash_drake", 2.0, 1, 4), g(12, "ash_runner", 1.2, 0, 6)],
                    [g(8, "ash_drake", 1.8), g(16, "bone_thrall", 1.4, 1), g(14, "scarab", 0.3, 0, 8)],
                    [g(6, "revenant_knight", 3.0, 1, 0, 1), g(10, "ash_drake", 1.6, 0, 0, 1), g(2, "rusted_ballista", 5.0, 1, 6)],
                    [g(12, "ash_drake", 1.4, 1, 0, 2), g(8, "revenant_knight", 2.6, 0, 0, 2), g(22, "bone_thrall", 1.0, 1), g(16, "scarab", 0.3, 0, 8)]]),
    41: dict(name="The Last Oasis", gold=33, health=(1.7, 10.6),
             story="The only water for days. The road splits around it, and the grave callers wait in the reeds to raise whoever falls.",
             lines=[(None, 0, "Water! I could nap by water. No. Focus, Puffe."),
                    (WAVE_STARTED, 2, "Grave callers. Kill them first, or every fallen bone gets up again."),
                    (WAVE_STARTED, 5, "Their champions march with them now. Elite bones. Shinier bones.")],
             waves=[[g(14, "bone_thrall", 2.0), g(12, "scarab", 0.3, 1, 4)],
                    [g(3, "grave_caller", 4.0), g(16, "bone_thrall", 1.6, 1)],
                    [g(4, "grave_caller", 3.6, 1), g(5, "revenant_knight", 3.2), g(6, "ash_drake", 2.0, 1, 6)],
                    [g(14, "ash_runner", 1.2), g(3, "rusted_ballista", 5.0, 1), g(16, "scarab", 0.3, 0, 6), g(3, "grave_caller", 4.0, 1, 8)],
                    [g(7, "revenant_knight", 2.8, 0, 0, 2), g(5, "grave_caller", 3.4, 1, 0, 1), g(10, "ash_drake", 1.6, 1, 0, 1), g(20, "bone_thrall", 1.0, 0, 6)],
                    [g(9, "revenant_knight", 2.4, 1, 0, 3), g(4, "grave_caller", 3.6, 0, 0, 2), g(12, "ash_drake", 1.4, 0, 0, 2), g(18, "scarab", 0.3, 1, 6), g(24, "bone_thrall", 0.9, 1, 8)]]),
    # the desert's second half (2026-11-18): six more levels before the Fallen Elder
    42: dict(name="Scarab Warrens", gold=33, health=(1.7, 10.6),
             story="A hollow dug out under the dunes, where the scarabs breed by the thousand. Small, tight, and loud with clicking.",
             lines=[(None, 0, "A small hollow. Small is good. Small means I can see every corner."),
                    (WAVE_STARTED, 2, "That clicking is coming from everywhere. Novas, Puffe. Lots of Novas."),
                    (WAVE_STARTED, 4, "Grave callers down here too. They raise the bones the scarabs leave.")],
             waves=[[g(12, "bone_thrall", 2.0), g(12, "scarab", 0.3, 1, 4)],
                    [g(14, "scarab", 0.3), g(14, "scarab", 0.3, 1, 6), g(10, "bone_thrall", 1.6, 1), g(3, "ash_drake", 2.2, 0, 8)],
                    [g(10, "ash_runner", 1.4), g(16, "scarab", 0.3, 1), g(4, "ash_drake", 2.0, 0, 6), g(3, "bone_rider", 3.0, 1, 8)],
                    [g(3, "grave_caller", 3.8, 1), g(18, "scarab", 0.3), g(14, "bone_thrall", 1.4, 1, 6), g(4, "bone_rider", 2.8, 0, 8)],
                    [g(5, "revenant_knight", 3.0, 0, 0, 1), g(20, "scarab", 0.3, 1, 0, 1), g(18, "scarab", 0.3, 0, 8), g(5, "bone_rider", 2.6, 1, 6)],
                    [g(7, "revenant_knight", 2.6, 1, 0, 2), g(24, "scarab", 0.3, 0, 0, 2), g(22, "scarab", 0.3, 1, 8), g(4, "grave_caller", 3.4, 0, 6, 1),
                     g(8, "ash_drake", 1.6, 1, 10)]]),
    43: dict(name="Windscour Flats", gold=33, health=(1.7, 10.6),
             story="A long run over open salt flats, where the storms blow worst. Nothing stands in the way but what you build.",
             lines=[(None, 0, "Flat, white and endless. No ridges to hide behind. I will have to build my own."),
                    (WAVE_STARTED, 2, "Here comes the storm. Short sight for the towers inside it. Walls do not mind."),
                    (WAVE_STARTED, 4, "Bone riders on the flats. Fast ones. A long maze gives the towers time.")],
             waves=[[g(14, "bone_thrall", 2.0, 1), g(8, "ash_runner", 1.6, 0, 4), g(8, "ash_runner", 1.6, 2, 8)],
                    [g(12, "bone_thrall", 1.6), g(12, "bone_thrall", 1.6, 2, 4), g(4, "ash_drake", 2.2, 1, 6)],
                    [g(4, "revenant_knight", 3.4, 1), g(14, "scarab", 0.3, 0, 4), g(14, "scarab", 0.3, 2, 8), g(4, "bone_rider", 2.8, 1, 10)],
                    [g(6, "bone_rider", 2.4, 0), g(2, "rusted_ballista", 5.0, 1), g(16, "bone_thrall", 1.2, 2, 4), g(6, "ash_drake", 1.8, 1, 8)],
                    [g(6, "revenant_knight", 3.0, 2, 0, 1), g(8, "bone_rider", 2.0, 0, 0, 1), g(3, "grave_caller", 3.6, 1, 6), g(18, "scarab", 0.3, 1, 10)],
                    [g(8, "revenant_knight", 2.6, 1, 0, 2), g(10, "bone_rider", 1.8, 0, 0, 2), g(10, "bone_rider", 1.8, 2, 6, 2),
                     g(3, "rusted_ballista", 4.4, 1, 4), g(10, "ash_drake", 1.4, 1, 10)]]),
    44: dict(name="The Ossuary Stair", gold=34, health=(1.7, 10.7),
             story="Terraces cut into a cliff of bones lead down to a castle at its foot. The dead come down the stair, step by step.",
             lines=[(None, 0, "A stair of bones down a cliff. Long way down for them. Good."),
                    (WAVE_STARTED, 3, "Ballistas up on the terraces. They shoot down the rows. Do not stack towers in a line."),
                    (WAVE_CLEARED, 6, "The elder lies further on. I can feel it in the sand. Something huge, and sad.")],
             waves=[[g(14, "bone_thrall", 1.8), g(14, "bone_thrall", 1.8, 1, 6)],
                    [g(4, "revenant_knight", 3.4), g(14, "scarab", 0.3, 1, 4), g(4, "ash_drake", 2.0, 0, 8)],
                    [g(2, "rusted_ballista", 5.0, 1), g(16, "bone_thrall", 1.4), g(4, "bone_rider", 2.8, 1, 6), g(3, "grave_caller", 3.8, 0, 8)],
                    [g(6, "revenant_knight", 3.0, 0, 0, 1), g(3, "rusted_ballista", 4.4, 1), g(16, "scarab", 0.3, 0, 6), g(6, "ash_drake", 1.8, 1, 8)],
                    [g(8, "bone_rider", 2.2, 1, 0, 1), g(4, "grave_caller", 3.4, 0, 0, 1), g(20, "bone_thrall", 1.0, 0, 6), g(16, "scarab", 0.3, 1, 10)],
                    [g(9, "revenant_knight", 2.4, 0, 0, 3), g(4, "rusted_ballista", 4.0, 1), g(10, "bone_rider", 1.8, 1, 6, 2), g(12, "ash_drake", 1.4, 0, 8, 2)]]),
    # two castles: the north keep takes spawners 0 (north) and 1 (east), the south keep spawner 2 (south-east)
    45: dict(name="Old War Camp", gold=34, health=(1.7, 10.7),
             story="The dragons' camp from the old war: two keeps behind a wall of rock. The dead remember where it was, and ride for both.",
             lines=[(None, 0, "Two keeps, one camp. Our grandparents camped here. Two castles to hold, one set of lives."),
                    (WAVE_STARTED, 2, "Riders on the south road. The south keep is on its own down there. Give it towers."),
                    (WAVE_STARTED, 5, "Their champions ride for the north keep. Hold the gate!")],
             waves=[[g(12, "bone_thrall", 2.0), g(10, "bone_thrall", 2.0, 2, 4)],
                    [g(10, "ash_runner", 1.4, 1), g(3, "bone_rider", 3.0, 2), g(12, "scarab", 0.3, 0, 6)],
                    [g(4, "revenant_knight", 3.4, 0), g(5, "bone_rider", 2.6, 2), g(14, "bone_thrall", 1.4, 1, 4), g(5, "ash_drake", 2.0, 1, 8)],
                    [g(6, "bone_rider", 2.4, 1, 0, 1), g(3, "grave_caller", 3.6, 2), g(2, "rusted_ballista", 5.0, 0, 6), g(16, "scarab", 0.3, 2, 8)],
                    [g(7, "revenant_knight", 2.8, 2, 0, 2), g(8, "bone_rider", 2.0, 0, 0, 1), g(18, "bone_thrall", 1.0, 1, 6), g(8, "ash_drake", 1.6, 2, 10)],
                    [g(10, "bone_rider", 1.8, 1, 0, 3), g(8, "revenant_knight", 2.4, 0, 0, 2), g(8, "bone_rider", 1.8, 2, 4, 2), g(4, "grave_caller", 3.4, 2, 8, 1),
                     g(20, "scarab", 0.3, 0, 10)]]),
    46: dict(name="Mirage Wells", gold=35, health=(1.8, 10.8),
             story="Five wells in a ring, some real, some not, all of them full of reeds. The roads wind between them, and the ash drakes fly straight over.",
             lines=[(None, 0, "Water! Real water? That one is real. That one is not. Do not build on a mirage."),
                    (WAVE_STARTED, 2, "Drakes over the wells. They do not care about roads. Towers near the middle."),
                    (WAVE_STARTED, 5, "Shiny bones again. Champions. Hit them with everything.")],
             waves=[[g(14, "bone_thrall", 1.8), g(12, "scarab", 0.3, 1, 4)],
                    [g(6, "ash_drake", 2.0), g(12, "bone_thrall", 1.6, 1), g(3, "revenant_knight", 3.6, 0, 6)],
                    [g(8, "ash_drake", 1.8, 1), g(4, "bone_rider", 2.8), g(3, "grave_caller", 3.8, 1, 6), g(14, "scarab", 0.3, 0, 8)],
                    [g(6, "revenant_knight", 3.0, 0, 0, 1), g(10, "ash_drake", 1.6, 1, 0, 1), g(2, "rusted_ballista", 5.0, 0, 6), g(16, "ash_runner", 1.0, 1, 8)],
                    [g(8, "bone_rider", 2.0, 1, 0, 2), g(12, "ash_drake", 1.4, 0, 0, 1), g(4, "grave_caller", 3.4, 1, 6, 1), g(20, "bone_thrall", 1.0, 0, 8)],
                    [g(10, "revenant_knight", 2.2, 0, 0, 3), g(14, "ash_drake", 1.2, 1, 0, 2), g(10, "bone_rider", 1.8, 1, 6, 2), g(3, "rusted_ballista", 4.4, 0, 8),
                     g(20, "scarab", 0.3, 1, 10)]]),
    47: dict(name="Gate of Bones", gold=35, health=(1.8, 10.8),
             story="Four walls of bone across the road to the elder's resting place, a gap in each. Everything the desert has comes through them at once.",
             lines=[(None, 0, "Walls of bone, built by the dead. Each one has a gap. Each gap is a door for them, and a trap for us."),
                    (WAVE_STARTED, 3, "Three roads, one gate at a time. Build where they all have to pass."),
                    (WAVE_CLEARED, 6, "Past the last wall. The elder is close now. I wish it were not.")],
             waves=[[g(14, "bone_thrall", 1.8), g(12, "bone_thrall", 1.8, 2, 4), g(8, "ash_runner", 1.4, 1, 8)],
                    [g(4, "revenant_knight", 3.4, 1), g(14, "scarab", 0.3, 0, 4), g(14, "scarab", 0.3, 2, 8), g(5, "ash_drake", 2.0, 1, 10)],
                    [g(5, "bone_rider", 2.6, 0), g(3, "grave_caller", 3.6, 2), g(2, "rusted_ballista", 5.0, 1, 6), g(16, "bone_thrall", 1.2, 1, 8)],
                    [g(6, "revenant_knight", 3.0, 2, 0, 1), g(8, "ash_drake", 1.6, 0, 0, 1), g(6, "bone_rider", 2.2, 1, 6), g(18, "scarab", 0.3, 2, 10)],
                    [g(8, "revenant_knight", 2.6, 0, 0, 2), g(4, "grave_caller", 3.4, 1, 0, 1), g(3, "rusted_ballista", 4.4, 2, 6), g(10, "bone_rider", 1.8, 2, 8, 1),
                     g(20, "bone_thrall", 1.0, 1, 10)],
                    [g(10, "revenant_knight", 2.2, 1, 0, 3), g(12, "bone_rider", 1.6, 0, 0, 2), g(14, "ash_drake", 1.2, 2, 4, 2), g(4, "grave_caller", 3.2, 0, 8, 1),
                     g(4, "rusted_ballista", 4.0, 1, 10), g(24, "scarab", 0.3, 2, 12)]]),
    48: dict(name="The Fallen Elder", gold=34, health=(1.8, 10.8),
             story="At the end of the bone road lies the skeleton of an elder dragon, the greatest of the old war. It has been raised against its will.",
             lines=[(None, 0, "That skeleton. That was an elder. The oldest stories speak of one who stood against a dragon of ash."),
                    (WAVE_STARTED, 7, "The Bone Colossus. Forgive us, elder. We have to put you back to sleep."),
                    (WAVE_CLEARED, 7, "It spoke as it fell: the Ashen Wyrm, exiled for wanting the eggs. It waits in the volcano. So that is who.")],
             waves=[[g(16, "bone_thrall", 1.8), g(10, "ash_runner", 1.4, 0, 6)],
                    [g(5, "revenant_knight", 3.2), g(16, "scarab", 0.3, 0, 4), g(3, "grave_caller", 4.0, 0, 8)],
                    [g(8, "ash_drake", 1.8), g(3, "rusted_ballista", 4.6, 0, 4), g(16, "bone_thrall", 1.4, 0, 6)],
                    [g(7, "revenant_knight", 2.8, 0, 0, 2), g(5, "grave_caller", 3.4, 0, 4), g(16, "ash_runner", 1.0, 0, 6)],
                    [g(12, "ash_drake", 1.4, 0, 0, 2), g(4, "rusted_ballista", 4.0), g(20, "scarab", 0.3, 0, 6), g(22, "bone_thrall", 1.0, 0, 8)],
                    [g(9, "revenant_knight", 2.4, 0, 0, 3), g(6, "grave_caller", 3.0, 0, 4, 2), g(14, "ash_drake", 1.2, 0, 6, 2), g(24, "bone_thrall", 0.9, 0, 8)],
                    [g(1, "bone_colossus", 1.0), g(12, "bone_thrall", 1.6, 0, 6), g(6, "revenant_knight", 3.0, 0, 14)]]),
    49: dict(name="Cinder Gate", gold=33, health=(1.8, 5.4),
             story="The road climbs into the volcano's red lands. A river of lava cuts it with one ford, and the Wyrm's creatures come down to meet us.",
             lines=[(None, 0, "Hot. So hot. I cannot sleep here either. The joke is wearing thin, Puffe."),
                    (AFTER_PREVIOUS, 0, "Lava next to a Frost tower cools into rock. Rock I can build on."),
                    (WAVE_STARTED, 2, "Salamanders swim the lava. Watch the ford and the far bank."),
                    (WAVE_STARTED, 3, "Fire barely hurts them here. Frost does.")],
             waves=[[g(16, "cinder_imp", 2.0), g(8, "cinder_imp", 2.0, 1, 4)],
                    [g(8, "magma_salamander", 1.8, 1), g(14, "cinder_imp", 1.6)],
                    [g(16, "cinder_imp", 1.4, 1), g(10, "magma_salamander", 1.4), g(14, "ember_wisp", 0.3, 1, 8)],
                    [g(18, "cinder_imp", 1.2), g(12, "magma_salamander", 1.2, 1), g(16, "ember_wisp", 0.3, 0, 6)],
                    [g(20, "cinder_imp", 1.0, 0, 0, 2), g(14, "magma_salamander", 1.0, 1, 0, 1), g(16, "ember_wisp", 0.3, 1, 8)],
                    [g(22, "cinder_imp", 0.9, 1, 0, 3), g(16, "magma_salamander", 0.9, 0, 0, 2), g(18, "ember_wisp", 0.3, 0, 6), g(6, "ash_drake", 1.6, 1, 10)]]),
    50: dict(name="Obsidian Pass", gold=33, health=(1.8, 5.5),
             story="Three narrow lanes of black glass climb the mountain. The castle at the top of the pass guards the way to the crater.",
             lines=[(None, 0, "Black glass everywhere. Sharp. Do not sit down."),
                    (WAVE_STARTED, 2, "Obsidian golems. Fire, poison and plain hits all glance off. Frost cracks them."),
                    (WAVE_CLEARED, 2, "When a golem breaks, two blobs of magma crawl on. Keep hitting.")],
             waves=[[g(16, "cinder_imp", 1.8), g(14, "ember_wisp", 0.3, 0, 6)],
                    [g(3, "obsidian_golem", 4.0), g(14, "cinder_imp", 1.6, 0, 4)],
                    [g(4, "obsidian_golem", 3.6), g(12, "magma_salamander", 1.2, 0, 4), g(16, "ember_wisp", 0.3, 0, 10)],
                    [g(5, "obsidian_golem", 3.2, 0, 0, 1), g(20, "cinder_imp", 1.2, 0, 6), g(6, "ash_drake", 1.8)],
                    [g(6, "obsidian_golem", 3.0, 0, 0, 2), g(16, "magma_salamander", 1.0, 0, 4), g(18, "ember_wisp", 0.3, 0, 10)],
                    [g(8, "obsidian_golem", 2.6, 0, 0, 3), g(24, "cinder_imp", 0.9, 0, 4, 2), g(10, "ash_drake", 1.4, 0, 8), g(18, "ember_wisp", 0.3, 0, 14)]]),
    51: dict(name="Ember Monastery", gold=34, health=(1.8, 5.6),
             story="The Wyrm's human cultists keep a monastery on the slopes, its braziers burning day and night. They chose the dragon of ash over their own kind.",
             lines=[(None, 0, "Humans. Here? They are wearing robes with flames on them. Oh no."),
                    (WAVE_STARTED, 2, "Cultists. Their fire ward soaks up a hit for anyone near them. Hit fast, hit often."),
                    (WAVE_STARTED, 4, "Lava spitters. Where their shots land, nothing can be built for a while.")],
             waves=[[g(18, "cinder_imp", 1.6), g(8, "magma_salamander", 1.6, 1, 4)],
                    [g(4, "ember_cultist", 3.6, 1), g(16, "cinder_imp", 1.4), g(14, "ember_wisp", 0.3, 2, 6)],
                    [g(4, "obsidian_golem", 3.4, 1), g(5, "ember_cultist", 3.2, 0), g(12, "magma_salamander", 1.2, 2, 6)],
                    [g(3, "lava_spitter", 4.6, 1), g(20, "cinder_imp", 1.2), g(16, "ember_wisp", 0.3, 2, 6), g(4, "ember_cultist", 3.4, 0, 8)],
                    [g(6, "obsidian_golem", 3.0, 1, 0, 2), g(6, "ember_cultist", 3.0, 0, 0, 1), g(4, "lava_spitter", 4.0, 2), g(16, "magma_salamander", 1.0, 0, 6)],
                    [g(8, "obsidian_golem", 2.6, 1, 0, 3), g(8, "ember_cultist", 2.6, 0, 0, 2), g(4, "lava_spitter", 3.6, 2), g(24, "cinder_imp", 0.9, 2, 4), g(18, "ember_wisp", 0.3, 0, 10)]]),
    52: dict(name="Lava Falls", gold=34, health=(1.9, 5.7),
             story="Lava pours down the cliffs in two burning rivers. The ground here is cracked, and the cracks glow before the mountain spits.",
             lines=[(None, 0, "Cracks in the ground. Glowing cracks. I do not like glowing cracks."),
                    (WAVE_CLEARED, 1, "When the cracks glow, lava comes next wave. Do not build on them, or cool it with Frost."),
                    (WAVE_STARTED, 4, "Phoenixes! They rise from their ashes unless Frost puts them out.")],
             waves=[[g(18, "cinder_imp", 1.6), g(10, "magma_salamander", 1.6, 1, 4)],
                    [g(4, "obsidian_golem", 3.4), g(16, "ember_wisp", 0.3, 1, 4), g(14, "cinder_imp", 1.4, 1, 8)],
                    [g(5, "ember_cultist", 3.2, 1), g(3, "lava_spitter", 4.4), g(14, "magma_salamander", 1.2, 1, 6)],
                    [g(5, "phoenix", 2.4, 1), g(6, "obsidian_golem", 3.0), g(18, "ember_wisp", 0.3, 1, 8)],
                    [g(7, "phoenix", 2.0, 0, 0, 1), g(7, "obsidian_golem", 2.8, 1, 0, 2), g(5, "ember_cultist", 3.0, 0, 6), g(4, "lava_spitter", 3.8, 1, 8)],
                    [g(9, "phoenix", 1.8, 1, 0, 2), g(9, "obsidian_golem", 2.4, 0, 0, 3), g(6, "ember_cultist", 2.8, 1, 4), g(26, "cinder_imp", 0.8, 0, 6), g(20, "ember_wisp", 0.3, 1, 10)]]),
    # the convergence level: spawner 0 north (cultists), 1 west (the raised dead), 2 east (fire creatures), 3 south
    # (golems, phoenixes, drakes); weak to Fire from the west, to Frost from the east, so no one element holds it
    53: dict(name="Caldera Rim", gold=35, health=(1.9, 5.8),
             story="The old crater, a ring of lava around an island castle. Everything the Wyrm commands converges on it: its dead from the desert, its fire creatures from the slopes, its cultists from their monastery.",
             lines=[(None, 0, "An island in a ring of fire, and they come from every side. Good thing I am awake."),
                    (WAVE_STARTED, 1, "Bones from the west, fire from the east. One element will not hold every bridge."),
                    (WAVE_STARTED, 2, "The cracks on the west and east roads glow. Cool them, or route around."),
                    (WAVE_STARTED, 3, "Golems and phoenixes up the south road. The Wyrm is sending everything.")],
             waves=[[g(12, "bone_thrall", 1.8, 1), g(12, "cinder_imp", 1.8, 2, 2)],
                    [g(10, "ash_runner", 1.4, 1), g(10, "magma_salamander", 1.4, 2), g(4, "ember_cultist", 3.4, 0, 4)],
                    [g(3, "revenant_knight", 3.6, 1), g(4, "obsidian_golem", 3.4, 3), g(16, "ember_wisp", 0.3, 2, 6), g(14, "scarab", 0.3, 1, 8)],
                    [g(6, "phoenix", 2.0, 3), g(3, "grave_caller", 3.8, 1, 0, 1), g(5, "ember_cultist", 3.0, 0, 2), g(18, "cinder_imp", 1.0, 2, 4, 2)],
                    [g(6, "revenant_knight", 3.0, 1, 0, 2), g(6, "obsidian_golem", 2.8, 3, 0, 2), g(4, "lava_spitter", 3.6, 0), g(16, "magma_salamander", 0.9, 2, 4)],
                    [g(8, "ash_drake", 1.6, 1), g(8, "phoenix", 1.6, 3, 0, 2), g(6, "ember_cultist", 2.6, 0, 0, 2), g(22, "bone_thrall", 0.9, 1, 4, 2), g(20, "ember_wisp", 0.3, 2, 8)],
                    [g(8, "revenant_knight", 2.4, 1, 0, 3), g(10, "obsidian_golem", 2.2, 3, 0, 3), g(6, "lava_spitter", 3.0, 0, 2), g(4, "grave_caller", 3.4, 1, 6, 1),
                     g(28, "cinder_imp", 0.7, 2, 4, 3), g(10, "phoenix", 1.4, 0, 10, 2)]]),
    # the volcano's second half (2026-11-18): six more levels before the Throne of Embers
    54: dict(name="Smoldering Steps", gold=35, health=(1.9, 5.8),
             story="Terraces climb the mountain, lava trickling over their edges. The cracks in the steps glow before they burst.",
             lines=[(None, 0, "Steps up a volcano. Nobody builds steps up a volcano for a good reason."),
                    (WAVE_CLEARED, 2, "The cracks glow. Lava next wave. Keep towers off them, or cool them."),
                    (WAVE_STARTED, 4, "Golems on the stairs. Frost cracks them, and the cold keeps the steps clear.")],
             waves=[[g(16, "cinder_imp", 1.6), g(10, "magma_salamander", 1.6, 1, 4)],
                    [g(4, "obsidian_golem", 3.4, 1), g(14, "cinder_imp", 1.4), g(14, "ember_wisp", 0.3, 1, 6)],
                    [g(5, "ember_cultist", 3.2), g(12, "magma_salamander", 1.2, 1), g(5, "phoenix", 2.2, 0, 8)],
                    [g(6, "obsidian_golem", 3.0, 0, 0, 1), g(3, "lava_spitter", 4.4, 1), g(18, "ember_wisp", 0.3, 0, 6), g(20, "cinder_imp", 1.0, 1, 8)],
                    [g(7, "obsidian_golem", 2.8, 1, 0, 2), g(6, "ember_cultist", 3.0, 0, 0, 1), g(7, "phoenix", 1.8, 1, 6), g(16, "magma_salamander", 0.9, 0, 8)],
                    [g(9, "obsidian_golem", 2.4, 0, 0, 3), g(7, "ember_cultist", 2.6, 1, 0, 2), g(4, "lava_spitter", 3.6, 0, 4), g(9, "phoenix", 1.6, 1, 8, 2),
                     g(24, "cinder_imp", 0.8, 0, 10)]]),
    55: dict(name="Glassfield", gold=35, health=(1.9, 5.8),
             story="A long field of black glass, cut by three rivers of lava with a ford at one end of each. The salamanders do not need fords.",
             lines=[(None, 0, "Three lava rivers. The walkers take the fords; the salamanders take the short way."),
                    (WAVE_STARTED, 2, "Cool a river with Frost and it turns to rock. Rock I can build on, right where they swim."),
                    (WAVE_STARTED, 4, "Golems across the glass. Slow, but they never stop.")],
             waves=[[g(14, "magma_salamander", 1.6), g(14, "cinder_imp", 1.6, 1, 4)],
                    [g(16, "magma_salamander", 1.2, 1), g(4, "obsidian_golem", 3.4), g(14, "ember_wisp", 0.3, 1, 8)],
                    [g(18, "magma_salamander", 1.0), g(5, "ember_cultist", 3.2, 1), g(6, "ash_drake", 1.8, 0, 6)],
                    [g(7, "obsidian_golem", 2.8, 1, 0, 1), g(20, "magma_salamander", 0.9, 0, 0, 1), g(3, "lava_spitter", 4.4, 1, 6), g(18, "ember_wisp", 0.3, 0, 8)],
                    [g(8, "obsidian_golem", 2.6, 0, 0, 2), g(22, "magma_salamander", 0.8, 1, 0, 2), g(7, "phoenix", 1.8, 0, 6), g(6, "ember_cultist", 2.8, 1, 8)],
                    [g(10, "obsidian_golem", 2.2, 1, 0, 3), g(26, "magma_salamander", 0.7, 0, 0, 3), g(10, "ash_drake", 1.4, 1, 6), g(4, "lava_spitter", 3.6, 0, 8),
                     g(20, "ember_wisp", 0.3, 1, 10)]]),
    56: dict(name="The Cinder Forge", gold=36, health=(1.9, 5.9),
             story="The forge where the old war's weapons were made, cold for an age. The cultists have lit it again, and they are making something big.",
             lines=[(None, 0, "The old forge. Lit again. Whatever they are making in there, I do not want to meet it."),
                    (WAVE_STARTED, 2, "The yard cracks in front of the forge. Watch the glow."),
                    (WAVE_STARTED, 4, "Spitters behind the cultists. Kill the cultists first, or the wards soak the hits.")],
             waves=[[g(16, "cinder_imp", 1.6, 1), g(6, "magma_salamander", 1.8, 0, 4), g(6, "magma_salamander", 1.8, 2, 4)],
                    [g(5, "ember_cultist", 3.2, 1), g(14, "ember_wisp", 0.3, 0, 4), g(14, "cinder_imp", 1.4, 2, 6)],
                    [g(4, "obsidian_golem", 3.4, 0), g(4, "obsidian_golem", 3.4, 2, 4), g(6, "ember_cultist", 3.0, 1, 6)],
                    [g(4, "lava_spitter", 4.0, 1), g(6, "ember_cultist", 3.0, 0, 0, 1), g(16, "magma_salamander", 1.0, 2, 4), g(6, "phoenix", 2.0, 1, 8)],
                    [g(8, "obsidian_golem", 2.6, 1, 0, 2), g(7, "ember_cultist", 2.8, 2, 0, 1), g(4, "lava_spitter", 3.8, 0, 6), g(22, "cinder_imp", 0.9, 0, 8)],
                    [g(10, "obsidian_golem", 2.2, 0, 0, 3), g(9, "ember_cultist", 2.4, 1, 0, 2), g(5, "lava_spitter", 3.4, 2, 4), g(8, "phoenix", 1.6, 1, 8, 2),
                     g(20, "ember_wisp", 0.3, 2, 10)]]),
    57: dict(name="Magma Heart", gold=36, health=(1.9, 5.9),
             story="Two lakes of magma under the summit, a strip of rock between them. The walkers go round; the salamanders swim straight through.",
             lines=[(None, 0, "The mountain's heart. It beats. I can hear it through my feet."),
                    (WAVE_STARTED, 2, "Salamanders across the lakes, straight at the castle. Frost on the shore stops that."),
                    (WAVE_STARTED, 5, "Phoenixes over the lakes. Frost puts them out for good.")],
             waves=[[g(14, "cinder_imp", 1.6), g(12, "magma_salamander", 1.6, 1, 4)],
                    [g(14, "magma_salamander", 1.2), g(14, "magma_salamander", 1.2, 1, 6), g(14, "ember_wisp", 0.3, 0, 8)],
                    [g(5, "obsidian_golem", 3.2, 1), g(5, "ember_cultist", 3.2), g(6, "phoenix", 2.0, 1, 8)],
                    [g(7, "obsidian_golem", 2.8, 0, 0, 1), g(18, "magma_salamander", 0.9, 1, 0, 1), g(4, "lava_spitter", 4.0, 0, 6), g(8, "ash_drake", 1.6, 1, 8)],
                    [g(8, "phoenix", 1.8, 0, 0, 1), g(8, "obsidian_golem", 2.6, 1, 0, 2), g(7, "ember_cultist", 2.8, 0, 6), g(20, "magma_salamander", 0.8, 1, 8)],
                    [g(10, "phoenix", 1.6, 1, 0, 2), g(10, "obsidian_golem", 2.2, 0, 0, 3), g(24, "magma_salamander", 0.7, 0, 4, 2), g(5, "lava_spitter", 3.4, 1, 8),
                     g(20, "ember_wisp", 0.3, 0, 10)]]),
    58: dict(name="Phoenix Roost", gold=36, health=(2.0, 5.9),
             story="Cliffs stacked above each other where the phoenixes nest. The road zig-zags down the ledges; the birds take the short way.",
             lines=[(None, 0, "Nests. Big ones. Burning ones. Phoenixes live here."),
                    (WAVE_STARTED, 2, "They rise from their ashes unless Frost finishes them. Keep Frost along their flight."),
                    (WAVE_STARTED, 5, "The whole roost is up. Every bird at once.")],
             waves=[[g(16, "cinder_imp", 1.6), g(14, "ember_wisp", 0.3, 1, 4)],
                    [g(5, "phoenix", 2.2), g(14, "cinder_imp", 1.4, 1), g(6, "ash_drake", 2.0, 1, 6)],
                    [g(6, "phoenix", 2.0, 1), g(5, "obsidian_golem", 3.2), g(14, "magma_salamander", 1.2, 1, 6)],
                    [g(8, "phoenix", 1.8, 0, 0, 1), g(5, "ember_cultist", 3.0, 1), g(8, "ash_drake", 1.6, 0, 6), g(3, "lava_spitter", 4.4, 1, 8)],
                    [g(10, "phoenix", 1.6, 1, 0, 2), g(8, "obsidian_golem", 2.6, 0, 0, 2), g(10, "ash_drake", 1.4, 1, 6), g(22, "cinder_imp", 0.9, 0, 8)],
                    [g(14, "phoenix", 1.2, 0, 0, 3), g(12, "ash_drake", 1.2, 1, 0, 2), g(9, "obsidian_golem", 2.4, 1, 4, 3), g(7, "ember_cultist", 2.6, 0, 8, 2),
                     g(20, "ember_wisp", 0.3, 1, 10)]]),
    59: dict(name="The Black Gate", gold=37, health=(2.0, 6.0),
             story="The Wyrm's own wall of basalt, two gate lines before its throne. Three roads converge on the gaps, and the gaps crack and burn.",
             lines=[(None, 0, "The Black Gate. Beyond it, the throne. Everything it has is behind this wall."),
                    (WAVE_CLEARED, 2, "The gaps crack. When they burst, the road shuts and they look for another. Be there."),
                    (WAVE_CLEARED, 6, "The gate is ours. One more climb.")],
             waves=[[g(16, "cinder_imp", 1.4, 1), g(10, "magma_salamander", 1.4, 0, 4), g(10, "magma_salamander", 1.4, 2, 4)],
                    [g(5, "obsidian_golem", 3.2, 1), g(5, "ember_cultist", 3.2, 0), g(16, "ember_wisp", 0.3, 2, 6), g(6, "phoenix", 2.0, 1, 8)],
                    [g(6, "obsidian_golem", 3.0, 0, 0, 1), g(4, "lava_spitter", 4.0, 1), g(8, "ash_drake", 1.6, 2, 4), g(18, "cinder_imp", 1.0, 1, 8)],
                    [g(8, "phoenix", 1.8, 2, 0, 1), g(7, "ember_cultist", 2.8, 1, 0, 1), g(8, "obsidian_golem", 2.6, 0, 4, 2), g(20, "magma_salamander", 0.8, 2, 8)],
                    [g(10, "obsidian_golem", 2.2, 1, 0, 3), g(5, "lava_spitter", 3.4, 0), g(10, "ash_drake", 1.4, 2, 4, 2), g(8, "ember_cultist", 2.6, 2, 8, 2),
                     g(24, "cinder_imp", 0.8, 0, 10)],
                    [g(12, "obsidian_golem", 2.0, 0, 0, 4), g(12, "phoenix", 1.4, 1, 0, 3), g(10, "ember_cultist", 2.2, 2, 4, 3), g(6, "lava_spitter", 3.0, 1, 8),
                     g(24, "ember_wisp", 0.3, 0, 10), g(14, "ash_drake", 1.2, 2, 12)]]),
    60: dict(name="Throne of Embers", gold=36, health=(2.0, 6.0),
             story="The heart of the volcano, where the Ashen Wyrm has waited since the old war. It wants the eggs. It will not have them.",
             lines=[(None, 0, "The Ashen Wyrm's throne. Every egg in every castle depends on this."),
                    (WAVE_STARTED, 7, "There it is. The Ashen Wyrm. Exiled for wanting our eggs, and it never stopped wanting them."),
                    (WAVE_CLEARED, 7, "It is over. The ash settles. And now, at last... I can sleep.")],
             waves=[[g(22, "cinder_imp", 1.2), g(12, "magma_salamander", 1.2, 1), g(16, "ember_wisp", 0.3, 2, 6)],
                    [g(6, "obsidian_golem", 3.0, 1, 0, 1), g(5, "ember_cultist", 3.2, 0), g(8, "phoenix", 1.8, 2)],
                    [g(5, "lava_spitter", 3.6, 1), g(10, "ash_drake", 1.4, 2), g(18, "magma_salamander", 1.0, 0, 6)],
                    [g(9, "obsidian_golem", 2.4, 0, 0, 3), g(10, "phoenix", 1.6, 1, 0, 2), g(7, "ember_cultist", 2.8, 2, 4)],
                    [g(10, "obsidian_golem", 2.2, 2, 0, 3), g(6, "lava_spitter", 3.0, 0), g(12, "ash_drake", 1.2, 1, 0, 3), g(30, "cinder_imp", 0.7, 1, 6)],
                    [g(12, "phoenix", 1.4, 0, 0, 3), g(9, "ember_cultist", 2.4, 1, 0, 3), g(12, "obsidian_golem", 2.0, 2, 0, 4), g(24, "ember_wisp", 0.3, 0, 8)],
                    [g(1, "ashen_wyrm", 1.0, 1), g(14, "cinder_imp", 1.2, 0, 8), g(14, "cinder_imp", 1.2, 2, 8), g(6, "obsidian_golem", 3.0, 1, 16)]]),
}

# LevelData's Scorched Lands group: sandstorms in the desert (seconds between them), lava that cools at the volcano
# Windscour Flats (43) has the worst storms
SANDSTORM_EVERY = {37: 75.0, 38: 70.0, 39: 60.0, 40: 60.0, 41: 55.0, 42: 60.0, 43: 40.0, 44: 55.0, 45: 55.0, 46: 50.0,
                   47: 50.0, 48: 55.0}
LAVA_COOLS = range(49, 61)
DATA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scenes", "level", "level_data", "level_%03d_data.tres")


# Hard mixes in other factions (the user, 2026-11-17: Normal never locks the player into one element; Hard may need a
# spec, with enemies of different weaknesses in one level). The desert's Hard brings the volcano's fire creatures
# (weak to Frost) and armoured humans (they resist Physical); the volcano's Hard brings the desert's dead (weak to
# Fire, they resist Poison) and armoured humans. By wave from the second: (count, enemy, interval).
DESERT_MIX = [(8, "cinder_imp", 1.4), (8, "magma_salamander", 1.2), (12, "ember_wisp", 0.3), (3, "obsidian_golem", 3.4),
              (4, "ember_cultist", 3.2), (10, "cinder_imp", 1.0)]
VOLCANO_MIX = [(10, "bone_thrall", 1.4), (8, "ash_runner", 1.2), (14, "scarab", 0.3), (3, "revenant_knight", 3.4),
               (3, "grave_caller", 3.6), (12, "bone_thrall", 1.0)]
HUMANS_LATE = [(3, "armored_knight", 3.6), (2, "priest", 4.4), (4, "armored_knight", 3.2)]
HARD_DEFAULT = ["health_multiplier = 2.0", "speed_multiplier = 1.15", "count_multiplier = 1.4", "interval_multiplier = 0.85",
                "first_wave_share = 0.2", "last_wave_share = 1.0", "xp_multiplier = 1.5"]
MODES = "res://scenes/level/level_data/modes/level_%03d_hard%s.tres"
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def hard_mix(number):
    """per wave (0-based) the groups Hard adds; the first wave stays the level's own"""
    waves = LEVELS[number]["waves"]
    spawners = 1 + max(group[3] for wave in waves for group in wave)
    mix = DESERT_MIX if number <= 48 else VOLCANO_MIX
    added = [[]]
    for i in range(1, len(waves)):
        count, enemy, interval = mix[(i - 1) % len(mix)]
        groups = [g(count, enemy, interval, i % spawners, 2.0)]
        if i >= 3:
            count, enemy, interval = HUMANS_LATE[(i - 3) % len(HUMANS_LATE)]
            groups.append(g(count, enemy, interval, (i + 1) % spawners, 5.0))
        added.append(groups)
    return added


def res_path(path):
    return os.path.join(ROOT_DIR, path.replace("res://", "").replace("/", os.sep))


def write_group_file(path, groups):
    enemies = sorted(set(group[1] for group in groups))
    out = ['[gd_resource type="Resource" script_class="WaveData" format=3]', '',
           '[ext_resource type="Script" uid="uid://cpw7ia3ek2yvs" path="res://scenes/level/level_data/wave_data.gd" id="1_wave"]',
           '[ext_resource type="Script" uid="uid://bbhd3iyjav4h2" path="res://scenes/level/level_data/spawn_group_data.gd" id="2_group"]']
    out += ['[ext_resource type="PackedScene" path="res://scenes/unit/enemy/enemies/%s.tscn" id="e_%s"]' % (e, e) for e in enemies]
    out.append('')
    ids = []
    for i, (count, enemy, interval, spawner, delay, _, _) in enumerate(groups, 1):
        ids.append('SubResource("Resource_group%d")' % i)
        out += ['[sub_resource type="Resource" id="Resource_group%d"]' % i, 'script = ExtResource("2_group")',
                'enemy_scene = ExtResource("e_%s")' % enemy, 'count = %d' % count, 'interval = %s' % float(interval)]
        if delay:
            out.append('delay = %s' % float(delay))
        if spawner:
            out.append('spawner_id = %d' % spawner)
        out.append('')
    out += ['[resource]', 'script = ExtResource("1_wave")', 'spawn_groups = Array[ExtResource("2_group")]([%s])' % ', '.join(ids)]
    open(res_path(path), "w", encoding="utf8", newline="\n").write("\n".join(out) + "\n")


def write_hard(number):
    """the level's own Hard (LevelData.hard_mode): the default Hard plus its added groups"""
    paths = []
    for i, groups in enumerate(hard_mix(number), 1):
        path = MODES % (number, "_wave_%d" % i)
        write_group_file(path, groups)
        paths.append(path)
    out = ['[gd_resource type="Resource" script_class="LevelModeData" format=3]', '',
           '[ext_resource type="Script" path="res://scenes/level/level_data/level_mode_data.gd" id="1_mode"]',
           '[ext_resource type="Script" uid="uid://cpw7ia3ek2yvs" path="res://scenes/level/level_data/wave_data.gd" id="0_wave"]']
    out += ['[ext_resource type="Resource" path="%s" id="a%d"]' % (path, i) for i, path in enumerate(paths, 1)]
    out += ['', '[resource]', 'script = ExtResource("1_mode")'] + HARD_DEFAULT
    out.append('added_groups = Array[ExtResource("0_wave")]([%s])' % ", ".join('ExtResource("a%d")' % i for i in range(1, len(paths) + 1)))
    open(res_path(MODES % (number, "")), "w", encoding="utf8", newline="\n").write("\n".join(out) + "\n")
    return MODES % (number, "")


# Wave pressure (2026-11-17): the tuner found 37-44 too easy for health alone (flawless at x2 health): their waves
# were mostly basic units. Groups grow by PRESSURE_COUNT, bigger groups bring elites from wave 3, and each level gets
# one of its specials two waves earlier (by wave index: groups added).
PRESSURE_LEVELS = set(range(37, 51))
# Group growth only where it still helps: in the desert more walkers meant more kill gold and cards (level 38: 420
# enemies, 732 gold, 14 cards) and the Nova ate the crowds, so 37-42 lean on a steeper health ramp instead (2026-11-17:
# the bot lost in wave 1 at x3 health but kept 10/10 lives at x1.6 on the last waves alone; the last wave's health was
# doubled). 43-44 keep x1.5, on target.
PRESSURE_COUNT = {49: 1.5, 50: 1.5}
# the threats that make a level hard (what the Fields have): flyers that skip the maze from wave 2, bone riders (fast and
# tough) from wave 3, ballistas and grave callers through the middle and late waves; by wave index: groups added
EARLY_SPECIALS = {
    37: {1: [g(4, "giant_eagle", 2.0, 1)], 2: [g(2, "armored_knight", 3.6, 1)], 3: [g(6, "giant_eagle", 1.8), g(3, "cavalry", 3.0, 1)],
         4: [g(3, "bone_rider", 3.0, 1)], 5: [g(4, "bone_rider", 2.6)]},
    38: {1: [g(4, "ash_drake", 2.0, 1)], 2: [g(2, "revenant_knight", 3.6, 1), g(2, "bone_rider", 3.0, 2)],
         3: [g(6, "ash_drake", 1.8), g(3, "bone_rider", 3.0, 1)], 4: [g(4, "bone_rider", 2.6, 2), g(1, "rusted_ballista", 4.0)],
         5: [g(6, "ash_drake", 1.6, 1), g(5, "bone_rider", 2.4)]},
    39: {1: [g(2, "grave_caller", 4.0, 1), g(4, "ash_drake", 2.0)], 2: [g(1, "rusted_ballista", 4.0), g(3, "bone_rider", 3.0, 1)],
         3: [g(4, "bone_rider", 2.6), g(6, "ash_drake", 1.8, 1)], 4: [g(3, "grave_caller", 3.6, 1), g(1, "rusted_ballista", 4.0)],
         5: [g(5, "bone_rider", 2.4, 1)]},
    40: {1: [g(1, "rusted_ballista", 4.0, 1)], 2: [g(2, "grave_caller", 3.8), g(3, "bone_rider", 3.0, 1)],
         3: [g(4, "bone_rider", 2.6)], 4: [g(2, "rusted_ballista", 4.0, 1), g(2, "grave_caller", 3.6)], 5: [g(6, "bone_rider", 2.2, 1)]},
    41: {1: [g(1, "rusted_ballista", 4.0)], 2: [g(3, "revenant_knight", 3.4, 1), g(3, "bone_rider", 3.0)],
         3: [g(4, "bone_rider", 2.6, 1)], 4: [g(2, "rusted_ballista", 4.0)], 5: [g(6, "bone_rider", 2.2, 1)]},
    48: {1: [g(2, "grave_caller", 3.8)], 2: [g(2, "rusted_ballista", 4.0), g(3, "bone_rider", 3.0)], 3: [g(4, "bone_rider", 2.6)],
         4: [g(2, "rusted_ballista", 4.0)], 5: [g(6, "bone_rider", 2.2)]},
    49: {1: [g(4, "ash_drake", 2.0, 1)], 2: [g(2, "obsidian_golem", 3.6, 1)], 4: [g(3, "obsidian_golem", 3.2)]},
    50: {1: [g(2, "ember_cultist", 3.6)]},
}


def pressured(number, waves):
    if number not in PRESSURE_LEVELS:
        return waves
    out = []
    for i, wave in enumerate(waves):
        groups = []
        for count, enemy, interval, spawner, delay, elites, affix in wave:
            if count > 1:
                count = int(round(count * PRESSURE_COUNT.get(number, 1.0)))
                if i >= 2 and count >= 6:
                    elites = max(elites, count // 8)
            groups.append((count, enemy, interval, spawner, delay, elites, affix))
        out.append(groups + EARLY_SPECIALS.get(number, {}).get(i, []))
    return out


def write_scorched(number):
    # a rewrite keeps the knobs tools/tune_levels.py set
    path = DATA % number
    knobs = []
    if os.path.exists(path):
        knobs = [line for line in open(path, encoding="utf8").read().splitlines() if line.startswith(("health_scale", "hard_health_scale"))]
    spec = dict(LEVELS[number], waves=pressured(number, LEVELS[number]["waves"]))
    write_level(number, spec)
    hard = write_hard(number)
    extra = knobs + ['hard_mode = ExtResource("hard_mode")']
    if number in SANDSTORM_EVERY:
        extra.append("sandstorm_every = %s" % SANDSTORM_EVERY[number])
    if number in LAVA_COOLS:
        extra.append("lava_cools = true")
    text = open(path, encoding="utf8").read().rstrip("\n") + "\n" + "\n".join(extra) + "\n"
    first_sub = text.index("\n\n[sub_resource")
    text = text[:first_sub] + '\n[ext_resource type="Resource" path="%s" id="hard_mode"]' % hard + text[first_sub:]
    open(path, "w", encoding="utf8", newline="\n").write(text)


if __name__ == "__main__":
    for number in [int(a) for a in sys.argv[1:]] or sorted(LEVELS):
        write_scorched(number)
