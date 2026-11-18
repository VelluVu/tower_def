"""32x32 landmarks for the swamp (levels 13-24) and the human fields (levels 25-36), like the Scorched Lands' ones
(scorched_decor.py): big set pieces cut into four blocking 16 px tiles (object_tile_set_01 sources 12 and 13), placed
on open ground off the roads by tools/level_dressing.py. Light from the top left, no black outlines.

usage: area_landmarks.py <parts dir> <tiles dir>   (then tools/sprite/sprite.py build <spec> <out.aseprite>)"""
import math
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame
from scorched_decor import put, ellipse, seg, mound, landmark_sheet

TILES = sys.argv[2]

# ======================= swamp =======================
SWAMP_PAL = {'m': '2f6b3d', 'M': '4a8a45', 'n': '7cbf4a', 'k': '3e2731', 'K': '733e39', 'l': 'b86f50',
             'd': '45472a', 'D': '56602f', 'u': '68386c', 'U': 'b55088', 'w': 'c0cbdc', 'W': 'e0c070', 'v': '8b9bb4',
             't': '1f5048', 'T': '2d7356', 'y': 'f2e3a0'}
MUD = ['D', 'd', 'd']


def fallen_log():
    f = Frame(32, 32)
    # the trunk lies across, its broken end towards us as rings
    for x in range(3, 27):
        for y in range(15, 23):
            put(f, x, y, 'l' if y == 15 else 'K' if y < 21 else 'k')
        if x % 5 == 0:
            seg(f, x, 16, x + 1, 20, 'k')  # bark furrows
    ellipse(f, 27, 19, 3, 4, ['k', 'K', 'l', 'W'])
    put(f, 27, 19, 'K')
    for x in range(4, 25):
        if (x * 7) % 5:
            put(f, x, 14, 'M' if x % 3 else 'n')  # moss on top
            if x % 4 == 0:
                put(f, x, 13, 'm')
    for (x, y) in ((9, 13), (16, 13), (21, 13)):  # little fungi on the moss
        put(f, x, y - 1, 'U')
        put(f, x + 1, y - 1, 'u')
        put(f, x, y, 'y')
    seg(f, 10, 22, 6, 26, 'k')  # a broken branch into the mud
    mound(f, 16, 29, 15, 4, MUD)
    return f


def giant_mushrooms():
    f = Frame(32, 32)
    for cx, top, r, stem in ((11, 8, 8, 14), (22, 14, 6, 10), (6, 19, 4, 7)):
        for y in range(top + 3, top + 3 + stem):
            for x in range(cx - 1, cx + 2):
                put(f, x, y, 'y' if x < cx + 1 else 'W')
        ellipse(f, cx, top + 2, r, max(2, r // 2 + 1), ['u', 'u', 'U', 'U'])
        for k in range(3):  # pale spots on the cap
            put(f, cx - r // 2 + k * (r // 2), top + 1 + (k % 2), 'w')
    mound(f, 16, 29, 15, 4, MUD)
    return f


def stilt_hut():
    f = Frame(32, 32)
    for x in (9, 15, 21):  # stilts into the mud
        seg(f, x, 18, x, 27, 'k')
    for y in range(10, 19):  # the hut: plank walls, a dark door
        for x in range(8, 24):
            put(f, x, y, 'l' if x == 8 else 'K' if x % 3 else 'k')
    for y in range(13, 19):
        for x in range(14, 17):
            put(f, x, y, 'k' if y > 13 else 'K')
    for y in range(3, 11):  # a thatched roof, moss on it
        half = (y - 3) + 2
        for x in range(16 - half, 16 + half + 1):
            put(f, x, y, 'n' if x < 16 - half + 2 else 'M' if (x + y) % 3 else 'm')
    seg(f, 6, 18, 25, 18, 'k')  # the porch
    mound(f, 16, 29, 15, 3, MUD)
    return f


def sunken_boat():
    f = Frame(32, 32)
    # a hull tilted into the bog, ribs showing on the near side, reeds around
    for x in range(4, 28):
        top = round(16 + (x - 4) * 0.35)
        bottom = round(21 + (x - 4) * 0.15)
        for y in range(top, bottom + 1):
            put(f, x, y, 'l' if y == top else 'K' if y < bottom else 'k')
    for x in range(8, 26, 4):
        seg(f, x, 15 + (x - 4) // 3, x - 1, 10 + (x - 4) // 3, 'K')  # ribs
    seg(f, 14, 14, 14, 4, 'k')  # the mast stump
    seg(f, 15, 8, 20, 9, 'w')  # a torn sail rag
    for x in (3, 6, 26, 29):  # reeds
        seg(f, x, 27, x, 20, 'M')
        put(f, x, 19, 'K')
    for x in range(5, 28):  # murky water line
        put(f, x, 24, 't' if x % 2 else 'T')
    mound(f, 16, 29, 15, 3, MUD)
    return f


# ======================= human fields =======================
FIELDS_PAL = {'g': '5aa04a', 'G': '3e8948', 'h': 'fee761', 'H': 'feae34', 'k': '733e39', 'K': '3e2731', 'l': 'b86f50',
              'a': 'c0cbdc', 'b': '8b9bb4', 'c': '5a6988', 'r': 'a22633', 'R': 'e43b44', 'o': 'f77622', 'e': 'e4c08a',
              'E': 'd8b07a', 'w': 'ffffff', 'n': '124e89'}
EARTH = ['e', 'E', 'k']


def stone_well():
    f = Frame(32, 32)
    for x in (8, 23):  # posts and a little roof
        seg(f, x, 6, x, 18, 'k')
    for y in range(3, 7):
        for x in range(6 - (6 - y), 26 + (6 - y)):
            put(f, x, y, 'R' if y == 3 else 'r')
    seg(f, 9, 9, 22, 9, 'K')  # the windlass, a bucket on its rope
    seg(f, 16, 10, 16, 13, 'b')
    for (x, y) in ((15, 14), (16, 14), (17, 14), (15, 15), (16, 15), (17, 15)):
        put(f, x, y, 'l')
    ellipse(f, 16, 22, 10, 6, ['c', 'b', 'a', 'a'])  # the stone ring
    ellipse(f, 16, 19, 7, 2, ['K', 'K', 'n', 'n'])  # dark water inside
    for x in range(6, 27, 3):
        put(f, x, 22, 'c')  # stone joints
    mound(f, 16, 29, 14, 2, EARTH)
    return f


def hay_wagon():
    f = Frame(32, 32)
    ellipse(f, 15, 12, 11, 7, ['H', 'H', 'h', 'h'])  # the hay load
    for x in range(6, 25, 3):
        seg(f, x, 8, x + 1, 14, 'H')  # straw lines
    for y in range(17, 21):  # the wagon bed
        for x in range(3, 28):
            put(f, x, y, 'l' if y == 17 else 'k')
    seg(f, 27, 18, 30, 15, 'k')  # the shaft
    for cx in (8, 22):  # wheels with spokes
        for a in range(16):
            ang = a / 16 * 2 * math.pi
            put(f, round(cx + 4 * math.cos(ang)), round(23 + 4 * math.sin(ang)), 'K' if a > 7 else 'k')
        seg(f, cx - 3, 23, cx + 3, 23, 'k')
        seg(f, cx, 20, cx, 26, 'k')
    return f


def scarecrow():
    f = Frame(32, 32)
    seg(f, 16, 8, 16, 27, 'k')  # the pole and the crossbar
    seg(f, 7, 12, 25, 12, 'k')
    for y in range(11, 20):  # a patched coat
        for x in range(12, 21):
            put(f, x, y, 'n' if x < 17 else 'c')
    put(f, 14, 15, 'r')
    put(f, 18, 17, 'H')
    for x in (7, 8, 24, 25):  # straw hands
        put(f, x, 13, 'h')
    ellipse(f, 16, 7, 3, 3, ['E', 'e', 'e', 'w'])  # a sack head and a straw hat
    put(f, 15, 7, 'K')
    put(f, 17, 7, 'K')
    seg(f, 11, 4, 21, 4, 'H')
    for y in (2, 3):
        seg(f, 13, y, 19, y, 'h')
    for cx, cy in ((6, 25), (25, 26), (20, 27)):  # pumpkins
        ellipse(f, cx, cy, 3, 2, ['r', 'o', 'o', 'H'])
        put(f, cx, cy - 2, 'G')
    mound(f, 16, 29, 15, 2, EARTH)
    return f


def shed():
    f = Frame(32, 32)
    for y in range(13, 27):  # plank walls, a door with a cross brace
        for x in range(6, 26):
            put(f, x, y, 'l' if x == 6 else 'k' if x % 4 == 0 else 'l' if x < 12 else 'K' if x > 23 else 'k' if y % 5 == 0 else 'l')
    for y in range(17, 27):
        for x in range(13, 19):
            put(f, x, y, 'K')
    seg(f, 13, 17, 18, 26, 'k')
    seg(f, 13, 26, 18, 17, 'k')
    for y in range(4, 14):  # a red roof
        half = (y - 4) + 3
        for x in range(16 - half, 16 + half + 1):
            put(f, x, y, 'R' if x < 16 else 'r')
    seg(f, 16 - 12, 13, 16 + 12, 13, 'K')
    mound(f, 16, 29, 14, 2, EARTH)
    return f


if __name__ == '__main__':
    landmark_sheet(TILES + '/swamp/swamp_landmarks.txt', '''
# Source of swamp_landmarks.aseprite and swamp_landmarks.png: the swamp's 32x32 landmarks (object_tile_set_01 source
# 12, four blocking 16 px tiles each): a fallen mossy log with fungi, a cluster of giant mushrooms, a hut on stilts, a
# boat sunk in the bog. Drawn by tools/sprite/parts/area_landmarks.py.''', SWAMP_PAL,
                   [('FALLEN_LOG', fallen_log), ('GIANT_MUSHROOMS', giant_mushrooms), ('STILT_HUT', stilt_hut),
                    ('SUNKEN_BOAT', sunken_boat)])
    landmark_sheet(TILES + '/humans/fields_landmarks.txt', '''
# Source of fields_landmarks.aseprite and fields_landmarks.png: the human fields' 32x32 landmarks (object_tile_set_01
# source 13, four blocking 16 px tiles each): a stone well, a hay wagon, a scarecrow among pumpkins, a red-roofed shed.
# Drawn by tools/sprite/parts/area_landmarks.py.''', FIELDS_PAL,
                   [('STONE_WELL', stone_well), ('HAY_WAGON', hay_wagon), ('SCARECROW', scarecrow), ('SHED', shed)])
    print('ok')
