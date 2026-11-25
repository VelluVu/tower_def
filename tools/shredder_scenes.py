"""The Shredder's scenes and data (2026-11-25), rerunnable:

    python tools/shredder_scenes.py

Art first: tools/sprite/parts/shredder_art.py (and the icons).
Writes
- scenes/unit/evolve_tree/puffe_shredder_evolve/<sheet>_frames.tres and the element sprite swaps
- scenes/unit/building/buildings/puffe_shredder.tscn: from the Nova's scene with the Shredder script (its pulse tears
  armour: ResistanceShred), a weak, slow pulse, the Shredder's art and the Nova's element leaves (their burst effects);
  puffe_shredder.tres (the build tray, unlocks on level 25); the upgrade data (a copy of the Nova's)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mortar_scenes as ms

ART = "assets/art/units/building/puffe/puffe_shredder"
EVOLVE = "scenes/unit/evolve_tree/puffe_shredder_evolve"
UNLOCK_LEVEL = 25
LIST_ID = 13
# placeholders until playtests: the pulse is for the shred, not the damage
PRICE = 6.0
DAMAGE = 1.5
RANGE_TILES = 2.5
COOLDOWN_SECONDS = 3.0
LEAF_INFO = {
    "physical": "Physical: the pulse tears and knocks",
    "fire": "Fire: the torn armour burns",
    "frost": "Frost: the pulse chills as it tears",
    "poison": "Poison: poison seeps through the tears",
}


def sheet_name(element):
    return (ms.COLOUR[element] + "_" if ms.COLOUR[element] else "") + "puffe_shredder"


def swap_scene(element, sheet_frames):
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
            'position = Vector2(0, 1)\ntexture = ExtResource("4_base")\n') % (sheet_frames, ms.TOWER_BASE[element], title)
    path = "%s/%s.tscn" % (EVOLVE, name)
    ms.write(path, text)
    return "res://" + path


def main():
    ms.EVOLVE = EVOLVE
    frames = {e: ms.frames("%s/%s" % (ART, sheet_name(e)), sheet_name(e)) for e in ms.ELEMENTS}
    swaps = {e: swap_scene(e, frames[e]) for e in ("fire", "frost", "poison")}
    text = open(os.path.join(ms.ROOT, "scenes/unit/building/buildings/puffe_nova.tscn"), encoding="utf8").read()
    text = re.sub(r'\[gd_scene [^\]]*\]', '[gd_scene format=3]', text, count=1)
    text = re.sub(r' uid="[^"]+"', "", text)
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("4_xlmif"\)\nregion = [^\n]*\n\n', "", text)
    text = re.sub(r'\[sub_resource type="SpriteFrames" id="SpriteFrames_fhwnl"\]\nanimations = \[.*?\]\n\n', "", text, flags=re.S)
    text = text.replace('sprite_frames = SubResource("SpriteFrames_fhwnl")', 'sprite_frames = ExtResource("s_frames")')
    text = ms.remove_node_metadata(text, '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."')
    text = ms.remove_node_metadata(text, '[node name="TowerBaseSprite" type="Sprite2D" parent="AnimatedSprite2D"')
    text = re.sub(r'\[ext_resource type="Resource" path="res://scenes/unit/evolve_tree/tiers/[^\n]*\n', "", text)
    text = re.sub(r'\[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="tier_script"\]\n', "", text)
    text = re.sub(r'^tiers = [^\n]*\n', "", text, flags=re.M)
    replace_ext = {
        "4_xlmif": None,
        "1_t60dc": '[ext_resource type="Script" path="res://scenes/unit/building/shredder/shredder.gd" id="1_t60dc"]',
        "2_amlqn": '[ext_resource type="Texture2D" path="res://%s/puffe_shredder_icon.png" id="2_amlqn"]' % ART,
        "22_u5e7f": '[ext_resource type="Texture2D" path="res://%s/red_puffe_shredder_icon.png" id="22_u5e7f"]' % ART,
        "27_fapa0": '[ext_resource type="Texture2D" path="res://%s/blue_puffe_shredder_icon.png" id="27_fapa0"]' % ART,
        "32_1be7x": '[ext_resource type="Texture2D" path="res://%s/green_puffe_shredder_icon.png" id="32_1be7x"]' % ART,
        "23_iiqqs": '[ext_resource type="PackedScene" path="%s" id="23_iiqqs"]' % swaps["fire"],
        "26_rr1ji": '[ext_resource type="PackedScene" path="%s" id="26_rr1ji"]' % swaps["frost"],
        "29_5ite4": '[ext_resource type="PackedScene" path="%s" id="29_5ite4"]' % swaps["poison"],
    }
    for ext_id, line in replace_ext.items():
        pattern = r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id)
        assert re.search(pattern, text), ext_id
        text = re.sub(pattern, "" if line is None else line + "\n", text)
    data = re.search(r'\[ext_resource type="Resource" path="res://scenes/upgrades/building_upgrades/nova_upgrade_data.tres" id="([^"]+)"\]', text)
    if data:
        text = text.replace(data.group(0), '[ext_resource type="Resource" path="res://scenes/upgrades/building_upgrades/shredder_upgrade_data.tres" id="%s"]' % data.group(1))
    first_sub = text.index("[sub_resource")
    text = text[:first_sub] + '[ext_resource type="SpriteFrames" path="%s" id="s_frames"]\n\n' % frames["physical"] + text[first_sub:]
    text = text.replace('[node name="PuffeNova" type="StaticBody2D"', '[node name="PuffeShredder" type="StaticBody2D"')
    text = ms.set_props(text, '[node name="LaunchProjectile" parent="."', {"skill_name": '"Shred"', "base_cooldown": repr(COOLDOWN_SECONDS)})
    for node, value in (("Damage", DAMAGE), ("AttackRange", RANGE_TILES)):
        text = ms.set_props(text, '[node name="%s" type="Node" parent="LaunchProjectile/Stats"' % node, {"base_value": repr(value), "value": repr(value)})
    text = ms.set_props(text, '[node name="Price" type="Node" parent="Stats"', {"base_value": repr(PRICE), "value": repr(PRICE)})
    text = ms.set_props(text, '[node name="SelectableUnit" parent="."', {"display_name": '"Shredder"'})
    for element in ms.ELEMENTS:
        text = ms.set_props(text, '[node name="%s"' % ms.LEAF[element], {"info": '"%s"' % LEAF_INFO[element]})
    assert "puffe_nova/" not in text, [l for l in text.split("\n") if "puffe_nova/" in l]
    text = re.sub(r"\n{3,}", "\n\n", text)
    ms.write("scenes/unit/building/buildings/puffe_shredder.tscn", text)
    ms.write("scenes/unit/building/buildings/puffe_shredder.tres", (
        '[gd_resource type="Resource" script_class="BuildingListElement" format=3]\n\n'
        '[ext_resource type="Script" path="res://scenes/unit/building/building_list_element.gd" id="1_script"]\n'
        '[ext_resource type="Texture2D" path="res://%s/puffe_shredder_icon.png" id="2_icon"]\n'
        '[ext_resource type="PackedScene" path="res://scenes/unit/building/buildings/puffe_shredder.tscn" id="3_scene"]\n\n'
        '[resource]\nscript = ExtResource("1_script")\nscene = ExtResource("3_scene")\nid = %d\nicon = ExtResource("2_icon")\n'
        'unlock_level = %d\ndescription = "A weak, slow pulse that tears armour: every enemy it hits loses 15%% of each '
        'resistance, up to three times, for a few seconds. Every tower around it hits harder."\n') % (ART, LIST_ID, UNLOCK_LEVEL))
    path = "scenes/upgrades/building_upgrades/shredder_upgrade_data.tres"
    if not os.path.exists(os.path.join(ms.ROOT, path)):
        src = open(os.path.join(ms.ROOT, "scenes/upgrades/building_upgrades/nova_upgrade_data.tres"), encoding="utf8").read()
        ms.write(path, re.sub(r' uid="[^"]+"', "", src, count=1))
    print("shredder scenes written")


if __name__ == "__main__":
    main()
