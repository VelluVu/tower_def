"""Give the Scorched Lands enemies their abilities and components (levels 37-48). Run after tools/scorched_enemies.py
(which rewrites the scenes from their parents without any); rerunning this alone replaces what it added before.

    python tools/scorched_abilities.py [names...]

Abilities go under an EnemyAbilities node (child order = priority, see EnemyAbilities); components are direct
children. Values: a property line as it appears in the .tscn; ExtResource ids come from REFS.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMIES = os.path.join(ROOT, "scenes", "unit", "enemy", "enemies")
ABILITIES = "res://scenes/unit/enemy/abilities/"
COMPONENTS = "res://scenes/unit/enemy/components/"
MARK = "scorched_"

# ExtResource id: (type, path)
REFS = {
    "bone_thrall": ("PackedScene", "res://scenes/unit/enemy/enemies/bone_thrall.tscn"),
    "magma_blob": ("PackedScene", "res://scenes/unit/enemy/enemies/magma_blob.tscn"),
    "ash_drake": ("PackedScene", "res://scenes/unit/enemy/enemies/ash_drake.tscn"),
    "arrow": ("Texture2D", "res://assets/art/projectile/enemy_arrow.png"),
    "lava_glob": ("Texture2D", "res://assets/art/units/enemy/lava_spitter/lava_glob.png"),
    "bone_shard": ("Texture2D", "res://assets/art/units/enemy/bone_colossus/bone_shard.png"),
}
FIRE, FROST = 2, 4
MOLTEN = ("component", "MoltenBody", COMPONENTS + "molten_body.gd", [])

# name: [(kind, node name, script, [property lines])]
SETUP = {
    "grave_caller": [("ability", "RaiseDead", ABILITIES + "raise_dead_ability.gd", [
        "cooldown = 6.0", "starts_on_cooldown = true", "raise_range = 3.5", 'raised_scene = ExtResource("scorched_bone_thrall")'])],
    "rusted_ballista": [("ability", "Bolt", ABILITIES + "ranged_shot_ability.gd", [
        "cooldown = 6.0", "starts_on_cooldown = true", "shot_range = 5.0", "damage = 3.0", "pierce_line = true",
        'shot_texture = ExtResource("scorched_arrow")', "shot_speed = 200.0", "shot_rotates = true",
        "shot_offset = Vector2(0, -10)"])],
    "bone_colossus": [
        ("ability", "TailSweep", ABILITIES + "multi_strike_ability.gd", [
            "min_health_ratio = 0.33", "cooldown = 5.0", "strike_range = 2.5", "targets = 3", "damage = 3.0"]),
        ("ability", "Frenzy", ABILITIES + "brood_frenzy_ability.gd", [
            "max_health_ratio = 0.33", "cooldown = 0.0", 'screech_animation = "ATTACK"', "silence_radius = 3.0",
            "speed_bonus = 0.5", 'swarm_scene = ExtResource("scorched_bone_thrall")', "swarm_count = 4"]),
        ("ability", "SinkIntoSand", ABILITIES + "burrow_ability.gd", [
            "min_health_ratio = 0.33", "max_health_ratio = 0.66", "cooldown = 12.0", "hidden_time = 2.5",
            'tunnel_scene = ExtResource("scorched_bone_thrall")', "tunnel_count = 4", 'burrow_animation = "SUBMERGE"',
            'emerge_animation = "EMERGE"']),
        ("ability", "BoneSpit", ABILITIES + "ranged_shot_ability.gd", [
            "min_health_ratio = 0.66", "cooldown = 7.0", "starts_on_cooldown = true", "shot_range = 5.0",
            "target_rule = 1", "towers_only = true", "damage = 3.0", "area_radius = 1.0", 'shot_animation = "SPIT"',
            'shot_texture = ExtResource("scorched_bone_shard")', "shot_hframes = 2", "shot_speed = 100.0",
            "shot_arc = 24.0", "shot_offset = Vector2(0, -24)"])],
    "cinder_imp": [MOLTEN],
    "magma_salamander": [MOLTEN],
    "magma_blob": [MOLTEN],
    "obsidian_golem": [MOLTEN, ("component", "DeathSpawn", COMPONENTS + "death_spawn.gd", [
        'scene = ExtResource("scorched_magma_blob")', "count = 2"])],
    "ember_wisp": [("component", "Rebirth", COMPONENTS + "rebirth.gd", ["health_share = 0.6", "put_out_by_area = true"])],
    "phoenix": [("component", "Rebirth", COMPONENTS + "rebirth.gd", ["health_share = 0.6"])],
    "ember_cultist": [("ability", "FireWard", ABILITIES + "fire_ward_ability.gd", [
        "cooldown = 6.0", "ward_range = 3.0", "targets = 4"])],
    "lava_spitter": [MOLTEN, ("ability", "LavaGlob", ABILITIES + "ranged_shot_ability.gd", [
        "cooldown = 6.0", "starts_on_cooldown = true", "shot_range = 5.0", "target_rule = 1", "towers_only = true",
        "damage = 3.0", "damage_type = %d" % FIRE, "area_radius = 1.0", "scorch_seconds = 10.0",
        'shot_texture = ExtResource("scorched_lava_glob")', "shot_hframes = 2", "shot_vframes = 2", "shot_speed = 90.0",
        "shot_arc = 24.0", "shot_offset = Vector2(0, -12)"])],
    # the volcano's mid-boss (57): slams and hurls magma above 66%, cracks the ground under towers 66-33% (the Wyrm's
    # Erupt), and under 33% roars up magma blobs and speeds up; the hurl and slam go on through every phase
    "magma_titan": [
        MOLTEN,
        ("ability", "MagmaCall", ABILITIES + "brood_frenzy_ability.gd", [
            "max_health_ratio = 0.33", "cooldown = 0.0", 'screech_animation = "ROAR"', "silence_radius = 3.0",
            "speed_bonus = 0.3", 'swarm_scene = ExtResource("scorched_magma_blob")', "swarm_count = 6"]),
        ("ability", "Erupt", ABILITIES + "erupt_ability.gd", [
            "min_health_ratio = 0.33", "max_health_ratio = 0.66", "cooldown = 8.0", "starts_on_cooldown = true"]),
        ("ability", "MagmaSlam", ABILITIES + "multi_strike_ability.gd", [
            "cooldown = 6.0", "strike_range = 2.0", "targets = 3", "damage = 3.0", "damage_type = %d" % FIRE,
            'strike_animation = "SLAM"']),
        ("ability", "MagmaHurl", ABILITIES + "ranged_shot_ability.gd", [
            "cooldown = 8.0", "starts_on_cooldown = true", "shot_range = 5.0", "target_rule = 1", "towers_only = true",
            "damage = 3.0", "damage_type = %d" % FIRE, "area_radius = 1.0", "scorch_seconds = 10.0", 'shot_animation = "HURL"',
            'shot_texture = ExtResource("scorched_lava_glob")', "shot_hframes = 2", "shot_vframes = 2", "shot_speed = 90.0",
            "shot_arc = 28.0", "shot_offset = Vector2(0, -26)"])],
    "ashen_wyrm": [
        MOLTEN,
        ("ability", "Land", ABILITIES + "land_ability.gd", ["max_health_ratio = 0.66", "cooldown = 0.0"]),
        ("ability", "BroodOfAsh", ABILITIES + "brood_frenzy_ability.gd", [
            "max_health_ratio = 0.33", "cooldown = 0.0", 'screech_animation = "ROAR"', "silence_radius = 4.0",
            "speed_bonus = 0.3", 'swarm_scene = ExtResource("scorched_ash_drake")', "swarm_count = 6",
            "heads_for_fullest_castle = true"]),
        ("ability", "Erupt", ABILITIES + "erupt_ability.gd", [
            "min_health_ratio = 0.33", "max_health_ratio = 0.66", "cooldown = 7.0", "starts_on_cooldown = true"]),
        ("ability", "FireBreath", ABILITIES + "fire_breath_ability.gd", [
            "min_health_ratio = 0.66", "cooldown = 7.0", "starts_on_cooldown = true"]),
        ("ability", "LastBreath", ABILITIES + "fire_breath_ability.gd", [
            "max_health_ratio = 0.33", "cooldown = 9.0", "damage = 5.0"])],
}
# lava crossings (BogCrossing over lava): the salamander swims
WADERS = ("magma_salamander",)


def add_ext(text, line):
    last = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
    return text[:last] + line + "\n" + text[last:]


def build(name):
    path = os.path.join(ENEMIES, name + ".tscn")
    text = open(path, encoding="utf8").read()
    # what an earlier run added
    text = re.sub(r'\[ext_resource [^\n]*id="%s[^"]*"\]\n' % MARK, "", text)
    text = re.sub(r'\n\[node name="[^"]+" type="Node2?D?" parent="(?:\.|EnemyAbilities)"\]\nscript = ExtResource\("%s[^"]*"\)\n(?:[^\[\n][^\n]*\n)*' % MARK, "\n", text)
    text = re.sub(r'\n\[node name="EnemyAbilities" type="Node" parent="\."\]\nscript = ExtResource\("%sabilities"\)\n' % MARK, "\n", text)
    text = re.sub(r'\ncan_wade = true', '', text)
    items = SETUP.get(name, [])
    scripts = {}
    for _, node, script, _ in items:
        scripts.setdefault(script, "%sscript_%d" % (MARK, len(scripts)))
    for script, rid in scripts.items():
        text = add_ext(text, '[ext_resource type="Script" path="%s" id="%s"]' % (script, rid))
    used = set(re.findall(r'ExtResource\("%s(\w+)"\)' % MARK, " ".join(p for item in items for p in item[3])))
    for ref in sorted(used):
        kind, ref_path = REFS[ref]
        text = add_ext(text, '[ext_resource type="%s" path="%s" id="%s%s"]' % (kind, ref_path, MARK, ref))
    text = text.rstrip("\n") + "\n"
    if any(kind == "ability" for kind, _, _, _ in items):
        text = add_ext(text, '[ext_resource type="Script" path="%senemy_abilities.gd" id="%sabilities"]' % (ABILITIES, MARK))
        text += '\n[node name="EnemyAbilities" type="Node" parent="."]\nscript = ExtResource("%sabilities")\n' % MARK
    for kind, node, script, props in items:
        parent = "EnemyAbilities" if kind == "ability" else "."
        text += '\n[node name="%s" type="Node" parent="%s"]\nscript = ExtResource("%s")\n%s' % (
            node, parent, scripts[script], "".join(p + "\n" for p in props))
    if name in WADERS:
        m = re.search(r'(\[node name="[^"]+" type="RigidBody2D"[^\]]*\]\n(?:[^\[\n][^\n]*\n)*?script = [^\n]+\n)', text)
        text = text[:m.end()] + "can_wade = true\n" + text[m.end():]
    open(path, "w", encoding="utf8", newline="\n").write(text)
    print("set up", name)


if __name__ == "__main__":
    for enemy_name in sys.argv[1:] or sorted(set(SETUP) | set(WADERS)):
        build(enemy_name)
