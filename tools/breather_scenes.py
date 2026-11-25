"""The Breather's scenes and data (2026-11-24), rerunnable:

    python tools/breather_scenes.py      then  python tools/tier_data.py  (the T2/T3 tiers and the leaves' tiers)

Art first: tools/sprite/parts/breather_art.py (drakelings, breath puffs) and tower_tiers.py ... breather (T2/T3).
Writes
- scenes/unit/evolve_tree/puffe_breather_evolve/<sheet>_frames.tres: SpriteFrames for the drakelings and the puffs
- scenes/unit/skills/projectiles/<element>_breath_puff.tscn: a BreathPuff with its sprite
- scenes/unit/evolve_tree/puffe_breather_evolve/: the element sprite swaps and damage data (copies of the Bolter's:
  burn, slow and poison stacks, which every enemy in the cone gets on every tick)
- scenes/unit/building/buildings/puffe_breather.tscn: from the Bolter's scene with the Breath skill, the Breather's
  stats, art and element leaves, and the ConeWidth stat; puffe_breather.tres (the build tray, unlocks on level 19);
  the upgrade data (a copy of the Bolter's)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mortar_scenes as ms

ART = "assets/art/units/building/puffe/puffe_breather"
PROJ_ART = "assets/art/projectile"
EVOLVE = "scenes/unit/evolve_tree/puffe_breather_evolve"
PROJ = "scenes/unit/skills/projectiles"
ELEMENTS = ms.ELEMENTS
UNLOCK_LEVEL = 14
LIST_ID = 7

# the Breather's numbers (placeholders until playtests): a short cone, 4 hits on everything in it per gust
PRICE = 5.0
DAMAGE = 1.5
RANGE_TILES = 2.5
CRIT_CHANCE = 0.05
CAST_SECONDS = 0.3
COOLDOWN_SECONDS = 2.5
FLAT, MULTIPLY = 0, 1
DAMAGE_STAT, KNOCKBACK, PATCH_DURATION, PATCH_SHARE, CONE_WIDTH = 2, 24, 25, 26, 31
# the element leaves (design doc, New Towers: roar with knockback / burning ground / stacks toward a freeze / a cloud)
LEAF_MODIFIERS = {
    "physical": [("DamageModifier", MULTIPLY, DAMAGE_STAT, 0.15), ("RoarModifier", FLAT, KNOCKBACK, 1.0)],
    "fire": [("DamageModifier", MULTIPLY, DAMAGE_STAT, 0.1), ("PatchModifier", FLAT, PATCH_DURATION, 1.5),
             ("PatchShareModifier", FLAT, PATCH_SHARE, 0.2)],
    # the slow stacks come with every tick (the damage data's)
    "frost": [("DamageModifier", MULTIPLY, DAMAGE_STAT, 0.05)],
    "poison": [("CloudModifier", FLAT, PATCH_DURATION, 2.0), ("CloudShareModifier", FLAT, PATCH_SHARE, 0.15)],
}


def sheet_name(element):
    return (ms.COLOUR[element] + "_" if ms.COLOUR[element] else "") + "puffe_breather"


def frames(base, out_name):
    ms.EVOLVE = EVOLVE
    return ms.frames(base, out_name)


def puff_scene(element, puff_frames):
    name = "%s_breath_puff" % element
    title = "".join(p.capitalize() for p in name.split("_"))
    text = ('[gd_scene format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/skills/projectiles/breath_puff.gd" id="1_script"]\n'
            '[ext_resource type="SpriteFrames" path="%s" id="2_frames"]\n\n'
            '[node name="%s" type="Node2D"]\nvisible = false\nscript = ExtResource("1_script")\n\n'
            '[node name="Sprite" type="AnimatedSprite2D" parent="."]\ntexture_filter = 1\n'
            'sprite_frames = ExtResource("2_frames")\nanimation = &"FLY"\n') % (puff_frames, title)
    path = "%s/%s.tscn" % (PROJ, name)
    ms.write(path, text)
    return "res://" + path


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
    title = "%sBreathDamageData" % element.capitalize()
    text = re.sub(r'\[node name="[^"]+" type="Node"\]', '[node name="%s" type="Node"]' % title, text, count=1)
    path = "%s/%s_breath_damage_data.tscn" % (EVOLVE, element)
    ms.write(path, text)
    return "res://" + path


def tower_scene(drakeling_frames, puffs, swaps, damages):
    text = open(os.path.join(ms.ROOT, "scenes/unit/building/buildings/puffe_bolter.tscn"), encoding="utf8").read()
    text = re.sub(r'\[gd_scene [^\]]*\]', '[gd_scene format=3]', text, count=1)
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("4_04kgf"\)\nregion = [^\n]*\n\n', "", text)
    text = re.sub(r'\[sub_resource type="SpriteFrames" id="SpriteFrames_udt3q"\]\nanimations = \[.*?\]\n\n', "", text, flags=re.S)
    text = text.replace('sprite_frames = SubResource("SpriteFrames_udt3q")', 'sprite_frames = ExtResource("m_frames")')
    text = re.sub(r'\[ext_resource type="Resource" path="res://scenes/unit/evolve_tree/tiers/[^\n]*\n', "", text)
    text = re.sub(r'\[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="tier_script"\]\n', "", text)
    text = re.sub(r'^tiers = [^\n]*\n', "", text, flags=re.M)
    replace_ext = {
        "4_04kgf": None,
        "snd_activate": '[ext_resource type="AudioStream" path="res://assets/audio/sfx/retro/beamer_start.ogg" id="snd_activate"]',
        "3_8jepy": '[ext_resource type="PackedScene" path="res://scenes/unit/skills/breath.tscn" id="3_8jepy"]',
        "19_tlf38": '[ext_resource type="Texture2D" path="res://%s/puffe_breather_icon.png" id="19_tlf38"]' % ART,
        "20_qaoyh": '[ext_resource type="Texture2D" path="res://%s/red_puffe_breather_icon.png" id="20_qaoyh"]' % ART,
        "26_nwa4t": '[ext_resource type="Texture2D" path="res://%s/blue_puffe_breather_icon.png" id="26_nwa4t"]' % ART,
        "29_pjst3": '[ext_resource type="Texture2D" path="res://%s/green_puffe_breather_icon.png" id="29_pjst3"]' % ART,
        "9_elqq4": '[ext_resource type="PackedScene" path="%s" id="9_elqq4"]' % puffs["physical"],
        "21_t17ii": '[ext_resource type="PackedScene" path="%s" id="21_t17ii"]' % puffs["fire"],
        "26_k77d7": '[ext_resource type="PackedScene" path="%s" id="26_k77d7"]' % puffs["frost"],
        "29_bqugu": '[ext_resource type="PackedScene" path="%s" id="29_bqugu"]' % puffs["poison"],
        "22_ll5c1": '[ext_resource type="PackedScene" path="%s" id="22_ll5c1"]' % swaps["fire"],
        "26_alotc": '[ext_resource type="PackedScene" path="%s" id="26_alotc"]' % swaps["frost"],
        "28_4x4pp": '[ext_resource type="PackedScene" path="%s" id="28_4x4pp"]' % swaps["poison"],
        "20_ccteo": '[ext_resource type="PackedScene" path="%s" id="20_ccteo"]' % damages["physical"],
        "23_pbrrj": '[ext_resource type="PackedScene" path="%s" id="23_pbrrj"]' % damages["fire"],
        "27_pf0qb": '[ext_resource type="PackedScene" path="%s" id="27_pf0qb"]' % damages["frost"],
        "29_ajupy": '[ext_resource type="PackedScene" path="%s" id="29_ajupy"]' % damages["poison"],
        "0_upgradedata": '[ext_resource type="Resource" path="res://scenes/upgrades/building_upgrades/breather_upgrade_data.tres" id="0_upgradedata"]',
    }
    for ext_id, line in replace_ext.items():
        pattern = r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id)
        assert re.search(pattern, text), ext_id
        text = re.sub(pattern, "" if line is None else line + "\n", text)
    first_sub = text.index("[sub_resource")
    text = text[:first_sub] + '[ext_resource type="SpriteFrames" path="%s" id="m_frames"]\n\n' % drakeling_frames + text[first_sub:]
    text = text.replace('[node name="PuffeBolter" type="StaticBody2D" node_paths=PackedStringArray("skill")]',
                        '[node name="PuffeBreather" type="StaticBody2D" node_paths=PackedStringArray("skill")]')
    text = text.replace('skill = NodePath("LaunchProjectile")', 'skill = NodePath("Breath")')
    text = ms.remove_node_metadata(text, '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."')
    text = ms.remove_node_metadata(text, '[node name="TowerBaseSprite" type="Sprite2D" parent="AnimatedSprite2D"')
    # the bolt launcher becomes the breath, at the drakeling's mouth
    text = text.replace('[node name="LaunchProjectile" parent="."', '[node name="Breath" parent="."')
    text = text.replace('parent="LaunchProjectile', 'parent="Breath')
    m = re.search(r'\[node name="Breath" parent="\." instance=[^\n]*\]\n(?:[^\[\n][^\n]*\n)*', text)
    block = re.sub(r'^(position|skill_type|skill_name|base_cast_time|base_cooldown) = [^\n]*\n', '', m.group(0), flags=re.M)
    text = text[:m.start()] + block + text[m.end():]
    text = ms.set_props(text, '[node name="Breath" parent="."', {
        "position": "Vector2(0, -11)", "skill_type": "64", "skill_name": '"Breath"', "base_cast_time": repr(CAST_SECONDS),
        "base_cooldown": repr(COOLDOWN_SECONDS)})
    for node, value in (("Damage", DAMAGE), ("AttackRange", RANGE_TILES), ("CriticalChance", CRIT_CHANCE)):
        text = ms.set_props(text, '[node name="%s" type="Node" parent="Breath/Stats"' % node,
                            {"base_value": repr(value), "value": repr(value)})
    text = ms.set_props(text, '[node name="Price" type="Node" parent="Stats"', {"base_value": repr(PRICE), "value": repr(PRICE)})
    text = ms.set_props(text, '[node name="SelectableUnit" parent="."', {"display_name": '"Breather"'})
    # the cone width stat, only the Breather has it
    m = re.search(r'\[node name="EvolveTree" type="Node" parent="\."\]', text)
    stat_script = re.search(r'\[node name="Price" type="Node" parent="Stats"\]\nscript = ExtResource\("([^"]+)"\)', text).group(1)
    text = text[:m.start()] + '[node name="ConeWidth" type="Node" parent="Stats"]\nscript = ExtResource("%s")\ntype = %d\n\n' % (
        stat_script, CONE_WIDTH) + text[m.start():]
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
    text = ms.set_props(text, '[node name="PhysicalElementEvolveLeaf"', {"new_projectile_scene": 'ExtResource("9_elqq4")'})
    text = re.sub(r"\n{3,}", "\n\n", text)
    ms.write("scenes/unit/building/buildings/puffe_breather.tscn", text)


def list_element():
    text = ('[gd_resource type="Resource" script_class="BuildingListElement" format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/building/building_list_element.gd" id="1_script"]\n'
            '[ext_resource type="Texture2D" path="res://%s/puffe_breather_icon.png" id="2_icon"]\n'
            '[ext_resource type="PackedScene" path="res://scenes/unit/building/buildings/puffe_breather.tscn" id="3_scene"]\n\n'
            '[resource]\nscript = ExtResource("1_script")\nscene = ExtResource("3_scene")\nid = %d\nicon = ExtResource("2_icon")\n'
            'unlock_level = %d\ndescription = "Breathes short gusts over a cone in front of it: every enemy in the cone is hit '
            '4 times a gust. Short range; best at a maze corner where groups bunch up."\n') % (ART, LIST_ID, UNLOCK_LEVEL)
    ms.write("scenes/unit/building/buildings/puffe_breather.tres", text)


def upgrade_data():
    path = "scenes/upgrades/building_upgrades/breather_upgrade_data.tres"
    if os.path.exists(os.path.join(ms.ROOT, path)):
        return
    src = open(os.path.join(ms.ROOT, "scenes/upgrades/building_upgrades/bolter_upgrade_data.tres"), encoding="utf8").read()
    ms.write(path, re.sub(r' uid="[^"]+"', "", src, count=1))


def main():
    drakelings = {e: frames("%s/%s" % (ART, sheet_name(e)), sheet_name(e)) for e in ELEMENTS}
    puffs = {e: puff_scene(e, frames("%s/%s_breath_puff" % (PROJ_ART, e), "%s_breath_puff" % e)) for e in ELEMENTS}
    swaps = {e: swap_scene(e, drakelings[e]) for e in ELEMENTS}
    damages = {e: damage_scene(e) for e in ELEMENTS}
    upgrade_data()
    tower_scene(drakelings["physical"], puffs, swaps, damages)
    list_element()
    print("breather scenes written; now run python tools/tier_data.py")


if __name__ == "__main__":
    main()
