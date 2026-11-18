"""Write the SpriteFrames of the element wall overlays (Fire, Frost, Poison, Fortress; drawn by tools/sprite/parts/walls.py), one
animation per wall connector tag, so Wall can lay the element over any stage:

    python tools/wall_overlay_frames.py

Writes scenes/unit/building/wall_stages/wall_<element>_overlay_frames.tres. Rerun after redrawing an overlay.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import enemy_scene as es

ROOT = es.ROOT
ART = "assets/art/units/building/wall/wall_%s_overlay"
OUT = "scenes/unit/building/wall_stages/wall_%s_overlay_frames.tres"

for element in ("fire", "frost", "poison", "fortress"):
    base = ART % element
    aseprite, png = os.path.join(ROOT, base + ".aseprite"), os.path.join(ROOT, base + ".png")
    w, h, durs, tags = es.info(aseprite)
    where = es.regions(aseprite, png, w, h, len(durs))
    text = '[gd_resource type="SpriteFrames" format=3]\n\n[ext_resource type="Texture2D" path="res://%s.png" id="1_sheet"]\n\n' % base
    anims = []
    for tag, a, b in tags:
        refs = []
        for i in range(a, b + 1):
            text += '[sub_resource type="AtlasTexture" id="AtlasTexture_f%02d"]\natlas = ExtResource("1_sheet")\nregion = Rect2(%d, %d, %d, %d)\n\n' % (
                i, where[i][0], where[i][1], w, h)
            refs.append('{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_f%02d")\n}' % i)
        anims.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(refs), tag, 1000.0 / durs[a]))
    text += "[resource]\nanimations = [%s]\n" % ", ".join(anims)
    with open(os.path.join(ROOT, OUT % element), "w", encoding="utf8", newline="\n") as f:
        f.write(text)
    print("wrote", OUT % element, len(tags), "tags")
