"""Build the five variant enemies of 2026-11-16 (leaper frog, bloater, sapper, burrower, crystal brute): their scenes
from a parent enemy (tools/enemy_scene.py), then their abilities and resistances. Their art is their own, drawn by
tools/sprite/parts/new_enemies_art.py (specs next to the sheets). Rerun after changing a number here; it rewrites the
five .tscn files.

    python tools/new_enemies_2026_11.py
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMIES = os.path.join(ROOT, "scenes", "unit", "enemy", "enemies")
ABILITIES = "res://scenes/unit/enemy/abilities/"
RESISTANCES = "res://scenes/unit/enemy/resistances/"

# name: (parent, stats for enemy_scene.py, resistance profile or None, extra nodes)
ENEMIES_2026_11 = {
    "leaper_frog": ("swampling", ["health=16", "speed=24", "price=2"], "swamp",
                    ("abilities", "Leap", "burrow_ability.gd", [
                        "cooldown = 5.0", "starts_on_cooldown = true", "hidden_time = 0.4", "min_cells_ahead = 3",
                        "max_cells_ahead = 4", "castle_margin = 3", 'burrow_animation = "LEAP"', 'emerge_animation = "LAND"'])),
    "bloater": ("plaguepig", ["health=50", "speed=10", "price=5"], "plaguepig",
                ("component", "DeathBurst", "death_burst.gd", ["radius = 1.5", "damage = 4.0", "damage_type = 8"])),
    "sapper": ("soldier", ["health=20", "speed=17", "price=2"], None,
               ("abilities", "PlantCharge", "ranged_shot_ability.gd", [
                   "cooldown = 9.0", "shot_range = 2.5", "damage = 3.0", "area_radius = 1.0",
                   'shot_texture = ExtResource("charge_texture")', "shot_hframes = 2", "shot_vframes = 2",
                   "shot_speed = 70.0", "shot_arc = 16.0", "shot_offset = Vector2(0, -8)"])),
    "burrower": ("soldier", ["health=14", "speed=20", "price=1"], None,
                 ("abilities", "Dig", "burrow_ability.gd", [
                     "cooldown = 9.0", "starts_on_cooldown = true", "hidden_time = 1.5", "min_cells_ahead = 4",
                     "max_cells_ahead = 6"])),
    "crystal_brute": ("beefling", ["health=60", "speed=12", "price=6"], "crystal", None),
}
CHARGE_TEXTURE = "res://assets/art/units/enemy/destroyerling/destroyerling_rock.png"


def add_ext(text, line):
    last = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
    return text[:last] + line + "\n" + text[last:]


def build(name, parent, stats, profile, extra):
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "enemy_scene.py"), parent, name] + stats, check=True)
    path = os.path.join(ENEMIES, name + ".tscn")
    text = open(path, encoding="utf8").read()
    # the parent's abilities and resistances are not the variant's
    text = re.sub(r'\[node name="EnemyAbilities"[^\n]*\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    text = re.sub(r'\[node name="[^"]+" type="Node" parent="EnemyAbilities"\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    text = re.sub(r'\nresistances = ExtResource\("res_profile"\)', '', text)
    text = re.sub(r'\[ext_resource type="Resource" path="res://scenes/unit/enemy/resistances/[^"]+" id="res_profile"\]\n', '', text)
    text = re.sub(r'\ncan_wade = true', '', text)
    if profile:
        text = add_ext(text, '[ext_resource type="Resource" path="%s%s.tres" id="res_profile"]' % (RESISTANCES, profile))
        m = re.search(r'(\[node name="[^"]+" type="RigidBody2D"[^\]]*\]\n(?:[^\[\n][^\n]*\n)*?script = [^\n]+\n)', text)
        text = text[:m.end()] + 'resistances = ExtResource("res_profile")\n' + text[m.end():]
    if extra:
        kind, node, script, props = extra
        text = add_ext(text, '[ext_resource type="Script" path="%s%s" id="extra_script"]' % (ABILITIES, script))
        if any("charge_texture" in p for p in props):
            text = add_ext(text, '[ext_resource type="Texture2D" path="%s" id="charge_texture"]' % CHARGE_TEXTURE)
        text = text.rstrip("\n") + "\n"
        if kind == "abilities":
            text = add_ext(text, '[ext_resource type="Script" path="%senemy_abilities.gd" id="abilities_script"]' % ABILITIES)
            text += '\n[node name="EnemyAbilities" type="Node" parent="."]\nscript = ExtResource("abilities_script")\n'
            text += '\n[node name="%s" type="Node" parent="EnemyAbilities"]\nscript = ExtResource("extra_script")\n%s\n' % (node, "\n".join(props))
        else:
            text += '\n[node name="%s" type="Node" parent="."]\nscript = ExtResource("extra_script")\n%s\n' % (node, "\n".join(props))
    open(path, "w", encoding="utf8", newline="\n").write(text)
    print("built", name)


if __name__ == "__main__":
    for enemy_name, spec in ENEMIES_2026_11.items():
        build(enemy_name, *spec)
