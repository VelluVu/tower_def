"""The Egg Bomb's talents (2026-11-25), rerunnable:

    python tools/egg_bomb_talents.py      (run from tools/)

- the Egg Bomb branch's stat nodes (from tools/new_tower_talents.py) get their TalentEffects: blast damage (Multiply,
  like every talent damage), faster rebuilding (attack speed: its cooldown is the rebuild), blast radius
  (SplashRadius), armour piercing (resistance penetration), critical chance, potency, and the ground the blast leaves
  (PatchDuration)
- the entry node each branch shares with the trap path, the Harpooner and the Hatchery (Sharp Teeth, Hot Snare, Cold
  Snare, Venom Snare) counts for the Egg Bomb too: its effects get the Egg Bomb flag and its text names it
The rest (Short Fuse, Stunning Blast, Ember Clutch, Ice Shrapnel, Sticky Yolk and the capstones Clutch Bomb, Inferno
Egg, Glacier Egg, Plague Egg) stays without effects until their mechanics exist.
"""
import os
import re

import mortar_talents as mt

EGG_BOMB = 2048  # TalentEffect.EGG_BOMB
ENTRY = {"building": "sharp_teeth", "fire": "hot_snare", "frost": "cold_snare", "poison": "venom_snare"}
DAMAGE, SPEED, CRIT_CHANCE, POTENCY, PENETRATION, SPLASH, PATCH_TIME = 2, 6, 7, 10, 18, 20, 25
FLAT, MULTIPLY = 0, 1
EL = r"(?:Fire |Frost |Poison )?"
# description pattern -> [(kind, stat, modify, value per rank, condition, per stack)]
RULES = [
    (EL + r"Egg Bomb blast damage \+(\d+)%$", lambda m: [(0, DAMAGE, MULTIPLY, int(m.group(1)) / 100.0, 0, False)]),
    (EL + r"Egg Bombs? rebuilds? (\d+)% faster", lambda m: [(0, SPEED, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (EL + r"Egg Bomb blast radius \+([\d.]+) tiles", lambda m: [(0, SPLASH, FLAT, float(m.group(1)), 0, False)]),
    (r"The blast ignores (\d+)% of the enemy's armor", lambda m: [(0, PENETRATION, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (EL + r"Egg Bomb critical chance \+(\d+) points", lambda m: [(0, CRIT_CHANCE, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (EL + r"Egg Bomb (?:burn |slow )?potency \+(\d+)%", lambda m: [(0, POTENCY, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"The blast leaves (?:burning ground|freezing ground|a poison cloud) for ([\d.]+) s", lambda m: [(0, PATCH_TIME, FLAT, float(m.group(1)), 0, False)]),
]


def egg_bomb_nodes(tree, text):
    script_id = mt.effect_script_id(text)
    # the old run's effects go first, so a rerun writes them anew
    text = re.sub(r'\[sub_resource type="Resource" id="Effect_egg_bomb_[^"]*"\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    done = []
    for node_id, desc in re.findall(r'id = &"(egg_bomb_[a-z_]+)"\ndisplay_name = "[^"]*"\ndescription = "([^"]*)"', text):
        if node_id.endswith(("_t2", "_t3")):
            continue
        effects = []
        for pattern, make in RULES:
            m = re.search(pattern, desc)
            if m:
                effects = make(m)
                break
        if not effects:
            continue
        ids = []
        for i, (kind, stat, modify, value, condition, per_stack) in enumerate(effects):
            effect_id = "Effect_egg_bomb_%s_%d" % (node_id[len("egg_bomb_"):], i)
            body = 'script = ExtResource("%s")\n' % script_id
            if kind:
                body += "kind = %d\n" % kind
            body += "buildings = %d\nelements = %d\n" % (EGG_BOMB, mt.ELEMENT[tree])
            if stat != DAMAGE:
                body += "stat_type = %d\n" % stat
            body += "modify_type = %d\nvalue_per_rank = %s\n" % (modify, repr(value))
            if condition:
                body += "condition = %d\n" % condition
            if per_stack:
                body += "per_stack = true\n"
            first = text.index("[sub_resource")
            text = text[:first] + '[sub_resource type="Resource" id="%s"]\n%s\n' % (effect_id, body) + text[first:]
            ids.append(effect_id)
        text = mt.set_effects(text, node_id, ids, script_id)
        done.append(node_id)
    return text, done


def entry_node(tree, text):
    node_id = ENTRY[tree]
    m = mt.node_block(text, node_id)
    effects = re.findall(r'SubResource\("([^"]+)"\)', re.search(r'effects = [^\n]*', m.group(0)).group(0))
    for effect_id in effects:
        em = re.search(r'\[sub_resource type="Resource" id="%s"\]\n((?:[^\[\n][^\n]*\n)*)' % effect_id, text)
        body = em.group(1)
        flags = re.search(r'^buildings = (\d+)$', body, re.M)
        # no buildings flag = every building already
        if flags and int(flags.group(1)) & EGG_BOMB == 0:
            body = body.replace(flags.group(0), "buildings = %d" % (int(flags.group(1)) | EGG_BOMB))
            text = text[:em.start(1)] + body + text[em.end(1):]
    m = mt.node_block(text, node_id)
    block = m.group(0)
    if "Egg Bomb" not in block:
        block = block.replace("rap, Harpooner and Hatchery damage", "rap, Harpooner, Hatchery and Egg Bomb damage")
    return text[:m.start()] + block + text[m.end():]


def main():
    for tree in ("building", "fire", "frost", "poison"):
        path = os.path.join(mt.TREES, "%s_tree.tres" % tree)
        text = open(path, encoding="utf8").read()
        text, done = egg_bomb_nodes(tree, text)
        text = entry_node(tree, text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        with open(path, "w", encoding="utf8", newline="\n") as f:
            f.write(text)
        print(tree, len(done), "Egg Bomb nodes working:", ", ".join(done))


if __name__ == "__main__":
    main()
