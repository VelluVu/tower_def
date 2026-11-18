"""Build the Scorched Lands enemy scenes (levels 37-48) from a parent enemy of the same role (tools/enemy_scene.py),
with their resistance profiles; the parents' own abilities are dropped. Their art is drawn by
tools/sprite/parts/scorched_enemies.py (specs next to the sheets); their abilities are added by
tools/scorched_abilities.py. Rerun after changing a number here; it rewrites the .tscn files (rerun
scorched_abilities.py after it).

    python tools/scorched_enemies.py [names...]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from new_enemies_2026_11 import build

# name: (parent, stats for enemy_scene.py, resistance profile)
SCORCHED = {
    # the ash desert's raised dead
    "bone_thrall": ("soldier", ["health=22", "speed=17", "price=2"], "undead"),
    "ash_runner": ("scout", ["health=12", "speed=34", "price=2"], "undead"),
    "scarab": ("swarmling", ["health=7", "speed=26", "price=1", "xp=0.4"], "scarab"),
    "revenant_knight": ("armored_knight", ["health=80", "speed=11", "price=7"], "undead_armored"),
    "ash_drake": ("batling", ["health=22", "speed=22", "price=3"], "undead"),
    "grave_caller": ("wizard", ["health=24", "speed=15", "price=4"], "undead_caster"),
    "rusted_ballista": ("armored_knight", ["health=60", "speed=9", "price=6"], "siege_engine"),
    "bone_rider": ("cavalry", ["health=50", "speed=30", "price=5"], "undead"),
    "bone_colossus": ("bog_hydra", ["health=5500", "speed=7", "price=80"], "bone_colossus"),
    # the volcano's fire creatures and cultists
    "cinder_imp": ("fastling", ["health=24", "speed=18", "price=2"], "volcanic"),
    "magma_salamander": ("fastswampling", ["health=14", "speed=32", "price=2"], "volcanic"),
    "ember_wisp": ("swarmling", ["health=8", "speed=22", "price=1", "xp=0.4"], "ember_spirit"),
    "obsidian_golem": ("crystal_brute", ["health=90", "speed=10", "price=8"], "obsidian"),
    "magma_blob": ("leechling", ["health=18", "speed=14", "price=1", "xp=0.5"], "volcanic"),
    "phoenix": ("giant_eagle", ["health=30", "speed=24", "price=4"], "ember_spirit"),
    "ember_cultist": ("priest", ["health=26", "speed=15", "price=4"], "cultist"),
    "lava_spitter": ("destroyerling", ["health=60", "speed=10", "price=6"], "volcanic"),
    "ashen_wyrm": ("giant_eagle", ["health=7000", "speed=10", "price=120", "boss=1", "damage=10", "sprite_y=-14", "popup_y=-30", "hitbox=24x18"], "ashen_wyrm"),
}

if __name__ == "__main__":
    for name in sys.argv[1:] or SCORCHED:
        parent, stats, profile = SCORCHED[name]
        build(name, parent, stats, profile, None)
