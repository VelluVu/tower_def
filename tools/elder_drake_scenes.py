"""The Elder Drake's scenes and data (2026-11-25), rerunnable:

    python tools/elder_drake_scenes.py

Art first: tools/sprite/parts/elder_drake_art.py (and the icons).
Writes
- scenes/unit/evolve_tree/puffe_elder_evolve/<sheet>_frames.tres and the element sprite swaps
- scenes/unit/building/buildings/puffe_elder.tscn: from the Bolter's scene with the ElderDrake script (once a wave a
  breath along the line through the most enemies), heavy slow bites (its bolts), the Bolter's element leaves (their
  bolts and damage data: the breath carries the element too); puffe_elder.tres (the build tray, unlocks on level 37);
  the upgrade data (a copy of the Bolter's)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mortar_scenes as ms
import shredder_scenes as ss

ART = "assets/art/units/building/puffe/puffe_elder"
EVOLVE = "scenes/unit/evolve_tree/puffe_elder_evolve"
UNLOCK_LEVEL = 37
LIST_ID = 15
# placeholders until playtests: an expensive anchor; the bite is a heavy, slow bolt
PRICE = 16.0
DAMAGE = 14.0
RANGE_TILES = 3.5
COOLDOWN_SECONDS = 1.8
CRIT_CHANCE = 0.1
LEAF_INFO = {
    "physical": "Physical: a breath of grinding wind",
    "fire": "Fire: a breath of flame that sets the road burning",
    "frost": "Frost: a breath of frost that slows everything in it",
    "poison": "Poison: a breath of venom that poisons everything in it",
}


def sheet_name(element):
    return (ms.COLOUR[element] + "_" if ms.COLOUR[element] else "") + "puffe_elder"


def main():
    ms.EVOLVE = EVOLVE
    frames = {e: ms.frames("%s/%s" % (ART, sheet_name(e)), sheet_name(e)) for e in ms.ELEMENTS}
    swaps = {}
    for element in ("fire", "frost", "poison"):
        ss.EVOLVE = EVOLVE
        ss_path = ss.swap_scene(element, frames[element])
        old = os.path.join(ms.ROOT, ss_path.replace("res://", ""))
        new_rel = "%s/%s.tscn" % (EVOLVE, sheet_name(element))
        text = open(old, encoding="utf8").read().replace("PuffeShredder", "PuffeElder")
        os.remove(old)
        ms.write(new_rel, text)
        swaps[element] = "res://" + new_rel

    text = open(os.path.join(ms.ROOT, "scenes/unit/building/buildings/puffe_bolter.tscn"), encoding="utf8").read()
    text = re.sub(r'\[gd_scene [^\]]*\]', '[gd_scene format=3]', text, count=1)
    text = re.sub(r' uid="[^"]+"', "", text)
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("4_04kgf"\)\nregion = [^\n]*\n\n', "", text)
    text = re.sub(r'\[sub_resource type="SpriteFrames" id="SpriteFrames_udt3q"\]\nanimations = \[.*?\]\n\n', "", text, flags=re.S)
    text = text.replace('sprite_frames = SubResource("SpriteFrames_udt3q")', 'sprite_frames = ExtResource("s_frames")')
    text = ms.remove_node_metadata(text, '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."')
    text = ms.remove_node_metadata(text, '[node name="TowerBaseSprite" type="Sprite2D" parent="AnimatedSprite2D"')
    text = re.sub(r'\[ext_resource type="Resource" path="res://scenes/unit/evolve_tree/tiers/[^\n]*\n', "", text)
    text = re.sub(r'\[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="tier_script"\]\n', "", text)
    text = re.sub(r'^tiers = [^\n]*\n', "", text, flags=re.M)
    replace_ext = {
        "4_04kgf": None,
        "1_wwpqv": '[ext_resource type="Script" path="res://scenes/unit/building/elder_drake/elder_drake.gd" id="1_wwpqv"]',
        "19_tlf38": '[ext_resource type="Texture2D" path="res://%s/puffe_elder_icon.png" id="19_tlf38"]' % ART,
        "20_qaoyh": '[ext_resource type="Texture2D" path="res://%s/red_puffe_elder_icon.png" id="20_qaoyh"]' % ART,
        "26_nwa4t": '[ext_resource type="Texture2D" path="res://%s/blue_puffe_elder_icon.png" id="26_nwa4t"]' % ART,
        "29_pjst3": '[ext_resource type="Texture2D" path="res://%s/green_puffe_elder_icon.png" id="29_pjst3"]' % ART,
        "22_ll5c1": '[ext_resource type="PackedScene" path="%s" id="22_ll5c1"]' % swaps["fire"],
        "26_alotc": '[ext_resource type="PackedScene" path="%s" id="26_alotc"]' % swaps["frost"],
        "28_4x4pp": '[ext_resource type="PackedScene" path="%s" id="28_4x4pp"]' % swaps["poison"],
        "0_upgradedata": '[ext_resource type="Resource" path="res://scenes/upgrades/building_upgrades/elder_drake_upgrade_data.tres" id="0_upgradedata"]',
    }
    for ext_id, line in replace_ext.items():
        pattern = r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id)
        assert re.search(pattern, text), ext_id
        text = re.sub(pattern, "" if line is None else line + "\n", text)
    first_sub = text.index("[sub_resource")
    text = text[:first_sub] + '[ext_resource type="SpriteFrames" path="%s" id="s_frames"]\n\n' % frames["physical"] + text[first_sub:]
    text = text.replace('[node name="PuffeBolter" type="StaticBody2D"', '[node name="PuffeElderDrake" type="StaticBody2D"')
    text = ms.set_props(text, '[node name="LaunchProjectile" parent="."', {"skill_name": '"Bite"', "base_cooldown": repr(COOLDOWN_SECONDS)})
    for node, value in (("Damage", DAMAGE), ("AttackRange", RANGE_TILES), ("CriticalChance", CRIT_CHANCE)):
        text = ms.set_props(text, '[node name="%s" type="Node" parent="LaunchProjectile/Stats"' % node, {"base_value": repr(value), "value": repr(value)})
    text = ms.set_props(text, '[node name="Price" type="Node" parent="Stats"', {"base_value": repr(PRICE), "value": repr(PRICE)})
    text = ms.set_props(text, '[node name="SelectableUnit" parent="."', {"display_name": '"Elder Drake"'})
    for element in ms.ELEMENTS:
        text = ms.set_props(text, '[node name="%s"' % ms.LEAF[element], {"info": '"%s"' % LEAF_INFO[element]})
    assert "puffe_bolter_" not in text.replace("puffe_bolter_evolve", ""), [l for l in text.split("\n") if "puffe_bolter_" in l]
    text = re.sub(r"\n{3,}", "\n\n", text)
    ms.write("scenes/unit/building/buildings/puffe_elder.tscn", text)
    ms.write("scenes/unit/building/buildings/puffe_elder.tres", (
        '[gd_resource type="Resource" script_class="BuildingListElement" format=3]\n\n'
        '[ext_resource type="Script" path="res://scenes/unit/building/building_list_element.gd" id="1_script"]\n'
        '[ext_resource type="Texture2D" path="res://%s/puffe_elder_icon.png" id="2_icon"]\n'
        '[ext_resource type="PackedScene" path="res://scenes/unit/building/buildings/puffe_elder.tscn" id="3_scene"]\n\n'
        '[resource]\nscript = ExtResource("1_script")\nscene = ExtResource("3_scene")\nid = %d\nicon = ExtResource("2_icon")\n'
        'unlock_level = %d\ndescription = "An old drake: expensive, with heavy bites. Once every wave it breathes its '
        'element along the road, through as many enemies as it can line up."\n') % (ART, LIST_ID, UNLOCK_LEVEL))
    path = "scenes/upgrades/building_upgrades/elder_drake_upgrade_data.tres"
    if not os.path.exists(os.path.join(ms.ROOT, path)):
        src = open(os.path.join(ms.ROOT, "scenes/upgrades/building_upgrades/bolter_upgrade_data.tres"), encoding="utf8").read()
        ms.write(path, re.sub(r' uid="[^"]+"', "", src, count=1))
    print("elder drake scenes written")


if __name__ == "__main__":
    main()
