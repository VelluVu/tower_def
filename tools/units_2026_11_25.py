"""Build the sixteen enemies of 2026-11-25 (four per area; design doc, Enemies -> Rosters): each scene from a parent
enemy of the same build (tools/enemy_scene.py through new_enemies_2026_11.build, which drops the parent's abilities and
resistances), then its resistance profile, root flags, abilities and components. Their art is drawn by
tools/sprite/parts/units_2026_11_25_art.py. Placeholder stats: the balancing comes after the bug rounds. Rerun after
changing a number here; it rewrites the .tscn files.

    python tools/units_2026_11_25.py [names...]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from new_enemies_2026_11 import build, add_ext  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENEMIES = os.path.join(ROOT, "scenes", "unit", "enemy", "enemies")
ABILITIES = "res://scenes/unit/enemy/abilities/"
COMPONENTS = "res://scenes/unit/enemy/components/"
MARK = "u1125_"
FIRE = 2

# ExtResource id (after MARK): (type, path)
REFS = {
    "leechling": ("PackedScene", "res://scenes/unit/enemy/enemies/leechling.tscn"),
    "arrow": ("Texture2D", "res://assets/art/projectile/enemy_arrow.png"),
}

# name: (parent, stats for enemy_scene.py, resistance profile or None, root property lines,
#        [(kind "ability"/"component", node name, node type, script, [property lines])])
UNITS = {
    # Caves
    "cave_shaman": ("wizard", ["health=22", "speed=15", "price=3"], None, [], [
        ("ability", "StoneSkin", "Node", ABILITIES + "fire_ward_ability.gd", [
            "cooldown = 7.0", "starts_on_cooldown = true", "ward_range = 3.0", "targets = 3",
            "ward_color = Color(0.62, 0.62, 0.66, 1)"])]),
    "wall_crawler": ("fastswampling", ["health=14", "speed=22", "price=2"], "cave_fast", ["can_be_held = false"], [
        ("component", "WallClimber", "Node", COMPONENTS + "wall_climber.gd", ["wall_weight = 1.2"])]),
    "spore_carrier": ("fastling", ["health=20", "speed=18", "price=2"], None, [], [
        ("component", "DeathCloud", "Node", COMPONENTS + "death_cloud.gd", [
            "radius = 1.5", "duration = 4.0", "heal_share = 0.06"])]),
    "glow_moth": ("batling", ["health=6", "speed=20", "price=1", "xp=0.4"], None, [], []),
    # Swamp
    "bog_witch": ("wizard", ["health=24", "speed=15", "price=4"], "swamp", [], [
        ("ability", "Hex", "Node", ABILITIES + "curse_towers_ability.gd", [
            "cooldown = 6.0", "starts_on_cooldown = true", "curse_range = 3.5", "targets = 2", "slow = 0.3",
            "curse_seconds = 5.0"])]),
    "snapping_turtle": ("plaguepig", ["health=70", "speed=11", "price=7", "gore=bog_ichor_spill"], "swamp", [], [
        ("component", "ShellGuard", "Node", COMPONENTS + "shell_guard.gd", [
            "trigger_share = 0.08", "shell_seconds = 2.0", "damage_share = 0.3", "cooldown = 4.0"])]),
    "mosquito": ("giant_wasp", ["health=5", "speed=24", "price=1", "xp=0.4"], "swamp", [], []),
    "leech_mother": ("plaguepig", ["health=55", "speed=10", "price=6", "gore=blood_spill"], "swamp", [], [
        ("ability", "Brood", "Node", ABILITIES + "lay_egg_ability.gd", [
            "cooldown = 4.0", "starts_on_cooldown = true", 'egg_scene = ExtResource("%sleechling")' % MARK])]),
    # Humans
    "shieldbearer": ("armored_knight", ["health=60", "speed=12", "price=6"], "armored", [], [
        ("component", "ShieldAura", "Node2D", COMPONENTS + "shield_aura.gd", ["radius = 1.5", "reduction = 0.4"])]),
    "battering_ram": ("armored_knight", ["health=90", "speed=8", "price=8", "hitbox=20x14"], "siege_engine",
                      ["can_be_held = false", "wall_path_weight = 8.0"], []),
    "war_drummer": ("soldier", ["health=20", "speed=17", "price=3"], None, [], [
        ("component", "SpeedAura", "Node", COMPONENTS + "speed_aura.gd", ["radius = 2.5", "bonus = 0.25"])]),
    "crossbow_sniper": ("archer", ["health=16", "speed=16", "price=4"], None, [], [
        ("ability", "Snipe", "Node", ABILITIES + "ranged_shot_ability.gd", [
            "cooldown = 8.0", "starts_on_cooldown = true", "shot_range = 6.0", "target_rule = 2", "towers_only = true",
            "damage = 2.0", "silence_time = 2.0", 'shot_texture = ExtResource("%sarrow")' % MARK, "shot_speed = 220.0",
            "shot_rotates = true", "shot_offset = Vector2(0, -8)"])]),
    # Scorched Lands
    "sand_wurm": ("beefling", ["health=60", "speed=12", "price=6"], None, [], [
        ("ability", "Dive", "Node", ABILITIES + "burrow_ability.gd", [
            "cooldown = 10.0", "starts_on_cooldown = true", "hidden_time = 2.0", "min_cells_ahead = 8",
            "max_cells_ahead = 12", "castle_margin = 4"])]),
    "bone_vulture": ("giant_eagle", ["health=10", "speed=24", "price=1", "xp=0.5"], "undead", [], [
        ("component", "Rebirth", "Node", COMPONENTS + "rebirth.gd", ["health_share = 0.5", "lands = true"])]),
    "mummy_priest": ("priest", ["health=26", "speed=14", "price=4"], "undead_caster", [], [
        ("component", "DeathCurse", "Node", ABILITIES + "death_burst.gd", [
            "radius = 2.0", "damage = 0.0", "silence_time = 3.0"])]),
    "ash_harpy": ("giant_eagle", ["health=26", "speed=24", "price=3"], "volcanic", [], [
        ("component", "MoltenBody", "Node", COMPONENTS + "molten_body.gd", []),
        ("ability", "Dive", "Node", ABILITIES + "multi_strike_ability.gd", [
            "cooldown = 7.0", "starts_on_cooldown = true", "strike_range = 2.5", "targets = 1", "damage = 3.0",
            "damage_type = %d" % FIRE])]),
    # the second round (the user's picks 2026-11-25): each answers a tower that is strong today
    "tunnel_rat": ("swarmling", ["health=5", "speed=30", "price=1", "xp=0.4"], None, ["ignores_traps = true"], []),
    "bog_lurker": ("fastswampling", ["health=40", "speed=16", "price=4"], "swamp", [], [
        ("component", "Submerged", "Node", COMPONENTS + "submerged.gd", ["surface_cells = 8"])]),
    "standard_bearer": ("soldier", ["health=30", "speed=16", "price=4"], None, [], [
        ("component", "SteadfastAura", "Node", COMPONENTS + "steadfast_aura.gd", ["radius = 2.5"])]),
    "ash_wraith": ("wizard", ["health=30", "speed=17", "price=4"], "undead_caster", [], [
        ("component", "PhaseShift", "Node", COMPONENTS + "phase_shift.gd", ["period = 4.0", "phase_seconds = 1.0"])]),
}
# the ram's blow on buildings (its MeleeAttack's own Damage; the unit's Damage stays the life it costs)
MELEE_DAMAGE = {"battering_ram": 6.0}


def set_up(name, roots, items):
    path = os.path.join(ENEMIES, name + ".tscn")
    text = open(path, encoding="utf8").read()
    scripts = {}
    for _, _, _, script, _ in items:
        scripts.setdefault(script, "%sscript_%d" % (MARK, len(scripts)))
    for script, rid in scripts.items():
        text = add_ext(text, '[ext_resource type="Script" path="%s" id="%s"]' % (script, rid))
    used = set(re.findall(r'ExtResource\("%s(\w+)"\)' % MARK, " ".join(p for item in items for p in item[4])))
    for ref in sorted(used):
        kind, ref_path = REFS[ref]
        text = add_ext(text, '[ext_resource type="%s" path="%s" id="%s%s"]' % (kind, ref_path, MARK, ref))
    if roots:
        m = re.search(r'(\[node name="[^"]+" type="RigidBody2D"[^\]]*\]\n(?:[^\[\n][^\n]*\n)*?script = [^\n]+\n)', text)
        text = text[:m.end()] + "".join(r + "\n" for r in roots) + text[m.end():]
    if name in MELEE_DAMAGE:
        text = re.sub(r'(\[node name="Damage" type="Node" parent="MeleeAttack/Stats"[^\]]*\]\nscript = [^\n]+\n)base_value = [\d.]+\nvalue = [\d.]+',
                      r'\g<1>base_value = %s\nvalue = %s' % (MELEE_DAMAGE[name], MELEE_DAMAGE[name]), text)
    text = text.rstrip("\n") + "\n"
    if any(kind == "ability" for kind, _, _, _, _ in items):
        text = add_ext(text, '[ext_resource type="Script" path="%senemy_abilities.gd" id="%sabilities"]' % (ABILITIES, MARK))
        text += '\n[node name="EnemyAbilities" type="Node" parent="."]\nscript = ExtResource("%sabilities")\n' % MARK
    for kind, node, node_type, script, props in items:
        parent = "EnemyAbilities" if kind == "ability" else "."
        text += '\n[node name="%s" type="%s" parent="%s"]\nscript = ExtResource("%s")\n%s' % (
            node, node_type, parent, scripts[script], "".join(p + "\n" for p in props))
    open(path, "w", encoding="utf8", newline="\n").write(text)


if __name__ == "__main__":
    for unit in sys.argv[1:] or UNITS:
        parent, stats, profile, roots, items = UNITS[unit]
        build(unit, parent, stats, profile, None)
        set_up(unit, roots, items)
