"""The Buffer's talents (2026-11-24), rerunnable:

    python tools/buffer_talents.py

The Buffer branch's nodes (from tools/new_tower_talents.py) and the maze entry nodes' Buffer half get their effects:
- "aura radius +X tiles": the Buffer's AttackRange (its aura)
- "buffs +N% stronger", "... Buffer auras are N% stronger": TalentEffect.Kind.BufferStrength
- "pip budget +1": TalentEffect.Kind.BufferBudget
- "penetration a Physical Buffer gives +N points": the Buffer's ResistancePenetration (added to what its aura gives)
- "chance a ... Buffer gives +N points": the Buffer's EffectChance (added to its element's chance on hit)
- "Buffed towers' ... potency +N%": the Buffer's EffectPotency (added to its potency buff)
Effects of the Building tree count for every Buffer; an element tree's only for a Buffer of that element.
The rest (weakening shares, walls in the aura, the roar's boosts, "every 10th attack", one track's strength) wait.
"""
import os
import re

import mortar_talents as mt

BUFFER = 64  # TalentEffect.BUFFER
BUFFER_STRENGTH, BUFFER_BUDGET = 21, 22  # TalentEffect.Kind
RANGE, POTENCY, CHANCE, PENETRATION = 5, 10, 11, 18
FLAT = 0
MAZE_ENTRY = {"fire": "smouldering_maze", "frost": "frozen_maze", "poison": "toxic_maze"}
RULES = [
    (r"aura radius \+([\d.]+) tiles", lambda m: [(0, RANGE, float(m.group(1)))]),
    (r"Buffer buffs \+(\d+)% stronger", lambda m: [(BUFFER_STRENGTH, 0, int(m.group(1)) / 100.0)]),
    (r"pip budget \+(\d+)", lambda m: [(BUFFER_BUDGET, 0, float(m.group(1)))]),
    (r"penetration a Physical Buffer gives \+(\d+) points", lambda m: [(0, PENETRATION, int(m.group(1)) / 100.0)]),
    (r"chance a \w+ Buffer gives \+(\d+) points", lambda m: [(0, CHANCE, int(m.group(1)) / 100.0)]),
    (r"Buffed towers' \w+ potency \+(\d+)%", lambda m: [(0, POTENCY, int(m.group(1)) / 100.0)]),
]


def effect_body(script_id, kind, stat, value, elements):
    body = 'script = ExtResource("%s")\n' % script_id
    if kind:
        body += "kind = %d\n" % kind
    body += "buildings = %d\n" % BUFFER
    if elements:
        body += "elements = %d\n" % elements
    if stat:
        body += "stat_type = %d\nmodify_type = %d\n" % (stat, FLAT)
    return body + "value_per_rank = %s\n" % repr(value)


def add_effect(text, effect_id, body):
    first = text.index("[sub_resource")
    return text[:first] + '[sub_resource type="Resource" id="%s"]\n%s\n' % (effect_id, body) + text[first:]


def node_effect_ids(text, node_id):
    m = mt.node_block(text, node_id)
    found = re.search(r'effects = [^\n]*', m.group(0))
    return re.findall(r'SubResource\("([^"]+)"\)', found.group(0)) if found else []


def main():
    for tree in ("building", "fire", "frost", "poison"):
        path = os.path.join(mt.TREES, "%s_tree.tres" % tree)
        text = open(path, encoding="utf8").read()
        script_id = mt.effect_script_id(text)
        elements = 0 if tree == "building" else mt.ELEMENT[tree]
        # the old run's effects go first, so a rerun writes them anew
        text = re.sub(r'\[sub_resource type="Resource" id="Effect_buffer_[^"]*"\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
        done = []
        for node_id, desc in re.findall(r'id = &"(buffer_[a-z_]+)"\ndisplay_name = "[^"]*"\ndescription = "([^"]*)"', text):
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
            for i, (kind, stat, value) in enumerate(effects):
                effect_id = "Effect_buffer_%s_%d" % (node_id[len("buffer_"):], i)
                text = add_effect(text, effect_id, effect_body(script_id, kind, stat, value, elements))
                ids.append(effect_id)
            text = mt.set_effects(text, node_id, ids, script_id)
            done.append(node_id)
        # the maze entry node's Buffer half: its auras stronger, next to the walls effect it already has
        if tree in MAZE_ENTRY:
            node_id = MAZE_ENTRY[tree]
            m = re.search(r'Buffer auras are (\d+)% stronger', mt.node_block(text, node_id).group(0))
            if m:
                effect_id = "Effect_buffer_maze_entry_%s" % tree
                text = add_effect(text, effect_id, effect_body(script_id, BUFFER_STRENGTH, 0, int(m.group(1)) / 100.0, elements))
                ids = [e for e in node_effect_ids(text, node_id) if e != effect_id] + [effect_id]
                text = mt.set_effects(text, node_id, ids, script_id)
                done.append(node_id)
        text = re.sub(r"\n{3,}", "\n\n", text)
        with open(path, "w", encoding="utf8", newline="\n") as f:
            f.write(text)
        print(tree, len(done), "Buffer nodes working:", ", ".join(done))


if __name__ == "__main__":
    main()
