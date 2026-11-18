"""Gives talent nodes that had no effect the level-wide effects built on 2026-11-16 (TalentEffect kinds Vulnerability,
Weakness, MazeSlow, TurnPause, CardOffer, EarlyStartBonus, WaveGold, UpgradeDiscount, FreezeLonger, FreezeExtra, Mending,
WallThorns, WallArmor; the Fortress unlock) and, the same day, the mechanics (Strike, DeathBurst, CastleDragon, per-stack
Vulnerability: TalentMechanics) of the capstones and signature nodes; "description" in the extra fields rewrites the
node's text where the built mechanic differs from it. Skips a node that already has effects, so it is safe to run twice.

    python tools/talent_effects_2026_11.py
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TREES = os.path.join(ROOT, "scenes", "talents", "trees")
KIND = {"BuildingStat": 0, "UnlockTier": 2, "Vulnerability": 3, "Weakness": 4, "MazeSlow": 5, "TurnPause": 6, "CardOffer": 7, "EarlyStartBonus": 8,
        "WaveGold": 9, "UpgradeDiscount": 10, "FreezeLonger": 11, "FreezeExtra": 12, "Mending": 13, "WallThorns": 14, "WallArmor": 15,
        "Strike": 16, "DeathBurst": 17, "CastleDragon": 18, "SellRefund": 19, "FirstUpgradeDiscount": 20}
STRIKE = {"Blast": 0, "Freeze": 1, "Stacks": 2, "Split": 3}
FIRE, FROST, POISON = 2, 4, 8
CONDITION = {"Burning": 1, "Poisoned": 2, "Frozen": 3, "Chilled": 4}
BOLTER, NOVA, BEAMER, TRAP, WALL = 1, 2, 4, 8, 16
PHYSICAL, ELEMENTS = 1, 14

# tree file: node id -> (kind, value per rank, extra fields)
EFFECTS = {
    "building_tree.tres": {
        "fortress_t1": ("UnlockTier", 1.0, {"buildings": WALL, "elements": PHYSICAL}),
        # resistance penetration (StatType 18) and critical penetration (19)
        "piercing": ("BuildingStat", 0.1, {"buildings": BOLTER | NOVA | BEAMER | TRAP, "elements": PHYSICAL, "stat_type": 18, "modify_type": 0}),
        "shatter": ("BuildingStat", 1.0, {"buildings": BOLTER | NOVA | BEAMER, "elements": PHYSICAL, "stat_type": 19, "modify_type": 0}),
        "titan_claws": ("BuildingStat", 0.15, {"buildings": TRAP, "stat_type": 18, "modify_type": 0}),
        "fortress_t2": ("UnlockTier", 1.0, {"buildings": WALL, "elements": 1}),
        "fortress_t3": ("UnlockTier", 1.0, {"buildings": WALL, "elements": 1}),
        "narrow_ways": ("MazeSlow", 0.03, {}),
        "dragons_maze": ("MazeSlow", 0.10, {}),
        "sharp_corners": ("TurnPause", 0.05, {}),
        "scholar": ("CardOffer", 1.0, {}),
        "bold_start": ("EarlyStartBonus", 0.5, {}),
        "spoils": ("WaveGold", 1.0, {}),
        "haggling": ("UpgradeDiscount", 0.1, {}),
        "mending": ("Mending", 0.02, {}),
        "spiked_stones": ("WallThorns", 0.25, {}),
        "stubborn_stone": ("WallArmor", 0.05, {}),
        "iron_bands": ("WallArmor", 0.10, {"elements": PHYSICAL}),
        "warded_stones": ("WallArmor", 0.10, {"elements": ELEMENTS}),
    },
    "fire_tree.tres": {
        "heat_haze": ("Vulnerability", 0.04, {"condition": "Burning"}),
        "overheat": ("Vulnerability", 0.10, {"condition": "Burning", "buildings": NOVA}),
        "flashover": ("Vulnerability", 0.20, {"condition": "Burning", "buildings": TRAP}),
        "choking_smoke": ("Weakness", 0.10, {"condition": "Burning"}),
        "twin_sparks": [("BuildingStat", 1.0, {"buildings": BOLTER, "elements": 2, "stat_type": 28, "modify_type": 0}),
                        ("BuildingStat", 0.15, {"buildings": BOLTER, "elements": 2, "stat_type": 29, "modify_type": 0})],
        "solar_lance": ("BuildingStat", 1.0, {"buildings": BEAMER, "elements": 2, "stat_type": 27, "modify_type": 0}),
        "fire_wall_t2": ("UnlockTier", 1.0, {"buildings": WALL, "elements": 2}),
        "fire_wall_t3": ("UnlockTier", 1.0, {"buildings": WALL, "elements": 2}),
        # each burst leaves a ground patch (GroundPatch): seconds and the share of the hit a second
        "cinders": [("BuildingStat", 1.0, {"buildings": NOVA, "elements": 2, "stat_type": 25, "modify_type": 0}),
                    ("BuildingStat", 0.1, {"buildings": NOVA, "elements": 2, "stat_type": 26, "modify_type": 0})],
    },
    "frost_tree.tres": {
        "cold_heart": ("Vulnerability", 0.06, {"condition": "Frozen"}),
        "shatterburst": ("Vulnerability", 0.15, {"condition": "Frozen", "buildings": NOVA}),
        "ice_spikes": ("Vulnerability", 0.20, {"condition": "Chilled", "buildings": TRAP}),
        "brittle": ("Vulnerability", 0.04, {"condition": "Chilled", "elements": PHYSICAL}),
        "numbing_cold": ("Weakness", 0.10, {"condition": "Chilled"}),
        "wall_t2": ("UnlockTier", 1.0, {"buildings": WALL, "elements": 4}),
        "wall_t3": ("UnlockTier", 1.0, {"buildings": WALL, "elements": 4}),
        "absolute_zero": ("FreezeLonger", 0.5, {}),
        "snap_freeze": ("FreezeExtra", 0.25, {}),
        "ice_splinters": [("BuildingStat", 1.0, {"buildings": BOLTER, "elements": 4, "stat_type": 28, "modify_type": 0}),
                          ("BuildingStat", 0.15, {"buildings": BOLTER, "elements": 4, "stat_type": 29, "modify_type": 0})],
        "frost_field": [("BuildingStat", 1.0, {"buildings": NOVA, "elements": 4, "stat_type": 25, "modify_type": 0}),
                        ("BuildingStat", 0.1, {"buildings": NOVA, "elements": 4, "stat_type": 26, "modify_type": 0})],
        "icicle_lance":("BuildingStat", 1.0, {"buildings": BOLTER, "elements": 4, "stat_type": 23, "modify_type": 0}),
    },
    "poison_tree.tres": {
        "corrosion": ("Vulnerability", 0.04, {"condition": "Poisoned"}),
        "opportunist": ("Vulnerability", 0.10, {"condition": "Poisoned", "buildings": BOLTER}),
        "sickening_snap": ("Vulnerability", 0.20, {"condition": "Poisoned", "buildings": TRAP}),
        "weakening": ("Weakness", 0.10, {"condition": "Poisoned"}),
        "plague": ("BuildingStat", 2.0, {"buildings": BOLTER | NOVA | BEAMER, "elements": 8, "stat_type": 30, "modify_type": 0}),
        "acid_splash": ("BuildingStat", 3.0, {"buildings": BEAMER, "elements": 8, "stat_type": 30, "modify_type": 0}),
        "wall_t2": ("UnlockTier", 1.0, {"buildings": WALL, "elements": 8}),
        "wall_t3": ("UnlockTier", 1.0, {"buildings": WALL, "elements": 8}),
        "lingering_cloud": [("BuildingStat", 1.0, {"buildings": NOVA, "elements": 8, "stat_type": 25, "modify_type": 0}),
                            ("BuildingStat", 0.1, {"buildings": NOVA, "elements": 8, "stat_type": 26, "modify_type": 0})],
    },
}

# the mechanics (2026-11-16): the capstones and signature nodes that make a path exciting
MECHANICS = {
    "building_tree.tres": {
        "salvage": ("SellRefund", 0.25, {}),
        "hoard": ("FirstUpgradeDiscount", 0.5, {}),
    },
    "fire_tree.tres": {
        "supernova": ("Strike", 1.0, {"buildings": NOVA, "elements": FIRE, "strike": "Blast", "every": 4, "at_tower": True, "range_factor": 2.0}),
        "meteor": ("Strike", 1.0, {"buildings": BOLTER, "elements": FIRE, "strike": "Blast", "every": 6, "radius_tiles": 1.0}),
        "funeral_pyre": ("DeathBurst", 0.15, {"elements": FIRE, "condition": "Burning", "radius_tiles": 1.0,
                                             "description": "Burning enemies explode on death: enemies within 1 tile take Fire damage, 15% of its max health"}),
        "keep_awakens": ("CastleDragon", 0.1, {"interval": 4.0, "radius_tiles": 3.0,
                                              "description": "An elder dragon wakes in each castle: every 4 s it breathes fire on enemies within 3 tiles of the castle (10% of their max health), and the first enemy to reach each castle every wave costs no life"}),
    },
    "frost_tree.tres": {
        "blizzard": ("Strike", 0.75, {"buildings": NOVA, "elements": FROST, "strike": "Freeze", "every": 4, "at_tower": True}),
        "pinning_shot": ("Strike", 0.5, {"buildings": BOLTER, "elements": FROST, "strike": "Freeze", "every": 5,
                                         "description": "Every 5th bolt freezes its target for 0.5 s"}),
        "ice_shards": ("DeathBurst", 0.2, {"elements": FROST, "condition": "Frozen", "radius_tiles": 1.0}),
    },
    "poison_tree.tres": {
        "toxic_bloom": ("Strike", 2.0, {"buildings": NOVA, "elements": POISON, "strike": "Stacks", "every": 4, "at_tower": True}),
        "hydra_bolts": ("Strike", 3.0, {"buildings": BOLTER, "elements": POISON, "strike": "Split", "every": 5}),
        "necrosis": ("Vulnerability", 0.05, {"elements": POISON, "condition": "Poisoned", "per_stack": True}),
        "overdose": ("Vulnerability", 0.03, {"buildings": NOVA, "condition": "Poisoned", "per_stack": True}),
    },
}
# the element traps' stat nodes (2026-11-16, after tools/trap_elements.py): Utils.StatType numbers, Flat 0 / Multiply 1
ATTACK_SPEED, EFFECT_POTENCY, SPLASH_RADIUS, FREEZE_DURATION, PATCH_DURATION, PATCH_SHARE = 6, 10, 20, 22, 25, 26
TRAP_STATS = {
    "building_tree.tres": {
        "leopard_t1": ("BuildingStat", 0.1, {"buildings": TRAP, "elements": PHYSICAL, "stat_type": ATTACK_SPEED, "modify_type": 0,
                                            "description": "Leopard traps re-arm 10% faster"}),
    },
    "fire_tree.tres": {
        "lasting_coals": ("BuildingStat", 1.0, {"buildings": TRAP, "elements": FIRE, "stat_type": PATCH_DURATION, "modify_type": 0}),
        "searing_ground": ("BuildingStat", 0.1, {"buildings": TRAP, "elements": FIRE, "stat_type": PATCH_SHARE, "modify_type": 1}),
    },
    "frost_tree.tres": {
        "bitter_snap": ("BuildingStat", 0.1, {"buildings": TRAP, "elements": FROST, "stat_type": EFFECT_POTENCY, "modify_type": 0}),
        "long_root": ("BuildingStat", 0.25, {"buildings": TRAP, "elements": FROST, "stat_type": FREEZE_DURATION, "modify_type": 0}),
        "hold_fast": ("BuildingStat", 0.1, {"buildings": TRAP, "elements": FROST, "stat_type": FREEZE_DURATION, "modify_type": 0,
                                           "description": "Frost trap roots last 0.1 s longer"}),
        "frost_aura": ("BuildingStat", 0.25, {"buildings": TRAP, "elements": FROST, "stat_type": SPLASH_RADIUS, "modify_type": 0,
                                             "description": "The chill around the trap (T2) reaches 0.25 tiles further"}),
    },
    "poison_tree.tres": {
        "thick_cloud": ("BuildingStat", 1.0, {"buildings": TRAP, "elements": POISON, "stat_type": PATCH_DURATION, "modify_type": 0}),
        "choking_gas": ("BuildingStat", 0.1, {"buildings": TRAP, "elements": POISON, "stat_type": PATCH_SHARE, "modify_type": 1}),
    },
}
for tree_file, nodes in TRAP_STATS.items():
    MECHANICS.setdefault(tree_file, {}).update(nodes)
for tree_file, nodes in MECHANICS.items():
    EFFECTS.setdefault(tree_file, {}).update(nodes)


def main():
    for tree_file, nodes in EFFECTS.items():
        path = os.path.join(TREES, tree_file)
        s = open(path, encoding="utf8").read()
        eff_id = re.search(r'\[ext_resource type="Script"[^\n]*talent_effect.gd" id="([^"]+)"\]', s).group(1)
        added = 0
        for node_id, spec in nodes.items():
            # one effect (kind, value, extra), or a list of them
            specs = spec if isinstance(spec, list) else [spec]
            m = re.search(r'(\[sub_resource type="Resource" id="(Node_[^"]+)"\]\nscript = [^\n]+\nid = &"%s"\n(?:[^\[\n][^\n]*\n)*)' % node_id, s)
            assert m, (tree_file, node_id)
            if "effects =" in m.group(1):
                continue
            block, sub_ids = "", []
            for i, (kind, value, extra) in enumerate(specs):
                sub_id = "Effect_%s_level%s" % (node_id, i if i else "")
                body = ["kind = %d" % KIND[kind]]
                for key in ("buildings", "elements", "stat_type", "modify_type"):
                    if key in extra:
                        body.append("%s = %d" % (key, extra[key]))
                body.append("value_per_rank = %s" % repr(float(value)))
                if "condition" in extra:
                    body.append("condition = %d" % CONDITION[extra["condition"]])
                if extra.get("per_stack"):
                    body.append("per_stack = true")
                if "strike" in extra:
                    body.append("strike = %d" % STRIKE[extra["strike"]])
                if "every" in extra:
                    body.append("every = %d" % extra["every"])
                if extra.get("at_tower"):
                    body.append("at_tower = true")
                for key in ("range_factor", "radius_tiles", "interval"):
                    if key in extra:
                        body.append("%s = %s" % (key, repr(float(extra[key]))))
                block += '[sub_resource type="Resource" id="%s"]\nscript = ExtResource("%s")\n%s\n\n' % (sub_id, eff_id, "\n".join(body))
                sub_ids.append('SubResource("%s")' % sub_id)
            node_text = m.group(1)
            described = [extra["description"] for _, _, extra in specs if "description" in extra]
            if described:
                node_text = re.sub(r'^description = "[^"]*"$', 'description = "%s"' % described[0], node_text, count=1, flags=re.M)
            node_block = node_text.rstrip("\n") + '\neffects = Array[ExtResource("%s")]([%s])\n' % (eff_id, ", ".join(sub_ids))
            s = s[:m.start()] + block + node_block + s[m.end():]
            added += 1
        open(path, "w", encoding="utf8", newline="\n").write(s)
        print("%s: %d nodes given effects" % (tree_file, added))


if __name__ == "__main__":
    main()
