"""The Wasted Lands' set pieces (levels 25-36, the humans' worked land; the user, 2026-11-18: "dirt, green and used
natural resources"): felled forest, timber and a quarry among the farms.

Landmarks (32x32, object_tile_set_01 source 14, four blocking 16 px tiles each, placed by tools/level_dressing.py next
to the fields' farm landmarks): a log pile, a quarry pit, a big stump with an axe in it, a sawhorse with a half-sawn
log. Decor (16x16, decor_tile_set source 3, non-blocking, scattered on open ground by tools/level_dressing.py): a
small stump, a cut log, wood chips, sawdust, cart ruts, gravel, a broken plank, a dry tuft, stone chips, a rope coil,
a dirt clod, a felled branch. Light from the top left, no black outlines, the fields' palette (area_landmarks.py).

usage: wasted_lands_art.py <parts dir> <tiles dir>   (then tools/sprite/sprite.py build <spec> <out.aseprite>)"""
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame
from scorched_decor import put, ellipse, seg, mound, landmark_sheet, decor_sheet

TILES = sys.argv[2]

PAL = {'g': '5aa04a', 'G': '3e8948', 'k': '733e39', 'K': '3e2731', 'l': 'b86f50', 'L': 'e4a672', 'f': 'ead4aa',
       'F': 'c28569', 'a': 'c0cbdc', 'b': '8b9bb4', 'c': '5a6988', 'd': '3a4466', 'e': 'e4c08a', 'E': 'd8b07a',
       'y': 'e8b796'}
EARTH = ['e', 'E', 'k']
BARK = ['K', 'k', 'l', 'L']
STONE = ['d', 'c', 'b', 'a']


def log_end(f, cx, cy, r):
    """the cut end of a log: rings of pale wood, a dark heart"""
    ellipse(f, cx, cy, r, r, ['F', 'f', 'f', 'f'])
    put(f, cx, cy, 'F')


def log(f, x0, x1, y, r=2):
    """a log lying left to right, its cut end on the right"""
    for x in range(x0, x1):
        for dy in range(-r, r + 1):
            put(f, x, y + dy, 'L' if dy == -r else 'k' if dy == r else 'l')
    put(f, x0, y + r, 'K')
    log_end(f, x1, y, r)


def log_pile():
    f = Frame(32, 32)
    mound(f, 16, 29, 14, 2, EARTH)
    for y, x0, x1 in ((24, 3, 22), (24, 9, 27), (19, 6, 24), (14, 9, 21)):
        log(f, x0, x1, y)
    put(f, 4, 27, 'L')
    put(f, 27, 28, 'f')
    return f


def quarry_pit():
    f = Frame(32, 32)
    # the pit on the left: a rim of cut stone, the hole stepping down, a ladder into it
    for y in range(4, 24):
        for x in range(1, 22):
            d = ((x - 11) / 9.5) ** 2 + ((y - 13) / 8.5) ** 2
            if d <= 1.0:
                put(f, x, y, 'a' if y > 18 and d > 0.5 else 'b' if y > 13 else 'c')
    for y in range(7, 21):
        for x in range(4, 19):
            d = ((x - 11) / 6.5) ** 2 + ((y - 13) / 5.5) ** 2
            if d <= 1.0:
                put(f, x, y, 'K' if d < 0.35 else 'd')
    for x in (8, 11):  # the ladder
        seg(f, x, 6, x, 17, 'l')
    for y in range(7, 17, 2):
        seg(f, 9, y, 10, y, 'L')
    # squared blocks stacked on the right: lit top, front face, dark joints
    for bx, by in ((18, 23), (24, 23), (21, 18)):
        for y in range(by, by + 5):
            for x in range(bx, bx + 6):
                put(f, x, y, 'a' if y == by else 'd' if x == bx + 5 or y == by + 4 else 'b')
    mound(f, 24, 29, 7, 1, EARTH)
    # a pickaxe on the ground in front of the pit
    seg(f, 3, 28, 13, 23, 'l')
    seg(f, 3, 27, 12, 23, 'L')
    seg(f, 10, 20, 16, 26, 'b')
    put(f, 10, 20, 'a')
    put(f, 11, 21, 'a')
    return f


def big_stump():
    f = Frame(32, 32)
    mound(f, 16, 29, 13, 2, EARTH)
    for x0, y0, x1, y1 in ((8, 24, 3, 28), (24, 24, 29, 28), (16, 26, 16, 29)):  # roots
        seg(f, x0, y0, x1, y1, 'k', 2)
    # a short trunk, lit from the left, with bark ribs
    for x in range(8, 25):
        shade = 'L' if x < 10 else 'l' if x < 15 else 'k' if x < 22 else 'K'
        for y in range(14, 26 - (1 if x in (8, 24) else 0)):
            put(f, x, y, 'k' if x % 3 == 0 and shade in 'Ll' else 'K' if x % 3 == 0 and shade == 'k' else shade)
    for y in range(11, 18):  # the cut face, wide and pale, with its rings
        for x in range(7, 26):
            d = ((x - 16) / 8.5) ** 2 + ((y - 14) / 3.2) ** 2
            if d <= 1.0:
                put(f, x, y, 'F' if d > 0.7 else 'f' if d > 0.35 else 'y' if d > 0.12 else 'F')
    seg(f, 20, 12, 27, 4, 'l')  # an axe left in it
    seg(f, 21, 12, 28, 4, 'k')
    for x, y in ((17, 12), (18, 12), (19, 12), (18, 13), (19, 13), (18, 11)):
        put(f, x, y, 'b')
    put(f, 17, 12, 'a')
    for x, y in ((4, 18), (27, 21), (6, 23), (25, 17)):  # chips
        put(f, x, y, 'L')
    return f


def sawhorse():
    f = Frame(32, 32)
    mound(f, 16, 29, 14, 2, ['f', 'y', 'E'])  # sawdust
    for cx in (8, 23):  # the trestles
        seg(f, cx - 3, 26, cx + 2, 15, 'k')
        seg(f, cx + 3, 26, cx - 2, 15, 'K')
    log(f, 3, 26, 14, 3)
    seg(f, 14, 6, 17, 16, 'b', 2)  # a saw half way through
    seg(f, 13, 5, 15, 3, 'k', 2)
    put(f, 14, 6, 'a')
    return f


DECOR = [
    ('SMALL_STUMP', '''
.FFF.
FfffF
kyfyk
lllkK
.KkK.'''),
    ('CUT_LOG', '''
.LLLLL.F.
Llllll.fF
kkkkkkFfF
.KKKK..F.'''),
    ('WOOD_CHIPS', '''
L...f.
..l..L
f..L..
.l...f'''),
    ('SAWDUST', '''
..ff..
.fyyf.
fyyEEy
.EEEE.'''),
    ('CART_RUTS', '''
E......E...
.E......E..
..EE.....EE
....E......'''),
    ('GRAVEL', '''
.b..a.
cb..bc
...c..
.ab..b'''),
    ('BROKEN_PLANK', '''
LL.....
lllL...
.kllL..
...kkl.
.....k.'''),
    ('DRY_TUFT', '''
e..e..e
.E.e.E.
..EeE..
.kEEEk.'''),
    ('STONE_CHIPS', '''
.a...
abc.a
.cc.b
...bc'''),
    ('ROPE_COIL', '''
.yyy.
yFFFy
yF.Fy
yFFFy
.yyy.'''),
    ('DIRT_CLOD', '''
..EE..
.EeeEk
EEeEkk
.kkkk.'''),
    ('FELLED_BRANCH', '''
G.....g
.k...g.
..kkk..
.g..kk.
G....kg'''),
]


if __name__ == '__main__':
    landmark_sheet(TILES + '/humans/wasted_landmarks.txt', '''
# Source of wasted_landmarks.aseprite and wasted_landmarks.png: the Wasted Lands' 32x32 landmarks (object_tile_set_01
# source 14, four blocking 16 px tiles each): a log pile, a quarry pit, a big stump with an axe in it, a sawhorse with
# a half-sawn log. Drawn by tools/sprite/parts/wasted_lands_art.py.''', PAL,
                   [('LOG_PILE', log_pile), ('QUARRY_PIT', quarry_pit), ('BIG_STUMP', big_stump), ('SAWHORSE', sawhorse)])
    decor_sheet(TILES + '/humans/wasted_decor.txt', '''
# Source of wasted_decor.aseprite and wasted_decor.png: the Wasted Lands' ground decor (decor_tile_set source 3,
# non-blocking), 16x16 each: a small stump, a cut log, wood chips, sawdust, cart ruts, gravel, a broken plank, a dry
# tuft, stone chips, a rope coil, a dirt clod, a felled branch. Drawn by tools/sprite/parts/wasted_lands_art.py.''',
                PAL, DECOR)
    print('ok')
