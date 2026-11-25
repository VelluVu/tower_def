"""Write the tower evolve tiers T2 and T3 (EvolveTierData) and wire them in:

    python tools/tier_data.py

- scenes/unit/evolve_tree/tiers/<tower>_<element>_t<n>_frames.tres: SpriteFrames from the T2/T3 sheets drawn by
  tools/sprite/parts/tower_tiers.py (regions found on each packed .png like tools/enemy_scene.py does)
- scenes/unit/evolve_tree/tiers/<tower>_<element>_t<n>.tres: the tier (title, info, talent node, stat steps, frames)
- each tower's ElementEvolveLeaf gets tiers = [T2, T3]; the tower upgrade data gets tier_upgrades [2, 3, 3]
  (Base, Up 1, Up 2, T1, Up 3, T2, T3)
- the tier talent nodes get an UnlockTier effect, so the menu and the bot count them as working

The effects live in TIERS below: every tier has a placeholder stat step; the decided tiers that existing stats can do
get their mechanic too (Fire Nova: always ignites, then a second burst; Physical and Frost Beamer T2: chain to one
more enemy). The rest wait for their mechanics (pierce, explosions, freeze, ground effects, clouds). Rerun after a
change; it rewrites the tier files and is safe to run twice.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import enemy_scene as es

ROOT = es.ROOT
OUT = "scenes/unit/evolve_tree/tiers"
ART = "assets/art/units/building/puffe/puffe_%s/%s_t%d"
TOWERS = ("bolter", "nova", "beamer", "mortar", "buffer", "breather", "spotter", "harpooner", "hatchery", "egg_bomb",
          "spike_field", "hoard", "shredder", "elder_drake")
# the towers whose talent nodes are named after them (<tower>_t2, <tower>_t3), in the tree of their element
OWN_NODE_TOWERS = ("mortar", "buffer", "breather", "spotter", "harpooner", "hatchery", "egg_bomb",
                   "spike_field", "hoard", "shredder", "elder_drake")
# the Buffer never attacks: its tiers have no stat steps, their effects live in BufferAuras (2026-11-24); the Hoard
# Keeper neither: every tier is one more upgrade step, so one more gold a wave (HoardKeeper.get_pay)
NO_STEP_TOWERS = ("buffer", "hoard")
# scene file and art folder names where they differ from puffe_<tower>
SCENE = {"egg_bomb": "egg_bomb", "leopard_trap": "leopard_trap", "spike_field": "spike_field", "elder_drake": "puffe_elder"}
ART_TOWER = {"elder_drake": "elder"}
# the Leopard Trap's elements (tools/trap_elements.py, 2026-11-16): no tier art, its own scene and talent nodes
TRAP = "leopard_trap"
ELEMENTS = ("physical", "fire", "frost", "poison")
LEAF = {"physical": "PhysicalElementEvolveLeaf", "fire": "FireElementEvolveLeaf",
        "frost": "FrostElementEvolveLeaf", "poison": "PoisonElementEvolveLeaf"}
COLOUR = {"physical": "", "fire": "red", "frost": "blue", "poison": "green"}
LOOPING = ("IDLE", "ATTACK")
# stat type numbers (Utils.StatType) and modify types (Utils.ModifyType: Flat 0, Multiply 1, Additive 2)
DAMAGE, ATTACK_SPEED, EFFECT_CHANCE, EXTRA_SHOTS, CHAIN_TARGETS = 2, 6, 11, 16, 17
EFFECT_POTENCY, EFFECT_DURATION, EFFECT_STACKS, EFFECT_TICK_RATE, RICOCHET = 10, 12, 13, 14, 15
SPLASH_RADIUS, FREEZE_CHANCE, FREEZE_DURATION, PIERCE, KNOCKBACK, PATCH_DURATION, PATCH_SHARE = 20, 21, 22, 23, 24, 25, 26
LINE_HITS, SPLIT_COUNT, SPLIT_SHARE, POISON_SPREAD, CONE_WIDTH, MARK_SHARE, EXECUTE_BELOW = 27, 28, 29, 30, 31, 32, 33
TETHER_TIME, TETHER_SLOW = 34, 35
GUARD_HEALTH, GUARD_COUNT = 36, 37
FLAT, ADDITIVE = 0, 2
STEP = {2: [("Damage", DAMAGE, ADDITIVE, 0.25, True)],
        3: [("Damage", DAMAGE, ADDITIVE, 0.4, True), ("Attack Speed", ATTACK_SPEED, FLAT, 0.15, True)]}
STEP_INFO = {2: "Damage +25%", 3: "Damage +40%, attack speed +15%"}
# (tower, element, tier): extra stat steps and their text
TIERS = {
    ("nova", "fire", 2): ([("Always Ignites", EFFECT_CHANCE, FLAT, 1.0, False)], "Bursts always ignite"),
    ("nova", "fire", 3): ([("Second Burst", EXTRA_SHOTS, FLAT, 1.0, False)], "Two bursts per cast"),
    ("beamer", "physical", 2): ([("Chain", CHAIN_TARGETS, FLAT, 1.0, False)], "The beam chains to a second enemy"),
    ("beamer", "frost", 2): ([("Chain", CHAIN_TARGETS, FLAT, 1.0, False)], "The beam chains to one more enemy"),
    # 2026-11-16: the rest, with the splash and freeze mechanics (TowerHitEffects); "(for now)" marks a stand-in from
    # existing stats until the decided mechanic exists (pierce as a bounce, line hits as chains, clouds and ground
    # effects as more potency, knockback as a short stagger)
    ("bolter", "physical", 2): ([("Pierce", PIERCE, FLAT, 1.0, False)], "Bolts pierce: they fly on through their target to the enemy behind"),
    ("bolter", "physical", 3): ([("Double Shot", EXTRA_SHOTS, FLAT, 1.0, False)], "A second bolt after each shot"),
    ("bolter", "fire", 2): ([("Explosive Bolts", SPLASH_RADIUS, FLAT, 0.75, False)], "Bolts explode: half damage to enemies within 0.75 tiles"),
    ("bolter", "fire", 3): ([("Burning Ground", PATCH_DURATION, FLAT, 2.0, False), ("Ground Heat", PATCH_SHARE, FLAT, 0.25, False)],
                            "Bolts leave burning ground for 2 s (a quarter of the hit a second)"),
    ("bolter", "frost", 2): ([("Splitting Shards", SPLIT_COUNT, FLAT, 2.0, False), ("Shard Edge", SPLIT_SHARE, FLAT, 0.3, False)],
                             "Shards split to the 2 nearest enemies, 30% of the hit each"),
    ("bolter", "frost", 3): ([("Freezing Hits", FREEZE_CHANCE, FLAT, 0.15, False), ("Freeze Time", FREEZE_DURATION, FLAT, 0.5, False)],
                             "15% of hits freeze for 0.5 s"),
    ("bolter", "poison", 2): ([("Pierce", PIERCE, FLAT, 1.0, False)], "Bolts pierce: they fly on through their target to the enemy behind"),
    ("bolter", "poison", 3): ([("Poison Cloud", PATCH_DURATION, FLAT, 3.0, False), ("Cloud Venom", PATCH_SHARE, FLAT, 0.2, False)],
                              "Impacts leave a poison cloud for 3 s"),
    ("nova", "physical", 2): ([("Knockback", KNOCKBACK, FLAT, 1.0, False)], "Bursts push enemies back a cell along their path"),
    ("nova", "physical", 3): ([("Stun", FREEZE_CHANCE, FLAT, 1.0, False), ("Stun Time", FREEZE_DURATION, FLAT, 0.3, False)],
                              "Bursts stun for 0.3 s"),
    ("nova", "frost", 2): ([("Chilled Ground", PATCH_DURATION, FLAT, 1.0, False), ("Ground Cold", PATCH_SHARE, FLAT, 0.2, False)],
                           "Bursts leave chilled ground for 1 s"),
    ("nova", "frost", 3): ([("Deep Freeze", FREEZE_CHANCE, FLAT, 0.33, False), ("Freeze Time", FREEZE_DURATION, FLAT, 1.0, False)],
                           "A third of the bursts freeze for 1 s"),
    ("nova", "poison", 2): ([("Double Dose", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Dose", EFFECT_CHANCE, FLAT, 0.5, False)],
                            "Bursts stack poison faster"),
    ("nova", "poison", 3): ([("Poison Cloud", PATCH_DURATION, FLAT, 2.0, False), ("Cloud Venom", PATCH_SHARE, FLAT, 0.2, False)],
                            "Bursts leave a poison cloud for 2 s"),
    ("beamer", "physical", 3): ([("Line Hits", LINE_HITS, FLAT, 1.0, False)], "The beam hits every enemy along its line"),
    ("beamer", "fire", 2): ([("Burning Line", LINE_HITS, FLAT, 1.0, False)], "The beam burns everything along its line"),
    ("beamer", "fire", 3): ([("Rising Heat", EFFECT_TICK_RATE, FLAT, 0.5, True)], "Burns tick 50% faster"),
    ("beamer", "frost", 3): ([("Holding Frost", FREEZE_CHANCE, FLAT, 0.03, False), ("Freeze Time", FREEZE_DURATION, FLAT, 3.0, False)],
                             "Held targets now and then freeze for 3 s"),
    ("beamer", "poison", 2): ([("Fast Venom", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Venom", EFFECT_CHANCE, FLAT, 0.5, False)],
                              "Stacks build twice as fast"),
    ("beamer", "poison", 3): ([("Spreading Venom", POISON_SPREAD, FLAT, 1.0, False)], "Poison jumps to the nearest enemy when the target dies"),
    # the trap evolves (design doc Trap evolves); the Leopard cub and the double snap wait for their mechanics
    ("leopard_trap", "physical", 2): ([("Quick Springs", ATTACK_SPEED, FLAT, 0.25, True)], "(for now: re-arms 25% faster; the leopard cub comes later)"),
    ("leopard_trap", "physical", 3): ([("Double Snap", SPLASH_RADIUS, FLAT, 0.75, False)], "(for now: the snap also hits enemies within 0.75 tiles)"),
    ("leopard_trap", "fire", 2): ([("Bigger Blaze", PATCH_DURATION, FLAT, 2.0, False), ("Hotter Ground", PATCH_SHARE, FLAT, 0.2, False)],
                                  "A bigger, longer burning patch: 4 s"),
    ("leopard_trap", "fire", 3): ([("Explosive Snap", SPLASH_RADIUS, FLAT, 1.25, False)], "Explodes on trigger: half the hit to enemies within 1.25 tiles"),
    ("leopard_trap", "frost", 2): ([("Frost Burst", SPLASH_RADIUS, FLAT, 1.0, False)], "The snap chills enemies within 1 tile too"),
    ("leopard_trap", "frost", 3): ([("Deep Freeze", FREEZE_DURATION, FLAT, 1.0, False)], "The root becomes a 1.5 s freeze"),
    ("leopard_trap", "poison", 2): ([("Thick Cloud", PATCH_DURATION, FLAT, 2.0, False), ("Cloud Venom", PATCH_SHARE, FLAT, 0.2, False)],
                                    "The cloud lasts 5 s and stings harder"),
    ("leopard_trap", "poison", 3): ([("Spreading Venom", POISON_SPREAD, FLAT, 2.0, False)], "Poison spreads to 2 enemies when a poisoned enemy dies to it"),
    # the Mortar (2026-11-24, design doc New Towers: cluster shells, a crater that slows, a rolling shell later)
    # the Buffer (2026-11-24): T2 weakens the enemies in the aura, T3 roars; the element's chance grows (Buffer.gd)
    **{("buffer", e, 2): ([], "Enemies in the aura take 10% more damage" + ("" if e == "physical" else "; the element rides on 25% of hits"))
       for e in ELEMENTS},
    **{("buffer", e, 3): ([], "Commander's Roar: every 12 s the buffed towers attack 0.4 faster for 3 s"
                          + ("" if e == "physical" else "; the element rides on 30% of hits")) for e in ELEMENTS},
    ("mortar", "physical", 2): ([("Cluster Shells", SPLIT_COUNT, FLAT, 3.0, False), ("Cluster Bite", SPLIT_SHARE, FLAT, 0.35, False)],
                                "Shells break into 3 bomblets that hit the nearest enemies for 35% of the hit"),
    ("mortar", "physical", 3): ([("Earthshaker", SPLASH_RADIUS, FLAT, 0.5, False), ("Shockwave", KNOCKBACK, FLAT, 1.0, False)],
                                "A bigger blast (+0.5 tiles); the enemy at its centre is thrown back a cell"),
    ("mortar", "fire", 2): ([("Napalm", PATCH_DURATION, FLAT, 2.0, False), ("Napalm Heat", PATCH_SHARE, FLAT, 0.15, False)],
                            "The burning ground lasts 2 s longer and burns hotter"),
    ("mortar", "fire", 3): ([("Second Shell", EXTRA_SHOTS, FLAT, 1.0, False)], "A second shell after each shot"),
    ("mortar", "frost", 2): ([("Frozen Crater", PATCH_DURATION, FLAT, 2.0, False), ("Crater Cold", PATCH_SHARE, FLAT, 0.15, False)],
                             "Shells leave a freezing crater that hurts for 2 s"),
    ("mortar", "frost", 3): ([("Hailstorm", FREEZE_CHANCE, FLAT, 0.3, False), ("Freeze Time", FREEZE_DURATION, FLAT, 0.8, False),
                              ("Wide Hail", SPLASH_RADIUS, FLAT, 0.25, False)],
                             "A wider blast (+0.25 tiles); 30% of shells freeze the enemy at the centre for 0.8 s"),
    ("mortar", "poison", 2): ([("Gas Shells", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Dose", EFFECT_CHANCE, FLAT, 0.3, False)],
                              "Shells stack poison faster on everything they hit"),
    ("mortar", "poison", 3): ([("Plague Barrage", POISON_SPREAD, FLAT, 2.0, False), ("Thick Gas", PATCH_DURATION, FLAT, 2.0, False)],
                              "The gas cloud lasts 2 s longer; poison jumps to 2 enemies when the centre enemy dies"),
    # the Breather (2026-11-24, design doc New Towers: T3 sweeps a wider arc); one direct hit per enemy per gust
    ("breather", "physical", 2): ([("Stunning Roar", FREEZE_CHANCE, FLAT, 0.3, False), ("Stun Time", FREEZE_DURATION, FLAT, 0.4, False)],
                                  "30% of the enemies a roar hits are stunned for 0.4 s"),
    ("breather", "physical", 3): ([("Thunder Roar", CONE_WIDTH, FLAT, 30.0, False), ("Shove", KNOCKBACK, FLAT, 1.0, False)],
                                  "A wider cone (+30 degrees); the roar throws enemies 2 cells back"),
    ("breather", "fire", 2): ([("Scorched Earth", PATCH_DURATION, FLAT, 2.0, False), ("Ground Heat", PATCH_SHARE, FLAT, 0.15, False)],
                              "The burning ground lasts 2 s longer and burns hotter"),
    ("breather", "fire", 3): ([("Dragonfire", CONE_WIDTH, FLAT, 30.0, False), ("Rising Heat", EFFECT_TICK_RATE, FLAT, 0.5, True)],
                              "A wider cone (+30 degrees); burns tick 50% faster"),
    ("breather", "frost", 2): ([("Frostbite", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Chill", EFFECT_CHANCE, FLAT, 0.3, False)],
                               "Slow stacks build faster"),
    ("breather", "frost", 3): ([("Winter's Breath", CONE_WIDTH, FLAT, 30.0, False), ("Freezing Gust", FREEZE_CHANCE, FLAT, 0.15, False),
                                ("Freeze Time", FREEZE_DURATION, FLAT, 0.8, False)],
                               "A wider cone (+30 degrees); each gust freezes 15% of the enemies it hits for 0.8 s"),
    ("breather", "poison", 2): ([("Choking Fumes", EFFECT_STACKS, FLAT, 2.0, False), ("Thick Cloud", PATCH_DURATION, FLAT, 1.0, False)],
                                "Poison stacks higher; the cloud lasts 1 s longer"),
    ("breather", "poison", 3): ([("Miasma", CONE_WIDTH, FLAT, 30.0, False), ("Spreading Venom", POISON_SPREAD, FLAT, 1.0, False)],
                                "A wider cone (+30 degrees); poison jumps to the nearest enemy when a poisoned enemy dies to it"),
    # the Spotter (2026-11-24, design doc New Towers: execute at a later tier); the marks grow at T3
    ("spotter", "physical", 2): ([("Piercing Bolt", PIERCE, FLAT, 1.0, False)], "Bolts fly on through their target to the enemy behind"),
    ("spotter", "physical", 3): ([("Execute", EXECUTE_BELOW, FLAT, 0.12, False)], "Hits kill enemies left under 12% health (not bosses)"),
    ("spotter", "fire", 2): ([("Explosive Bolt", SPLASH_RADIUS, FLAT, 0.75, False)], "Bolts explode: half damage to enemies within 0.75 tiles"),
    ("spotter", "fire", 3): ([("Searing Mark", MARK_SHARE, FLAT, 0.1, False), ("Burning Ground", PATCH_DURATION, FLAT, 2.0, False),
                              ("Ground Heat", PATCH_SHARE, FLAT, 0.2, False)],
                             "The mark grows to +20%; hits leave burning ground for 2 s"),
    ("spotter", "frost", 2): ([("Pinning Bolt", FREEZE_CHANCE, FLAT, 0.3, False), ("Pin Time", FREEZE_DURATION, FLAT, 0.8, False)],
                              "30% of hits freeze the target for 0.8 s"),
    ("spotter", "frost", 3): ([("Frozen Mark", MARK_SHARE, FLAT, 0.1, False), ("Ice Lance", PIERCE, FLAT, 2.0, False)],
                              "The mark grows to +20%; bolts pierce 2 enemies"),
    ("spotter", "poison", 2): ([("Deep Dose", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Dose", EFFECT_CHANCE, FLAT, 0.3, False)],
                               "Poison stacks higher and more surely"),
    ("spotter", "poison", 3): ([("Rotting Mark", MARK_SHARE, FLAT, 0.1, False), ("Plague Bolt", POISON_SPREAD, FLAT, 2.0, False)],
                               "The mark grows to +20%; poison jumps to 2 enemies when the target dies"),
    # the Harpooner (2026-11-24, design doc New Towers): every harpoon tethers; the tiers add to the hook
    ("harpooner", "physical", 2): ([("Heavy Yank", KNOCKBACK, FLAT, 1.0, False), ("Stagger", FREEZE_CHANCE, FLAT, 0.25, False),
                                    ("Stagger Time", FREEZE_DURATION, FLAT, 0.4, False)],
                                   "The yank throws enemies 2 cells back; 25% of hits stagger for 0.4 s"),
    ("harpooner", "physical", 3): ([("Skewer", PIERCE, FLAT, 1.0, False)], "The harpoon flies on through its target and chains the enemy behind too"),
    ("harpooner", "fire", 2): ([("Searing Hook", SPLASH_RADIUS, FLAT, 0.75, False)], "The hook bursts: half damage to enemies within 0.75 tiles"),
    ("harpooner", "fire", 3): ([("Drag to the Fire", PATCH_DURATION, FLAT, 2.0, False), ("Ground Heat", PATCH_SHARE, FLAT, 0.2, False)],
                               "Hits leave burning ground for 2 s"),
    ("harpooner", "frost", 2): ([("Ice Barbs", FREEZE_CHANCE, FLAT, 0.3, False), ("Ice Time", FREEZE_DURATION, FLAT, 0.8, False)],
                                "30% of hits freeze their target for 0.8 s"),
    ("harpooner", "frost", 3): ([("Anchor", TETHER_SLOW, FLAT, 0.15, False), ("Long Anchor", TETHER_TIME, FLAT, 1.5, False)],
                                "The tether slows 15 points more and lasts 1.5 s longer"),
    ("harpooner", "poison", 2): ([("Deep Barbs", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Barbs", EFFECT_CHANCE, FLAT, 0.3, False)],
                                 "More and surer poison stacks"),
    ("harpooner", "poison", 3): ([("Plague Hook", POISON_SPREAD, FLAT, 2.0, False)], "Poison jumps to 2 enemies when the target dies"),
    # the Hatchery (2026-11-25): the claws carry the tier effects (TowerHitEffects on every claw), the T3s add a guard
    # or make them tougher
    ("hatchery", "physical", 2): ([("Bruisers", GUARD_HEALTH, ADDITIVE, 0.5, True), ("Stunning Claws", FREEZE_CHANCE, FLAT, 0.2, False),
                                   ("Stun Time", FREEZE_DURATION, FLAT, 0.4, False)],
                                  "Guards are 50% tougher; 20% of claws stun for 0.4 s"),
    ("hatchery", "physical", 3): ([("Fourth Guard", GUARD_COUNT, FLAT, 1.0, False)], "A fourth guard holds the line"),
    ("hatchery", "fire", 2): ([("Scorched Ground", PATCH_DURATION, FLAT, 1.5, False), ("Ground Heat", PATCH_SHARE, FLAT, 0.2, False)],
                              "Claws leave burning ground for 1.5 s"),
    ("hatchery", "fire", 3): ([("Fire Breath", SPLASH_RADIUS, FLAT, 0.75, False), ("Fourth Guard", GUARD_COUNT, FLAT, 1.0, False)],
                              "Claws burst: half damage to enemies within 0.75 tiles; a fourth guard"),
    ("hatchery", "frost", 2): ([("Frozen Grip", FREEZE_CHANCE, FLAT, 0.2, False), ("Grip Time", FREEZE_DURATION, FLAT, 0.8, False)],
                               "20% of claws freeze for 0.8 s"),
    ("hatchery", "frost", 3): ([("Ice Scales", GUARD_HEALTH, ADDITIVE, 0.6, True), ("Fourth Guard", GUARD_COUNT, FLAT, 1.0, False)],
                               "Guards are 60% tougher; a fourth guard"),
    ("hatchery", "poison", 2): ([("Venom Glands", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Venom", EFFECT_CHANCE, FLAT, 0.3, False)],
                                "Poison stacks higher and more surely"),
    # the Egg Bomb (2026-11-25): the blast's centre enemy takes the direct hit, so freezes, patches and spread fire there
    ("egg_bomb", "physical", 2): ([("Shrapnel", SPLIT_COUNT, FLAT, 3.0, False), ("Shrapnel Bite", SPLIT_SHARE, FLAT, 0.3, False)],
                                  "The shell flies as shrapnel: 3 more hits on the nearest enemies for 30%"),
    ("egg_bomb", "physical", 3): ([("Big Egg", SPLASH_RADIUS, FLAT, 0.5, False), ("Shockwave", KNOCKBACK, FLAT, 1.0, False)],
                                  "A bigger blast (+0.5 tiles); the enemy at its centre is thrown back a cell"),
    ("egg_bomb", "fire", 2): ([("Fire Pit", PATCH_DURATION, FLAT, 2.0, False), ("Pit Heat", PATCH_SHARE, FLAT, 0.15, False)],
                              "The burning ground lasts 2 s longer and burns hotter"),
    ("egg_bomb", "fire", 3): ([("Inferno Egg", EFFECT_CHANCE, FLAT, 1.0, False), ("Wide Flames", SPLASH_RADIUS, FLAT, 0.5, False)],
                              "Everything the blast hits burns; a bigger blast (+0.5 tiles)"),
    ("egg_bomb", "frost", 2): ([("Frost Burst", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Chill", EFFECT_CHANCE, FLAT, 0.3, False)],
                               "The blast stacks its slow higher on everything it hits"),
    ("egg_bomb", "frost", 3): ([("Glacier Egg", FREEZE_DURATION, FLAT, 1.0, False), ("Wide Frost", SPLASH_RADIUS, FLAT, 0.5, False)],
                               "The centre freeze lasts 1 s longer; a bigger blast (+0.5 tiles)"),
    ("egg_bomb", "poison", 2): ([("Rotten Yolk", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Rot", EFFECT_CHANCE, FLAT, 0.3, False)],
                                "Poison stacks higher and more surely"),
    ("egg_bomb", "poison", 3): ([("Plague Egg", POISON_SPREAD, FLAT, 2.0, False), ("Thick Gas", PATCH_DURATION, FLAT, 2.0, False)],
                                "The gas cloud lasts 2 s longer; poison jumps to 2 enemies when the centre enemy dies"),
    # the second round (2026-11-25): Spike Field, Hoard Keeper (no steps: a tier is one more gold a wave), Shredder,
    # Elder Drake; every strike, pulse or bite is a direct hit, so TowerHitEffects fire on each enemy it lands on
    ("spike_field", "physical", 2): ([("Quick Springs", ATTACK_SPEED, FLAT, 0.25, True)], "The spikes strike 25% more often"),
    ("spike_field", "physical", 3): ([("Impale", FREEZE_CHANCE, FLAT, 0.2, False), ("Impale Time", FREEZE_DURATION, FLAT, 0.5, False)],
                                     "20% of the enemies struck are pinned for 0.5 s"),
    ("spike_field", "fire", 2): ([("Red-Hot Spikes", EFFECT_CHANCE, FLAT, 1.0, False)], "Every strike ignites"),
    ("spike_field", "fire", 3): ([("Forge Heat", EFFECT_TICK_RATE, FLAT, 0.5, True), ("Deep Burns", EFFECT_STACKS, FLAT, 1.0, False)],
                                 "Burns tick 50% faster and stack once more"),
    ("spike_field", "frost", 2): ([("Ice Barbs", EFFECT_STACKS, FLAT, 2.0, False)], "Slow stacks build higher"),
    ("spike_field", "frost", 3): ([("Frozen Field", FREEZE_CHANCE, FLAT, 0.15, False), ("Freeze Time", FREEZE_DURATION, FLAT, 0.8, False)],
                                  "15% of the enemies struck freeze for 0.8 s"),
    ("spike_field", "poison", 2): ([("Venom Tips", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Venom", EFFECT_CHANCE, FLAT, 0.3, False)],
                                   "Poison stacks higher and more surely"),
    ("spike_field", "poison", 3): ([("Spreading Venom", POISON_SPREAD, FLAT, 2.0, False)], "Poison jumps to 2 enemies when a poisoned enemy dies"),
    ("hoard", "physical", 2): ([], "+1 gold a wave"), ("hoard", "physical", 3): ([], "+1 gold a wave"),
    ("hoard", "fire", 2): ([], "+1 gold a wave"), ("hoard", "fire", 3): ([], "+1 gold a wave"),
    ("hoard", "frost", 2): ([], "+1 gold a wave"), ("hoard", "frost", 3): ([], "+1 gold a wave"),
    ("hoard", "poison", 2): ([], "+1 gold a wave"), ("hoard", "poison", 3): ([], "+1 gold a wave"),
    ("shredder", "physical", 2): ([("Shove", KNOCKBACK, FLAT, 1.0, False)], "Pulses push enemies a cell back"),
    ("shredder", "physical", 3): ([("Twin Pulse", EXTRA_SHOTS, FLAT, 1.0, False)], "Two pulses per cast: the shred stacks twice as fast"),
    ("shredder", "fire", 2): ([("Scorched Ground", PATCH_DURATION, FLAT, 1.5, False), ("Ground Heat", PATCH_SHARE, FLAT, 0.2, False)],
                              "Pulses leave burning ground for 1.5 s"),
    ("shredder", "fire", 3): ([("Always Ignites", EFFECT_CHANCE, FLAT, 1.0, False), ("Twin Pulse", EXTRA_SHOTS, FLAT, 1.0, False)],
                              "Pulses always ignite; two pulses per cast"),
    ("shredder", "frost", 2): ([("Brittle", FREEZE_CHANCE, FLAT, 0.2, False), ("Freeze Time", FREEZE_DURATION, FLAT, 0.5, False)],
                               "20% of the enemies a pulse hits freeze for 0.5 s"),
    ("shredder", "frost", 3): ([("Twin Pulse", EXTRA_SHOTS, FLAT, 1.0, False), ("Deep Cold", EFFECT_STACKS, FLAT, 1.0, False)],
                               "Two pulses per cast; slow stacks once more"),
    ("shredder", "poison", 2): ([("Corroding Dose", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Dose", EFFECT_CHANCE, FLAT, 0.3, False)],
                                "Poison stacks higher and more surely"),
    ("shredder", "poison", 3): ([("Twin Pulse", EXTRA_SHOTS, FLAT, 1.0, False), ("Spreading Rot", POISON_SPREAD, FLAT, 2.0, False)],
                                "Two pulses per cast; poison jumps to 2 enemies when a poisoned enemy dies"),
    ("elder_drake", "physical", 2): ([("Piercing Bite", PIERCE, FLAT, 1.0, False)], "Bites fly on through their target to the enemy behind"),
    ("elder_drake", "physical", 3): ([("Crushing Bite", SPLASH_RADIUS, FLAT, 1.0, False), ("Throw", KNOCKBACK, FLAT, 1.0, False)],
                                     "Bites crush: half damage within 1 tile, the target thrown a cell back"),
    ("elder_drake", "fire", 2): ([("Explosive Bite", SPLASH_RADIUS, FLAT, 0.75, False)], "Bites explode: half damage to enemies within 0.75 tiles"),
    ("elder_drake", "fire", 3): ([("Scorched Earth", PATCH_DURATION, FLAT, 3.0, False), ("Ground Heat", PATCH_SHARE, FLAT, 0.25, False)],
                                 "Hits leave burning ground for 3 s"),
    ("elder_drake", "frost", 2): ([("Freezing Bite", FREEZE_CHANCE, FLAT, 0.25, False), ("Freeze Time", FREEZE_DURATION, FLAT, 0.8, False)],
                                  "25% of hits freeze for 0.8 s"),
    ("elder_drake", "frost", 3): ([("Shattering Bite", SPLIT_COUNT, FLAT, 2.0, False), ("Shard Edge", SPLIT_SHARE, FLAT, 0.4, False)],
                                  "Shards split to the 2 nearest enemies, 40% of the hit each"),
    ("elder_drake", "poison", 2): ([("Deep Venom", EFFECT_STACKS, FLAT, 2.0, False), ("Sure Venom", EFFECT_CHANCE, FLAT, 0.3, False)],
                                   "Poison stacks higher and more surely"),
    ("elder_drake", "poison", 3): ([("Plague Breath", POISON_SPREAD, FLAT, 2.0, False), ("Poison Cloud", PATCH_DURATION, FLAT, 3.0, False),
                                    ("Cloud Venom", PATCH_SHARE, FLAT, 0.2, False)],
                                   "Hits leave a poison cloud for 3 s; poison jumps to 2 enemies when a poisoned enemy dies"),
    ("hatchery", "poison", 3): ([("Plague Brood", POISON_SPREAD, FLAT, 2.0, False), ("Fourth Guard", GUARD_COUNT, FLAT, 1.0, False)],
                                "Poison jumps to 2 enemies when a held enemy dies; a fourth guard"),
}


def art_name(tower, element):
    if tower == "bolter":
        return "puffe_bolter" + ("_" + COLOUR[element] if COLOUR[element] else "")
    return (COLOUR[element] + "_" if COLOUR[element] else "") + "puffe_" + tower


def talent(tower, element, tier):
    if tower == TRAP:
        return ("building", "leopard_t%d" % tier) if element == "physical" else (element, "trap_t%d" % tier)
    # the Hoard Keeper's branch is only in the Building tree (the user, 2026-11-25): its nodes unlock every element
    if tower == "hoard":
        return "building", "hoard_keeper_t%d" % tier
    if tower in OWN_NODE_TOWERS:
        return ("building" if element == "physical" else element), "%s_t%d" % (tower, tier)
    if element == "physical":
        return "building", "phys_t%d" % tier
    return element, "%s_t%d" % (tower, tier)


def write(path, text):
    with open(os.path.join(ROOT, path), "w", encoding="utf8", newline="\n") as f:
        f.write(text)


def frames(tower, element, tier):
    if tower == TRAP:
        return None
    art_tower = ART_TOWER.get(tower, tower)
    base = ART % (art_tower, art_name(art_tower, element), tier)
    #the Egg Bomb's sheets are its own, not a drakeling's
    if tower == "egg_bomb":
        base = "assets/art/units/building/egg_bomb/%s_egg_bomb_t%d" % (element, tier)
    if tower == "spike_field":
        base = "assets/art/units/building/spike_field/%sspike_field_t%d" % ("" if element == "physical" else element + "_", tier)
    aseprite, png = os.path.join(ROOT, base + ".aseprite"), os.path.join(ROOT, base + ".png")
    w, h, durs, tags = es.info(aseprite)
    where = es.regions(aseprite, png, w, h, len(durs))
    text = '[gd_resource type="SpriteFrames" format=3]\n\n[ext_resource type="Texture2D" path="res://%s.png" id="1_sheet"]\n\n' % base
    anims = []
    for tag, a, b in tags:
        refs = []
        for i in range(a, b + 1):
            text += '[sub_resource type="AtlasTexture" id="AtlasTexture_f%02d"]\natlas = ExtResource("1_sheet")\nregion = Rect2(%d, %d, %d, %d)\n\n' % (
                i, where[i][0], where[i][1], w, h)
            refs.append('{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_f%02d")\n}' % i)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (
            ", ".join(refs), "true" if tag in (("IDLE",) if tower == "egg_bomb" else LOOPING) else "false", tag, 1000.0 / durs[a]))
    text += "[resource]\nanimations = [%s]\n" % ", ".join(anims)
    path = "%s/%s_%s_t%d_frames.tres" % (OUT, tower, element, tier)
    write(path, text)
    return path


def tier_data(tower, element, tier, frames_path):
    extra, extra_info = TIERS.get((tower, element, tier), ([], ""))
    tree, node = talent(tower, element, tier)
    text = ('[gd_resource type="Resource" script_class="EvolveTierData" format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="1_tier"]\n'
            '[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_resource.gd" id="2_evolve"]\n'
            + ('[ext_resource type="SpriteFrames" path="res://%s" id="3_frames"]\n' % frames_path if frames_path else '') + '\n')
    ids = []
    steps = extra if tower in NO_STEP_TOWERS else STEP[tier] + extra
    for i, (name, stat, modify, value, percent) in enumerate(steps):
        text += ('[sub_resource type="Resource" id="Resource_step%d"]\nscript = ExtResource("2_evolve")\nmodifier_type = 0\n'
                 'elements = 15\nmodify_stat_type = %d\nmodify_type = %d\nis_randomized_modify_value = false\n'
                 'is_percent = %s\nmodify_value = %s\nevolve_name = "%s"\n\n') % (
            i, stat, modify, "true" if percent else "false", repr(float(value)), name)
        ids.append('SubResource("Resource_step%d")' % i)
    info = ". ".join(s for s in (extra_info, "" if tower in NO_STEP_TOWERS else STEP_INFO[tier]) if s)
    text += ('[resource]\nscript = ExtResource("1_tier")\ntitle = "T%d"\ninfo = "%s"\ntalent_tree = &"%s"\ntalent_node = &"%s"\n'
             'upgrade_resources = Array[ExtResource("2_evolve")]([%s])\n') % (
        tier, info, tree, node, ", ".join(ids))
    #the trap has no tier art: its sprite stays
    if frames_path:
        text += 'sprite_frames = ExtResource("3_frames")\n'
    path = "%s/%s_%s_t%d.tres" % (OUT, tower, element, tier)
    write(path, text)
    return path


def wire_leaves(tower, paths):
    scene = "scenes/unit/building/buildings/%s.tscn" % SCENE.get(tower, "puffe_" + tower)
    text = open(os.path.join(ROOT, scene), encoding="utf8").read()
    for element in ELEMENTS:
        ids = []
        for tier in (2, 3):
            ext_id = "tier_%s_t%d" % (element, tier)
            ids.append('ExtResource("%s")' % ext_id)
            if 'id="%s"' % ext_id not in text:
                last = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
                text = text[:last] + '[ext_resource type="Resource" path="res://%s" id="%s"]\n' % (paths[(element, tier)], ext_id) + text[last:]
        m = re.search(r'\[node name="%s" type="Node" parent="[^"]+"\]\n(?:[^\[\n][^\n]*\n)*' % LEAF[element], text)
        block = re.sub(r'tiers = [^\n]*\n', '', m.group(0))
        block = block.rstrip("\n") + "\ntiers = Array[ExtResource(\"%s\")]([%s])\n" % ("tier_script", ", ".join(ids))
        text = text[:m.start()] + block + text[m.end():]
    if 'id="tier_script"' not in text:
        last = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
        text = text[:last] + '[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="tier_script"]\n' + text[last:]
    write(scene, text)


def rhythm(tower):
    path = "scenes/upgrades/building_upgrades/%s_upgrade_data.tres" % tower
    text = open(os.path.join(ROOT, path), encoding="utf8").read()
    text = re.sub(r'tier_upgrades = [^\n]*\n', '', text)
    # the last section is [resource]; a default upgrades_per_tier is not written, so append instead of replacing
    text = text.rstrip("\n") + "\ntier_upgrades = Array[int](%s)" % ("[2, 5, 8]" if tower == "buffer" else "[2, 3, 3]") + "\n"
    write(path, text)


def unlock_effects():
    # TalentEffect flags: buildings Bolter 1, Nova 2, Beamer 4, Trap 8, Mortar 32; elements Physical 1, Fire 2, Frost 4, Poison 8
    tower_flag = {"bolter": 1, "nova": 2, "beamer": 4, TRAP: 8, "mortar": 32, "buffer": 64, "breather": 128, "spotter": 256, "harpooner": 512, "hatchery": 1024, "egg_bomb": 2048,
                  "spike_field": 4096, "hoard": 8192, "shredder": 16384, "elder_drake": 32768}
    element_flag = {"physical": 1, "fire": 2, "frost": 4, "poison": 8}
    unlocks = {}
    for t in TOWERS + (TRAP,):
        for e in ELEMENTS:
            for n in (2, 3):
                key = talent(t, e, n)
                flags = unlocks.get(key, (0, 0))
                unlocks[key] = (flags[0] | tower_flag[t], flags[1] | element_flag[e])
    for tree in ("building", "fire", "frost", "poison"):
        path = "scenes/talents/trees/%s_tree.tres" % tree
        text = open(os.path.join(ROOT, path), encoding="utf8").read()
        effect_script = re.search(r'\[ext_resource type="Script"[^\]]*path="res://scenes/talents/talent_effect.gd" id="([^"]+)"\]', text).group(1)
        # one effect per unlock node, with the towers and element it unlocks (the bot's build fit reads them)
        text = re.sub(r'\[sub_resource type="Resource" id="TalentEffect_unlock_[^"]*"\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
        for (t, node), (buildings, elements) in sorted(unlocks.items()):
            if t != tree:
                continue
            effect_id = "TalentEffect_unlock_%s" % node
            first = text.index("[sub_resource")
            text = text[:first] + ('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("%s")\nkind = 2\nbuildings = %d\nelements = %d\n\n'
                                   % (effect_id, effect_script, buildings, elements)) + text[first:]
            m = re.search(r'\[sub_resource type="Resource" id="[^"]+"\]\n(?:[^\[\n][^\n]*\n)*?id = &"%s"\n(?:[^\[\n][^\n]*\n)*' % node, text)
            # a tower whose talent branch is not in the tree yet: its tiers stay locked, no effect to hang
            if m is None:
                print("  no talent node %s in the %s tree yet" % (node, tree))
                text = text.replace(('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("%s")\nkind = 2\nbuildings = %d\nelements = %d\n\n'
                                     % (effect_id, effect_script, buildings, elements)), "")
                continue
            block = re.sub(r'effects = [^\n]*\n', '', m.group(0))
            block = block.rstrip("\n") + '\neffects = Array[ExtResource("%s")]([SubResource("%s")])\n' % (effect_script, effect_id)
            text = text[:m.start()] + block + text[m.end():]
        write(path, text)


def main():
    os.makedirs(os.path.join(ROOT, OUT), exist_ok=True)
    for tower in TOWERS + (TRAP,):
        paths = {}
        for element in ELEMENTS:
            for tier in (2, 3):
                paths[(element, tier)] = tier_data(tower, element, tier, frames(tower, element, tier))
        wire_leaves(tower, paths)
        rhythm(tower)
        print(tower, "tiers written")
    unlock_effects()
    print("talent unlocks set")


if __name__ == "__main__":
    main()
