"""The Hatchery's talents (2026-11-25), rerunnable:

    python tools/hatchery_talents.py      (run from tools/)

- the Hatchery branch's stat nodes (from tools/new_tower_talents.py) get their TalentEffects: damage (Multiply, like
  every talent damage), the guards' health (GuardHealth, Multiply), attack speed, critical chance, ignite chance,
  potency, and Big Clutch (one more guard: GuardCount)
- the entry node each branch shares with the trap path and the Harpooner (Sharp Teeth, Hot Snare, Cold Snare, Venom
  Snare) counts for the Hatchery too: its effects get the Hatchery flag and its text names the Hatchery
The rest (faster hatching, Guard Post's second enemy, Pack Tactics, Ice Scales, Hot Blood, Toxic Blood, the spits,
Winter Brood, and the capstones Brood Champion, Brood Inferno, Plague Brood) stays without effects until their
mechanics exist.
"""
import os
import re

import mortar_talents as mt

HATCHERY = 1024  # TalentEffect.HATCHERY
ENTRY = {"building": "sharp_teeth", "fire": "hot_snare", "frost": "cold_snare", "poison": "venom_snare"}
DAMAGE, SPEED, CRIT_CHANCE, POTENCY, CHANCE, GUARD_HEALTH, GUARD_COUNT = 2, 6, 7, 10, 11, 36, 37
FLAT, MULTIPLY = 0, 1
# description pattern -> [(kind, stat, modify, value per rank, condition, per stack)]
RULES = [
    (r"(?:Fire |Frost |Poison )?[Dd]rakeling damage \+(\d+)%$", lambda m: [(0, DAMAGE, MULTIPLY, int(m.group(1)) / 100.0, 0, False)]),
    (r"(?:Fire |Frost |Poison )?[Dd]rakeling health \+(\d+)%$", lambda m: [(0, GUARD_HEALTH, MULTIPLY, int(m.group(1)) / 100.0, 0, False)]),
    (r"(?:Fire |Frost |Poison )?[Dd]rakeling attack speed \+([\d.]+)", lambda m: [(0, SPEED, FLAT, float(m.group(1)), 0, False)]),
    (r"(?:Fire |Frost |Poison )?[Dd]rakeling critical chance \+(\d+) points", lambda m: [(0, CRIT_CHANCE, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"(?:Fire |Frost |Poison )?[Dd]rakeling ignite chance \+(\d+) points", lambda m: [(0, CHANCE, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"(?:Fire |Frost |Poison )?[Dd]rakeling (?:slow )?potency \+(\d+)%", lambda m: [(0, POTENCY, FLAT, int(m.group(1)) / 100.0, 0, False)]),
    (r"One more drakeling at a time", lambda m: [(0, GUARD_COUNT, FLAT, 1.0, 0, False)]),
]


def hatchery_nodes(tree, text):
    script_id = mt.effect_script_id(text)
    # the old run's effects go first, so a rerun writes them anew
    text = re.sub(r'\[sub_resource type="Resource" id="Effect_hatchery_[^"]*"\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    done = []
    for node_id, desc in re.findall(r'id = &"(hatchery_[a-z_]+)"\ndisplay_name = "[^"]*"\ndescription = "([^"]*)"', text):
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
            effect_id = "Effect_hatchery_%s_%d" % (node_id[len("hatchery_"):], i)
            body = 'script = ExtResource("%s")\n' % script_id
            if kind:
                body += "kind = %d\n" % kind
            body += "buildings = %d\nelements = %d\n" % (HATCHERY, mt.ELEMENT[tree])
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
        if flags and int(flags.group(1)) & HATCHERY == 0:
            body = body.replace(flags.group(0), "buildings = %d" % (int(flags.group(1)) | HATCHERY))
            text = text[:em.start(1)] + body + text[em.end(1):]
    m = mt.node_block(text, node_id)
    block = m.group(0)
    if "Hatchery" not in block:
        block = block.replace("rap and Harpooner damage", "rap, Harpooner and Hatchery damage")
    return text[:m.start()] + block + text[m.end():]


def main():
    for tree in ("building", "fire", "frost", "poison"):
        path = os.path.join(mt.TREES, "%s_tree.tres" % tree)
        text = open(path, encoding="utf8").read()
        text, done = hatchery_nodes(tree, text)
        text = entry_node(tree, text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        with open(path, "w", encoding="utf8", newline="\n") as f:
            f.write(text)
        print(tree, len(done), "Hatchery nodes working:", ", ".join(done))


if __name__ == "__main__":
    main()
