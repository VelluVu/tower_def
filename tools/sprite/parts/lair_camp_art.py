"""Dragonslayer's Camp lair art (2026-11-26, level 36, the Dragonslayer's lair; concept in the design doc's Boss lairs):
the humans' war camp at a blood-red dusk round the drakelings' last keep. 32x32 landmarks on the map (a dragon trophy
pole, the forge sharpening dragonbane spears, an empty egg cage, a dragon-headed training dummy, a supply wagon, a
weapon rack), the camp past the map's edge (tents, palisade stakes, a watchtower, a trebuchet, campfires, banners),
the 48x48 command tent (a spawn point's art: IDLE its banner flying, BOIL its flaps thrown open when he comes) and the
castle under siege (64x64 over the 48x48 castle, offset 8: IDLE the ram battering the gate, REVEAL the drakelings
shoving the ladders off). Light from the top left, no black outlines, Endesga 32. The dusk itself is the level's
LairLighting.

usage: lair_camp_art.py <parts dir> <tiles dir>   (then tools/sprite/sprite.py build <spec> <out.aseprite>)"""
import math
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, write_spec
from scorched_decor import put, ellipse, seg, mound
import lair_art
from lair_art import _rand, write_sprite_frames

TILES = sys.argv[2]

CAMP_PAL = {
    'H': '181425', 'k': '3e2731', 'l': '733e39', 'L': 'b86f50',  # dark, timber
    'c': 'c28569', 'C': 'e4a672', 'U': 'ead4aa', 'B': 'e8b796',  # canvas, bone
    'r': 'a22633', 'R': 'e43b44', 'o': 'f77622', 'O': 'feae34', 'Y': 'fee761', 'z': 'ffffff',  # red, flame, gold
    'i': '262b44', 'I': '3a4466', 'j': '5a6988', 'J': '8b9bb4', 'w': 'c0cbdc',  # iron, stone
    'm': '193c3e', 'M': '265c42', 'n': '3e8948', 'N': '63c74d',  # dragon green
    'e': '0099db', 'E': '2ce8f5',  # an egg's shell
}
STONE = ['I', 'j', 'J']
CANVAS = ['c', 'C', 'U']
STRAW = ['c', 'C', 'O']
GREEN = ['M', 'n', 'N']
BONE = ['c', 'B', 'U']


def post(f, x, top, base, ch='l'):
    """a timber post lit from the left"""
    for y in range(top, base + 1):
        put(f, x, y, 'L')
        put(f, x + 1, y, ch)
        put(f, x + 2, y, 'k')


def stake(f, x, base, height, key):
    """a sharpened stake: a 3 px log with a pointed top"""
    top = base - height
    for y in range(top + 2, base + 1):
        put(f, x, y, 'L')
        put(f, x + 1, y, 'l')
        put(f, x + 2, y, 'k')
    put(f, x + 1, top, 'U')
    put(f, x, top + 1, 'C')
    put(f, x + 1, top + 1, 'L')
    put(f, x + 2, top + 1, 'l')
    if _rand('knot', key, x) < 0.4:
        put(f, x + 1, base - height // 2, 'k')


def arrow(f, x, y, dx, dy):
    """an arrow stuck in something, pointing into it along (dx, dy): shaft and a red-and-white fletching"""
    seg(f, x, y, x - dx * 3, y - dy * 3, 'l')
    put(f, x - dx * 4, y - dy * 4, 'U')
    put(f, x - dx * 4 + dy, y - dy * 4 + dx, 'R')


def dragon_skull_head(f, cx, cy, facing=1):
    """a dragon's skull, snout to one side, horns sweeping back"""
    ellipse(f, cx, cy, 4, 3.2, BONE)
    for k in range(6):
        x = cx + facing * (3 + k)
        put(f, x, cy - 1, 'U' if k < 4 else 'B')
        put(f, x, cy, 'B')
        put(f, x, cy + 1, 'c')
        if k % 2 == 0:
            put(f, x, cy + 2, 'U')  # teeth
    put(f, cx + facing * 8, cy - 2, 'c')  # nostril ridge
    put(f, cx, cy - 1, 'H')
    put(f, cx + facing, cy - 1, 'k')  # the eye socket
    put(f, cx + facing * 5, cy, 'k')
    seg(f, cx - facing * 2, cy - 3, cx - facing * 6, cy - 7, 'B')
    seg(f, cx - facing * 1, cy - 3, cx - facing * 5, cy - 6, 'U')
    seg(f, cx - facing * 3, cy - 1, cx - facing * 7, cy - 3, 'c')


def trophy_pole():
    f = Frame(32, 32)
    mound(f, 16, 29, 7, 2, STONE)
    post(f, 15, 9, 28)
    for x in range(8, 25):
        put(f, x, 13, 'L' if x < 16 else 'l')
        put(f, x, 14, 'k')
    dragon_skull_head(f, 15, 7, 1)
    # a tattered dragon hide on the left arm, a red pennant on the right
    for y in range(15, 23):
        width = 5 if y < 20 else 4 - (y - 20)
        for x in range(9, 9 + width):
            ch = 'N' if x == 9 else 'n' if y < 19 else 'M'
            if _rand('tear', x, y) < 0.12 and y > 18:
                continue
            put(f, x, y, ch)
        if y in (16, 19):
            put(f, 10, y, 'm')  # scale rows
            put(f, 12, y, 'm')
    for y in range(15, 21):
        for x in range(19, 23 - max(0, y - 18)):
            put(f, x, y, 'R' if x == 19 else 'r')
    put(f, 20, 17, 'O')  # the humans' gold sun on the pennant
    # small bones on strings
    seg(f, 24, 14, 24, 18, 'c')
    put(f, 24, 19, 'B')
    put(f, 23, 19, 'U')
    return f


def forge():
    f = Frame(32, 32)
    # the stone forge with its hood
    for y in range(14, 29):
        for x in range(3, 18):
            ch = 'J' if y == 14 or x == 3 else 'j' if x < 15 else 'I'
            if (x + (y // 3) * 2) % 6 == 0 and y > 14:
                ch = 'I'
            put(f, x, y, ch)
    for y in range(6, 14):
        half = 3 + (y - 6) // 3
        for x in range(10 - half, 11 + half):
            put(f, x, y, 'J' if x == 10 - half else 'j' if x < 11 + half - 1 else 'I')
    for x in range(8, 13):
        put(f, x, 5, 'I')
    # the glowing mouth and coals
    for y in range(19, 27):
        for x in range(6, 15):
            d = abs(x - 10) + abs(y - 24) * 0.8
            put(f, x, y, 'Y' if d < 2 else 'O' if d < 3.5 else 'o' if d < 5 else 'r')
    for x in range(6, 15, 2):
        put(f, x, 26, 'H')
    # the anvil
    for x in range(19, 29):
        put(f, x, 21, 'J' if x < 26 else 'j')
        put(f, x, 22, 'I')
    put(f, 29, 21, 'j')
    put(f, 30, 21, 'I')  # the horn
    for y in range(23, 28):
        for x in range(22, 26):
            put(f, x, y, 'I' if x > 22 else 'j')
    for x in range(20, 28):
        put(f, x, 28, 'i')
    # dragonbane spears leaning on the hood: long shafts with barbed tips
    for (x0, y0, x1, y1) in ((17, 27, 22, 4), (19, 27, 25, 6)):
        seg(f, x0, y0, x1, y1, 'l')
        put(f, x1, y1 - 1, 'w')
        put(f, x1, y1 - 2, 'J')
        put(f, x1 - 1, y1, 'J')
        put(f, x1 + 1, y1, 'J')  # the barbs
    put(f, 24, 20, 'O')  # a spark off the anvil
    return f


def egg_cage():
    f = Frame(32, 32)
    for y in range(24, 29):
        for x in range(6, 26):
            put(f, x, y, STRAW[min(2, int(_rand('straw', x, y) * 3))])
    # a broken shell on the straw
    ellipse(f, 15, 23, 3.4, 2.6, ['e', 'E', 'E'])
    for (x, y) in ((14, 21), (15, 21), (16, 22), (13, 22)):
        put(f, x, y, 'C')  # the inside of the shell
    put(f, 20, 25, 'E')
    put(f, 21, 26, 'e')
    put(f, 10, 26, 'E')
    # the bars, the frame, a ring and chain on top
    for x in range(6, 26, 3):
        seg(f, x, 8, x, 28, 'J' if x < 16 else 'j')
    for x in range(6, 26):
        put(f, x, 7, 'J')
        put(f, x, 8, 'I')
        put(f, x, 28, 'i')
    seg(f, 15, 3, 15, 6, 'j')
    put(f, 15, 2, 'J')
    # the door hanging open on the right
    seg(f, 25, 9, 29, 12, 'J')
    seg(f, 25, 27, 29, 25, 'j')
    for x in (27, 29):
        seg(f, x, 11 + (x - 27), x, 25 - (x - 27), 'j')
    return f


def dragon_dummy():
    f = Frame(32, 32)
    seg(f, 10, 29, 22, 29, 'k')
    seg(f, 12, 28, 20, 28, 'l')
    post(f, 15, 12, 28)
    for x in range(8, 24):
        put(f, x, 15, 'L' if x < 16 else 'l')
    ellipse(f, 16, 21, 5, 5.5, STRAW)
    for x in range(12, 21):
        put(f, x, 19, 'l')
        put(f, x, 23, 'l')  # rope bands
    # the carved dragon head, painted green, a red eye
    ellipse(f, 15, 9, 4.5, 3.2, GREEN)
    for k in range(5):
        put(f, 19 + k, 9, 'n')
        put(f, 19 + k, 10, 'M')
    put(f, 24, 9, 'N')
    put(f, 15, 8, 'R')
    seg(f, 12, 6, 9, 3, 'B')
    seg(f, 14, 6, 13, 2, 'U')
    # arrows in the straw and the head
    arrow(f, 18, 20, 1, 0)
    arrow(f, 13, 24, -1, 0)
    arrow(f, 17, 10, 0, 1)
    return f


def supply_wagon():
    f = Frame(32, 32)
    # the bed and the shaft
    for x in range(5, 27):
        put(f, x, 19, 'L')
        put(f, x, 20, 'l')
        put(f, x, 21, 'k')
    seg(f, 1, 22, 5, 21, 'l')
    # the arched canvas cover with its ribs
    for x in range(6, 26):
        top = 9 + round(2 * ((x - 15.5) / 10) ** 2)
        for y in range(top, 19):
            ch = 'U' if y < top + 2 else 'C' if y < 16 else 'c'
            if (x - 6) % 6 == 0:
                ch = 'c'
            put(f, x, y, ch)
    for y in range(12, 19):
        put(f, 25, y, 'c')
    # two wheels
    for cx in (9, 22):
        for k in range(16):
            a = k / 16 * math.tau
            put(f, round(cx + math.cos(a) * 3.2), round(25 + math.sin(a) * 3.2), 'k')
        seg(f, cx - 2, 25, cx + 2, 25, 'l')
        seg(f, cx, 23, cx, 27, 'l')
        put(f, cx, 25, 'L')
    # a barrel and a crate by it
    for y in range(22, 29):
        for x in range(26, 30):
            put(f, x, y, 'L' if x == 26 else 'l' if y not in (24, 27) else 'k')
    return f


def weapon_rack():
    f = Frame(32, 32)
    for x in (5, 25):
        post(f, x, 10, 28)
    for x in range(5, 28):
        put(f, x, 11, 'L')
        put(f, x, 24, 'l')
    for x in (9, 12, 15):
        seg(f, x, 4, x, 28, 'l')
        put(f, x, 3, 'w')
        put(f, x, 4, 'J')
    # two round shields, red with a gold rim, a slain dragon painted on one
    for (cx, cy) in (20, 15), (20, 22):
        for k in range(24):
            a = k / 24 * math.tau
            put(f, round(cx + math.cos(a) * 3.6), round(cy + math.sin(a) * 3.3), 'O' if math.sin(a) < 0.3 else 'o')
        ellipse(f, cx, cy, 2.6, 2.4, ['r', 'r', 'R'])
    seg(f, 18, 14, 22, 16, 'N')
    put(f, 21, 14, 'z')
    seg(f, 19, 13, 22, 17, 'U')  # the slash through it
    put(f, 20, 22, 'O')
    return f


def tent(variant):
    """a camp tent past the map's edge, 32x32: an A-frame of plain canvas, or a striped round pavilion"""
    f = Frame(32, 32)
    if variant == 0:
        for y in range(8, 28):
            half = (y - 8) * 0.7 + 1
            for x in range(round(16 - half), round(16 + half) + 1):
                ch = 'U' if x < 16 - half / 3 else 'C' if x < 16 + half / 2 else 'c'
                put(f, x, y, ch)
        for y in range(18, 28):
            half = (y - 18) * 0.35 + 1
            for x in range(round(16 - half), round(16 + half) + 1):
                put(f, x, y, 'H' if y > 19 else 'k')
        seg(f, 16, 5, 16, 8, 'l')
        seg(f, 4, 28, 9, 27, 'c')
        seg(f, 28, 28, 23, 27, 'c')  # the guy ropes
    else:
        for y in range(9, 28):
            half = min(12, (y - 9) * 1.1 + 1) if y < 19 else 12
            for x in range(round(16 - half), round(16 + half) + 1):
                stripe = int((x - 16) / max(1.0, half) * 3 + 3) % 2
                lit = x < 16 - half / 3
                ch = ('R' if lit else 'r') if stripe else ('U' if lit else 'C')
                if y >= 19 and y in (19,):
                    ch = 'O'
                put(f, x, y, ch)
        for y in range(21, 28):
            for x in range(14, 19):
                put(f, x, y, 'H')
        seg(f, 16, 3, 16, 9, 'l')
        for k in range(4):
            put(f, 17 + k, 3 + (k % 2), 'R')  # a pennant on the top
    return f


def palisade(variant):
    """a run of sharpened stakes, 16x32, lashed with a rope"""
    f = Frame(16, 32)
    for k, x in enumerate(range(1, 14, 4)):
        stake(f, x, 29, 22 + (k + variant) % 3 * 2, variant * 7 + k)
    for x in range(1, 15):
        put(f, x, 18, 'C' if x % 3 else 'c')
    return f


def watchtower():
    f = Frame(32, 48)
    for (x0, x1) in ((6, 10), (24, 20)):
        seg(f, x0, 45, x1, 16, 'l', 2)
    seg(f, 8, 38, 22, 26, 'k')
    seg(f, 22, 38, 8, 26, 'k')  # cross braces
    for y in range(13, 18):
        for x in range(7, 25):
            put(f, x, y, 'L' if y == 13 else 'l' if y < 17 else 'k')
    for x in (8, 23):
        seg(f, x, 6, x, 13, 'l')
    for y in range(2, 7):
        half = 9 + (y - 2)
        for x in range(16 - half, 16 + half + 1):
            put(f, x, y, 'R' if x < 16 else 'r')
    seg(f, 16, 2, 16, 0, 'l')
    put(f, 12, 11, 'O')  # a watchman's lantern
    return f


def trebuchet():
    f = Frame(48, 48)
    for x in range(4, 44):
        put(f, x, 42, 'L')
        put(f, x, 43, 'l')
        put(f, x, 44, 'k')
    for (x0, x1) in ((14, 22), (32, 24)):
        seg(f, x0, 42, x1, 18, 'l', 2)
    put(f, 23, 18, 'J')  # the axle
    seg(f, 23, 18, 42, 4, 'L', 2)  # the throwing arm, cocked
    seg(f, 23, 18, 12, 26, 'l', 2)
    for y in range(24, 33):
        for x in range(7, 15):
            put(f, x, y, 'j' if x < 9 else 'I')  # the counterweight box
    seg(f, 42, 4, 40, 20, 'C')
    ellipse(f, 40, 21, 2, 1.6, ['j', 'J', 'J'])  # the sling with a stone
    for (x, y) in ((6, 40), (40, 40)):
        for k in range(12):
            a = k / 12 * math.tau
            put(f, round(x + math.cos(a) * 2.5), round(y + math.sin(a) * 2.5), 'k')
    return f


def campfire_frames():
    frames = []
    for k in range(6):
        f = Frame(16, 16)
        seg(f, 3, 13, 12, 11, 'l')
        seg(f, 3, 11, 12, 13, 'k')
        for y in range(3, 12):
            for x in range(4, 12):
                h = 11 - y
                width = 3.6 - h * 0.38 + math.sin(k * 1.4 + y * 0.9) * 0.6
                d = abs(x - 7.5 - math.sin(k * 1.1 + y * 0.7) * 0.8)
                if d < width:
                    ch = 'Y' if d < width * 0.35 and h < 6 else 'O' if d < width * 0.7 else 'o'
                    if h > 7 and d < width * 0.5:
                        ch = 'R'
                    put(f, x, y, ch)
        frames.append(f)
    return frames


def banner_frames():
    """a red war banner with the gold sun, 16x32, four waving frames"""
    frames = []
    for k in range(4):
        f = Frame(16, 32)
        seg(f, 3, 3, 3, 30, 'l')
        put(f, 3, 2, 'O')
        for x in range(4, 13):
            wave = round(math.sin(k * 1.57 + x * 0.6) * 1.2)
            for y in range(4 + wave, 15 + wave - (1 if x > 10 else 0)):
                put(f, x, y, 'R' if y < 6 + wave else 'r')
            put(f, x, 15 + wave, 'O')
        put(f, 7, 9 + round(math.sin(k * 1.57 + 4.2) * 1.2), 'O')
        put(f, 8, 9 + round(math.sin(k * 1.57 + 4.8) * 1.2), 'Y')
        frames.append(f)
    return frames


def _command_tent(f, open_amount, wave):
    """the Dragonslayer's pavilion, 48x48: red and gold, a slain-dragon banner on its pole; the mouth (the door) at the
    bottom middle, where he walks out"""
    for y in range(12, 42):
        half = min(20, (y - 12) * 1.3 + 2) if y < 27 else 20
        for x in range(round(24 - half), round(24 + half) + 1):
            stripe = int((x - 24) / max(1.0, half) * 4 + 4) % 2
            lit = x < 24 - half / 3
            ch = ('R' if lit else 'r') if stripe else ('O' if lit else 'o')
            if y == 27:
                ch = 'Y' if lit else 'O'  # the gold valance
            elif y == 28 and x % 3 == 0:
                ch = 'O'
            put(f, x, y, ch)
    # the door: closed gold-trimmed flaps, or thrown open on the dark inside
    for y in range(30, 44):
        for x in range(19, 30):
            if open_amount == 0:
                ch = 'r' if x != 24 else 'O'
            else:
                gap = 1 + open_amount * 2
                ch = 'H' if abs(x - 24) <= gap else 'r'
                if abs(x - 24) == gap + 1:
                    ch = 'O'
            put(f, x, y, ch)
    if open_amount:
        put(f, 23, 37, 'J')
        put(f, 25, 36, 'w')  # a glint of his armour in the dark
        for y in range(31, 44, 2):  # the flaps whipping back
            put(f, 19 - (y + wave) % 3, y, 'R')
            put(f, 29 + (y + wave) % 3, y, 'r')
    # the pole and his banner: a red dragon run through by a sword, on gold
    seg(f, 24, 2, 24, 13, 'l')
    put(f, 24, 1, 'O')
    for x in range(25, 35):
        w = round(math.sin(wave * 1.57 + x * 0.55) * 1.0)
        for y in range(3 + w, 10 + w):
            put(f, x, y, 'O' if y > 3 + w else 'Y')
        if 28 <= x <= 31:
            put(f, x, 6 + w, 'R')
    seg(f, 27, 9, 32, 4, 'w')  # the sword
    # guy ropes and pegs
    for (x0, x1) in ((3, 8), (45, 40)):
        seg(f, x0, 45, x1, 35, 'c')
        put(f, x0, 46, 'l')


def command_tent_frames(open_):
    frames = []
    for k in range(4 if not open_ else 6):
        f = Frame(48, 48)
        _command_tent(f, (min(3, k + 1) if open_ else 0), k)
        frames.append(f)
    return frames


SIEGE_LADDERS = [((1, 27), (17, 27)), ((46, 19), (62, 19))]  # (outer end, wall end), horizontal, over the wall top
SIEGE_DROP_LADDER = ((14, 62), (14, 50))  # under the bottom-left tower, vertical
SIEGE_TOP_LADDER = ((38, 1), (38, 15))  # on the north wall, vertical
SIEGE_ARROWS = [(20, 12, 0, 1), (33, 11, 0, 1), (43, 14, 0, 1), (11, 20, 1, 0), (54, 31, -1, 0), (12, 38, 1, 0),
                (52, 40, -1, 0), (44, 50, 0, -1), (21, 50, 0, -1)]


def _ladder_h(f, x0, x1, y, shift=0, cut=0):
    lo, hi = sorted((x0, x1))
    lo, hi = lo + shift, hi + shift - cut
    for x in range(lo, hi + 1):
        put(f, x, y, 'L')
        put(f, x, y + 4, 'l')
        if (x - lo) % 2 == 0:
            put(f, x, y + 1, 'C')
            put(f, x, y + 2, 'L')
            put(f, x, y + 3, 'l')


def _ladder_v(f, x, y0, y1, shift=0, cut=0):
    lo, hi = sorted((y0, y1))
    lo, hi = lo + cut, hi
    for y in range(lo, hi + 1):
        put(f, x + shift, y, 'L')
        put(f, x + 4 + shift, y, 'l')
        if (y - lo) % 2 == 0:
            put(f, x + 1 + shift, y, 'C')
            put(f, x + 2 + shift, y, 'L')
            put(f, x + 3 + shift, y, 'l')


def _ram(f, beat, drop=0):
    """a wheeled ram under a hide roof below the gate, its iron-capped beam in the gate"""
    by = 49 - beat + drop
    for y in range(by, by + 7):
        put(f, 31, y, 'L')
        put(f, 32, y, 'l')
    put(f, 31, by - 1, 'J')
    put(f, 32, by - 1, 'w')
    for y in range(54 + drop, 63 + drop):
        for x in range(23, 41):
            ch = 'U' if x in (31, 32) else 'C' if x < 31 else 'c'
            if (y - 54 - drop) % 3 == 2 and x not in (31, 32):
                ch = 'L' if x < 31 else 'l'
            if x in (23, 40):
                ch = 'k'
            put(f, x, y, ch)
    for x in (22, 41):
        for y in (56 + drop, 57 + drop, 60 + drop, 61 + drop):
            put(f, x, y, 'k')


def siege_idle_frames():
    frames = []
    for beat in (0, 1, 2, 1):
        f = Frame(64, 64)
        for (outer, inner) in SIEGE_LADDERS:
            _ladder_h(f, outer[0], inner[0], outer[1])
            put(f, inner[0], outer[1] - 1, 'J')  # the hooks on the wall top
        _ladder_v(f, SIEGE_DROP_LADDER[0][0], SIEGE_DROP_LADDER[1][1], SIEGE_DROP_LADDER[0][1] - 1)
        _ladder_v(f, SIEGE_TOP_LADDER[0][0], SIEGE_TOP_LADDER[0][1], SIEGE_TOP_LADDER[1][1])
        put(f, SIEGE_TOP_LADDER[0][0], SIEGE_TOP_LADDER[1][1] + 1, 'J')
        put(f, SIEGE_TOP_LADDER[0][0] + 4, SIEGE_TOP_LADDER[1][1] + 1, 'J')
        seg(f, 55, 9, 62, 2, 'C')  # a grappling rope off the top-right tower
        put(f, 54, 10, 'J')
        seg(f, 8, 9, 2, 3, 'C')
        put(f, 9, 10, 'J')
        for a in SIEGE_ARROWS:
            arrow(f, *a)
        _ram(f, beat)
        frames.append(f)
    return frames


def siege_reveal_frames():
    """the drakelings shove the ladders off, cut the ropes and the ram rolls back: everything slides out and is gone"""
    frames = []
    n = lair_art.CAMO_REVEAL_FRAMES
    for k in range(n):
        f = Frame(64, 64)
        out = k * 2
        if k < n - 2:
            (o0, i0), (o1, i1) = SIEGE_LADDERS
            _ladder_h(f, o0[0], i0[0], o0[1] + k // 3, shift=-out, cut=0)
            _ladder_h(f, o1[0], i1[0], o1[1] + k // 3, shift=out, cut=0)
            _ladder_v(f, SIEGE_DROP_LADDER[0][0], SIEGE_DROP_LADDER[1][1] + out, SIEGE_DROP_LADDER[0][1] - 1, cut=0)
            _ladder_v(f, SIEGE_TOP_LADDER[0][0], SIEGE_TOP_LADDER[0][1], SIEGE_TOP_LADDER[1][1] - out)
            if k < 3:
                seg(f, 55, 9, 62, 2, 'C')
                seg(f, 8, 9, 2, 3, 'C')
            _ram(f, 0, drop=out)
        if k < n - 1:
            for a in SIEGE_ARROWS:
                arrow(f, *a)
        frames.append(f)
    return frames


# the background sheet's dark fill (past the map) becomes the camp's trampled earth; the stone frame stays
CAMP_GROUND_RECOLOUR = {'1f1419': '3e2731', '2f1e25': '4a2e2c'}
DARK_FILL = [(0, 0), (1, 0), (0, 1), (1, 1)]
GROUND_BITS = ['733e39', 'c28569', '2f1e25']  # ruts, straw, hoof prints


def background_sheet(src, out):
    from PIL import Image
    im = Image.open(src).convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            hexc = '%02x%02x%02x' % (r, g, b)
            if a and hexc in CAMP_GROUND_RECOLOUR:
                c = CAMP_GROUND_RECOLOUR[hexc]
                if hexc == '1f1419' and _rand('mottle', x // 2, y // 2) < 0.2:
                    c = CAMP_GROUND_RECOLOUR['2f1e25']
                px[x, y] = (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)
    for tx, ty in DARK_FILL:  # a few bits of straw, ruts and prints per tile
        for k in range(4):
            if _rand('bit', tx, ty, k) < 0.3:
                continue
            c = GROUND_BITS[int(_rand('bc', tx, ty, k) * len(GROUND_BITS))]
            gx = tx * 16 + 2 + int(_rand('gx', tx, ty, k) * 11)
            gy = ty * 16 + 2 + int(_rand('gy', tx, ty, k) * 12)
            for d in range(1 + int(_rand('gl', tx, ty, k) * 3)):
                px[gx + d, gy] = (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)
    im.save(out)


if __name__ == '__main__':
    out_dir = os.path.join(TILES, 'lairs')
    os.makedirs(out_dir, exist_ok=True)
    background_sheet(os.path.join(TILES, 'green_land', 'background_tiles.png'),
                     os.path.join(out_dir, 'camp_background_tiles.png'))
    pieces = [('TROPHY_POLE', trophy_pole()), ('FORGE', forge()), ('EGG_CAGE', egg_cage()),
              ('DRAGON_DUMMY', dragon_dummy()), ('SUPPLY_WAGON', supply_wagon()), ('WEAPON_RACK', weapon_rack())]
    write_spec(os.path.join(out_dir, 'camp_landmarks.txt'), '''
# Source of camp_landmarks.aseprite and camp_landmarks.png: Dragonslayer's Camp's 32x32 landmarks (level 36), four
# blocking 16 px tiles each: a dragon trophy pole, the forge with dragonbane spears, an empty egg cage, a dragon-headed
# training dummy, a supply wagon, a weapon rack. Drawn by tools/sprite/parts/lair_camp_art.py.''', CAMP_PAL, (32, 32),
               [(n, 100, [f]) for n, f in pieces])
    write_spec(os.path.join(out_dir, 'camp_tents.txt'), '''
# Source of camp_tents.aseprite and camp_tents.png: tents of the war camp past the map's edge, 32x32: TENT_0 a plain
# A-frame, TENT_1 a striped pavilion. Drawn by tools/sprite/parts/lair_camp_art.py.''', CAMP_PAL, (32, 32),
               [('TENT_%d' % v, 100, [tent(v)]) for v in range(2)])
    write_spec(os.path.join(out_dir, 'camp_palisade.txt'), '''
# Source of camp_palisade.aseprite and camp_palisade.png: the camp's palisade, 16x32 runs of sharpened stakes (three).
# Drawn by tools/sprite/parts/lair_camp_art.py.''', CAMP_PAL, (16, 32),
               [('STAKES_%d' % v, 100, [palisade(v)]) for v in range(3)])
    write_spec(os.path.join(out_dir, 'camp_watchtower.txt'), '''
# Source of camp_watchtower.aseprite and camp_watchtower.png: a timber watchtower, 32x48. Drawn by
# tools/sprite/parts/lair_camp_art.py.''', CAMP_PAL, (32, 48), [('IDLE', 100, [watchtower()])])
    write_spec(os.path.join(out_dir, 'camp_trebuchet.txt'), '''
# Source of camp_trebuchet.aseprite and camp_trebuchet.png: a trebuchet aimed at the castle, 48x48. Drawn by
# tools/sprite/parts/lair_camp_art.py.''', CAMP_PAL, (48, 48), [('IDLE', 100, [trebuchet()])])
    write_spec(os.path.join(out_dir, 'camp_fire.txt'), '''
# Source of camp_fire.aseprite and camp_fire.png: a campfire, 16x16, six flicker frames. Drawn by
# tools/sprite/parts/lair_camp_art.py.''', CAMP_PAL, (16, 16), [('IDLE', 110, campfire_frames())])
    write_spec(os.path.join(out_dir, 'camp_banner.txt'), '''
# Source of camp_banner.aseprite and camp_banner.png: a red war banner with the humans' gold sun, 16x32, four waving
# frames. Drawn by tools/sprite/parts/lair_camp_art.py.''', CAMP_PAL, (16, 32), [('IDLE', 160, banner_frames())])
    write_spec(os.path.join(out_dir, 'camp_command_tent.txt'), '''
# Source of camp_command_tent.aseprite and camp_command_tent.png: the Dragonslayer's command tent, 48x48 (a spawn
# point): IDLE flaps shut, his banner flying; BOIL the flaps thrown open and whipping when he comes. Drawn by
# tools/sprite/parts/lair_camp_art.py.''', CAMP_PAL, (48, 48),
               [('IDLE', 180, command_tent_frames(False)), ('BOIL', 100, command_tent_frames(True))])
    write_spec(os.path.join(out_dir, 'camp_castle_siege.txt'), '''
# Source of camp_castle_siege.aseprite and camp_castle_siege.png: the castle under siege, 64x64 over the 48x48 castle
# (offset 8): IDLE ladders on its walls, ropes, arrows and a ram battering the gate; REVEAL (one shot) the drakelings
# shove it all off when the Dragonslayer arrives. Drawn by tools/sprite/parts/lair_camp_art.py.''', CAMP_PAL, (64, 64),
               [('IDLE', 160, siege_idle_frames()), ('REVEAL', 90, siege_reveal_frames())])
    write_sprite_frames('camp_fire', 16, 16, [('IDLE', 110, 6, True)])
    write_sprite_frames('camp_banner', 16, 32, [('IDLE', 160, 4, True)])
    write_sprite_frames('camp_command_tent', 48, 48, [('IDLE', 180, 4, True), ('BOIL', 100, 6, True)])
    write_sprite_frames('camp_castle_siege', 64, 64,
                        [('IDLE', 160, 4, True), ('REVEAL', 90, lair_art.CAMO_REVEAL_FRAMES, False)])
    print('ok')
