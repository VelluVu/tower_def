"""The world map's living touches (2026-11-24, the user: "moving fog clouds, and other immersive surroundings"): one
small sheet for MapAmbience (scenes/ui/game_world_map/map_ambience.gd) with three drifting clouds, a mist bank for the
swamp, four smoke puff frames for the lava, two flapping bird frames and three sparkle frames for the sea. Endesga 32,
lit from the top left, no outlines. The regions are fixed (MapAmbience's consts):

    clouds   (0, 0, 48, 20)  (48, 0, 40, 16)  (88, 0, 64, 24)
    mist     (0, 24, 64, 12)
    smoke    (64 + 8i, 24, 8, 8), i = 0..3
    bird     (96 + 6i, 24, 5, 4), i = 0..1
    sparkle  (108 + 4i, 24, 3, 3), i = 0..2

    python tools/art/world_map_ambience.py [--preview out.png]
"""
import math
import os
import sys
import zlib

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "art", "ui", "world_map_ambience.png")
SIZE = (152, 36)


def rgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


WHITE, CLOUD, UNDER, SHADE = rgb('ffffff'), rgb('c0cbdc'), rgb('8b9bb4'), rgb('5a6988')
MIST, MIST_DARK = rgb('c0cbdc'), rgb('8b9bb4')
SMOKE = [rgb('5a6988'), rgb('3a4466'), rgb('8b9bb4')]
BIRD = rgb('262b44')
GLINT, SPARK = rgb('2ce8f5'), rgb('ffffff')


def rnd(*key):
    return (zlib.crc32(repr(key).encode()) % 10007) / 10007.0


def cloud(im, ox, oy, w, h, key):
    """puffs side by side, a flat underside; white on top, grey-blue below"""
    puffs = []
    count = max(3, w // 11)
    for i in range(count):
        cx = ox + 6 + (w - 12) * i / (count - 1)
        r = h * (0.22 + 0.2 * math.sin(i / (count - 1) * math.pi)) + rnd(key, i) * 1.5
        puffs.append((cx, max(oy + r, oy + h - 4 - r * 0.3), r))
    for y in range(oy, oy + h):
        for x in range(ox, ox + w):
            inside = [(x - px) ** 2 + (y - py) ** 2 <= r * r for px, py, r in puffs]
            if not any(inside) or y > oy + h - 3:
                continue
            # dithered rim
            near = min(math.hypot(x - px, y - py) - r for px, py, r in puffs)
            if near > -1.0 and (x + y) % 2:
                continue
            depth = (y - oy) / h
            lit = min(math.hypot(x - px + r * 0.4, y - py + r * 0.4) / r for px, py, r in puffs)
            colour = WHITE if lit < 0.55 and depth < 0.6 else CLOUD if depth < 0.75 else UNDER
            if depth > 0.85:
                colour = SHADE if (x // 2) % 2 else UNDER
            im.putpixel((x, y), colour)


def mist(im, ox, oy, w, h):
    """a long low bank, thick in the middle, broken into a dither at its ends and edges"""
    for y in range(oy, oy + h):
        for x in range(ox, ox + w):
            nx = (x - ox - w / 2) / (w / 2)
            ny = (y - oy - h / 2) / (h / 2)
            body = 1.0 - nx * nx - ny * ny * 1.4 + 0.25 * math.sin(x * 0.4)
            if body <= 0:
                continue
            if body < 0.35 and (x + y * 2) % 3:
                continue
            if body < 0.15:
                continue
            im.putpixel((x, y), MIST if y < oy + h * 0.55 else MIST_DARK)


def smoke(im, ox, oy, frame):
    """a puff that grows and thins as it rises"""
    r = 1.4 + frame * 0.75
    cx, cy = ox + 4, oy + 5 - frame * 0.5
    for y in range(oy, oy + 8):
        for x in range(ox, ox + 8):
            d = math.hypot(x - cx, y - cy)
            if d > r or (frame >= 2 and (x + y) % 2 and d > r - 1.2) or (frame == 3 and (x + y) % 2):
                continue
            im.putpixel((x, y), SMOKE[2] if d < r * 0.5 and y < cy else SMOKE[0] if d < r * 0.8 else SMOKE[1])


def bird(im, ox, oy, frame):
    shape = ["X   X", " X X ", "  X  "] if frame == 0 else ["     ", "XX XX", "  X  "]
    for y, line in enumerate(shape):
        for x, ch in enumerate(line):
            if ch == 'X':
                im.putpixel((ox + x, oy + y), BIRD)


def sparkle(im, ox, oy, frame):
    if frame == 0:
        im.putpixel((ox + 1, oy + 1), GLINT)
    elif frame == 1:
        for x, y in ((1, 0), (0, 1), (2, 1), (1, 2)):
            im.putpixel((ox + x, oy + y), GLINT)
        im.putpixel((ox + 1, oy + 1), SPARK)
    else:
        im.putpixel((ox + 1, oy + 1), SPARK)


def main(args):
    im = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    cloud(im, 0, 0, 48, 20, 'a')
    cloud(im, 48, 0, 40, 16, 'b')
    cloud(im, 88, 0, 64, 24, 'c')
    mist(im, 0, 24, 64, 12)
    for i in range(4):
        smoke(im, 64 + 8 * i, 24, i)
    for i in range(2):
        bird(im, 96 + 6 * i, 24, i)
    for i in range(3):
        sparkle(im, 108 + 4 * i, 24, i)
    im.save(OUT)
    if "--preview" in args:
        out = args[args.index("--preview") + 1]
        back = Image.new("RGBA", SIZE, (0x3e, 0x89, 0x48, 255))
        back.alpha_composite(im)
        back.resize((SIZE[0] * 6, SIZE[1] * 6), Image.NEAREST).save(out)
    print("world_map_ambience.png %dx%d" % SIZE)


if __name__ == "__main__":
    main(sys.argv[1:])
