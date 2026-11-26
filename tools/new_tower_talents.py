"""Talent paths for the new towers (2026-11-24, the user's picks; the towers are not built yet).

    python tools/new_tower_talents.py            add the paths to the four trees (refuses if they are there)
    python tools/new_tower_talents.py --remove   take every node this script added back out

Every new tower gets its own branch in the old branches' form: its partner path's first node (shared), two
stat nodes, T2 at step 4, a two-lane fork of three nodes, T3 at step 8 (one-way to the tree's overall
capstone), then a capstone. Pairs (the user): Bolter + Spotter, Nova + Mortar, Beamer + Breather, the trap
path + Egg Bomb, Harpooner and Hatchery, the maze + Buffer (plus more maze talents). The nodes have no
effects yet: the menu shows them as "does nothing yet" until the towers exist.

Layout: the flame-like trees (Fire up, Poison down, Building up) get new columns beside the old ones; the
Frost snowflake gets new rays between the old ones. The user fine-tunes positions in the editor's Talents
screen, so rerunning after --remove loses those moves.
"""
import colorsys
import math
import re
import sys
from pathlib import Path

TREES = Path(__file__).resolve().parent.parent / "scenes" / "talents" / "trees"
MARK = "new_tower_talents"  # every node id this script adds is listed in a comment line with this mark

STAT, SIDE, EVOLVE, CAPSTONE = 0, 1, 2, 3

# One branch: tower name, the node it hangs from (shared), the tree's element word, then eleven nodes:
# s2, s3, T2, a1, a2, a3, b1, b2, b3, T3, capstone as (name, max rank, description). T2/T3 are made here.
# A branch with "entry" makes its own first node (the maze entry) and hangs it from the tree's start.


def branch(tower, hang_from, stats, lane_a, lane_b, capstone, t2_text="", t3_text=""):
    return dict(tower=tower, hang_from=hang_from, stats=stats, a=lane_a, b=lane_b, cap=capstone,
                t2_text=t2_text, t3_text=t3_text)


FIRE = [
    branch("Spotter", "hot_bolts",
           [("Hawk's Eye", 3, "Fire Spotter damage +8%"), ("Still Breath", 2, "Fire Spotter range +0.2 tiles")],
           [("Smouldering Mark", 3, "Fire Spotter ignite chance +5 points"),
            ("Pyre Mark", 2, "A Spotter hit marks its target: it takes +10% Fire damage from every tower for 3 s"),
            ("Hot Shot", 3, "Fire Spotter burn potency +10%")],
           [("Steady Aim", 3, "Fire Spotter attack speed +0.03"),
            ("Molten Round", 2, "Spotter shots also hit enemies within 0.5 tiles of the target for 25% of the hit"),
            ("Weak Spot", 2, "Fire Spotter critical chance +4 points")],
           ("Sunspear", "Every 4th shot is a Sunspear: double damage, and it sets every enemy along its line on fire")),
    branch("Mortar", "blast_furnace",
           [("Heavy Shells", 3, "Fire Mortar damage +8%"), ("Long Lob", 2, "Fire Mortar range +0.2 tiles")],
           [("Incendiary Fill", 3, "Fire Mortar ignite chance +5 points"),
            ("Napalm", 2, "The burning patch a shell leaves lasts 1 s longer"),
            ("Wide Shells", 2, "Fire Mortar splash radius +0.1 tiles")],
           [("Quick Loader", 3, "Fire Mortar attack speed +0.04"),
            ("Shell Shock", 2, "Enemies at the centre of the splash are knocked back 0.25 tiles"),
            ("Scorch", 3, "Fire Mortar burn potency +10%")],
           ("Firestorm", "Every 5th shell bursts into 3 burning bomblets around the landing spot")),
    branch("Breather", "hot_beam",
           [("Bellows", 3, "Fire Breather damage +8%"), ("Deep Lungs", 2, "Fire Breather cone length +0.1 tiles")],
           [("Fan of Flame", 2, "Fire Breather cone width +10 degrees"),
            ("Searing Breath", 3, "Fire Breather ignite chance +5 points"),
            ("Burning Floor", 2, "The breath leaves burning ground for 1 s")],
           [("Hot Air", 3, "Fire Breather attack speed +0.04"),
            ("Backdraft", 2, "The breath deals +10% damage to enemies that are already burning"),
            ("Cinder Lungs", 3, "Fire Breather burn potency +10%")],
           ("Dragonfire", "The breath sweeps across a 120 degree arc and its burns last twice as long")),
    branch("Egg Bomb", "hot_snare",
           [("Hot Yolk", 3, "Fire Egg Bomb blast damage +8%"), ("Quick Hatch", 3, "Fire Egg Bomb rebuilds 10% faster")],
           [("Wide Blast", 2, "Fire Egg Bomb blast radius +0.1 tiles"),
            ("Scalding Shell", 3, "Fire Egg Bomb burn potency +10%"),
            ("Fire Pit", 2, "The blast leaves burning ground for 1.5 s")],
           [("Short Fuse", 2, "The egg goes off 0.1 s sooner"),
            ("Ember Clutch", 2, "The blast throws 2 embers that ignite enemies within 1 tile of where they land"),
            ("Warm Nest", 3, "Fire Egg Bomb rebuilds 10% faster")],
           ("Inferno Egg", "The blast ignites every enemy within 2 tiles, and once per wave the egg rebuilds at once")),
    branch("Harpooner", "hot_snare",
           [("Barbed Hooks", 3, "Fire Harpooner damage +8%"), ("Long Chain", 2, "Fire Harpooner range +0.2 tiles")],
           [("Red-Hot Hook", 3, "Fire Harpooner ignite chance +5 points"),
            ("Searing Chain", 2, "Burns on a tethered enemy are 15% stronger"),
            ("Hot Tether", 2, "The tether lasts 0.25 s longer")],
           [("Quick Reel", 3, "Fire Harpooner attack speed +0.04"),
            ("Drag to the Fire", 2, "A harpooned flyer lands on burning ground that lasts 1.5 s"),
            ("Skyhook", 2, "Fire Harpooner damage +15% against flyers")],
           ("Chain of Embers", "The harpoon chains on to 2 more enemies within 1.5 tiles, tethering and burning each")),
    branch("Hatchery", "hot_snare",
           [("Fire-Fed Brood", 3, "Fire drakeling damage +8%"), ("Warm Clutch", 3, "Fire Hatchery hatches 10% faster")],
           [("Ember Claws", 3, "Fire drakeling ignite chance +5 points"),
            ("Hot Blood", 2, "Fire drakelings burn the enemies that hit them"),
            ("Thick Scales", 2, "Fire drakeling health +15%")],
           [("Big Clutch", 1, "One more drakeling at a time"),
            ("Fire Spit", 2, "Every 4 s a Fire drakeling spits a burning glob at an enemy within 1.5 tiles"),
            ("Fierce Hatchlings", 3, "Fire drakeling attack speed +0.04")],
           ("Brood Inferno", "A falling Fire drakeling bursts into flame: 20% of its max health as Fire damage within 1 tile")),
    branch("Buffer", None,
           [("Warm Aura", 3, "Fire Buffer aura radius +0.1 tiles"), ("Kindled Hearts", 2, "Fire Buffer buffs +5% stronger")],
           [("Burning Zeal", 3, "The burn chance a Fire Buffer gives +3 points"),
            ("Heat Shimmer", 2, "Enemies in a Fire Buffer's aura take +5% Fire damage"),
            ("Hearth", 2, "Fire Buffer pip budget +1")],
           [("Forge Song", 3, "Buffed towers' burn potency +5%"),
            ("Fire Drill", 2, "The attack speed buff of a Fire Buffer is 5% stronger"),
            ("Warm Stones", 2, "Fire walls in a Fire Buffer's aura heal 1% of their max health per second")],
           ("Heart of the Forge", "Every 10th attack of a buffed tower is a critical hit that ignites"),
           t2_text="Unlocks Fire Buffer T2: the aura also weakens enemies in it",
           t3_text="Unlocks Fire Buffer T3: Commander's Roar"),
]
FIRE_MAZE = dict(
    entry=("Smouldering Maze", 3, "Fire walls burn their attackers 10% harder, and Fire Buffer auras are 5% stronger"),
    side=[("Ember Walls", 3, "Enemies walking next to a Fire wall get 1 burn tick"),
          ("Hot Corners", 2, "Turns next to Fire walls deal 5% of the enemy's max health as Fire damage"),
          ("Ring of Fire", 1, "A straight line of 5 or more Fire walls flames up: enemies walking along it burn twice as hard")])

FROST = [
    branch("Spotter", "ice_bolts",
           [("Cold Eye", 3, "Frost Spotter damage +8%"), ("Still Air", 2, "Frost Spotter range +0.2 tiles")],
           [("Chilling Mark", 3, "Frost Spotter slow potency +10%"),
            ("Frost Mark", 2, "A Spotter hit marks its target: it takes +10% Frost damage from every tower for 3 s"),
            ("Ice Sight", 2, "Frost Spotter critical chance +4 points")],
           [("Patient Aim", 3, "Frost Spotter attack speed +0.03"),
            ("Glacial Round", 2, "Spotter hits freeze their target for 0.3 s"),
            ("Hailstone", 3, "Frost Spotter damage +8%")],
           ("Winter's Needle", "Shots pierce every enemy in a line and freeze the first one for 1 s")),
    branch("Mortar", "frost_ring",
           [("Ice Shells", 3, "Frost Mortar damage +8%"), ("High Arc", 2, "Frost Mortar range +0.2 tiles")],
           [("Frost Fill", 3, "Frost Mortar slow potency +10%"),
            ("Frozen Crater", 2, "A shell leaves chilled ground for 1.5 s"),
            ("Wide Shells", 2, "Frost Mortar splash radius +0.1 tiles")],
           [("Quick Loader", 3, "Frost Mortar attack speed +0.04"),
            ("Shatter Shell", 2, "Shells deal +15% damage to frozen enemies"),
            ("Hard Ice", 2, "Frost Mortar critical chance +3 points")],
           ("Hailstorm", "Every 5th shell bursts into 5 hailstones over 2 tiles, each freezing what it hits for 0.5 s")),
    branch("Breather", "cold_beam",
           [("Cold Breath", 3, "Frost Breather damage +8%"), ("Deep Lungs", 2, "Frost Breather cone length +0.1 tiles")],
           [("Fan of Frost", 2, "Frost Breather cone width +10 degrees"),
            ("Rime Breath", 3, "Frost Breather slow potency +10%"),
            ("Frostbite", 2, "Each second in the cone adds 1 more slow stack")],
           [("Steady Breath", 3, "Frost Breather attack speed +0.04"),
            ("Flash Freeze", 2, "Enemies at the slow floor in the cone freeze for 0.5 s"),
            ("Icy Lungs", 3, "Frost Breather damage +8%")],
           ("Winter's Breath", "The breath sweeps across a 120 degree arc and leaves freezing ground behind")),
    branch("Egg Bomb", "cold_snare",
           [("Cold Yolk", 3, "Frost Egg Bomb blast damage +8%"), ("Quick Hatch", 3, "Frost Egg Bomb rebuilds 10% faster")],
           [("Wide Blast", 2, "Frost Egg Bomb blast radius +0.1 tiles"),
            ("Rime Shell", 3, "Frost Egg Bomb slow potency +10%"),
            ("Frozen Pit", 2, "The blast leaves freezing ground for 1.5 s")],
           [("Short Fuse", 2, "The egg goes off 0.1 s sooner"),
            ("Ice Shrapnel", 2, "The blast deals +20% damage to frozen enemies"),
            ("Cold Nest", 3, "Frost Egg Bomb rebuilds 10% faster")],
           ("Glacier Egg", "The blast freezes every enemy it hits for 1 s")),
    branch("Harpooner", "cold_snare",
           [("Ice Hooks", 3, "Frost Harpooner damage +8%"), ("Long Chain", 2, "Frost Harpooner range +0.2 tiles")],
           [("Frozen Chain", 2, "The tether lasts 0.25 s longer"),
            ("Pin Down", 2, "A tethered enemy freezes for 0.5 s when the tether ends"),
            ("Cold Barbs", 3, "Frost Harpooner slow potency +10%")],
           [("Quick Reel", 3, "Frost Harpooner attack speed +0.04"),
            ("Grounded", 2, "Harpooned flyers walk 20% slower once they land"),
            ("Skyhook", 2, "Frost Harpooner damage +15% against flyers")],
           ("Glacial Anchor", "The tether freezes its target for its whole length; bosses are held at the slow floor instead")),
    branch("Hatchery", "cold_snare",
           [("Frost-Fed Brood", 3, "Frost drakeling damage +8%"), ("Cold Clutch", 3, "Frost Hatchery hatches 10% faster")],
           [("Frost Claws", 3, "Frost drakeling slow potency +10%"),
            ("Ice Scales", 2, "Frost drakelings take 10% less damage"),
            ("Hardy Brood", 2, "Frost drakeling health +15%")],
           [("Big Clutch", 1, "One more drakeling at a time"),
            ("Frost Spit", 2, "Every 5 s a Frost drakeling spits an icy glob that freezes an enemy for 0.5 s"),
            ("Fierce Hatchlings", 3, "Frost drakeling attack speed +0.04")],
           ("Winter Brood", "Enemies fighting Frost drakelings are slowed to the slow floor")),
    branch("Buffer", None,
           [("Cold Aura", 3, "Frost Buffer aura radius +0.1 tiles"), ("Clear Mind", 2, "Frost Buffer buffs +5% stronger")],
           [("Frost Zeal", 3, "The slow chance a Frost Buffer gives +3 points"),
            ("Biting Chill", 2, "Enemies in a Frost Buffer's aura move 5% slower"),
            ("Deep Reserve", 2, "Frost Buffer pip budget +1")],
           [("Rime Song", 3, "Buffed towers' slow potency +5%"),
            ("Cold Focus", 2, "The range buff of a Frost Buffer is 5% stronger"),
            ("Glazed Stones", 2, "Frost walls in a Frost Buffer's aura take 5% less damage")],
           ("Heart of Winter", "Every 10th attack of a buffed tower freezes its target for 0.5 s"),
           t2_text="Unlocks Frost Buffer T2: the aura also weakens enemies in it",
           t3_text="Unlocks Frost Buffer T3: Commander's Roar"),
]
FROST_MAZE = dict(
    entry=("Frozen Maze", 3, "Frost walls slow 2 points more, and Frost Buffer auras are 5% stronger"),
    side=[("Icy Floor", 3, "Turns next to Frost walls pause enemies 0.05 s longer"),
          ("Frost Corners", 2, "Turns next to Frost walls add 1 slow stack"),
          ("Glacier Maze", 1, "An enemy that walks 5 cells along Frost walls freezes for 0.5 s")])

POISON = [
    branch("Spotter", "venom_bolts",
           [("Viper Eye", 3, "Poison Spotter damage +8%"), ("Still Fangs", 2, "Poison Spotter range +0.2 tiles")],
           [("Venom Mark", 3, "Poison Spotter potency +10%"),
            ("Toxic Mark", 2, "A Spotter hit marks its target: it takes +10% Poison damage from every tower for 3 s"),
            ("Deep Dose", 2, "Each shot adds 1 more poison stack")],
           [("Patient Aim", 3, "Poison Spotter attack speed +0.03"),
            ("Rot Round", 2, "Shots also hit enemies within 0.5 tiles of the target for 25% and poison them"),
            ("Weak Spot", 2, "Poison Spotter critical chance +4 points")],
           ("Death Sentence", "A shot on an enemy with 10 or more stacks deals all their remaining poison damage at once")),
    branch("Mortar", "toxic_burst",
           [("Rot Shells", 3, "Poison Mortar damage +8%"), ("Long Lob", 2, "Poison Mortar range +0.2 tiles")],
           [("Toxic Fill", 3, "Poison Mortar potency +10%"),
            ("Gas Shells", 2, "A shell leaves a poison cloud for 1.5 s"),
            ("Wide Shells", 2, "Poison Mortar splash radius +0.1 tiles")],
           [("Quick Loader", 3, "Poison Mortar attack speed +0.04"),
            ("Corroding Splash", 2, "The splash lowers armor by 5% for 3 s"),
            ("Heavy Dose", 2, "Each splash hit adds 1 more poison stack")],
           ("Plague Barrage", "Every 5th shell bursts into 3 gas bombs around the landing spot")),
    branch("Breather", "acid_beam",
           [("Acid Breath", 3, "Poison Breather damage +8%"), ("Deep Lungs", 2, "Poison Breather cone length +0.1 tiles")],
           [("Wide Fumes", 2, "Poison Breather cone width +10 degrees"),
            ("Choking Breath", 3, "Poison Breather potency +10%"),
            ("Lingering Breath", 2, "The breath leaves a poison cloud for 1 s")],
           [("Steady Breath", 3, "Poison Breather attack speed +0.04"),
            ("Corrosive Breath", 2, "The breath deals +3% damage for every poison stack on the enemy"),
            ("Thick Fumes", 2, "The breath's poison stacks 1 more time on each enemy")],
           ("Miasma", "The breath sweeps across a 120 degree arc, and every hit passes 1 stack to an enemy within 1 tile")),
    branch("Egg Bomb", "venom_snare",
           [("Rotten Yolk", 3, "Poison Egg Bomb blast damage +8%"), ("Quick Hatch", 3, "Poison Egg Bomb rebuilds 10% faster")],
           [("Wide Blast", 2, "Poison Egg Bomb blast radius +0.1 tiles"),
            ("Spore Shell", 3, "Poison Egg Bomb potency +10%"),
            ("Gas Pit", 2, "The blast leaves a poison cloud for 1.5 s")],
           [("Short Fuse", 2, "The egg goes off 0.1 s sooner"),
            ("Sticky Yolk", 2, "Enemies hit move 15% slower for 2 s"),
            ("Fetid Nest", 3, "Poison Egg Bomb rebuilds 10% faster")],
           ("Plague Egg", "The blast adds 5 poison stacks, and its cloud drifts along the enemy path for 3 s")),
    branch("Harpooner", "venom_snare",
           [("Venom Hooks", 3, "Poison Harpooner damage +8%"), ("Long Chain", 2, "Poison Harpooner range +0.2 tiles")],
           [("Toxic Barbs", 3, "Poison Harpooner potency +10%"),
            ("Festering Wound", 2, "A tethered enemy gains 1 poison stack every second"),
            ("Tight Tether", 2, "The tether lasts 0.25 s longer")],
           [("Quick Reel", 3, "Poison Harpooner attack speed +0.04"),
            ("Grounded Rot", 2, "Harpooned flyers lose 10% armor for 5 s"),
            ("Skyhook", 2, "Poison Harpooner damage +15% against flyers")],
           ("Leech Chain", "Poison ticks on a tethered enemy also hit every enemy within 1 tile")),
    branch("Hatchery", "venom_snare",
           [("Venom-Fed Brood", 3, "Poison drakeling damage +8%"), ("Rot Clutch", 3, "Poison Hatchery hatches 10% faster")],
           [("Venom Claws", 3, "Poison drakeling potency +10%"),
            ("Toxic Blood", 2, "Poison drakelings poison the enemies that hit them"),
            ("Hardy Brood", 2, "Poison drakeling health +15%")],
           [("Big Clutch", 1, "One more drakeling at a time"),
            ("Acid Spit", 2, "Every 4 s a Poison drakeling spits acid: the enemy loses 10% armor for 3 s"),
            ("Fierce Hatchlings", 3, "Poison drakeling attack speed +0.04")],
           ("Plague Brood", "A falling Poison drakeling leaves a poison cloud for 3 s")),
    branch("Buffer", None,
           [("Spore Aura", 3, "Poison Buffer aura radius +0.1 tiles"), ("Bitter Tonic", 2, "Poison Buffer buffs +5% stronger")],
           [("Venom Zeal", 3, "The poison stack chance a Poison Buffer gives +3 points"),
            ("Noxious Air", 2, "Enemies in a Poison Buffer's aura take +5% Poison damage"),
            ("Deep Reserve", 2, "Poison Buffer pip budget +1")],
           [("Brew Song", 3, "Buffed towers' poison potency +5%"),
            ("Sharp Senses", 2, "The critical chance buff of a Poison Buffer is 5% stronger"),
            ("Mossy Stones", 2, "Poison walls in a Poison Buffer's aura heal 1% of their max health per second")],
           ("Heart of the Bog", "Every 10th attack of a buffed tower adds 3 poison stacks"),
           t2_text="Unlocks Poison Buffer T2: the aura also weakens enemies in it",
           t3_text="Unlocks Poison Buffer T3: Commander's Roar"),
]
POISON_MAZE = dict(
    entry=("Toxic Maze", 3, "Poison walls poison their attackers 10% harder, and Poison Buffer auras are 5% stronger"),
    side=[("Thorn Walls", 3, "Enemies walking next to a Poison wall gain 1 poison stack every 2 s"),
          ("Rotting Corners", 2, "Turns next to Poison walls add 1 poison stack"),
          ("Bog Maze", 1, "Poisoned enemies in the maze move 5% slower for every 5 stacks")])

BUILDING = [
    branch("Spotter", "hardened_shots",
           [("Keen Sight", 3, "Physical Spotter damage +8%"), ("Spotter's Perch", 2, "Physical Spotter range +0.2 tiles")],
           [("Armour Piercer", 3, "Physical Spotter ignores 10% of the target's resistance"),
            ("Called Shot", 2, "The first shot on a new target deals +30% damage"),
            ("Weak Spot", 2, "Physical Spotter critical chance +4 points")],
           [("Steady Aim", 3, "Physical Spotter attack speed +0.03"),
            ("Headhunter", 2, "Physical Spotter damage +15% against elites and bosses"),
            ("Heavy Bolt", 2, "Physical Spotter critical multiplier +0.1")],
           ("Execution", "Spotter hits kill enemies under 15% health (not bosses)")),
    branch("Mortar", "hardened_shots",
           [("Stone Shells", 3, "Physical Mortar damage +8%"), ("Long Lob", 2, "Physical Mortar range +0.2 tiles")],
           [("Wide Shells", 2, "Physical Mortar splash radius +0.1 tiles"),
            ("Concussion", 2, "Enemies at the centre of the splash are stunned for 0.3 s"),
            ("Rubble", 2, "A shell leaves rubble that slows enemies 10% for 2 s")],
           [("Quick Loader", 3, "Physical Mortar attack speed +0.04"),
            ("Big Charge", 2, "The splash knocks enemies back 0.25 tiles"),
            ("Heavy Shells", 2, "Physical Mortar critical chance +3 points")],
           ("Earthshaker", "Every 5th shell shakes the ground: every enemy within 2 tiles is stunned for 0.5 s")),
    branch("Breather", "hardened_shots",
           [("Mighty Roar", 3, "Physical Breather damage +8%"), ("Deep Lungs", 2, "Physical Breather cone length +0.1 tiles")],
           [("Wide Roar", 2, "Physical Breather cone width +10 degrees"),
            ("Deafening Roar", 2, "The roar's stun lasts 0.1 s longer"),
            ("Shove", 2, "The roar knocks enemies back 0.1 tiles further")],
           [("Steady Breath", 3, "Physical Breather attack speed +0.04"),
            ("Terrify", 2, "Enemies hit deal 10% less damage to buildings for 3 s"),
            ("Rending Roar", 2, "Physical Breather ignores 10% of the target's resistance")],
           ("Dragon's Roar", "Every 4th roar sends every enemy in the cone 1 tile back along its path")),
    branch("Egg Bomb", "sharp_teeth",
           [("Hard Shell", 3, "Egg Bomb blast damage +8%"), ("Quick Hatch", 3, "Egg Bombs rebuild 10% faster")],
           [("Wide Blast", 2, "Egg Bomb blast radius +0.1 tiles"),
            ("Shrapnel Shell", 2, "The blast ignores 10% of the enemy's armor"),
            ("Big Egg", 2, "Egg Bomb critical chance +5 points")],
           [("Short Fuse", 2, "The egg goes off 0.1 s sooner"),
            ("Stunning Blast", 2, "The blast stuns every enemy it hits for 0.3 s"),
            ("Nesting Instinct", 3, "Egg Bombs rebuild 10% faster")],
           ("Clutch Bomb", "The blast leaves 3 small eggs that go off 1 s later for 30% of the blast")),
    branch("Harpooner", "sharp_teeth",
           [("Barbed Hooks", 3, "Physical Harpooner damage +8%"), ("Long Chain", 2, "Physical Harpooner range +0.2 tiles")],
           [("Strong Chain", 2, "The tether lasts 0.25 s longer"),
            ("Yank", 2, "The harpoon pulls its target 0.5 tiles back along its path"),
            ("Hooked Barbs", 2, "Physical Harpooner ignores 10% of the enemy's armor")],
           [("Quick Reel", 3, "Physical Harpooner attack speed +0.04"),
            ("Skyhook", 2, "Physical Harpooner damage +15% against flyers"),
            ("Heavy Harpoon", 2, "Physical Harpooner critical multiplier +0.1")],
           ("Twin Harpoons", "Every Harpooner throws twice as many harpoons")),
    branch("Hatchery", "sharp_teeth",
           [("Vitamin Feed", 3, "Drakeling damage +8%"), ("Warm Clutch", 3, "Hatcheries hatch 10% faster")],
           [("Thick Scales", 3, "Drakeling health +15%"),
            ("Guard Post", 2, "Each drakeling holds one more enemy"),
            ("Pumped Up", 3, "Drakeling attack speed +0.04")],
           [("Big Clutch", 1, "One more drakeling at a time"),
            ("Pack Tactics", 2, "Drakelings deal +5% damage for every other drakeling within 1 tile"),
            ("Sharp Claws", 2, "Drakeling critical chance +4 points")],
           ("Brood Champion", "One drakeling in each clutch grows into a champion with triple health and a cleaving bite")),
    branch("Buffer", "narrow_ways",
           [("Drill Sergeant", 3, "Buffer aura radius +0.1 tiles")],
           [("Rallying Cry", 3, "Buffer buffs +5% stronger"),
            ("Sharp Orders", 2, "The resistance penetration a Physical Buffer gives +5 points"),
            ("Deep Reserve", 2, "Buffer pip budget +1")],
           [("Wide Command", 2, "Buffer aura radius +0.1 tiles"),
            ("Maze Master", 2, "Towers in a Buffer's aura deal +5% damage to enemies next to walls"),
            ("Stone Ward", 2, "Walls in a Buffer's aura take 5% less damage")],
           ("War Drums", "Commander's Roar comes twice as often and also gives +20% damage"),
           t2_text="Unlocks Physical Buffer T2: the aura also weakens enemies in it",
           t3_text="Unlocks Physical Buffer T3: Commander's Roar"),
]
BUILDING_MAZE = dict(
    hang_from="sharp_corners",
    side=[("Switchbacks", 3, "Maze slow 2 points stronger on cells with walls on both sides"),
          ("Dead Ends", 2, "Enemies that must find a new way because of a new wall stop for 0.3 s"),
          ("Long Way Round", 2, "Kill XP +3% for every 10 cells the maze adds to the shortest route"),
          ("Killing Corridor", 1, "Towers next to a straight line of 5 or more walls deal +10% damage")])

# Layout per tree. Flame-like trees: start y of a branch, step per node along the tree, lane offset, and each
# branch's column (x, k): k columns out from the old tree, each k sits STAGGER units nearer the start row, so
# the links from the shared entry nodes pass under the inner columns' first nodes (and the columns fan out).
# Frost: rays from the centre (angle, starting radius).
STAGGER = 1.0
FLAME = {
    "fire": dict(y0=20.0, step=-2.0, lane=0.9, cols={"Mortar": (-3.5, 0), "Spotter": (-7.0, 1), "Buffer": (-11.0, 2),
                                                    "maze": (-14.5, 3), "Breather": (23.5, 0), "Egg Bomb": (27.0, 1),
                                                    "Harpooner": (30.5, 2), "Hatchery": (34.0, 3)}),
    "poison": dict(y0=0.0, step=2.0, lane=0.9, cols={"Mortar": (-3.5, 0), "Spotter": (-7.0, 1), "Buffer": (-11.0, 2),
                                                    "maze": (-14.5, 3), "Breather": (21.5, 0), "Egg Bomb": (25.0, 1),
                                                    "Harpooner": (28.5, 2), "Hatchery": (32.0, 3)}),
    "building": dict(y0=26.0, step=-2.2, lane=0.9, cols={"Spotter": (-3.5, 0), "Mortar": (-7.0, 1),
                                                        "Breather": (-10.5, 2), "Egg Bomb": (23.5, 0),
                                                        "Harpooner": (27.0, 1), "Hatchery": (30.5, 2),
                                                        "Buffer": (34.0, 3), "maze": (37.5, 4)}),
}
FROST_RAYS = dict(centre=(10.0, 10.0), step=1.25, lane=0.6,
                  rays={"Spotter": (202.5, 2.6), "Breather": (157.5, 2.6), "Mortar": (337.5, 2.6),
                        "Egg Bomb": (22.5, 2.6), "Harpooner": (67.5, 2.6), "Hatchery": (112.5, 3.6),
                        "Buffer": (247.5, 6.0), "maze": (292.5, 6.0)})

TREE_DATA = {
    "fire": ("Fire", FIRE, FIRE_MAZE, "keep_awakens"),
    "frost": ("Frost", FROST, FROST_MAZE, "absolute_zero"),
    "poison": ("Poison", POISON, POISON_MAZE, "black_venom"),
    "building": ("Physical", BUILDING, BUILDING_MAZE, "dragons_keep"),
}


def slug(text):
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")


def tower_slug(tower):
    return slug(tower)


class Placer:
    def __init__(self, tree_id):
        self.tree_id = tree_id

    def at(self, column, distance, lateral=0.0):
        """A spot `distance` nodes out along a branch (0 = the branch's own entry), `lateral` lanes aside."""
        if self.tree_id == "frost":
            angle, r0 = FROST_RAYS["rays"][column]
            a = math.radians(angle)
            r = r0 + distance * FROST_RAYS["step"]
            cx, cy = FROST_RAYS["centre"]
            lane = lateral * FROST_RAYS["lane"]
            return (cx + math.cos(a) * r - math.sin(a) * lane, cy + math.sin(a) * r + math.cos(a) * lane)
        cfg = FLAME[self.tree_id]
        x, k = cfg["cols"][column]
        toward_start = -math.copysign(STAGGER * k, cfg["step"])
        return (x + lateral * cfg["lane"], cfg["y0"] + distance * cfg["step"] + toward_start)


def shade(color, index):
    """A branch colour next to its partner's: hue nudged by index, a little lighter."""
    h, s, v = colorsys.rgb_to_hsv(*color)
    h = (h + 0.035 * index) % 1.0
    v = min(1.0, v * 1.08)
    return colorsys.hsv_to_rgb(h, s, v)


def parse_nodes(text):
    nodes = {}
    for m in re.finditer(r'\[sub_resource type="Resource" id="(Node_\w+)"\]\n(.*?)(?=\n\[|\Z)', text, re.S):
        body = m[2]
        nid = re.search(r'^id = &"(\w+)"', body, re.M)[1]
        col = re.search(r"^color = Color\(([\d.]+), ([\d.]+), ([\d.]+)", body, re.M)
        links = re.search(r"^links = (.*)$", body, re.M)
        one_way = re.search(r"^one_way_links = (.*)$", body, re.M)
        nodes[nid] = dict(res=m[1], color=tuple(float(c) for c in col.groups()) if col else (1, 1, 1),
                          links=re.findall(r'&"(\w+)"', links[1]) if links else [],
                          one_way=re.findall(r'&"(\w+)"', one_way[1]) if one_way else [])
    return nodes


def steps_from(start_id, nodes):
    """Each node's step from the start (two-way links both ways, one-way links forward)."""
    near = {nid: set(n["one_way"]) | set(n["links"]) for nid, n in nodes.items()}
    for nid, n in nodes.items():
        for other in n["links"]:
            near.setdefault(other, set()).add(nid)
    steps = {start_id: 0}
    queue = [start_id]
    for nid in queue:
        for other in near.get(nid, ()):
            if other not in steps:
                steps[other] = steps[nid] + 1
                queue.append(other)
    return steps


def node_text(n):
    lines = [f'[sub_resource type="Resource" id="Node_{n["id"]}"]', 'script = ExtResource("2_node")',
             f'id = &"{n["id"]}"', f'display_name = "{n["name"]}"', f'description = "{n["desc"]}"']
    if n["kind"]:
        lines.append(f'kind = {n["kind"]}')
    if n["rank"] != 1:
        lines.append(f'max_rank = {n["rank"]}')
    x, y = n["pos"]
    lines.append(f"position = Vector2({x:.3f}, {y:.3f})")
    r, g, b = n["color"]
    lines.append(f"color = Color({r:.3f}, {g:.3f}, {b:.3f}, 1)")
    if n["links"]:
        lines.append("links = Array[StringName]([" + ", ".join(f'&"{l}"' for l in n["links"]) + "])")
    if n["one_way"]:
        lines.append("one_way_links = Array[StringName]([" + ", ".join(f'&"{l}"' for l in n["one_way"]) + "])")
    if n["needs"]:
        lines.append(f'needs = &"{n["needs"]}"')
    return "\n".join(lines) + "\n"


def make_nodes(tree_id, existing):
    element, branches, maze, overall = TREE_DATA[tree_id]
    place = Placer(tree_id)
    start_id = None
    new = []
    extra_links = {}  # existing node id -> new ids to link from it
    shade_count = {}

    def add(nid, name, rank, desc, kind, pos, color, links=(), one_way=(), needs=""):
        assert nid not in existing and all(nid != n["id"] for n in new), f"{tree_id}: id {nid} taken"
        new.append(dict(id=nid, name=name, rank=rank, desc=desc, kind=kind, pos=pos, color=color,
                        links=list(links), one_way=list(one_way), needs=needs))

    def link_from(old_id, new_id):
        extra_links.setdefault(old_id, []).append(new_id)

    text = (TREES / f"{tree_id}_tree.tres").read_text(encoding="utf-8")
    start_id = re.search(r'^start_id = &"(\w+)"', text, re.M)[1]
    old_steps = steps_from(start_id, existing)

    maze_entry_id = None
    if "entry" in maze:
        name, rank, desc = maze["entry"]
        maze_entry_id = slug(name)
        wall_color = (0.604, 0.651, 0.69)
        add(maze_entry_id, name, rank, desc, STAT, place.at("Buffer", 0), wall_color)
        link_from(start_id, maze_entry_id)
        prev = maze_entry_id
        side = maze["side"]
        for i, (sname, srank, sdesc) in enumerate(side):
            sid = "maze_" + slug(sname)
            kind = SIDE if i == len(side) - 1 else STAT
            add(sid, sname, srank, sdesc, kind, place.at("maze", i + 1), shade(wall_color, 1))
            _link_new(new, prev, sid)
            prev = sid
    else:
        prev = maze["hang_from"]
        wall_color = (0.604, 0.651, 0.69)
        for i, (sname, srank, sdesc) in enumerate(maze["side"]):
            sid = "maze_" + slug(sname)
            kind = SIDE if i == len(maze["side"]) - 1 else STAT
            add(sid, sname, srank, sdesc, kind, place.at("maze", i + 1), shade(wall_color, 1))
            if i == 0:
                link_from(prev, sid)
            else:
                _link_new(new, prev, sid)
            prev = sid

    for br in branches:
        tower = br["tower"]
        ts = tower_slug(tower)
        hang = br["hang_from"] or maze_entry_id
        base_color = existing[hang]["color"] if hang in existing else (0.604, 0.651, 0.69)
        shade_count[hang] = shade_count.get(hang, 0) + 1
        color = shade(base_color, shade_count[hang])
        # T2 sits at step 4 like the old branches: as many own stat nodes as fit after the hang node (two
        # after a step-1 node; one in Frost, whose tower paths start at step 2, and for the Building Buffer).
        hang_step = old_steps.get(hang, 1)
        stats = br["stats"][:3 - hang_step]
        prev = hang
        d = hang_step
        for sname, srank, sdesc in stats:
            sid = f"{ts}_{slug(sname)}"
            add(sid, sname, srank, sdesc, STAT, place.at(tower, d), color)
            if prev == hang and hang in existing:
                link_from(hang, sid)
            else:
                _link_new(new, prev, sid)
            prev = sid
            d += 1
        t2_id = f"{ts}_t2"
        add(t2_id, f"{tower} T2", 1, br["t2_text"] or f"Unlocks {element} {tower} T2", EVOLVE, place.at(tower, d), color)
        _link_new(new, prev, t2_id)
        lane_ends = []
        for lane, side in ((br["a"], -1.0), (br["b"], 1.0)):
            lprev = t2_id
            for i, (lname, lrank, ldesc) in enumerate(lane):
                lid = f"{ts}_{slug(lname)}"
                add(lid, lname, lrank, ldesc, STAT, place.at(tower, d + 1 + i, side), color)
                _link_new(new, lprev, lid)
                lprev = lid
            lane_ends.append(lprev)
        t3_id = f"{ts}_t3"
        add(t3_id, f"{tower} T3", 1, br["t3_text"] or f"Unlocks {element} {tower} T3", EVOLVE, place.at(tower, d + 4),
            color, one_way=[overall], needs=t2_id)
        for end in lane_ends:
            _link_new(new, end, t3_id)
        cname, cdesc = br["cap"]
        cap_id = f"{ts}_{slug(cname)}"
        add(cap_id, cname, 1, cdesc, CAPSTONE, place.at(tower, d + 5), color)
        _link_new(new, t3_id, cap_id)
    return new, extra_links


def _link_new(new, from_id, to_id):
    for n in new:
        if n["id"] == from_id:
            n["links"].append(to_id)
            return
    raise KeyError(from_id)


def add_tree(tree_id):
    path = TREES / f"{tree_id}_tree.tres"
    text = path.read_text(encoding="utf-8")
    if MARK in text:
        print(f"{path.name}: already has the new tower paths (use --remove first)")
        return
    existing = parse_nodes(text)
    new, extra_links = make_nodes(tree_id, existing)
    for old_id, targets in extra_links.items():
        res = existing[old_id]["res"]
        block = re.search(rf'\[sub_resource type="Resource" id="{res}"\]\n(.*?)(?=\n\[|\Z)', text, re.S)
        body = block[1]
        m = re.search(r"^links = Array\[StringName\]\(\[(.*)\]\)$", body, re.M)
        added = ", ".join(f'&"{t}"' for t in targets)
        if m:
            new_body = body[:m.start()] + f"links = Array[StringName]([{m[1]}, {added}])" + body[m.end():]
        else:
            new_body = re.sub(r"(^color = .*$)", rf"\1\nlinks = Array[StringName]([{added}])", body, count=1, flags=re.M)
        text = text[:block.start(1)] + new_body + text[block.end(1):]
    blocks = "\n".join(node_text(n) for n in new)
    ids = " ".join(n["id"] for n in new)
    links_note = " ".join(f"{k}>{'+'.join(v)}" for k, v in extra_links.items())
    marker = f"; {MARK} ids: {ids}\n; {MARK} links: {links_note}\n"
    text = text.replace("\n[resource]\n", "\n" + blocks + "\n" + marker + "\n[resource]\n", 1)
    refs = ", ".join(f'SubResource("Node_{n["id"]}")' for n in new)
    text = re.sub(r"^(nodes = Array\[ExtResource\(\"2_node\"\)\]\(\[.*)\]\)$", rf"\1, {refs}])", text, count=1, flags=re.M)
    path.write_text(text, encoding="utf-8")
    print(f"{path.name}: +{len(new)} nodes ({len(existing) + len(new)} in all)")


def remove_tree(tree_id):
    path = TREES / f"{tree_id}_tree.tres"
    text = path.read_text(encoding="utf-8")
    m = re.search(rf"^; {MARK} ids: (.*)$", text, re.M)
    if not m:
        print(f"{path.name}: nothing to remove")
        return
    ids = m[1].split()
    links = re.search(rf"^; {MARK} links: (.*)$", text, re.M)[1].split()
    for nid in ids:
        text = re.sub(rf'\[sub_resource type="Resource" id="Node_{nid}"\]\n.*?\n\n', "", text, count=1, flags=re.S)
        text = text.replace(f', SubResource("Node_{nid}")', "")
    for entry in links:
        old_id, targets = entry.split(">")
        for t in targets.split("+"):
            text = text.replace(f', &"{t}"', "").replace(f'links = Array[StringName]([&"{t}"])\n', "")
    text = re.sub(rf"^; {MARK} .*\n", "", text, flags=re.M)
    text = text.replace("\n\n\n[resource]", "\n\n[resource]")
    path.write_text(text, encoding="utf-8")
    print(f"{path.name}: -{len(ids)} nodes")


def main():
    remove = "--remove" in sys.argv
    for tree_id in TREE_DATA:
        (remove_tree if remove else add_tree)(tree_id)


if __name__ == "__main__":
    main()
