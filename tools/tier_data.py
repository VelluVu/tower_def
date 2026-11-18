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
TOWERS = ("bolter", "nova", "beamer")
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
LINE_HITS, SPLIT_COUNT, SPLIT_SHARE, POISON_SPREAD = 27, 28, 29, 30
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
}


def art_name(tower, element):
    if tower == "bolter":
        return "puffe_bolter" + ("_" + COLOUR[element] if COLOUR[element] else "")
    return (COLOUR[element] + "_" if COLOUR[element] else "") + "puffe_" + tower


def talent(tower, element, tier):
    if tower == TRAP:
        return ("building", "leopard_t%d" % tier) if element == "physical" else (element, "trap_t%d" % tier)
    if element == "physical":
        return "building", "phys_t%d" % tier
    return element, "%s_t%d" % (tower, tier)


def write(path, text):
    with open(os.path.join(ROOT, path), "w", encoding="utf8", newline="\n") as f:
        f.write(text)


def frames(tower, element, tier):
    if tower == TRAP:
        return None
    base = ART % (tower, art_name(tower, element), tier)
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
            ", ".join(refs), "true" if tag in LOOPING else "false", tag, 1000.0 / durs[a]))
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
    for i, (name, stat, modify, value, percent) in enumerate(STEP[tier] + extra):
        text += ('[sub_resource type="Resource" id="Resource_step%d"]\nscript = ExtResource("2_evolve")\nmodifier_type = 0\n'
                 'elements = 15\nmodify_stat_type = %d\nmodify_type = %d\nis_randomized_modify_value = false\n'
                 'is_percent = %s\nmodify_value = %s\nevolve_name = "%s"\n\n') % (
            i, stat, modify, "true" if percent else "false", repr(float(value)), name)
        ids.append('SubResource("Resource_step%d")' % i)
    info = ". ".join(s for s in (extra_info, STEP_INFO[tier]) if s)
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
    scene = "scenes/unit/building/buildings/%s.tscn" % (tower if tower == TRAP else "puffe_" + tower)
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
    text = text.rstrip("\n") + "\ntier_upgrades = Array[int]([2, 3, 3])\n"
    write(path, text)


def unlock_effects():
    # TalentEffect flags: buildings Bolter 1, Nova 2, Beamer 4; elements Physical 1, Fire 2, Frost 4, Poison 8
    tower_flag = {"bolter": 1, "nova": 2, "beamer": 4, TRAP: 8}
    element_flag = {"physical": 1, "fire": 2, "frost": 4, "poison": 8}
    unlocks = {}
    for t in TOWERS + (TRAP,):
        for e in ELEMENTS:
            for n in (2, 3):
                key = talent(t, e, n)
                flags = unlocks.get(key, (0, element_flag[e]))
                unlocks[key] = (flags[0] | tower_flag[t], flags[1])
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
