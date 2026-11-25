"""The Mortar's talents (2026-11-24), rerunnable:

    python tools/mortar_talents.py

- the Mortar branch's stat nodes (from tools/new_tower_talents.py) get their TalentEffects: damage (Multiply, like
  every talent damage), range, blast radius (SplashRadius), attack speed, crit, ignite chance, potency, the ground
  patches, and Shatter Shell's damage to frozen enemies
- the entry node each branch shares with the Nova's path (Blast Furnace, Frost Ring, Toxic Burst; Hardened Shots in
  the Building tree) counts for the Mortar too: its effects get the Mortar flag and its text names the Mortar
The mechanic nodes (stuns, rubble, knockback by a fraction of a tile, armour, extra stacks per splash, the "every 5th
shell" capstones) stay without effects until their mechanics exist.
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TREES = os.path.join(ROOT, "scenes", "talents", "trees")
MORTAR = 32  # TalentEffect.MORTAR
ELEMENT = {"building": 1, "fire": 2, "frost": 4, "poison": 8}
ENTRY = {"building": "hardened_shots", "fire": "blast_furnace", "frost": "frost_ring", "poison": "toxic_burst"}
# stat types (Utils.StatType) and modify types (Flat 0, Multiply 1)
DAMAGE, RANGE, SPEED, CRIT, POTENCY, CHANCE, SPLASH, FREEZE_CHANCE, FREEZE_TIME, PATCH, PATCH_SHARE = 2, 5, 6, 7, 10, 11, 20, 21, 22, 25, 26
FLAT, MULTIPLY = 0, 1
VULNERABILITY, FROZEN = 3, 3  # TalentEffect.Kind.Vulnerability, Condition.Frozen
# description pattern -> [(kind, stat, modify, value per rank, condition)]
RULES = [
    (r"Mortar damage \+(\d+)%", lambda m: [(0, DAMAGE, MULTIPLY, int(m.group(1)) / 100.0, 0)]),
    (r"Mortar range \+([\d.]+) tiles", lambda m: [(0, RANGE, FLAT, float(m.group(1)), 0)]),
    (r"Mortar splash radius \+([\d.]+) tiles", lambda m: [(0, SPLASH, FLAT, float(m.group(1)), 0)]),
    (r"Mortar attack speed \+([\d.]+)", lambda m: [(0, SPEED, FLAT, float(m.group(1)), 0)]),
    (r"Mortar critical chance \+(\d+) points", lambda m: [(0, CRIT, FLAT, int(m.group(1)) / 100.0, 0)]),
    (r"Mortar ignite chance \+(\d+) points", lambda m: [(0, CHANCE, FLAT, int(m.group(1)) / 100.0, 0)]),
    (r"Mortar (?:burn |slow )?potency \+(\d+)%", lambda m: [(0, POTENCY, FLAT, int(m.group(1)) / 100.0, 0)]),
    (r"burning patch a shell leaves lasts ([\d.]+) s longer", lambda m: [(0, PATCH, FLAT, float(m.group(1)), 0)]),
    (r"A shell leaves (?:chilled ground|a poison cloud) for ([\d.]+) s",
     lambda m: [(0, PATCH, FLAT, float(m.group(1)), 0), (0, PATCH_SHARE, FLAT, 0.1, 0)]),
    (r"Shells deal \+(\d+)% damage to frozen enemies", lambda m: [(VULNERABILITY, DAMAGE, FLAT, int(m.group(1)) / 100.0, FROZEN)]),
]


def node_block(text, node_id):
    m = re.search(r'\[sub_resource type="Resource" id="[^"]+"\]\n(?:[^\[\n][^\n]*\n)*?id = &"%s"\n(?:[^\[\n][^\n]*\n)*' % node_id, text)
    return m


def effect_script_id(text):
    return re.search(r'\[ext_resource type="Script"[^\]]*path="res://scenes/talents/talent_effect.gd" id="([^"]+)"\]', text).group(1)


def set_effects(text, node_id, effect_ids, script_id):
    m = node_block(text, node_id)
    block = re.sub(r'effects = [^\n]*\n', '', m.group(0))
    block = block.rstrip("\n") + '\neffects = Array[ExtResource("%s")]([%s])\n\n' % (
        script_id, ", ".join('SubResource("%s")' % e for e in effect_ids))
    return text[:m.start()] + block + text[m.end():]


def mortar_nodes(tree, text):
    script_id = effect_script_id(text)
    # the old run's effects go first, so a rerun writes them anew
    text = re.sub(r'\[sub_resource type="Resource" id="Effect_mortar_[^"]*"\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    done = []
    for node_id, desc in re.findall(r'id = &"(mortar_[a-z_]+)"\ndisplay_name = "[^"]*"\ndescription = "([^"]*)"', text):
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
        for i, (kind, stat, modify, value, condition) in enumerate(effects):
            effect_id = "Effect_mortar_%s_%d" % (node_id[len("mortar_"):], i)
            body = 'script = ExtResource("%s")\n' % script_id
            if kind:
                body += "kind = %d\n" % kind
            body += "buildings = %d\nelements = %d\n" % (MORTAR, ELEMENT[tree])
            if stat != DAMAGE:
                body += "stat_type = %d\n" % stat
            body += "modify_type = %d\nvalue_per_rank = %s\n" % (modify, repr(value))
            if condition:
                body += "condition = %d\n" % condition
            first = text.index("[sub_resource")
            text = text[:first] + '[sub_resource type="Resource" id="%s"]\n%s\n' % (effect_id, body) + text[first:]
            ids.append(effect_id)
        text = set_effects(text, node_id, ids, script_id)
        done.append(node_id)
    return text, done


def entry_node(tree, text):
    node_id = ENTRY[tree]
    m = node_block(text, node_id)
    effects = re.findall(r'SubResource\("([^"]+)"\)', re.search(r'effects = [^\n]*', m.group(0)).group(0))
    for effect_id in effects:
        em = re.search(r'\[sub_resource type="Resource" id="%s"\]\n((?:[^\[\n][^\n]*\n)*)' % effect_id, text)
        body = em.group(1)
        flags = re.search(r'^buildings = (\d+)$', body, re.M)
        # no buildings flag = every building already
        if flags and int(flags.group(1)) & MORTAR == 0:
            body = body.replace(flags.group(0), "buildings = %d" % (int(flags.group(1)) | MORTAR))
            text = text[:em.start(1)] + body + text[em.end(1):]
    m = node_block(text, node_id)
    block = re.sub(r'description = "(Fire|Frost|Poison) Nova damage', r'description = "\1 Nova and Mortar damage', m.group(0))
    return text[:m.start()] + block + text[m.end():]


def main():
    for tree in ("building", "fire", "frost", "poison"):
        path = os.path.join(TREES, "%s_tree.tres" % tree)
        text = open(path, encoding="utf8").read()
        text, done = mortar_nodes(tree, text)
        text = entry_node(tree, text)
        text = re.sub(r"\n{3,}", "\n\n", text)
        with open(path, "w", encoding="utf8", newline="\n") as f:
            f.write(text)
        print(tree, len(done), "Mortar nodes working:", ", ".join(done))


if __name__ == "__main__":
    main()
