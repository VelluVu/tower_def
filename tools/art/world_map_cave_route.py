#!/usr/bin/env python3
"""One-time patch of the world map for the caves' route (2026-11-25, the user: the drakelings carry their building
materials and hate water, so they stay on the cave side of the river until the swamp's top bridge; Puffe walks east
along the bottom, past the southern mountain's cave, to the smashed southern bridge, then north past the barricaded
bridge into the great cave).

    python tools/art/world_map_cave_route.py --preview <out.png>   before and after, 4x, nothing written
    python tools/art/world_map_cave_route.py                       patches world_map_big.png and its .aseprite

What it changes (art pixels of world_map_big.png):
  - the river no longer spreads into the lake: it runs down the crystal rock's west foot and on along its south side
    into the outflow under the smashed bridge;
  - the lake's east part and the old channel become a dry shore joining the southern peninsula to the cave's bank
    (grass, sand to the lake, a terraced bank to the river);
  - the barricaded bridge moves south: the old one (and its flag) is taken out, a new one with a barricade and the
    flag crosses the new channel from the shore to the rock (the humans come over it from the east).
Run it once, on the generated map: it reads the picture as it is now.
"""
import math
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


WATER = {rgb("0099db"), rgb("2ce8f5"), rgb("124e89")}
ROCK = {rgb("8b9bb4"), rgb("5a6988"), rgb("3a4466"), rgb("262b44"), rgb("181425"), rgb("c0cbdc")}
C = {k: rgb(v) for k, v in {
    "water": "0099db", "glint": "2ce8f5", "meadow": "63c74d", "grass": "3e8948", "forest": "265c42", "shade": "193c3e",
    "sand": "ead4aa", "sand2": "e8b796", "dirt": "e4a672", "dirt2": "c28569", "furrow": "b86f50", "rust": "be4a2f",
    "brown": "733e39", "outline": "3e2731", "red": "a22633", "lava": "e43b44", "white": "ffffff", "night": "181425",
}.items()}

# the region the patch works in
X0, X1, Y0, Y1 = 100, 200, 176, 292
# above the rock the river narrows against its east bank, from its full width at NARROW_FROM to CHANNEL_WIDTH
NARROW_FROM = 178
# the crystal rock's mass (its pixels inside this box)
ROCK_BOX = (136, 190, 196, 262)
CHANNEL_WIDTH = 6
# the outflow past the rock's south side, kept as it is
OUTFLOW_FROM_X = 160
# the old bridge and its flag, taken out (x0, x1, y0, y1, inclusive)
OLD_DECK = (136, 154, 162, 177)
OLD_FLAG = (140, 152, 147, 162)
OLD_BARRICADE = (131, 137, 155, 164)
# the new bridge's row (deck top) and the lake's new east shore
NEW_BRIDGE_Y = 222


def rnd(*key):
    return (zlib.crc32(repr(key).encode()) % 10007) / 10007.0


def lake_east(y):
    """the lake keeps everything west of this (none above its new north shore)"""
    if y < 212:
        return -1
    return int(113 + 3 * math.sin(y * 0.11) + max(0, y - 255) * 0.5)


class Map:
    def __init__(self, image):
        self.image = image
        self.px = image.load()

    def get(self, x, y):
        return self.px[x, y]

    def put(self, x, y, colour):
        self.px[x, y] = colour


def rock_mask(m):
    x0, x1, y0, y1 = ROCK_BOX
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if m.get(x, y) in ROCK}


def channel_pixels(m, rock):
    """water within CHANNEL_WIDTH west of or below the rock, from where the river meets it to the outflow"""
    channel = set()
    for y in range(Y0, ROCK_BOX[3] + 8):
        for x in range(X0, OUTFLOW_FROM_X + 8):
            if m.get(x, y) not in WATER:
                continue
            near = any((x + dx, y + dy) in rock for dx in range(0, CHANNEL_WIDTH + 1) for dy in range(-CHANNEL_WIDTH, CHANNEL_WIDTH + 1))
            if near:
                channel.add((x, y))
    # the river coming down from the north joins it along its east bank, narrowing as it comes
    for y in range(Y0, ROCK_BOX[2] + 6):
        row = [x for x in range(X0, ROCK_BOX[1]) if m.get(x, y) in WATER]
        if not row:
            continue
        right = max(row)
        full = right - min(row) + 1
        t = min(1.0, max(0.0, (y - NARROW_FROM) / (ROCK_BOX[2] + 4 - NARROW_FROM)))
        width = round(full + (CHANNEL_WIDTH + 1 - full) * t)
        for x in row:
            if x > right - width:
                channel.add((x, y))
    return channel


def stamp_old_flag(m):
    """the old flag's pixels (not water), to set up again by the new bridge"""
    x0, x1, y0, y1 = OLD_FLAG
    return {(x - x0, y - y0): m.get(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)
            if m.get(x, y) in (C["red"], C["lava"], C["white"], C["night"], C["outline"])}


def take_out_old_bridge(m):
    for box in (OLD_DECK, OLD_FLAG):
        x0, x1, y0, y1 = box
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if m.get(x, y) not in WATER:
                    m.put(x, y, C["glint"] if rnd(x, y, "glint") < 0.04 else C["water"])
    x0, x1, y0, y1 = OLD_BARRICADE
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if m.get(x, y) in (rgb("f6757a"), C["red"], C["lava"]):
                m.put(x, y, C["forest"])


def grass_at(x, y):
    n = rnd(x // 3, y // 3, "patch")
    if rnd(x, y, "speck") < 0.04:
        return C["forest"]
    return C["meadow"] if n < 0.62 else C["grass"]


def tree(m, x, y):
    """a small round tree like the map's grass trees"""
    shape = [" 12 ", "1122", "1223", " 33 ", "  o "]
    colours = {"1": C["meadow"], "2": C["grass"], "3": C["forest"], "o": C["outline"]}
    for dy, line in enumerate(shape):
        for dx, ch in enumerate(line):
            if ch != " ":
                m.put(x + dx - 2, y + dy - 4, colours[ch])


def patch(image):
    m = Map(image)
    flag = stamp_old_flag(m)
    take_out_old_bridge(m)
    rock = rock_mask(m)
    channel = channel_pixels(m, rock)
    land = set()
    for y in range(Y0, Y1 + 1):
        for x in range(X0, X1 + 1):
            if m.get(x, y) not in WATER or (x, y) in channel:
                continue
            if x <= lake_east(y):
                continue
            if x >= OUTFLOW_FROM_X and y >= ROCK_BOX[3] - 8:
                continue  # the outflow
            land.add((x, y))
    for (x, y) in land:
        m.put(x, y, grass_at(x, y))

    def water(x, y):
        return m.get(x, y) in WATER

    # the shores: sand to the lake, a terraced bank to the river
    for (x, y) in land:
        lake_near = any(water(x + dx, y + dy) and x + dx <= lake_east(y + dy) for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2))
        river_near = any((x + dx, y + dy) in channel for dx in (-2, -1, 0, 1, 2) for dy in (-1, 0, 1))
        if river_near:
            touching = any((x + dx, y) in channel for dx in (1, 2))
            stripe = C["dirt"] if y % 2 else C["furrow"]
            m.put(x, y, C["rust"] if touching and y % 2 == 0 else stripe)
        elif lake_near:
            m.put(x, y, C["sand2"] if water(x, y + 1) or water(x, y + 2) else C["sand"])
    for (x, y) in sorted(land):
        if m.get(x, y) in (C["meadow"], C["grass"]) and rnd(x, y, "tree") < 0.012 and \
                all((x + dx, y + dy) in land and m.get(x + dx, y + dy) in (C["meadow"], C["grass"], C["forest"])
                    for dx in (-3, 0, 3) for dy in (-5, 0, 2)):
            tree(m, x, y)

    # the new barricaded bridge across the channel, from the shore to the rock
    y0 = NEW_BRIDGE_Y
    row = [x for x in range(X0, ROCK_BOX[1]) if (x, y0 + 2) in channel]
    left, right = min(row) - 2, max(row) + 2
    for x in range(left, right + 1):
        m.put(x, y0, C["brown"])
        for k in range(1, 4):
            m.put(x, y0 + k, C["dirt"] if x % 2 else C["furrow"])
        m.put(x, y0 + 4, C["outline"])
    for x in range(left - 3, left + 2):  # the barricade: sharpened stakes across the shore end
        top = y0 - 3 - (x % 2)
        for y in range(top, y0 + 4):
            m.put(x, y, C["brown"] if y > top else C["sand2"])
    for (fx, fy), colour in flag.items():  # the flag, on the shore by the barricade
        m.put(left - 9 + fx, y0 - 13 + fy, colour)
    return image


def main(args):
    image = Image.open(PNG).convert("RGBA")
    before = image.copy()
    patch(image)
    if "--preview" in args:
        out = args[args.index("--preview") + 1]
        box = (X0 - 10, 140, X1 + 10, 300)
        a = before.crop(box)
        b = image.crop(box)
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
