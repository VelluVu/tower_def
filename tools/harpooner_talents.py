"""The Harpooner's talents (2026-11-24), rerunnable:

    python tools/harpooner_talents.py      (run from tools/)

- the Harpooner branch's stat nodes (from tools/new_tower_talents.py) get their TalentEffects: damage (Multiply, like
  every talent damage), range, attack speed, ignite chance, potency, the tether's length (TetherTime), armour
  piercing (resistance penetration), the critical multiplier, and Skyhook (more damage against flyers: a
  Vulnerability with the Flying condition)
- the entry node each branch shares with the trap path (Hot Snare, Cold Snare, Venom Snare; Sharp Teeth in the
  Building tree) counts for the Harpooner too: its effects get the Harpooner flag and its text names the Harpooner
The rest (Yank as a half-tile pull, Searing Chain, Pin Down, Festering Wound, the landing effects of Drag to the Fire,
Grounded and Grounded Rot, and the capstones Chain of Embers, Glacial Anchor, Leech Chain) stays without
effects until their mechanics exist.
"""
import os
import re

import mortar_talents as mt

HARPOONER = 512  # TalentEffect.HARPOONER
ENTRY = {"building": "sharp_teeth", "fire": "hot_snare", "frost": "cold_snare", "poison": "venom_snare"}
DAMAGE, RANGE, SPEED, CRIT_MULTIPLIER, POTENCY, CHANCE, PENETRATION, TETHER_TIME = 2, 5, 6, 8, 10, 11, 18, 34
VULNERABILITY, FLYING = 3, 5  # TalentEffect.Kind, TalentEffect.Condition
FLAT, MULTIPLY = 0, 1
# description pattern -> [(kind, stat, modify, value per rank, condition, per stack)]
RULES = [
    (r"Harpooner damage \+(\d+)%$", lambda m: [(0, DAMAGE, MULTIPLY, int(m.group(1)) / 100.0, 0, False)]),
    (r"Harpooner damage \+(\d+)% against flyers", lambda m: [(VULNERABILITY, DAMAGE, MULTIPLY, int(m.group(1)) / 100.0, FLYING, False)]),
    (r"Harpooner range \+([\d.]+) tiles", lambda m: [(0, RANGE, FLAT, float(m.group(1)), 0, False)]),
    (r"Harpooner attack speed \+([\d.]+)", lambda m: [(0, SPEED, FLAT, float(m.group(1)), 0, False)]),
    (r"Harpooner ignite chance \+(\d+) points", lambda m: [(0, CHANCE, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"Harpooner (?:burn |slow )?potency \+(\d+)%", lambda m: [(0, POTENCY, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"The tether lasts ([\d.]+) s longer", lambda m: [(0, TETHER_TIME, FLAT, float(m.group(1)), 0, False)]),
    (r"Harpooner ignores (\d+)% of the enemy's armor", lambda m: [(0, PENETRATION, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"Harpooner critical multiplier \+([\d.]+)", lambda m: [(0, CRIT_MULTIPLIER, FLAT, float(m.group(1)), 0, False)]),
]


def harpooner_nodes(tree, text):
    script_id = mt.effect_script_id(text)
    # the old run's effects go first, so a rerun writes them anew
    text = re.sub(r'\[sub_resource type="Resource" id="Effect_harpooner_[^"]*"\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    done = []
    for node_id, desc in re.findall(r'id = &"(harpooner_[a-z_]+)"\ndisplay_name = "[^"]*"\ndescription = "([^"]*)"', text):
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
            effect_id = "Effect_harpooner_%s_%d" % (node_id[len("harpooner_"):], i)
            body = 'script = ExtResource("%s")\n' % script_id
            if kind:
                body += "kind = %d\n" % kind
            body += "buildings = %d\nelements = %d\n" % (HARPOONER, mt.ELEMENT[tree])
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
        if flags and int(flags.group(1)) & HARPOONER == 0:
            body = body.replace(flags.group(0), "buildings = %d" % (int(flags.group(1)) | HARPOONER))
            text = text[:em.start(1)] + body + text[em.end(1):]
    m = mt.node_block(text, node_id)
    block = m.group(0)
    if "Harpooner" not in block:
        block = re.sub(r'description = "((?:Fire |Frost |Poison )?[Tt])rap damage', r'description = "\1rap and Harpooner damage', block)
    return text[:m.start()] + block + text[m.end():]


def main():
    for tree in ("building", "fire", "frost", "poison"):
        path = os.path.join(mt.TREES, "%s_tree.tres" % tree)
        text = open(path, encoding="utf8").read()
        text, done = harpooner_nodes(tree, text)
        text = entry_node(tree, text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        with open(path, "w", encoding="utf8", newline="\n") as f:
            f.write(text)
        print(tree, len(done), "Harpooner nodes working:", ", ".join(done))


if __name__ == "__main__":
    main()
