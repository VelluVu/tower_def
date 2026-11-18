"""Gives the Leopard Trap its element choices (2026-11-16), so the trap branches of the element trees and the Leopard
line of the Building tree do something. Rewrites the trap's EvolveTree in leopard_trap.tscn and the evolve prices in
its upgrade data; run tools/tier_data.py afterwards (it writes and wires the trap's T2/T3 and their talent unlocks).

    python tools/trap_elements.py

T1 per element (the design doc's Trap evolves), built from existing mechanics (TowerHitEffects):
    Leopard (Physical)  faster re-arm, keeps the bleed
    Fire                burning ground patch where it snaps, and the snap always ignites
    Frost               a short root (a 0.5 s freeze on every snap) and the Frost slow
    Poison              a poison cloud where it snaps
The element damage data is the Nova's (burn, slow stacks, poison stacks). Safe to run twice.
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENE = os.path.join(ROOT, "scenes", "unit", "building", "buildings", "leopard_trap.tscn")
DATA = os.path.join(ROOT, "scenes", "upgrades", "building_upgrades", "leopard_trap_upgrade_data.tres")
NOVA_EVOLVE = "res://scenes/unit/evolve_tree/puffe_nova_evolve/%s_puffe_nova_evolve_damage_data.tscn"
ICONS = "res://assets/art/ui/%s_element_icon.png"
TRAP_ICON = "res://assets/art/units/building/leopard_trap/lebu_trap_icon.png"
# Utils.StatType numbers, Utils.ModifyType: Flat 0, Multiply 1
DAMAGE, ATTACK_SPEED, EFFECT_CHANCE, FREEZE_CHANCE, FREEZE_DURATION, PATCH_DURATION, PATCH_SHARE = 2, 6, 11, 21, 22, 25, 26
FLAT, MULTIPLY = 0, 1

# leaf name: (element flag, info, damage data colour or None, icon name, glow colour, [(stat, modify, value)])
LEAVES = [
    ("PhysicalElementEvolveLeaf", 1, "Leopard: re-arms faster", None, "normal", None,
     [(ATTACK_SPEED, FLAT, 0.25), (DAMAGE, MULTIPLY, 0.15)]),
    ("FireElementEvolveLeaf", 2, "Fire: the snap ignites and leaves burning ground for 2 s", "red", "fire", "Color(1, 0.518903, 0.445677, 1)",
     [(EFFECT_CHANCE, FLAT, 0.7), (PATCH_DURATION, FLAT, 2.0), (PATCH_SHARE, FLAT, 0.3)]),
    ("FrostElementEvolveLeaf", 4, "Frost: the snap roots for 0.5 s and slows", "blue", "frost", "Color(0.494118, 1, 1, 1)",
     [(FREEZE_CHANCE, FLAT, 1.0), (FREEZE_DURATION, FLAT, 0.5)]),
    ("PoisonElementEvolveLeaf", 8, "Poison: the snap poisons and leaves a poison cloud for 3 s", "green", "poison", "Color(0.571428, 1, 0.494981, 1)",
     [(PATCH_DURATION, FLAT, 3.0), (PATCH_SHARE, FLAT, 0.2)]),
]


def ext(text, kind, path, ext_id):
    if 'id="%s"' % ext_id in text:
        return text
    last = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
    return text[:last] + '[ext_resource type="%s" path="%s" id="%s"]\n' % (kind, path, ext_id) + text[last:]


def main():
    text = open(SCENE, encoding="utf8").read()
    text = ext(text, "Script", "res://scenes/unit/evolve_tree/element_evolve_leaf.gd", "trap_leaf_script")
    text = ext(text, "Script", "res://scenes/unit/stats/modifier.gd", "trap_modifier_script")
    text = ext(text, "Texture2D", TRAP_ICON, "trap_selected_icon")
    branch_script = re.search(r'\[node name="EvolveBranch" type="Node" parent="EvolveTree"\]\nscript = ExtResource\("([^"]+)"\)', text).group(1)
    for _, _, _, colour, icon, _, _ in LEAVES:
        text = ext(text, "Texture2D", ICONS % icon, "trap_icon_%s" % icon)
        if colour:
            text = ext(text, "PackedScene", NOVA_EVOLVE % colour, "trap_damage_%s" % colour)
    # every node under EvolveTree goes; the branches and leaves are written again below
    text = re.sub(r'\[node name="[^"]+" type="Node" parent="EvolveTree(/[^"]*)?"\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    block = ""
    for i, (leaf, element, info, colour, icon, glow, modifiers) in enumerate(LEAVES):
        branch = "EvolveBranch" + (str(i + 1) if i else "")
        block += '[node name="%s" type="Node" parent="EvolveTree"]\nscript = ExtResource("%s")\nevolve_level = 2\n\n' % (branch, branch_script)
        lines = ['script = ExtResource("trap_leaf_script")']
        if element != 1:
            lines.append("evolve_element = %d" % element)
        lines.append('selected_icon = ExtResource("trap_selected_icon")')
        if colour:
            lines.append('new_damage_data_scene = ExtResource("trap_damage_%s")' % colour)
        if glow:
            lines.append("evolve_glow_color = %s" % glow)
        lines.append('icon = ExtResource("trap_icon_%s")' % icon)
        lines.append('info = "%s"' % info)
        block += '[node name="%s" type="Node" parent="EvolveTree/%s"]\n%s\n\n' % (leaf, branch, "\n".join(lines))
        for j, (stat, modify, value) in enumerate(modifiers):
            block += ('[node name="Modifier%d" type="Node" parent="EvolveTree/%s/%s"]\nscript = ExtResource("trap_modifier_script")\n'
                      'calculate_type = %d\nstat_type = %d\nvalue = %s\n\n') % (j, branch, leaf, modify, stat, repr(float(value)))
    m = re.search(r'\[node name="EvolveTree" type="Node" parent="\."\]\n(?:[^\[\n][^\n]*\n)*\n?', text)
    text = text[:m.end()] + block + text[m.end():]
    open(SCENE, "w", encoding="utf8", newline="\n").write(text)

    data = open(DATA, encoding="utf8").read()
    data = re.sub(r'evolve_cost_ratios = [^\n]*\n', '', data)
    data = data.rstrip("\n") + "\nevolve_cost_ratios = Array[float]([1.5, 2.5, 4.0])\n"
    open(DATA, "w", encoding="utf8", newline="\n").write(data)
    print("trap element leaves written")


if __name__ == "__main__":
    main()
