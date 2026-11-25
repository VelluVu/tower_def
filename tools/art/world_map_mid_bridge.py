#!/usr/bin/env python3
"""One-time patch of the world map (2026-11-25, the user): the barricaded middle bridge moves south, next to Barricade
Bridge (level 11) on the river bank south east of the great cave. The old bridge and its flag go (the river runs on
there), and a new plank bridge crosses from the cave's bank over the river along the crystal rock's back, partly behind it, to
the sand on the far shore. The humans hold it: their barricade of sharpened stakes across its west end faces the
drakelings' bank, their red banner planted behind it.

    python tools/art/world_map_mid_bridge.py --preview <out.png>   before and after, 4x, nothing written
    python tools/art/world_map_mid_bridge.py                       patches world_map_big.png and its .aseprite

Run it once, on the map as it is now.
"""
import os
import subprocess
import sys
import zlib

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PNG = os.path.join(ROOT, "assets", "art", "ui", "world_map_big.png")
ASEPRITE = os.path.join(ROOT, "assets", "art", "ui", "world_map_big.aseprite")
ASEPRITE_EXE = "C:/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe"


def rgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


C = {k: rgb(v) for k, v in {
    "water": "0099db", "glint": "2ce8f5", "deep": "124e89", "forest": "265c42", "shade": "193c3e",
    "dirt": "e4a672", "furrow": "b86f50", "brown": "733e39", "outline": "3e2731", "sand2": "e8b796",
    "red": "a22633", "lava": "e43b44", "white": "ffffff", "night": "181425", "pink": "f6757a",
}.items()}
WATER = {C["water"], C["glint"], C["deep"]}

# the old bridge's deck, its flag and the pink barricade bits on its west end (x0, x1, y0, y1, inclusive)
OLD_DECK = (136, 154, 162, 177)
OLD_FLAG = (140, 152, 147, 162)
OLD_BARRICADE = (131, 137, 155, 164)
# the new bridge: the deck's top row, and the span searched for its water (x0, x1)
NEW_DECK_Y = 196
NEW_SPAN = (100, 156)
# the deck runs along the crystal rock's back (north) edge to the sand on the far shore (x); where the rock stands in
# front of it, the rock stays drawn over it, so the bridge passes behind
DECK_END_X = 156
# its west end reaches over the terraced bank onto the grass of the west shore (x)
DECK_START_X = 120
ROCK = {rgb("8b9bb4"), rgb("5a6988"), rgb("3a4466"), rgb("262b44"), rgb("181425"), rgb("c0cbdc")}


def rnd(*key):
    return (zlib.crc32(repr(key).encode()) % 10007) / 10007.0


def patch(image):
    px = image.load()
    for box in (OLD_DECK, OLD_FLAG):
        x0, x1, y0, y1 = box
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if px[x, y] not in WATER:
                    px[x, y] = C["glint"] if rnd(x, y, "glint") < 0.04 else C["water"]
    x0, x1, y0, y1 = OLD_BARRICADE
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if px[x, y] in (C["pink"], C["red"], C["lava"]):
                px[x, y] = C["forest"]

    # the new deck spans the water on its middle row, a pixel onto each bank
    y = NEW_DECK_Y
    wet = [x for x in range(*NEW_SPAN) if px[x, y + 2] in WATER]
    left, right = min(wet) - 1, max(wet) + 1
    landing = right
    left, right = DECK_START_X, DECK_END_X
    def deck(x, yy, colour):
        if px[x, yy] not in ROCK:                   # the rock in front hides the deck
            px[x, yy] = colour
    for x in range(left, right + 1):
        deck(x, y, C["brown"])                      # the rail
        for k in range(1, 4):
            deck(x, y + k, C["dirt"] if x % 3 else C["furrow"])  # planks, a gap every third
        deck(x, y + 4, C["outline"])                # the deck's shadowed edge
        if px[x, y + 5] in WATER:
            px[x, y + 5] = C["deep"]                # its shadow on the water
    for x in range(left + 3, landing, 6):           # posts in the water
        px[x, y + 5] = C["brown"]
        px[x, y + 6] = C["outline"]
    # the humans' barricade across the deck, where it leaves the drakelings' bank: sharpened stakes leaning west
    # over a cross beam, standing against the water so they read
    for i, bx in enumerate(range(left + 12, left + 21, 3)):
        height = 9 if i % 2 == 0 else 8
        for k in range(height):
            sx, sy = bx - k // 3, y + 3 - k
            px[sx, sy] = C["sand2"] if k == height - 1 else C["dirt"] if k == height - 2 else C["brown"]
            px[sx + 1, sy] = C["outline"] if k < height - 1 else px[sx + 1, sy]   # its shaded side
    for x in range(left + 9, left + 21):
        px[x, y + 1] = C["outline"]                 # the cross beam
        px[x, y] = C["brown"]
    # the humans' banner planted behind it: a thin pole, a red cloth with a white emblem, flying east
    pole_x, ground = left + 22, y + 3
    for yy in range(ground - 10, ground + 1):
        px[pole_x, yy] = C["brown"]
    px[pole_x, ground - 11] = C["sand2"]
    for fy in range(3):
        for fx in range(1, 6):
            px[pole_x + fx, ground - 10 + fy] = C["lava"] if fy == 0 else C["red"]
    px[pole_x + 2, ground - 9] = C["white"]
    px[pole_x + 3, ground - 9] = C["white"]
    return image


def main(args):
    image = Image.open(PNG).convert("RGBA")
    before = image.copy()
    patch(image)
    if "--preview" in args:
        out = args[args.index("--preview") + 1]
        box = (90, 140, 200, 240)
        a, b = before.crop(box), image.crop(box)
        sheet = Image.new("RGBA", (a.width * 2 + 4, a.height), (0, 0, 0, 255))
        sheet.paste(a, (0, 0))
        sheet.paste(b, (a.width + 4, 0))
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out)
        return 0
    image.save(PNG)
    if os.path.exists(ASEPRITE_EXE):
        subprocess.run([ASEPRITE_EXE, "-b", PNG, "--save-as", ASEPRITE], check=True, capture_output=True)
    print("patched", PNG)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
