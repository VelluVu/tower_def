#!/usr/bin/env python3
"""One-time patch of the world map (2026-11-25, the user): the two ponds at the drakelings' start move so the caves'
route from level 1 can run east along the map's bottom edge, under them, and are drawn new, more magical than the
old art: the bigger pond (a little north west) deep and clear with a mossy stone rim, a sand beach, lily pads with
pink lotus flowers and glowing blue crystals on its shore; the small one (a little north) a spring in a ring of
standing stones, the water welling up in a bright swirl, glowing pink mushrooms round it. Lit from the top left,
Endesga 32, no outlines, like the rest of the map; MapAmbience twinkles on their water like on the sea.

    python tools/art/world_map_ponds.py --preview <out.png>   before and after, 4x, nothing written
    python tools/art/world_map_ponds.py                       patches world_map_big.png and its .aseprite

Run it once, on the map as it is now: it finds the old ponds by their water inside the boxes below.
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


C = {k: rgb(v) for k, v in {
    "water": "0099db", "glint": "2ce8f5", "deep": "124e89", "white": "ffffff", "foam": "c0cbdc",
    "meadow": "63c74d", "grass": "3e8948", "forest": "265c42", "shade": "193c3e",
    "sand": "ead4aa", "sand2": "e8b796", "dirt": "e4a672",
    "rock1": "c0cbdc", "rock2": "8b9bb4", "rock3": "5a6988", "rock4": "3a4466",
    "pink": "b55088", "rose": "f6757a", "purple": "68386c", "gold": "feae34",
}.items()}
WATER = {C["water"], C["glint"], C["deep"]}
GRASS = {C["meadow"], C["grass"], C["forest"], C["shade"]}

# the old ponds: a box round each one's water
OLD_PONDS = [(40, 296, 88, 332), (94, 312, 124, 335)]
# every non-grass pixel this close to an old pond's water is part of it
RING = 9
# where to borrow grass from to fill an old pond's spot: offsets tried in turn
GRASS_SOURCES = [(0, -40), (40, 0), (-40, 0), (0, 30), (60, -20), (-60, -20)]

# the new ponds (art pixels): water centre and half sizes
BIG = (55, 300, 21, 12)
SMALL = (110, 311, 8, 6)


def rnd(*key):
    return (zlib.crc32(repr(key).encode()) % 10007) / 10007.0


def old_pond_pixels(px, size, box):
    x0, y0, x1, y1 = box
    water = {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1) if px[x, y] in WATER}
    w, h = size
    pond = set(water)
    for (x, y) in water:
        for dy in range(-RING, RING + 1):
            for dx in range(-RING, RING + 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny] not in GRASS:
                    pond.add((nx, ny))
    return pond


def fill_with_grass(px, size, spots):
    w, h = size
    for (x, y) in spots:
        for dx, dy in GRASS_SOURCES:
            sx, sy = x + dx, y + dy
            if 0 <= sx < w and 0 <= sy < h and px[sx, sy] in GRASS and (sx, sy) not in spots:
                px[x, y] = px[sx, sy]
                break
        else:
            px[x, y] = C["meadow"]


def shape(cx, cy, rx, ry, key):
    """r < 1 inside: an ellipse whose shore wanders a little"""
    def r(x, y):
        a = math.atan2(y - cy, x - cx)
        wobble = 1.0 + 0.07 * math.sin(a * 3 + rnd(key, 'a') * 6) + 0.05 * math.sin(a * 5 + rnd(key, 'b') * 6)
        return math.hypot((x - cx) / rx, (y - cy) / ry) / wobble
    return r


class Canvas:
    def __init__(self, px, size):
        self.px, self.size = px, size

    def put(self, x, y, colour):
        if 0 <= x < self.size[0] and 0 <= y < self.size[1]:
            self.px[x, y] = colour

    def get(self, x, y):
        if 0 <= x < self.size[0] and 0 <= y < self.size[1]:
            return self.px[x, y]
        return None


def water_body(cv, cx, cy, rx, ry, key, deep_share=0.5):
    """shore band, water from bright shallows to a deep middle (lit from the top left: the deep sits low right)"""
    r = shape(cx, cy, rx, ry, key)
    rim = shape(cx, cy, rx + 3, ry + 3, key)
    inside = set()
    for y in range(cy - ry - 5, cy + ry + 6):
        for x in range(cx - rx - 5, cx + rx + 6):
            if rim(x, y) >= 1.0:
                continue
            if r(x, y) >= 1.0:
                # the shore: mossy stones on the north half, a sand beach on the south half
                if y < cy - 1:
                    stone = rnd(x // 2, y // 2, key, 'stone')
                    colour = C["rock2"] if stone < 0.35 else C["rock3"] if stone < 0.6 else C["grass"] if stone < 0.85 else C["meadow"]
                    if cv.get(x, y + 1) is not None and r(x, y + 1) < 1.0 and stone < 0.6:
                        colour = C["rock4"]  # the stones' wet foot
                else:
                    colour = C["sand"] if r(x, y - 1) >= 1.0 or rnd(x, y, key, 'sand') < 0.8 else C["sand2"]
                    if r(x, y - 1) < 1.0:
                        colour = C["sand2"]  # wet sand at the waterline
                cv.put(x, y, colour)
                continue
            inside.add((x, y))
            d = math.hypot((x - cx - rx * 0.12) / rx, (y - cy - ry * 0.15) / ry)
            colour = C["deep"] if d < deep_share else C["water"]
            if r(x, y) > 0.86 and y > cy:
                colour = C["glint"]  # bright shallows along the beach
            cv.put(x, y, colour)
    return inside, r


def ripples(cv, inside, key, count):
    """short light dashes on the water, like the map's other water"""
    cells = sorted(inside)
    for k in range(count):
        x, y = cells[int(rnd(key, k, 'rip') * len(cells))]
        for dx in range(3):
            if (x + dx, y) in inside and cv.get(x + dx, y) == C["water"]:
                cv.put(x + dx, y, C["glint"])


def lily_pad(cv, x, y, flower):
    for dx, dy, c in ((0, 0, "grass"), (1, 0, "meadow"), (2, 0, "grass"), (0, 1, "forest"), (1, 1, "grass"), (2, 1, "forest")):
        cv.put(x + dx, y + dy, C[c])
    if flower:
        cv.put(x + 1, y - 1, C["rose"])
        cv.put(x, y - 1, C["pink"])
        cv.put(x + 2, y - 1, C["pink"])
        cv.put(x + 1, y - 2, C["white"])


def crystal(cv, x, y, height):
    """a glowing blue crystal standing on the shore: lit face left, shaded face right, a white tip, a dark foot"""
    for k in range(height):
        cv.put(x, y - k, C["glint"] if k < height - 1 else C["white"])
        cv.put(x + 1, y - k, C["water"])
        if k < height - 2:
            cv.put(x + 2, y - k, C["deep"])
    cv.put(x + 1, y - height, C["glint"])
    for dx in range(-1, 4):
        cv.put(x + dx, y + 1, C["rock3"] if dx in (0, 1, 2) else C["shade"])


def big_pond(cv):
    cx, cy, rx, ry = BIG
    inside, r = water_body(cv, cx, cy, rx, ry, 'big', 0.32)
    ripples(cv, inside, 'big', 9)
    pads = [(-12, -3, True), (-9, 2, False), (-14, 3, False), (7, -5, False), (10, -2, True), (4, 5, True), (-2, -6, False)]
    for dx, dy, flower in pads:
        lily_pad(cv, cx + dx, cy + dy, flower)
    # a ring of soft light on the deep water: the pond's magic
    for k in range(10):
        a = k / 10 * math.tau
        x, y = round(cx + 2 + math.cos(a) * 5), round(cy + 1 + math.sin(a) * 2.5)
        if (x, y) in inside and k % 2 == 0:
            cv.put(x, y, C["glint"])
    cv.put(cx + 2, cy + 1, C["white"])
    # glowing crystals on the north east shore, and a pair on the west
    for dx, dy, height in ((rx - 4, -ry - 2, 8), (rx - 1, -ry, 5), (rx - 8, -ry - 2, 4), (-rx - 2, -1, 6), (-rx + 1, -3, 3)):
        crystal(cv, cx + dx, cy + dy, height)
    # reeds on the beach
    for dx in (-10, -8, 12, 14):
        x, y = cx + dx, cy + ry + 2
        cv.put(x, y, C["grass"])
        cv.put(x, y - 1, C["meadow"])
        cv.put(x, y - 2, C["dirt"] if dx % 4 else C["meadow"])


def small_pond(cv):
    cx, cy, rx, ry = SMALL
    inside, r = water_body(cv, cx, cy, rx, ry, 'small', 0.45)
    # the spring welling up: a bright swirl in the middle
    for k in range(9):
        a = k * 0.8
        rad = 0.6 + k * 0.45
        x, y = round(cx + math.cos(a) * rad * 1.5), round(cy + math.sin(a) * rad)
        if (x, y) in inside:
            cv.put(x, y, C["white"] if k < 2 else C["glint"])
    # standing stones round it, lit on the left
    for k in range(7):
        a = -math.pi / 2 + k / 7 * math.tau + 0.2
        x = round(cx + math.cos(a) * (rx + 5))
        y = round(cy + math.sin(a) * (ry + 4))
        tall = 4 if k % 2 == 0 else 3
        for t in range(tall):
            cv.put(x, y - t, C["rock2"] if t < tall - 1 else C["rock1"])
            cv.put(x + 1, y - t, C["rock3"])
        cv.put(x, y + 1, C["shade"])
        cv.put(x + 1, y + 1, C["shade"])
    # glowing mushrooms between the stones
    for k in range(5):
        a = k / 5 * math.tau + 0.9
        x = round(cx + math.cos(a) * (rx + 3))
        y = round(cy + math.sin(a) * (ry + 2)) + 1
        if cv.get(x, y) in GRASS or cv.get(x, y) in (C["sand"], C["sand2"]):
            cv.put(x, y, C["sand"])
            cv.put(x, y - 1, C["pink"])
            cv.put(x - 1, y - 1, C["rose"])
            cv.put(x + 1, y - 1, C["purple"])


def patch(image):
    px = image.load()
    size = image.size
    old = set()
    for box in OLD_PONDS:
        old |= old_pond_pixels(px, size, box)
    fill_with_grass(px, size, old)
    cv = Canvas(px, size)
    big_pond(cv)
    small_pond(cv)
    return image


def main(args):
    image = Image.open(PNG).convert("RGBA")
    before = image.copy()
    patch(image)
    if "--preview" in args:
        out = args[args.index("--preview") + 1]
        box = (0, 250, 190, 336)
        a, b = before.crop(box), image.crop(box)
        sheet = Image.new("RGBA", (a.width, a.height * 2 + 4), (0, 0, 0, 255))
        sheet.paste(a, (0, 0))
        sheet.paste(b, (0, a.height + 4))
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out)
        return 0
    image.save(PNG)
    if os.path.exists(ASEPRITE_EXE):
        subprocess.run([ASEPRITE_EXE, "-b", PNG, "--save-as", ASEPRITE], check=True, capture_output=True)
    print("patched", PNG)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
