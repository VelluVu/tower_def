"""The Hoard Keeper's scenes and data (2026-11-25), rerunnable:

    python tools/hoard_scenes.py

Art first: tools/sprite/parts/hoard_art.py (then sprite.py build each sheet and the icons).
Writes
- scenes/unit/evolve_tree/puffe_hoard_evolve/<sheet>_frames.tres and the element sprite swaps
- scenes/unit/building/buildings/puffe_hoard.tscn: from the Buffer's scene (a building with a passive skill and no
  behaviour tree) with the HoardKeeper script, no aura; puffe_hoard.tres (the build tray, unlocks on level 10);
  hoard_upgrade_data.tres (the usual line: Up 1, Up 2, the element, Up 3, T2, T3, each step +1 gold a wave)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import buffer_scenes as bs
import mortar_scenes as ms

ART = "assets/art/units/building/puffe/puffe_hoard"
EVOLVE = "scenes/unit/evolve_tree/puffe_hoard_evolve"
UNLOCK_LEVEL = 10
LIST_ID = 7
PRICE = 6.0
LEAF_INFO = {
    "physical": "Silver: the pile shines, +1 gold a wave",
    "fire": "Fire: red gold, +1 gold a wave",
    "frost": "Frost: ice-cold coins, +1 gold a wave",
    "poison": "Poison: a cursed hoard, +1 gold a wave",
}


def sheet_name(element):
    return (ms.COLOUR[element] + "_" if ms.COLOUR[element] else "") + "puffe_hoard"


def main():
    ms.EVOLVE = EVOLVE
    frames = {e: ms.frames("%s/%s" % (ART, sheet_name(e)), sheet_name(e)) for e in ms.ELEMENTS}
    swaps = {}
    for element in ms.ELEMENTS:
        bs.EVOLVE = EVOLVE
        path = bs.swap_scene(element, frames[element])
        # the Buffer's swap is named after its sheet: rename to the Keeper's
        old = os.path.join(ms.ROOT, path.replace("res://", ""))
        new_rel = "%s/%s.tscn" % (EVOLVE, sheet_name(element))
        text = open(old, encoding="utf8").read().replace("PuffeBuffer", "PuffeHoard")
        os.remove(old)
        ms.write(new_rel, text)
        swaps[element] = "res://" + new_rel

    text = open(os.path.join(ms.ROOT, "scenes/unit/building/buildings/puffe_buffer.tscn"), encoding="utf8").read()
    text = text.replace("res://scenes/unit/building/buffer/buffer.gd", "res://scenes/unit/building/hoard_keeper/hoard_keeper.gd")
    for element in ms.ELEMENTS:
        buffer_sheet = (ms.COLOUR[element] + "_" if ms.COLOUR[element] else "") + "puffe_buffer"
        text = text.replace("res://scenes/unit/evolve_tree/puffe_buffer_evolve/%s.tscn" % buffer_sheet, swaps[element])
        text = text.replace("puffe_buffer/%s_icon.png" % buffer_sheet, "puffe_hoard/%s_icon.png" % sheet_name(element))
    text = text.replace("res://scenes/unit/evolve_tree/puffe_buffer_evolve/puffe_buffer_frames.tres", frames["physical"])
    text = text.replace("buffer_upgrade_data.tres", "hoard_upgrade_data.tres")
    # no aura ring, no tiers yet
    text = re.sub(r'\[ext_resource [^\n]*id="b_ring"\]\n', "", text)
    text = re.sub(r'\[node name="AuraRing" type="Node2D" parent="\."\]\nscript = ExtResource\("b_ring"\)\n\n?', "", text)
    text = re.sub(r'\[ext_resource type="Resource" path="res://scenes/unit/evolve_tree/tiers/[^\n]*\n', "", text)
    text = re.sub(r'\[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="tier_script"\]\n', "", text)
    text = re.sub(r'^tiers = [^\n]*\n', "", text, flags=re.M)
    text = text.replace('[node name="PuffeBuffer" type="StaticBody2D"', '[node name="PuffeHoardKeeper" type="StaticBody2D"')
    text = text.replace('skill_name = "Aura"', 'skill_name = "Hoard"')
    text = ms.set_props(text, '[node name="AttackRange" type="Node" parent="Aura/Stats"', {"base_value": "0.0", "value": "0.0"})
    text = ms.set_props(text, '[node name="Price" type="Node" parent="Stats"', {"base_value": repr(PRICE), "value": repr(PRICE)})
    text = ms.set_props(text, '[node name="SelectableUnit" parent="."', {"display_name": '"Hoard Keeper"'})
    for element in ms.ELEMENTS:
        text = ms.set_props(text, '[node name="%s"' % ms.LEAF[element], {"info": '"%s"' % LEAF_INFO[element]})
    assert "buffer" not in text.lower().replace("buffer_", "x"), [l for l in text.split("\n") if "buffer" in l.lower()]
    text = re.sub(r"\n{3,}", "\n\n", text)
    ms.write("scenes/unit/building/buildings/puffe_hoard.tscn", text)

    ms.write("scenes/unit/building/buildings/puffe_hoard.tres", (
        '[gd_resource type="Resource" script_class="BuildingListElement" format=3]\n\n'
        '[ext_resource type="Script" path="res://scenes/unit/building/building_list_element.gd" id="1_script"]\n'
        '[ext_resource type="Texture2D" path="res://%s/puffe_hoard_icon.png" id="2_icon"]\n'
        '[ext_resource type="PackedScene" path="res://scenes/unit/building/buildings/puffe_hoard.tscn" id="3_scene"]\n\n'
        '[resource]\nscript = ExtResource("1_script")\nscene = ExtResource("3_scene")\nid = %d\nicon = ExtResource("2_icon")\n'
        'unlock_level = %d\ndescription = "Never attacks: guards a pile of gold and pays 2 gold after every wave cleared, '
        '+1 for each upgrade bought on it. Only your first two Keepers pay in full."\n') % (ART, LIST_ID, UNLOCK_LEVEL))
    path = "scenes/upgrades/building_upgrades/hoard_upgrade_data.tres"
    if not os.path.exists(os.path.join(ms.ROOT, path)):
        src = open(os.path.join(ms.ROOT, "scenes/upgrades/building_upgrades/bolter_upgrade_data.tres"), encoding="utf8").read()
        ms.write(path, re.sub(r' uid="[^"]+"', "", src, count=1))
    print("hoard keeper scenes written")


if __name__ == "__main__":
    main()
