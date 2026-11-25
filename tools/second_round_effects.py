"""The second round's talent effects (2026-11-25), rerunnable:

    python tools/second_round_effects.py      (run from tools/)

- the stat nodes of the Spike Field, Shredder and Elder Drake branches (from tools/second_round_talents.py) get their
  TalentEffects: damage (Multiply, like every talent damage), range, attack speed, critical chance and multiplier,
  ignite/poison chance, potency, slow ticks, extra poison stacks and resistance penetration
- the entry node each branch shares counts for its tower too: the Bolter's (Hot, Ice, Venom Bolts) for the Elder
  Drake, the Nova's (Blast Furnace, Frost Ring, Toxic Burst) for the Shredder, the trap path's (Hot, Cold, Venom
  Snare, Sharp Teeth) for the Spike Field, Hardened Shots for the Elder Drake and the Shredder; their text names them
The rest (the Hoard Keeper's pay nodes, health, the breath, shred, spike slow nodes and every capstone) stays without
effects until their mechanics exist; the menu shows those as "does nothing yet".
"""
import os
import re

import mortar_talents as mt

TOWERS = {"spike_field": 4096, "shredder": 16384, "elder_drake": 32768}  # TalentEffect flags
NAMES = {"spike_field": "Spike Field", "shredder": "Shredder", "elder_drake": "Elder Drake"}
# entry node per tree -> the new towers it counts for, and the text change that names them
ENTRY = {
    "building": {"hardened_shots": ("shredder", "elder_drake"), "sharp_teeth": ("spike_field",)},
    "fire": {"hot_bolts": ("elder_drake",), "blast_furnace": ("shredder",), "hot_snare": ("spike_field",)},
    "frost": {"ice_bolts": ("elder_drake",), "frost_ring": ("shredder",), "cold_snare": ("spike_field",)},
    "poison": {"venom_bolts": ("elder_drake",), "toxic_burst": ("shredder",), "venom_snare": ("spike_field",)},
}
TEXT = [("Bolter and Spotter damage", "Bolter, Spotter and Elder Drake damage"),
        ("Nova and Mortar damage", "Nova, Mortar and Shredder damage"),
        ("rap, Harpooner, Hatchery and Egg Bomb damage", "rap, Spike Field, Harpooner, Hatchery and Egg Bomb damage")]
DAMAGE, RANGE, SPEED, CRIT, CRIT_MULTIPLIER, POTENCY, CHANCE, DURATION, STACKS, PENETRATION = 2, 5, 6, 7, 8, 10, 11, 12, 13, 18
FLAT, MULTIPLY = 0, 1
T = r"(?:Spike Field|Shredder|Elder Drake)"
# description pattern -> [(stat, modify, value per rank)]
RULES = [
    (T + r" damage \+(\d+)%$", lambda m: [(DAMAGE, MULTIPLY, int(m.group(1)) / 100.0)]),
    (T + r" range \+([\d.]+) tiles", lambda m: [(RANGE, FLAT, float(m.group(1)))]),
    (T + r" attack speed \+([\d.]+)", lambda m: [(SPEED, FLAT, float(m.group(1)))]),
    (T + r" critical chance \+(\d+) points", lambda m: [(CRIT, FLAT, int(m.group(1)) / 100.0)]),
    (T + r" critical multiplier \+([\d.]+)", lambda m: [(CRIT_MULTIPLIER, FLAT, float(m.group(1)))]),
    (T + r" (?:ignite|poison) chance \+(\d+) points", lambda m: [(CHANCE, FLAT, int(m.group(1)) / 100.0)]),
    (T + r" (?:burn |slow |poison )?potency \+(\d+)%", lambda m: [(POTENCY, FLAT, int(m.group(1)) / 100.0)]),
    (T + r" slows last (\d+) tick longer", lambda m: [(DURATION, FLAT, float(m.group(1)))]),
    (T + r" (?:bites|strikes) add (\d+) more poison stack", lambda m: [(STACKS, FLAT, float(m.group(1)))]),
    (T + r" resistance penetration \+(\d+)%", lambda m: [(PENETRATION, FLAT, int(m.group(1)) / 100.0)]),
]


def tower_nodes(tree, text, tower):
    script_id = mt.effect_script_id(text)
    # the old run's effects go first, so a rerun writes them anew
    text = re.sub(r'\[sub_resource type="Resource" id="Effect_%s_[^"]*"\]\n(?:[^\[\n][^\n]*\n)*\n?' % tower, '', text)
    done = []
    for node_id, desc in re.findall(r'id = &"(%s_[a-z_]+)"\ndisplay_name = "[^"]*"\ndescription = "([^"]*)"' % tower, text):
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
        for i, (stat, modify, value) in enumerate(effects):
            effect_id = "Effect_%s_%s_%d" % (tower, node_id[len(tower) + 1:], i)
            body = 'script = ExtResource("%s")\nbuildings = %d\nelements = %d\n' % (script_id, TOWERS[tower], mt.ELEMENT[tree])
            if stat != DAMAGE:
                body += "stat_type = %d\n" % stat
            body += "modify_type = %d\nvalue_per_rank = %s\n" % (modify, repr(value))
            first = text.index("[sub_resource")
            text = text[:first] + '[sub_resource type="Resource" id="%s"]\n%s\n' % (effect_id, body) + text[first:]
            ids.append(effect_id)
        text = mt.set_effects(text, node_id, ids, script_id)
        done.append(node_id)
    return text, done


def entry_nodes(tree, text):
    for node_id, towers in ENTRY[tree].items():
        flag = sum(TOWERS[t] for t in towers)
        m = mt.node_block(text, node_id)
        listed = re.search(r'effects = [^\n]*', m.group(0))
        for effect_id in re.findall(r'SubResource\("([^"]+)"\)', listed.group(0)) if listed else []:
            em = re.search(r'\[sub_resource type="Resource" id="%s"\]\n((?:[^\[\n][^\n]*\n)*)' % effect_id, text)
            body = em.group(1)
            flags = re.search(r'^buildings = (\d+)$', body, re.M)
            # no buildings flag = every building already
            if flags and int(flags.group(1)) & flag != flag:
                body = body.replace(flags.group(0), "buildings = %d" % (int(flags.group(1)) | flag))
                text = text[:em.start(1)] + body + text[em.end(1):]
        m = mt.node_block(text, node_id)
        block = m.group(0)
        for old, new in TEXT:
            if new not in block:
                block = block.replace(old, new)
        text = text[:m.start()] + block + text[m.end():]
    return text


def main():
    for tree in ("building", "fire", "frost", "poison"):
        path = os.path.join(mt.TREES, "%s_tree.tres" % tree)
        text = open(path, encoding="utf8").read()
        report = []
        for tower in TOWERS:
            text, done = tower_nodes(tree, text, tower)
            report.append("%s %d" % (NAMES[tower], len(done)))
        text = entry_nodes(tree, text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        with open(path, "w", encoding="utf8", newline="\n") as f:
            f.write(text)
        print(tree, "working:", ", ".join(report))


if __name__ == "__main__":
    main()
