"""Joined fences for the human lands (the user, 2026-11-18: the fences looked weird). The old fence prop (humans_props,
object_tile_set_01 source 7, tile 1,0) is one piece drawn left to right with its own posts and a gap at each side:
a row of them reads as separate bits and a column as a ladder. This draws a fence set by neighbours instead (16
pieces, 4x4 on fence_tiles.png: the piece for mask m sits at (m % 4, m / 4), mask bits N=1 E=2 S=4 W=8): a post in
the middle and rails out to every side that has fence, so rows, columns and corners join up. A lone fence keeps the
old look. Colours of the old fence (Endesga 32).

    python tools/fence_tiles.py draw                 (writes assets/art/tiles/humans/fence_tiles.png and its .aseprite)
    python tools/fence_tiles.py retile [levels...]   (every fence in the levels gets its joined piece; default 25-36)
    python tools/fence_tiles.py preview <out.png>    (the sheet, scaled, to look at)

The tile set source (object_tile_set_01 source FENCE_SOURCE, every tile TileType Blocking) is added by `draw`; run
tools/area_tiles.py after it so the area copies get it too.
"""
import os
import re
import subprocess
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import level_tiles as lt

ROOT = lt.ROOT
PNG = os.path.join(ROOT, "assets", "art", "tiles", "humans", "fence_tiles.png")
ASEPRITE = os.path.join(ROOT, "assets", "art", "tiles", "humans", "fence_tiles.aseprite")
ASEPRITE_EXE = "C:/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe"
TILE_SET = os.path.join(ROOT, "assets", "tile_sets", "object_tile_set_01.tres")
OLD_FENCE = (7, (1, 0))
FENCE_SOURCE = 15
N, E, S, W = 1, 2, 4, 8
LIGHT, MID, DARK = (0xe4, 0xa6, 0x72, 255), (0xb8, 0x6f, 0x50, 255), (0x73, 0x3e, 0x39, 255)


def piece(mask):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()

    def put(x, y, c):
        if 0 <= x < 16 and 0 <= y < 16:
            px[x, y] = c

    if mask == 0:
        # alone: the old fence, two posts and two rails
        for x in (2, 12):
            for y in range(6, 14):
                put(x, y, LIGHT)
                put(x + 1, y, MID if y > 6 else LIGHT)
            put(x, 14, DARK)
            put(x + 1, 14, DARK)
        for y in (8, 11):
            for x in range(4, 12):
                put(x, y, LIGHT)
                put(x, y + 1, MID)
        return img
    # rails left and right: two bars, lit on top
    for side, xs in ((W, range(0, 7)), (E, range(9, 16))):
        if mask & side:
            for x in xs:
                for y in (8, 11):
                    put(x, y, LIGHT)
                    put(x, y + 1, MID)
    # rails up and down: seen from above, a wide bar lit on its left with its shadow side
    for side, ys in ((N, range(0, 5)), (S, range(13, 16))):
        if mask & side:
            for y in ys:
                put(7, y, LIGHT)
                put(8, y, MID)
    # the post in the middle, a cap on top and its foot in shadow; wider where the fence runs up and down
    x0, x1 = (6, 9) if mask & (N | S) else (7, 8)
    for y in range(4 if mask & (N | S) else 5, 13):
        for x in range(x0, x1 + 1):
            top = y == (4 if mask & (N | S) else 5)
            put(x, y, LIGHT if x == x0 or top else DARK if x == x1 and x1 - x0 > 1 else MID)
    for x in range(x0, x1 + 1):
        put(x, 13, DARK)
    return img


def sheet():
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    for m in range(16):
        img.alpha_composite(piece(m), (m % 4 * 16, m // 4 * 16))
    return img


def add_source():
    text = open(TILE_SET, encoding="utf8").read()
    if "TileSetAtlasSource_fence" in text:
        return
    ids = [int(i) for i in re.findall(r'\[ext_resource [^\]]* id="(\d+)_', text)]
    ext_id = "%d_fence_tiles" % (max(ids) + 1)
    ext = '[ext_resource type="Texture2D" path="res://assets/art/tiles/humans/fence_tiles.png" id="%s"]\n' % ext_id
    last_ext = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
    text = text[:last_ext] + ext + text[last_ext:]
    tiles = "".join("%d:%d/0 = 0\n%d:%d/0/custom_data_0 = 2\n" % (m % 4, m // 4, m % 4, m // 4) for m in range(16))
    sub = '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_fence"]\ntexture = ExtResource("%s")\n%s\n' % (ext_id, tiles)
    i = text.index("[resource]")
    text = text[:i] + sub + text[i:]
    text = re.sub(r'(sources/\d+ = SubResource\("[^"]+"\)\n)(?!sources/)', r'\g<1>sources/%d = SubResource("TileSetAtlasSource_fence")\n' % FENCE_SOURCE, text, count=1)
    open(TILE_SET, "w", encoding="utf8", newline="\n").write(text)


def is_fence(v):
    return v is not None and ((v[0], v[1]) == OLD_FENCE or v[0] == FENCE_SOURCE)


def retile(number):
    level = lt.Level(number)
    front = level.cells("FrontTileMapLayer")
    fences = [k for k, v in front.items() if is_fence(v)]
    for x, y in fences:
        mask = sum(bit for bit, (dx, dy) in ((N, (0, -1)), (E, (1, 0)), (S, (0, 1)), (W, (-1, 0)))
                   if is_fence(front.get((x + dx, y + dy))))
        front[(x, y)] = (FENCE_SOURCE, (mask % 4, mask // 4), 0)
    level.set_cells("FrontTileMapLayer", front)
    level.save()
    print("level %d: %d fences joined" % (number, len(fences)))


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    if argv[1] == "preview":
        sheet().resize((64 * 8, 64 * 8), Image.NEAREST).save(argv[2])
    elif argv[1] == "draw":
        sheet().save(PNG)
        subprocess.run([ASEPRITE_EXE, "-b", PNG, "--save-as", ASEPRITE], check=True)
        add_source()
        print("fence_tiles.png drawn, object_tile_set_01 source %d" % FENCE_SOURCE)
    elif argv[1] == "retile":
        for n in [int(a) for a in argv[2:]] or list(range(25, 37)):
            retile(n)


if __name__ == "__main__":
    main(sys.argv)
