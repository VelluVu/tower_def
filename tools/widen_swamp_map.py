"""Widens the swamp on the world map (the user, 2026-11-16: "you can widen the swamp area if needed") so the twelve
swamp levels have room: the lower slopes of the northern mountains above the old swamp become swamp ground in its
own colours (dark green with a darker rim against the rock, bog pools, a few trees). Water, existing ground and the
high peaks stay. Writes world_map.png and saves the .aseprite from it (one layer, as before).

    python tools/widen_swamp_map.py
"""
import math
import os
import subprocess

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PNG = os.path.join(ROOT, "assets", "art", "ui", "world_map.png")
ASEPRITE = os.path.join(ROOT, "assets", "art", "ui", "world_map.aseprite")
ASEPRITE_EXE = "C:/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe"

SWAMP = (0x26, 0x5c, 0x42)
RIM = (0x19, 0x3c, 0x3e)
POOL = (0x19, 0x3c, 0x3e)
POOL_WATER = (0x12, 0x4e, 0x89)
LEAF = (0x3e, 0x89, 0x48)
LEAF_LIGHT = (0x63, 0xc7, 0x4d)
ROCK = {(0x3a, 0x44, 0x66), (0x5a, 0x69, 0x88), (0x8b, 0x9b, 0xb4), (0x26, 0x2b, 0x44), (0x18, 0x14, 0x25), (0xc0, 0xcb, 0xdc)}
CENTER = (56.0, 34.0)
RADII = (40.0, 17.0)
#a dark pool with a small water eye, like the old swamp's: (x, y) of its top-left
POOLS = [(32, 27), (52, 22), (70, 28), (44, 36), (62, 38)]
TREES = [(27, 33), (61, 30), (81, 34), (40, 25), (54, 44), (75, 22)]
POOL_SHAPE = ["..aaa..", ".aabaa.", "aabbbaa", ".aaaaa."]
TREE_SHAPE = [".c.", "ccd", "ddd"]


def inside(x, y):
    # an ellipse with a wobbly edge, open at the bottom so it runs into the old swamp
    dx, dy = (x - CENTER[0]) / RADII[0], (y - CENTER[1]) / RADII[1]
    wobble = 0.12 * math.sin(x / 3.1) + 0.1 * math.sin(y / 2.2 + x / 5.0)
    return y > CENTER[1] and abs(dx) < 1.0 + wobble or dx * dx + dy * dy < 1.0 + wobble


def main():
    image = Image.open(PNG).convert("RGBA")
    px = image.load()
    changed = set()
    for x in range(0, 110):
        for y in range(0, 60):
            if inside(x, y) and px[x, y][:3] in ROCK:
                px[x, y] = SWAMP + (255,)
                changed.add((x, y))
    # a darker rim where the new swamp meets the rock
    for (x, y) in list(changed):
        if any(px[x + dx, y + dy][:3] in ROCK for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1))):
            px[x, y] = RIM + (255,)
    colours = {"a": POOL, "b": POOL_WATER, "c": LEAF_LIGHT, "d": LEAF}
    for shape, spots in ((POOL_SHAPE, POOLS), (TREE_SHAPE, TREES)):
        for (cx, cy) in spots:
            for dy, row in enumerate(shape):
                for dx, ch in enumerate(row):
                    if ch != "." and (cx + dx, cy + dy) in changed:
                        px[cx + dx, cy + dy] = colours[ch] + (255,)
    image.save(PNG)
    subprocess.run([ASEPRITE_EXE, "-b", PNG, "--save-as", ASEPRITE], check=True, capture_output=True)
    print("widened the swamp by %d pixels" % len(changed))


if __name__ == "__main__":
    main()
