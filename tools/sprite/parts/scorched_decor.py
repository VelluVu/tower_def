"""Ground decor and landmarks for the Scorched Lands (levels 37-48), so the open sand and ash are not bare.

Decor (16x16, one tag each, non-blocking; decor_tile_set sources 1 and 2): small things lying on the ground, drawn to
sit in the middle of a cell. Landmarks (32x32, one tag each; object_tile_set_01 sources 10 and 11, cut into four
16 px blocking tiles): big set pieces that fill 2x2 cells. Light from the top left, no black outlines, Endesga-led
colours that match the area's ground and props.

usage: scorched_decor.py <parts dir> <tiles dir>   (tiles dir = assets/art/tiles; then build each spec with
tools/sprite/sprite.py build <spec> <out.aseprite>)"""
import math
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, part, write_spec

TILES = sys.argv[2]


def centred(art, size):
    """an ASCII part centred in a size x size frame"""
    f = Frame(size, size)
    p = part(art)
    w = max(x for x, _, _ in p) + 1
    h = max(y for _, y, _ in p) + 1
    f.stamp(p, (size - w) // 2, (size - h) // 2)
    return f


def decor_sheet(path, header, pal, pieces):
    write_spec(path, header, pal, (16, 16), [(name, 100, [centred(art, 16)]) for name, art in pieces])


# ======================= desert decor =======================
DESERT_PAL = {'a': 'f0dcaa', 'b': 'c4a06c', 'B': 'a8825a', 'w': 'ece6d8', 'W': 'c8bfae', 'v': '9a8f80', 'x': '5e5448',
              'r': '9a4a2a', 'R': 'be6a3a', 'k': '733e39', 'K': '3e2731', 'g': 'feae34', 'G': 'f77622', 'y': 'fee761',
              'd': '8a6a4a', 'D': '6a4a30', 'i': 'c0cbdc', 'I': '8b9bb4'}
DESERT_DECOR = [
    ('PEBBLES', '''
..bB....
.bBBB..b
..BB..bB
.....bBB'''),
    ('BONE_SHARD', '''
.ww....
wWWw...
.vWWw..
..vvWw.
....vv.'''),
    ('SMALL_SKULL', '''
.www.
wxWxw
wWWWv
.vWv.
.v.v.'''),
    ('DRY_TUFT', '''
d..d..d
.d.d.d.
..dDd..
.DDDDD.'''),
    ('RIPPLES', '''
.aaaa......
aBBBBa.....
.......aaa.
......aBBBa'''),
    ('BROKEN_ARROW', '''
.......k
......k.
.....k..
..i.k...
.iik....
..I.....'''),
    ('RUSTY_HELMET', '''
..rRr..
.rRRRr.
rRRRRRr
rKKKKKr
.krrrk.'''),
    ('OLD_COINS', '''
.gy...
gyyG..
.GG.gy
....GG'''),
    ('CRACKS', '''
B.....B
.B...B.
..BBB..
..B....
.B.....'''),
    ('DEAD_SHRUB', '''
D.D.D.D
.DD.DD.
..DDD..
...D...
..DDD..'''),
    ('SWORD_IN_SAND', '''
..i..
..iI.
.giIg
..iI.
..iI.
bbIbb'''),
    ('ASH_PATCH', '''
.vv.v.
vvxvvv
.vvxv.
..vv..'''),
]

# ======================= volcano decor =======================
VOLCANO_PAL = {'a': '7a6872', 'b': '54444e', 'c': '2a2028', 'd': '181425', 'r': 'e43b44', 'R': 'a22633', 'o': 'f77622',
               'y': 'fee761', 'S': 'feae34', 'p': '3a4466', 'q': '8b9bb4', 'P': '262b44', 'w': 'c0cbdc', 'W': '8b9bb4'}
VOLCANO_DECOR = [
    ('EMBER_CRACK', '''
o......
RoR....
..RoR..
....Roo'''),
    ('ASH_PILE', '''
..aa..
.aaab.
aabbbb'''),
    ('OBSIDIAN_CHIP', '''
..p.
.pqp
ppPP'''),
    ('PEBBLES', '''
.bb...
bbab.b
....bb'''),
    ('SMALL_SKULL', '''
.www.
wdWdw
wWWWW
.WWW.'''),
    ('CHARRED_BONES', '''
ww....
.Wcc..
..ccW.
...cww'''),
    ('SULFUR', '''
..y.
.ySy
ySSy
.SS.'''),
    ('GLOWING_PEBBLE', '''
.RoR.
Royor
.oRR.'''),
    ('LAVA_STAIN', '''
.RR..
RrrR.
.RRrR
...R.'''),
    ('CINDERS', '''
o..R.
.R.o.
o...o'''),
    ('BURNT_GRASS', '''
c.c.c
.c.c.
cc.cc'''),
    ('STEAM_HOLE', '''
.ww.
..ww
.bb.
bddb
.bb.'''),
]


# ======================= landmarks (32x32) =======================
def put(f, x, y, ch):
    if 1 <= x <= f.w - 2 and 1 <= y <= f.h - 2:
        f.px[(x, y)] = ch


def ellipse(f, cx, cy, rx, ry, ramp, light=(-0.5, -0.7)):
    """filled, shaded from the top left: ramp dark to light"""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            d = nx * nx + ny * ny
            if d <= 1.0:
                lit = -(nx * light[0] + ny * light[1])
                v = 0.5 + lit * 0.55 - (0.25 if d > 0.75 else 0)
                put(f, x, y, ramp[max(0, min(len(ramp) - 1, int(v * len(ramp))))])


def seg(f, x0, y0, x1, y1, ch, width=1):
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for s in range(steps + 1):
        x, y = round(x0 + (x1 - x0) * s / steps), round(y0 + (y1 - y0) * s / steps)
        for o in range(width):
            put(f, x + o, y, ch)


def mound(f, cx, base, half, height, ramp):
    """a low heap of sand or ash the landmark sinks into"""
    for x in range(cx - half, cx + half + 1):
        top = base - round(height * (1 - ((x - cx) / (half + 0.5)) ** 2))
        for y in range(top, base + 1):
            put(f, x, y, ramp[0] if y == top and x < cx else ramp[1] if y == top else ramp[2])


SAND = ['a', 'b', 'B']
BONE = ['x', 'v', 'W', 'w']


def dragon_skull():
    f = Frame(32, 32)
    # horns sweeping back
    seg(f, 9, 12, 4, 6, 'W', 2)
    seg(f, 4, 6, 2, 3, 'v', 2)
    seg(f, 13, 10, 10, 3, 'w', 2)
    seg(f, 10, 3, 8, 2, 'W', 1)
    ellipse(f, 12, 17, 8, 7, BONE)
    # the long snout
    for x in range(17, 30):
        t = (x - 17) / 12
        top, bottom = round(14 + t * 3), round(22 - t * 2)
        for y in range(top, bottom + 1):
            put(f, x, y, 'w' if y == top else 'W' if y < bottom - 1 else 'v')
    # eye socket, nostril, a crack
    for (x, y) in ((11, 14), (12, 14), (10, 15), (11, 15), (12, 15), (13, 15), (11, 16), (12, 16)):
        put(f, x, y, 'x')
    put(f, 27, 16, 'x')
    put(f, 28, 16, 'x')
    seg(f, 6, 18, 9, 21, 'v')
    # teeth along the jaw
    for x in range(18, 29, 2):
        put(f, x, 23 - (x - 17) // 6, 'w')
    mound(f, 16, 29, 15, 5, SAND)
    return f


def rib_arch():
    f = Frame(32, 32)
    # the spine along the top, ribs curving down into the sand: each rib a joined curve, lit on its outer side
    seg(f, 3, 7, 28, 5, 'W', 1)
    seg(f, 3, 6, 28, 4, 'w', 1)
    for k, x0 in enumerate((5, 11, 17, 23)):
        points = []
        for t in range(9):
            ang = t / 8 * math.pi * 0.5
            points.append((round(x0 + 5 * math.sin(ang)), round(6 - k * 0.4 + 19 * (1 - math.cos(ang)) + t * 0.4)))
        for (xa, ya), (xb, yb) in zip(points, points[1:]):
            seg(f, xa, ya, xb, yb, 'w')
            seg(f, xa + 1, ya, xb + 1, yb, 'v')
    mound(f, 16, 29, 15, 4, SAND)
    return f


def statue_head():
    f = Frame(32, 32)
    stone = ['B', 'b', 'a']
    # a carved dragon head, broken off at the neck, leaning in the sand
    for y in range(8, 25):
        for x in range(6, 26):
            inside = (x - 6) + (y - 8) * 0.4 < 22 and y > 8 + max(0, 12 - x) * 0.6
            if inside:
                put(f, x, y, stone[2] if (x + y) < 22 else stone[1] if x < 20 else stone[0])
    seg(f, 8, 8, 4, 3, 'b', 2)  # stone horn
    seg(f, 13, 8, 12, 2, 'a', 2)
    for (x, y) in ((12, 13), (13, 13), (12, 14), (13, 14), (14, 14)):
        put(f, x, y, 'K')  # carved eye
    put(f, 13, 13, 'g')  # a gold inlay left in it
    seg(f, 18, 18, 25, 20, 'B')  # carved mouth line
    seg(f, 9, 21, 13, 17, 'B')  # a crack
    seg(f, 20, 10, 23, 14, 'B')
    mound(f, 16, 29, 14, 5, SAND)
    return f


def siege_wreck():
    f = Frame(32, 32)
    wood = ['K', 'k', 'd']
    # broken uprights and cross beams of a siege tower, a wheel on its side
    for (x0, y0, x1, y1) in ((6, 26, 10, 6), (14, 26, 12, 9), (22, 26, 26, 11), (5, 12, 27, 14), (6, 19, 25, 21)):
        seg(f, x0, y0, x1, y1, wood[1], 2)
        seg(f, x0, y0 - 1, x1, y1 - 1, wood[2], 1)
    for a in range(16):
        ang = a / 16 * 2 * math.pi
        put(f, round(23 + 4 * math.cos(ang)), round(23 + 2 * math.sin(ang)), 'r' if a > 8 else 'R')
    put(f, 23, 23, 'K')
    seg(f, 10, 6, 20, 16, 'D')  # a dangling rope
    mound(f, 16, 29, 15, 3, SAND)
    return f


OBSIDIAN = ['P', 'p', 'q']
BASALT = ['c', 'b', 'a']
ASH = ['a', 'b', 'c']


def shard(f, base_x, base_y, tip_x, tip_y, half):
    """a faceted glass shard from a base width to a tip: lit left face, dark right face, a glint on the ridge"""
    steps = max(abs(tip_y - base_y), 1)
    for s_ in range(steps + 1):
        t = s_ / steps
        cx = base_x + (tip_x - base_x) * t
        y = round(base_y + (tip_y - base_y) * t)
        w = max(0, round(half * (1 - t)))
        for x in range(round(cx) - w, round(cx) + w + 1):
            put(f, x, y, 'q' if x == round(cx) and s_ % 3 else OBSIDIAN[1] if x < cx else OBSIDIAN[0])


def obsidian_spire():
    f = Frame(32, 32)
    shard(f, 21, 27, 25, 13, 3)
    shard(f, 15, 27, 13, 3, 5)
    shard(f, 9, 27, 5, 15, 3)
    shard(f, 18, 27, 20, 19, 2)
    for x in (8, 12, 17, 22):
        put(f, x, 27, 'o')  # embers at its foot
    mound(f, 15, 29, 14, 2, ASH)
    return f


def cultist_shrine():
    f = Frame(32, 32)
    # two banner poles with red cloth
    for px_ in (4, 27):
        seg(f, px_, 6, px_, 25, 'c')
        for y in range(7, 15):
            for x in range(px_ + 1, px_ + 4) if px_ < 16 else range(px_ - 3, px_):
                put(f, x, y, 'R' if y < 14 or x % 2 else 'R')
        put(f, px_ + (2 if px_ < 16 else -2), 10, 'o')
    # steps and the altar
    for y, (x0, x1) in ((26, (6, 25)), (25, (7, 24)), (24, (8, 23))):
        for x in range(x0, x1 + 1):
            put(f, x, y, BASALT[0] if y == 26 else BASALT[1])
    for y in range(17, 24):
        for x in range(10, 22):
            put(f, x, y, BASALT[2] if y == 17 or x == 10 else BASALT[1] if x < 20 else BASALT[0])
    # the fire bowl and its flames
    for x in range(12, 20):
        put(f, x, 16, 'b')
    for (x, y, ch) in ((13, 15, 'R'), (14, 15, 'r'), (15, 15, 'o'), (16, 15, 'o'), (17, 15, 'r'), (18, 15, 'R'),
                       (14, 14, 'o'), (15, 14, 'y'), (16, 14, 'y'), (17, 14, 'o'), (15, 13, 'o'), (16, 13, 'y'),
                       (16, 12, 'o'), (15, 11, 'y')):
        put(f, x, y, ch)
    return f


def lava_cone():
    f = Frame(32, 32)
    for y in range(9, 28):
        half = round(4 + (y - 9) / 18 * 11)
        for x in range(16 - half, 16 + half + 1):
            put(f, x, y, BASALT[2] if x < 16 - half + 3 else BASALT[1] if x < 16 else BASALT[0])
    for x in range(13, 20):
        put(f, x, 9, 'o' if 14 <= x <= 18 else 'R')
        put(f, x, 10, 'y' if 15 <= x <= 17 else 'o')
    # lava trickling down two sides
    seg(f, 14, 11, 11, 20, 'r')
    seg(f, 18, 11, 21, 24, 'r')
    seg(f, 18, 11, 20, 18, 'o')
    put(f, 16, 7, 'q')
    put(f, 17, 6, 'q')
    return f


def basalt_cluster():
    f = Frame(32, 32)
    for x0, top, w in ((5, 14, 4), (9, 8, 5), (14, 4, 5), (19, 10, 4), (23, 16, 4), (12, 18, 4)):
        for x in range(x0, x0 + w):
            for y in range(top, 28):
                put(f, x, y, BASALT[2] if y == top else BASALT[1] if x < x0 + w - 1 else BASALT[0])
            put(f, x, top, 'a')
    for x in (8, 18, 26):
        put(f, x, 27, 'o')
    mound(f, 16, 29, 14, 2, ASH)
    return f


def landmark_sheet(path, header, pal, pieces):
    write_spec(path, header, pal, (32, 32), [(name, 100, [draw()]) for name, draw in pieces])


if __name__ == '__main__':
    decor_sheet(TILES + '/desert/desert_decor.txt', '''
    # Source of desert_decor.aseprite and desert_decor.png: the ash desert's ground decor (levels 37-42, decor_tile_set
    # source 1, non-blocking), 16x16 each: pebbles, a bone shard, a small skull, a dry tuft, sand ripples, a broken arrow,
    # a rusted helmet, old-war coins, cracks, a dead shrub, a sword in the sand, ash. Drawn by
    # tools/sprite/parts/scorched_decor.py.''', DESERT_PAL, DESERT_DECOR)
    decor_sheet(TILES + '/volcano/volcano_decor.txt', '''
    # Source of volcano_decor.aseprite and volcano_decor.png: the volcano's ground decor (levels 43-48, decor_tile_set
    # source 2, non-blocking), 16x16 each: an ember crack, an ash pile, an obsidian chip, pebbles, a small skull, charred
    # bones, sulfur, a glowing pebble, a lava stain, cinders, burnt grass, a steam hole. Drawn by
    # tools/sprite/parts/scorched_decor.py.''', VOLCANO_PAL, VOLCANO_DECOR)
    landmark_sheet(TILES + '/desert/desert_landmarks.txt', '''
    # Source of desert_landmarks.aseprite and desert_landmarks.png: the ash desert's 32x32 landmarks (object_tile_set_01
    # source 10, cut into four blocking 16 px tiles): a dragon skull half in the sand, a rib arch, a broken dragon
    # statue's head, a wrecked siege tower. Drawn by tools/sprite/parts/scorched_decor.py.''', DESERT_PAL,
                   [('DRAGON_SKULL', dragon_skull), ('RIB_ARCH', rib_arch), ('STATUE_HEAD', statue_head),
                    ('SIEGE_WRECK', siege_wreck)])
    landmark_sheet(TILES + '/volcano/volcano_landmarks.txt', '''
    # Source of volcano_landmarks.aseprite and volcano_landmarks.png: the volcano's 32x32 landmarks (object_tile_set_01
    # source 11, four blocking 16 px tiles each): an obsidian spire, a cultist shrine with banners and a fire bowl, a lava
    # cone, a cluster of basalt columns. Drawn by tools/sprite/parts/scorched_decor.py.''', VOLCANO_PAL,
                   [('OBSIDIAN_SPIRE', obsidian_spire), ('CULTIST_SHRINE', cultist_shrine), ('LAVA_CONE', lava_cone),
                    ('BASALT_CLUSTER', basalt_cluster)])
    print('ok')
