"""The Buffer's scenes and data (2026-11-24), rerunnable:

    python tools/buffer_scenes.py      then  python tools/tier_data.py  (the T2/T3 tiers and the leaves' tiers)

Art first: tools/sprite/parts/buffer_art.py and tower_tiers.py ... buffer (T2/T3).
Writes
- scenes/unit/evolve_tree/puffe_buffer_evolve/<sheet>_frames.tres and the element sprite swaps
- scenes/unit/building/buildings/puffe_buffer.tscn: from the Bolter's scene with the Buffer script, a passive Aura skill
  (its AttackRange is the aura), no behaviour tree, the aura ring, element leaves that only swap the sprite;
  puffe_buffer.tres (the build tray, unlocks on level 25); buffer_upgrade_data.tres (pips 2, 5, 8 before T1, T2, T3)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mortar_scenes as ms

ART = "assets/art/units/building/puffe/puffe_buffer"
EVOLVE = "scenes/unit/evolve_tree/puffe_buffer_evolve"
UNLOCK_LEVEL = 25
LIST_ID = 6
PRICE = 7.0
AURA_TILES = 2.0
ELEMENTS = ms.ELEMENTS
LEAF = ms.LEAF


def sheet_name(element):
    return (ms.COLOUR[element] + "_" if ms.COLOUR[element] else "") + "puffe_buffer"


def frames(element):
    ms.EVOLVE = EVOLVE
    return ms.frames("%s/%s" % (ART, sheet_name(element)), sheet_name(element))


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


def tower_scene(drakeling_frames, swaps):
    text = open(os.path.join(ms.ROOT, "scenes/unit/building/buildings/puffe_bolter.tscn"), encoding="utf8").read()
    text = re.sub(r'\[gd_scene [^\]]*\]', '[gd_scene format=3]', text, count=1)
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("4_04kgf"\)\nregion = [^\n]*\n\n', "", text)
    text = re.sub(r'\[sub_resource type="SpriteFrames" id="SpriteFrames_udt3q"\]\nanimations = \[.*?\]\n\n', "", text, flags=re.S)
    text = text.replace('sprite_frames = SubResource("SpriteFrames_udt3q")', 'sprite_frames = ExtResource("m_frames")')
    text = re.sub(r'\[ext_resource type="Resource" path="res://scenes/unit/evolve_tree/tiers/[^\n]*\n', "", text)
    text = re.sub(r'\[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="tier_script"\]\n', "", text)
    text = re.sub(r'^tiers = [^\n]*\n', "", text, flags=re.M)
    # what the Buffer does not use: the attack, its sound, bolts, element damage data, the behaviour tree
    for ext_id in ("4_04kgf", "snd_activate", "3_8jepy", "9_elqq4", "21_t17ii", "26_k77d7", "29_bqugu", "20_ccteo", "23_pbrrj",
                   "27_pf0qb", "29_ajupy", "5_6ycpu"):
        text = re.sub(r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id), "", text)
    for key in ("new_projectile_scene", "new_damage_data_scene"):
        text = re.sub(r'^%s = [^\n]*\n' % key, "", text, flags=re.M)
    replace_ext = {
        "1_wwpqv": '[ext_resource type="Script" path="res://scenes/unit/building/buffer/buffer.gd" id="1_wwpqv"]',
        "19_tlf38": '[ext_resource type="Texture2D" path="res://%s/puffe_buffer_icon.png" id="19_tlf38"]' % ART,
        "20_qaoyh": '[ext_resource type="Texture2D" path="res://%s/red_puffe_buffer_icon.png" id="20_qaoyh"]' % ART,
        "26_nwa4t": '[ext_resource type="Texture2D" path="res://%s/blue_puffe_buffer_icon.png" id="26_nwa4t"]' % ART,
        "29_pjst3": '[ext_resource type="Texture2D" path="res://%s/green_puffe_buffer_icon.png" id="29_pjst3"]' % ART,
        "22_ll5c1": '[ext_resource type="PackedScene" path="%s" id="22_ll5c1"]' % swaps["fire"],
        "26_alotc": '[ext_resource type="PackedScene" path="%s" id="26_alotc"]' % swaps["frost"],
        "28_4x4pp": '[ext_resource type="PackedScene" path="%s" id="28_4x4pp"]' % swaps["poison"],
        "0_upgradedata": '[ext_resource type="Resource" path="res://scenes/upgrades/building_upgrades/buffer_upgrade_data.tres" id="0_upgradedata"]',
    }
    for ext_id, line in replace_ext.items():
        pattern = r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id)
        assert re.search(pattern, text), ext_id
        text = re.sub(pattern, line + "\n", text)
    first_sub = text.index("[sub_resource")
    text = text[:first_sub] + (
        '[ext_resource type="SpriteFrames" path="%s" id="m_frames"]\n'
        '[ext_resource type="Script" path="res://scenes/unit/skills/skill.gd" id="b_skill"]\n'
        '[ext_resource type="PackedScene" path="res://scenes/unit/skills/skill_state_timers.tscn" id="b_timers"]\n'
        '[ext_resource type="Script" path="res://scenes/unit/building/buffer/buffer_aura_ring.gd" id="b_ring"]\n\n') % drakeling_frames + text[first_sub:]
    text = text.replace('[node name="PuffeBolter" type="StaticBody2D" node_paths=PackedStringArray("skill")]',
                        '[node name="PuffeBuffer" type="StaticBody2D" node_paths=PackedStringArray("skill")]')
    text = text.replace('skill = NodePath("LaunchProjectile")', 'skill = NodePath("Aura")')
    text = re.sub(r'^price_step = [^\n]*\n', '', text, flags=re.M)
    text = ms.remove_node_metadata(text, '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."')
    text = ms.remove_node_metadata(text, '[node name="TowerBaseSprite" type="Sprite2D" parent="AnimatedSprite2D"')
    # the attack becomes a passive aura: a plain Skill with its timers, the same Stats and DamageData children
    m = re.search(r'\[node name="LaunchProjectile" parent="\." instance=[^\n]*\]\n(?:[^\[\n][^\n]*\n)*', text)
    text = text[:m.start()] + ('[node name="Aura" type="Node2D" parent="."]\nscript = ExtResource("b_skill")\nskill_type = 32\n'
                               'skill_name = "Aura"\nbase_cooldown = 0.0\n\n'
                               '[node name="SkillStateTimers" parent="Aura" instance=ExtResource("b_timers")]\n') + text[m.end():]
    text = text.replace('parent="LaunchProjectile', 'parent="Aura')
    text = re.sub(r'\[node name="BasicTowerBt" parent="\." instance=[^\n]*\]\n\n?', "", text)
    for node, value in (("Damage", 0.0), ("AttackRange", AURA_TILES), ("CriticalChance", 0.0)):
        text = ms.set_props(text, '[node name="%s" type="Node" parent="Aura/Stats"' % node, {"base_value": repr(value), "value": repr(value)})
    text = ms.set_props(text, '[node name="Price" type="Node" parent="Stats"', {"base_value": repr(PRICE), "value": repr(PRICE)})
    text = ms.set_props(text, '[node name="SelectableUnit" parent="."', {"display_name": '"Buffer"'})
    text = ms.set_props(text, '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."', {"animation": '&"IDLE"'})
    # the element leaves only swap the sprite and set the element it passes on
    text = re.sub(r'\[node name="[A-Za-z]+Modifier" type="Node" parent="EvolveTree/EvolveBranch\d?/[A-Za-z]+ElementEvolveLeaf"\]\n(?:[^\[\n][^\n]*\n)*\n?', "", text)
    m = re.search(r'\[node name="ModifierManager"', text)
    text = text[:m.start()] + '[node name="AuraRing" type="Node2D" parent="."]\nscript = ExtResource("b_ring")\n\n' + text[m.start():]
    text = re.sub(r"\n{3,}", "\n\n", text)
    ms.write("scenes/unit/building/buildings/puffe_buffer.tscn", text)


def list_element():
    text = ('[gd_resource type="Resource" script_class="BuildingListElement" format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/building/building_list_element.gd" id="1_script"]\n'
            '[ext_resource type="Texture2D" path="res://%s/puffe_buffer_icon.png" id="2_icon"]\n'
            '[ext_resource type="PackedScene" path="res://scenes/unit/building/buildings/puffe_buffer.tscn" id="3_scene"]\n\n'
            '[resource]\nscript = ExtResource("1_script")\nscene = ExtResource("3_scene")\nid = %d\nicon = ExtResource("2_icon")\n'
            'unlock_level = %d\ndescription = "Never attacks: drums up the towers and traps around it. Buy its pips to choose '
            'what it raises; several Buffers never stack."\n') % (ART, LIST_ID, UNLOCK_LEVEL)
    ms.write("scenes/unit/building/buildings/puffe_buffer.tres", text)


def upgrade_data():
    text = ('[gd_resource type="Resource" script_class="BuildingUpgradeData" format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/upgrades/building_upgrade_data.gd" id="1_data"]\n\n'
            '[resource]\nscript = ExtResource("1_data")\n'
            '# the Buffer buys pips instead (Buffer.PIP_COST_RATIOS); these count the pips before each tier\n'
            'upgrade_cost_ratios = Array[float]([0.4, 0.5, 0.6, 0.7, 0.8, 1.0, 1.2, 1.4])\n'
            'evolve_cost_ratios = Array[float]([1.5, 2.5, 4.0])\n'
            'tier_upgrades = Array[int]([2, 5, 8])\n')
    ms.write("scenes/upgrades/building_upgrades/buffer_upgrade_data.tres", text.replace("# the Buffer", ";the Buffer"))


def main():
    drakelings = {e: frames(e) for e in ELEMENTS}
    swaps = {e: swap_scene(e, drakelings[e]) for e in ELEMENTS}
    upgrade_data()
    tower_scene(drakelings["physical"], swaps)
    list_element()
    print("buffer scenes written; now run python tools/tier_data.py")


if __name__ == "__main__":
    main()
