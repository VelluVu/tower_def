"""The Breather's talents (2026-11-24), rerunnable:

    python tools/breather_talents.py

- the Breather branch's stat nodes (from tools/new_tower_talents.py) get their TalentEffects: damage (Multiply, like
  every talent damage), cone length (AttackRange), cone width (ConeWidth, degrees), attack speed, ignite chance,
  potency, the breath's ground patch, the roar's stun time, resistance penetration, extra poison stacks, and the
  damage against burning enemies or per poison stack (Vulnerability)
- the entry node each branch shares with the Beamer's path (Hot Beam, Cold Beam, Acid Beam; Hardened Shots in the
  Building tree) counts for the Breather too: its effects get the Breather flag and its text names the Breather
The mechanic nodes (knockback by a fraction of a tile, Terrify's weakness, slow stacks per second in the cone,
Flash Freeze, the "every 4th roar" and 120 degree sweep capstones) stay without effects until their mechanics exist.
"""
import os
import re

import mortar_talents as mt

BREATHER = 128  # TalentEffect.BREATHER
ENTRY = {"building": "hardened_shots", "fire": "hot_beam", "frost": "cold_beam", "poison": "acid_beam"}
DAMAGE, RANGE, SPEED, POTENCY, CHANCE, STACKS, PENETRATION = 2, 5, 6, 10, 11, 13, 18
FREEZE_TIME, PATCH, PATCH_SHARE, CONE_WIDTH = 22, 25, 26, 31
FLAT, MULTIPLY = 0, 1
VULNERABILITY = 3  # TalentEffect.Kind
BURNING, POISONED = 1, 2  # TalentEffect.Condition
# description pattern -> [(kind, stat, modify, value per rank, condition, per stack)]
RULES = [
    (r"Breather damage \+(\d+)%", lambda m: [(0, DAMAGE, MULTIPLY, int(m.group(1)) / 100.0, 0, False)]),
    (r"Breather cone length \+([\d.]+) tiles", lambda m: [(0, RANGE, FLAT, float(m.group(1)), 0, False)]),
    (r"Breather cone width \+(\d+) degrees", lambda m: [(0, CONE_WIDTH, FLAT, float(m.group(1)), 0, False)]),
    (r"Breather attack speed \+([\d.]+)", lambda m: [(0, SPEED, FLAT, float(m.group(1)), 0, False)]),
    (r"Breather ignite chance \+(\d+) points", lambda m: [(0, CHANCE, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"Breather (?:burn |slow )?potency \+(\d+)%", lambda m: [(0, POTENCY, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"The breath leaves (?:burning ground|a poison cloud) for ([\d.]+) s",
     lambda m: [(0, PATCH, FLAT, float(m.group(1)), 0, False), (0, PATCH_SHARE, FLAT, 0.1, 0, False)]),
    (r"The roar's stun lasts ([\d.]+) s longer", lambda m: [(0, FREEZE_TIME, FLAT, float(m.group(1)), 0, False)]),
    (r"Breather ignores (\d+)% of the target's resistance", lambda m: [(0, PENETRATION, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"poison stacks (\d+) more time", lambda m: [(0, STACKS, FLAT, float(m.group(1)), 0, False)]),
    (r"\+(\d+)% damage to enemies that are already burning", lambda m: [(VULNERABILITY, DAMAGE, FLAT, int(m.group(1)) / 100.0, BURNING, False)]),
    (r"\+(\d+)% damage for every poison stack", lambda m: [(VULNERABILITY, DAMAGE, FLAT, int(m.group(1)) / 100.0, POISONED, True)]),
]


def breather_nodes(tree, text):
    script_id = mt.effect_script_id(text)
    # the old run's effects go first, so a rerun writes them anew
    text = re.sub(r'\[sub_resource type="Resource" id="Effect_breather_[^"]*"\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    done = []
    for node_id, desc in re.findall(r'id = &"(breather_[a-z_]+)"\ndisplay_name = "[^"]*"\ndescription = "([^"]*)"', text):
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
            effect_id = "Effect_breather_%s_%d" % (node_id[len("breather_"):], i)
            body = 'script = ExtResource("%s")\n' % script_id
            if kind:
                body += "kind = %d\n" % kind
            body += "buildings = %d\nelements = %d\n" % (BREATHER, mt.ELEMENT[tree])
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
        if flags and int(flags.group(1)) & BREATHER == 0:
            body = body.replace(flags.group(0), "buildings = %d" % (int(flags.group(1)) | BREATHER))
            text = text[:em.start(1)] + body + text[em.end(1):]
    m = mt.node_block(text, node_id)
    block = re.sub(r'description = "(Fire|Frost|Poison) Beamer damage', r'description = "\1 Beamer and Breather damage', m.group(0))
    return text[:m.start()] + block + text[m.end():]


def main():
    for tree in ("building", "fire", "frost", "poison"):
        path = os.path.join(mt.TREES, "%s_tree.tres" % tree)
        text = open(path, encoding="utf8").read()
        text, done = breather_nodes(tree, text)
        text = entry_node(tree, text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        with open(path, "w", encoding="utf8", newline="\n") as f:
            f.write(text)
        print(tree, len(done), "Breather nodes working:", ", ".join(done))


if __name__ == "__main__":
    main()
