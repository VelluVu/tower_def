"""The Spotter's talents (2026-11-24), rerunnable:

    python tools/spotter_talents.py      (run from tools/)

- the Spotter branch's stat nodes (from tools/new_tower_talents.py) get their TalentEffects: damage (Multiply, like
  every talent damage), range, resistance penetration, critical chance and multiplier, attack speed, ignite chance,
  potency, the element marks (MarkShare), the short freeze on every hit, an extra poison stack, and the execute
  capstone (ExecuteBelow)
- the entry node each branch shares with the Bolter's path (Hot Bolts, Ice Bolts, Venom Bolts; Hardened Shots in the
  Building tree) counts for the Spotter too: its effects get the Spotter flag and its text names the Spotter
The rest (the first shot on a new target, more damage to elites, the 25% splash, every 4th shot's Sunspear, the line
freeze, cashing in the poison) stays without effects until their mechanics exist.
"""
import os
import re

import mortar_talents as mt

SPOTTER = 256  # TalentEffect.SPOTTER
ENTRY = {"building": "hardened_shots", "fire": "hot_bolts", "frost": "ice_bolts", "poison": "venom_bolts"}
DAMAGE, RANGE, SPEED, CRIT, CRIT_MULTIPLIER, POTENCY, CHANCE, STACKS, PENETRATION = 2, 5, 6, 7, 8, 10, 11, 13, 18
FREEZE_CHANCE, FREEZE_TIME, MARK_SHARE, EXECUTE_BELOW = 21, 22, 32, 33
FLAT, MULTIPLY = 0, 1
# description pattern -> [(kind, stat, modify, value per rank, condition, per stack)]
RULES = [
    (r"Spotter damage \+(\d+)%$", lambda m: [(0, DAMAGE, MULTIPLY, int(m.group(1)) / 100.0, 0, False)]),
    (r"Spotter range \+([\d.]+) tiles", lambda m: [(0, RANGE, FLAT, float(m.group(1)), 0, False)]),
    (r"Spotter ignores (\d+)% of the target's resistance", lambda m: [(0, PENETRATION, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"Spotter critical chance \+(\d+) points", lambda m: [(0, CRIT, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"Spotter critical multiplier \+([\d.]+)", lambda m: [(0, CRIT_MULTIPLIER, FLAT, float(m.group(1)), 0, False)]),
    (r"Spotter attack speed \+([\d.]+)", lambda m: [(0, SPEED, FLAT, float(m.group(1)), 0, False)]),
    (r"Spotter ignite chance \+(\d+) points", lambda m: [(0, CHANCE, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"Spotter (?:burn |slow )?potency \+(\d+)%", lambda m: [(0, POTENCY, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"marks its target: it takes \+(\d+)%", lambda m: [(0, MARK_SHARE, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"hits freeze their target for ([\d.]+) s", lambda m: [(0, FREEZE_CHANCE, FLAT, 1.0, 0, False), (0, FREEZE_TIME, FLAT, float(m.group(1)), 0, False)]),
    (r"Each shot adds (\d+) more poison stack", lambda m: [(0, STACKS, FLAT, float(m.group(1)), 0, False)]),
    (r"kill enemies under (\d+)% health", lambda m: [(0, EXECUTE_BELOW, FLAT, int(m.group(1)) / 100.0, 0, False)]),
]


def spotter_nodes(tree, text):
    script_id = mt.effect_script_id(text)
    # the old run's effects go first, so a rerun writes them anew
    text = re.sub(r'\[sub_resource type="Resource" id="Effect_spotter_[^"]*"\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    done = []
    for node_id, desc in re.findall(r'id = &"(spotter_[a-z_]+)"\ndisplay_name = "[^"]*"\ndescription = "([^"]*)"', text):
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
            effect_id = "Effect_spotter_%s_%d" % (node_id[len("spotter_"):], i)
            body = 'script = ExtResource("%s")\n' % script_id
            if kind:
                body += "kind = %d\n" % kind
            body += "buildings = %d\nelements = %d\n" % (SPOTTER, mt.ELEMENT[tree])
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
        if flags and int(flags.group(1)) & SPOTTER == 0:
            body = body.replace(flags.group(0), "buildings = %d" % (int(flags.group(1)) | SPOTTER))
            text = text[:em.start(1)] + body + text[em.end(1):]
    m = mt.node_block(text, node_id)
    block = re.sub(r'description = "(Fire|Frost|Poison) Bolter damage', r'description = "\1 Bolter and Spotter damage', m.group(0))
    return text[:m.start()] + block + text[m.end():]


def main():
    for tree in ("building", "fire", "frost", "poison"):
        path = os.path.join(mt.TREES, "%s_tree.tres" % tree)
        text = open(path, encoding="utf8").read()
        text, done = spotter_nodes(tree, text)
        text = entry_node(tree, text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        with open(path, "w", encoding="utf8", newline="\n") as f:
            f.write(text)
        print(tree, len(done), "Spotter nodes working:", ", ".join(done))


if __name__ == "__main__":
    main()
