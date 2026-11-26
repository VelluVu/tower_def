"""The Hatchery's scenes and data (2026-11-25), rerunnable:

    python tools/hatchery_scenes.py      then  python tools/tier_data.py  (the T2/T3 tiers and the leaves' tiers)

Art first: tools/sprite/parts/hatchery_art.py (the brooding drakelings, the guards) and tower_tiers.py ... hatchery.
Writes
- scenes/unit/evolve_tree/puffe_hatchery_evolve/<sheet>_frames.tres: SpriteFrames for the drakelings and the guards
- scenes/unit/building/hatchery/hatchery_guard.tscn: the guard (HatcheryGuard) on the building physics layer, so the
  enemies' melee attacks land on it
- scenes/unit/evolve_tree/puffe_hatchery_evolve/: the element sprite swaps and damage data (copies of the Bolter's:
  burn, slow and poison stacks ride on the claws)
- scenes/unit/building/buildings/puffe_hatchery.tscn: from the Bolter's scene with the Hatchery script, a passive Hatch
  skill (its Damage, crit and AttackRange are the guards' claws and the rally reach), no behaviour tree, the
  GuardHealth and GuardCount stats, element leaves (Physical: tougher, harder claws; Fire: longer burns; Frost: a
  longer slow; Poison: more stacks); puffe_hatchery.tres (the build tray, unlocks on level 43); the upgrade data (a
  copy of the Bolter's)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mortar_scenes as ms

ART = "assets/art/units/building/puffe/puffe_hatchery"
EVOLVE = "scenes/unit/evolve_tree/puffe_hatchery_evolve"
GUARD_SCENE = "scenes/unit/building/hatchery/hatchery_guard.tscn"
ELEMENTS = ms.ELEMENTS
UNLOCK_LEVEL = 11
LIST_ID = 8

# the Hatchery's numbers (placeholders until playtests): three guards of 24 health clawing for 3 a second each
PRICE = 7.0
DAMAGE = 3.0
RANGE_TILES = 2.5
CRIT_CHANCE = 0.05
GUARD_HEALTH = 24.0
FLAT, MULTIPLY = 0, 1
DAMAGE_STAT, EFFECT_DURATION, EFFECT_STACKS = 2, 12, 13
GUARD_HEALTH_STAT, GUARD_COUNT_STAT = 36, 37
GUARD_SKILL_TYPE = 512  # Utils.SkillType.Guard
LEAF_MODIFIERS = {
    "physical": [("DamageModifier", MULTIPLY, DAMAGE_STAT, 0.11), ("ToughHideModifier", MULTIPLY, GUARD_HEALTH_STAT, 0.3)],
    "fire": [("FieryClawsModifier", FLAT, EFFECT_DURATION, 1.0)],
    "frost": [("ColdClawsModifier", FLAT, EFFECT_DURATION, 1.0)],
    "poison": [("VenomClawsModifier", FLAT, EFFECT_STACKS, 1.0)],
}
DRAKELING_LOOPING = ("IDLE",)
GUARD_LOOPING = ("IDLE", "WALK")


def sheet_name(element, kind="puffe_hatchery"):
    return (ms.COLOUR[element] + "_" if ms.COLOUR[element] else "") + kind


def frames(base, out_name, looping):
    ms.EVOLVE = EVOLVE
    ms.LOOPING = looping
    return ms.frames(base, out_name)


def guard_scene(guard_frames):
    text = ('[gd_scene format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/building/hatchery/hatchery_guard.gd" id="1_script"]\n'
            '[ext_resource type="Script" path="res://scenes/unit/animation_control.gd" id="2_control"]\n'
            '[ext_resource type="Material" path="res://assets/shaders/shader_materials/building_hit_shader_material.tres" id="3_material"]\n'
            '[ext_resource type="SpriteFrames" path="%s" id="4_frames"]\n\n'
            '[sub_resource type="CircleShape2D" id="CircleShape2D_guard"]\nradius = 4.0\n\n'
            '[node name="HatcheryGuard" type="StaticBody2D"]\ny_sort_enabled = true\ncollision_layer = 4\ncollision_mask = 0\n'
            'script = ExtResource("1_script")\n\n'
            '[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\nposition = Vector2(0, -2)\n'
            'shape = SubResource("CircleShape2D_guard")\n\n'
            '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\ntexture_filter = 1\nmaterial = ExtResource("3_material")\n'
            'position = Vector2(0, -5)\nsprite_frames = ExtResource("4_frames")\nanimation = &"IDLE"\nscript = ExtResource("2_control")\n'
            ) % guard_frames
    ms.write(GUARD_SCENE, text)
    return "res://" + GUARD_SCENE


def swap_scene(element, drakeling_frames):
    name = sheet_name(element)
    title = "".join(p.capitalize() for p in name.split("_"))
    text = ('[gd_scene format=3]\n\n'
            '[ext_resource type="Material" path="res://assets/shaders/shader_materials/building_hit_shader_material.tres" id="1_material"]\n'
            '[ext_resource type="Script" path="res://scenes/unit/animation_control.gd" id="2_control"]\n'
            '[ext_resource type="SpriteFrames" path="%s" id="3_frames"]\n'
            '[ext_resource type="Texture2D" path="res://assets/art/units/building/puffe/%s.png" id="4_base"]\n\n'
            '[node name="%s" type="AnimatedSprite2D"]\ntexture_filter = 1\nmaterial = ExtResource("1_material")\n'
            'sprite_frames = ExtResource("3_frames")\nanimation = &"IDLE"\nscript = ExtResource("2_control")\n\n'
            '[node name="TowerBaseSprite" type="Sprite2D" parent="."]\nshow_behind_parent = true\ntexture_filter = 1\n'
            'position = Vector2(0, 1)\ntexture = ExtResource("4_base")\n') % (drakeling_frames, ms.TOWER_BASE[element], title)
    path = "%s/%s.tscn" % (EVOLVE, name)
    ms.write(path, text)
    return "res://" + path


def damage_scene(element):
    src = open(os.path.join(ms.ROOT, "%s/%s_puffe_bolter_evolve_damage_data.tscn" % (ms.BOLTER_EVOLVE, ms.BOLTER_DAMAGE[element])), encoding="utf8").read()
    text = re.sub(r' uid="[^"]+"', "", src, count=1)
    text = re.sub(r'load_steps=\d+ ', "", text)
    title = "%sHatcheryDamageData" % element.capitalize()
    text = re.sub(r'\[node name="[^"]+" type="Node"\]', '[node name="%s" type="Node"]' % title, text, count=1)
    path = "%s/%s_hatchery_damage_data.tscn" % (EVOLVE, element)
    ms.write(path, text)
    return "res://" + path


def tower_scene(drakeling_frames, guard_frames, guard, swaps, damages):
    text = open(os.path.join(ms.ROOT, "scenes/unit/building/buildings/puffe_bolter.tscn"), encoding="utf8").read()
    text = re.sub(r'\[gd_scene [^\]]*\]', '[gd_scene format=3]', text, count=1)
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("4_04kgf"\)\nregion = [^\n]*\n\n', "", text)
    text = re.sub(r'\[sub_resource type="SpriteFrames" id="SpriteFrames_udt3q"\]\nanimations = \[.*?\]\n\n', "", text, flags=re.S)
    text = text.replace('sprite_frames = SubResource("SpriteFrames_udt3q")', 'sprite_frames = ExtResource("m_frames")')
    text = re.sub(r'\[ext_resource type="Resource" path="res://scenes/unit/evolve_tree/tiers/[^\n]*\n', "", text)
    text = re.sub(r'\[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="tier_script"\]\n', "", text)
    text = re.sub(r'^tiers = [^\n]*\n', "", text, flags=re.M)
    # what the Hatchery does not use: the bolt launcher, its sound, the bolts, the behaviour tree
    for ext_id in ("4_04kgf", "snd_activate", "3_8jepy", "9_elqq4", "21_t17ii", "26_k77d7", "29_bqugu", "5_6ycpu"):
        text = re.sub(r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id), "", text)
    text = re.sub(r'^new_projectile_scene = [^\n]*\n', "", text, flags=re.M)
    replace_ext = {
        "1_wwpqv": '[ext_resource type="Script" path="res://scenes/unit/building/hatchery/hatchery.gd" id="1_wwpqv"]',
        "19_tlf38": '[ext_resource type="Texture2D" path="res://%s/puffe_hatchery_icon.png" id="19_tlf38"]' % ART,
        "20_qaoyh": '[ext_resource type="Texture2D" path="res://%s/red_puffe_hatchery_icon.png" id="20_qaoyh"]' % ART,
        "26_nwa4t": '[ext_resource type="Texture2D" path="res://%s/blue_puffe_hatchery_icon.png" id="26_nwa4t"]' % ART,
        "29_pjst3": '[ext_resource type="Texture2D" path="res://%s/green_puffe_hatchery_icon.png" id="29_pjst3"]' % ART,
        "22_ll5c1": '[ext_resource type="PackedScene" path="%s" id="22_ll5c1"]' % swaps["fire"],
        "26_alotc": '[ext_resource type="PackedScene" path="%s" id="26_alotc"]' % swaps["frost"],
        "28_4x4pp": '[ext_resource type="PackedScene" path="%s" id="28_4x4pp"]' % swaps["poison"],
        "20_ccteo": '[ext_resource type="PackedScene" path="%s" id="20_ccteo"]' % damages["physical"],
        "23_pbrrj": '[ext_resource type="PackedScene" path="%s" id="23_pbrrj"]' % damages["fire"],
        "27_pf0qb": '[ext_resource type="PackedScene" path="%s" id="27_pf0qb"]' % damages["frost"],
        "29_ajupy": '[ext_resource type="PackedScene" path="%s" id="29_ajupy"]' % damages["poison"],
        "0_upgradedata": '[ext_resource type="Resource" path="res://scenes/upgrades/building_upgrades/hatchery_upgrade_data.tres" id="0_upgradedata"]',
    }
    for ext_id, line in replace_ext.items():
        pattern = r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id)
        assert re.search(pattern, text), ext_id
        text = re.sub(pattern, line + "\n", text)
    first_sub = text.index("[sub_resource")
    text = text[:first_sub] + (
        '[ext_resource type="SpriteFrames" path="%s" id="m_frames"]\n'
        '[ext_resource type="Script" path="res://scenes/unit/skills/skill.gd" id="h_skill"]\n'
        '[ext_resource type="PackedScene" path="res://scenes/unit/skills/skill_state_timers.tscn" id="h_timers"]\n'
        '[ext_resource type="PackedScene" path="%s" id="h_guard"]\n'
        '[ext_resource type="SpriteFrames" path="%s" id="h_guard_physical"]\n'
        '[ext_resource type="SpriteFrames" path="%s" id="h_guard_fire"]\n'
        '[ext_resource type="SpriteFrames" path="%s" id="h_guard_frost"]\n'
        '[ext_resource type="SpriteFrames" path="%s" id="h_guard_poison"]\n\n') % (
        drakeling_frames, guard, guard_frames["physical"], guard_frames["fire"], guard_frames["frost"], guard_frames["poison"]) + text[first_sub:]
    text = text.replace('[node name="PuffeBolter" type="StaticBody2D" node_paths=PackedStringArray("skill")]',
                        '[node name="PuffeHatchery" type="StaticBody2D" node_paths=PackedStringArray("skill")]')
    text = text.replace('skill = NodePath("LaunchProjectile")', 'skill = NodePath("Hatch")')
    text = ms.set_props(text, '[node name="PuffeHatchery"', {
        "guard_scene": 'ExtResource("h_guard")',
        "guard_frames": 'Array[SpriteFrames]([ExtResource("h_guard_physical"), ExtResource("h_guard_fire"), '
                        'ExtResource("h_guard_frost"), ExtResource("h_guard_poison")])'})
    text = ms.remove_node_metadata(text, '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."')
    text = ms.remove_node_metadata(text, '[node name="TowerBaseSprite" type="Sprite2D" parent="AnimatedSprite2D"')
    # the launcher becomes a passive skill: a plain Skill with its timers, the same Stats and DamageData children
    m = re.search(r'\[node name="LaunchProjectile" parent="\." instance=[^\n]*\]\n(?:[^\[\n][^\n]*\n)*', text)
    text = text[:m.start()] + ('[node name="Hatch" type="Node2D" parent="."]\nscript = ExtResource("h_skill")\nskill_type = %d\n'
                               'skill_name = "Claws"\nbase_cooldown = 0.0\n\n'
                               '[node name="SkillStateTimers" parent="Hatch" instance=ExtResource("h_timers")]\n') % GUARD_SKILL_TYPE + text[m.end():]
    text = text.replace('parent="LaunchProjectile', 'parent="Hatch')
    text = re.sub(r'\[node name="BasicTowerBt" parent="\." instance=[^\n]*\]\n\n?', "", text)
    for node, value in (("Damage", DAMAGE), ("AttackRange", RANGE_TILES), ("CriticalChance", CRIT_CHANCE)):
        text = ms.set_props(text, '[node name="%s" type="Node" parent="Hatch/Stats"' % node, {"base_value": repr(value), "value": repr(value)})
    text = ms.set_props(text, '[node name="Price" type="Node" parent="Stats"', {"base_value": repr(PRICE), "value": repr(PRICE)})
    text = ms.set_props(text, '[node name="SelectableUnit" parent="."', {"display_name": '"Hatchery"'})
    text = ms.set_props(text, '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."', {"animation": '&"IDLE"'})
    # the guard stats, only the Hatchery has them
    m = re.search(r'\[node name="EvolveTree" type="Node" parent="\."\]', text)
    stat_script = re.search(r'\[node name="Price" type="Node" parent="Stats"\]\nscript = ExtResource\("([^"]+)"\)', text).group(1)
    stats = "".join('[node name="%s" type="Node" parent="Stats"]\nscript = ExtResource("%s")\ntype = %d\nbase_value = %s\nvalue = %s\n\n'
                    % (n, stat_script, t, repr(v), repr(v))
                    for n, t, v in (("GuardHealth", GUARD_HEALTH_STAT, GUARD_HEALTH), ("GuardCount", GUARD_COUNT_STAT, 0.0)))
    text = text[:m.start()] + stats + text[m.start():]
    text = re.sub(r'\[node name="[A-Za-z]+Modifier" type="Node" parent="EvolveTree/EvolveBranch\d?/[A-Za-z]+ElementEvolveLeaf"\]\n(?:[^\[\n][^\n]*\n)*\n?', "", text)
    branch = {"physical": "EvolveBranch", "fire": "EvolveBranch2", "frost": "EvolveBranch3", "poison": "EvolveBranch4"}
    for element in ELEMENTS:
        leaf_path = "EvolveTree/%s/%s" % (branch[element], ms.LEAF[element])
        nodes = ""
        for name, modify, stat, value in LEAF_MODIFIERS[element]:
            nodes += ('[node name="%s" type="Node" parent="%s"]\nscript = ExtResource("24_v32av")\ncalculate_type = %d\n'
                      'stat_type = %d\nvalue = %s\n\n') % (name, leaf_path, modify, stat, repr(value))
        m = re.search(r'\[node name="%s" type="Node" parent="[^"]+"\]\n(?:[^\[\n][^\n]*\n)*\n?' % ms.LEAF[element], text)
        text = text[:m.end()] + nodes + text[m.end():]
    text = re.sub(r"\n{3,}", "\n\n", text)
    ms.write("scenes/unit/building/buildings/puffe_hatchery.tscn", text)


def list_element():
    text = ('[gd_resource type="Resource" script_class="BuildingListElement" format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/building/building_list_element.gd" id="1_script"]\n'
            '[ext_resource type="Texture2D" path="res://%s/puffe_hatchery_icon.png" id="2_icon"]\n'
            '[ext_resource type="PackedScene" path="res://scenes/unit/building/buildings/puffe_hatchery.tscn" id="3_scene"]\n\n'
            '[resource]\nscript = ExtResource("1_script")\nscene = ExtResource("3_scene")\nid = %d\nicon = ExtResource("2_icon")\n'
            'unlock_level = %d\ndescription = "Hatches guard drakelings that stand on the path and hold the enemies that come, '
            'one each, clawing them while they fight back. Fallen guards hatch again. Rally picks where they stand."\n') % (
        ART, LIST_ID, UNLOCK_LEVEL)
    ms.write("scenes/unit/building/buildings/puffe_hatchery.tres", text)


def upgrade_data():
    path = "scenes/upgrades/building_upgrades/hatchery_upgrade_data.tres"
    if os.path.exists(os.path.join(ms.ROOT, path)):
        return
    src = open(os.path.join(ms.ROOT, "scenes/upgrades/building_upgrades/bolter_upgrade_data.tres"), encoding="utf8").read()
    ms.write(path, re.sub(r' uid="[^"]+"', "", src, count=1))


def main():
    drakelings = {e: frames("%s/%s" % (ART, sheet_name(e)), sheet_name(e), DRAKELING_LOOPING) for e in ELEMENTS}
    guards = {e: frames("%s/%s" % (ART, sheet_name(e, "hatchery_guard")), sheet_name(e, "hatchery_guard"), GUARD_LOOPING) for e in ELEMENTS}
    guard = guard_scene(guards["physical"])
    swaps = {e: swap_scene(e, drakelings[e]) for e in ELEMENTS}
    damages = {e: damage_scene(e) for e in ELEMENTS}
    upgrade_data()
    tower_scene(drakelings["physical"], guards, guard, swaps, damages)
    list_element()
    print("hatchery scenes written; now run python tools/tier_data.py")


if __name__ == "__main__":
    main()
