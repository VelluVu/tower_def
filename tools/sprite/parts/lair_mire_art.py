"""Hydra's Mire lair art (2026-11-24, level 24, the Bog Hydra's lair): night in the deep mire. Drowned giant trees and
root arches standing in the black water past the map (sprites), the mire's background tiles (the swamp background
recoloured: the dark fill becomes deep water, the stone frame a muddy bank) and its extra water tiles (boardwalk,
lily pads, reeds), 32x32 landmarks (a skull totem, a half-sunk serpent statue, the Hydra's shed skin, a bitten
stump), the 48x48 Hydra's pool (a spawn point's art: IDLE ripples, BOIL when she comes), a totem brazier, a
will-o'-wisp and the overgrown castle (IDLE, REVEAL tearing the vines away). Light from the top left, no black
outlines, Endesga 32 with a few hue-shifted water steps.

usage: lair_mire_art.py <parts dir> <tiles dir>   (then tools/sprite/sprite.py build <spec> <out.aseprite>)"""
import math
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, write_spec
from scorched_decor import put, ellipse, seg, mound
import lair_art
from lair_art import _rand, write_sprite_frames

TILES = sys.argv[2]

MIRE_PAL = {
    'H': '181425', 'w': '0f1c22', 'W': '142a30', 'v': '193c3e', 'V': '2a5a5c', 'x': '5a8a8a',  # deep water, ripples
    'k': '262b44', 'K': '3a4466', 'j': '5a6988', 'J': '8b9bb4',  # drowned wood, statue stone
    'm': '193c3e', 'M': '265c42', 'n': '3e8948', 'N': '63c74d',  # moss
    'd': '3a3b24', 'D': '45472a', 'e': '56602f',  # mud
    's': 'b59e85', 'u': 'd5bf9b', 'U': 'ecd8b1',  # bone
    't': '122630', 'T': '275a56', 'g': '5a9a74', 'G': '8fc46a', 'y': 'e0c070',  # hydra skin
    'l': '733e39', 'L': 'b86f50',  # timber
    'q': '3e3226', 'b': '5a4a32', 'B': '7a6442',  # weathered planks
    'r': 'a22633', 'o': 'f77622', 'O': 'feae34', 'Y': 'fee761',  # paint, flame
    'p': '68386c', 'P': 'b55088',  # fungi
    'c': '2ce8f5', 'C': 'e6f07a', 'z': 'ffffff',  # wisp
}
WATER = ['w', 'W', 'v']
WOOD = ['H', 'k', 'K', 'j']
MOSS = ['m', 'M', 'n', 'N']
MUD = ['d', 'D', 'e']
SKIN = ['t', 'T', 'g', 'G']
STATUE = ['k', 'K', 'j', 'J']


def ripple_ring(f, cx, cy, rx, ry, key, ch='V', gap=0.0):
    """a broken ellipse outline on the water: the ring where something stands in it"""
    for k in range(int(rx * 6)):
        a = k / (rx * 6) * math.tau
        if (a + gap) % 1.9 < 0.35:
            continue
        put(f, round(cx + math.cos(a) * rx), round(cy + math.sin(a) * ry), ch if math.sin(a) > -0.2 else 'v')


def _trunk(f, cx, base, top, half0, half1, lean, key):
    """a trunk from base up to top, tapering, leaning by `lean` pixels at the top, lit from the left"""
    for y in range(top, base + 1):
        t = (base - y) / max(1, base - top)
        mid = cx + lean * t * t + math.sin(y * 0.4 + key) * 0.6
        half = half0 + (half1 - half0) * t
        for x in range(round(mid - half), round(mid + half) + 1):
            side = (x - (mid - half)) / max(1.0, half * 2)
            ch = 'j' if side < 0.22 else 'K' if side < 0.55 else 'k' if side < 0.85 else 'H'
            if _rand('bark', key, x, y // 3) < 0.12 and ch != 'H':
                ch = 'k'
            put(f, x, y, ch)
    return lambda y: cx + lean * ((base - y) / max(1, base - top)) ** 2


def _branch(f, x0, y0, x1, y1, width):
    seg(f, x0, y0, x1, y1, 'K', width)
    seg(f, x0, y0 + 1, x1, y1 + 1, 'k')


def _moss_strand(f, x, y, length, key):
    for k in range(length):
        sway = round(math.sin(k * 0.7 + key) * 0.6)
        put(f, x + sway, y + k, 'n' if k < length // 3 else 'M' if k < length - 1 else 'm')


def drowned_tree(variant):
    """a giant dead tree standing in the black water, 48x64: flared roots, bare crooked branches, hanging moss"""
    f = Frame(48, 64)
    base, cx = 57, 24
    ellipse(f, cx, base + 1, 15, 3.4, ['w', 'W', 'W'])  # its shadow on the water
    lean = (-3, 4, 1)[variant]
    top = (8, 12, 18)[variant]
    centre = _trunk(f, cx, base, top, 4.5, 1.6, lean, variant)
    for k, (dx, h) in enumerate(((-13, 5), (-8, 7), (8, 6), (13, 4), (-3, 3), (4, 3))):  # roots arching into the water
        x0 = cx + (dx > 0) * 3 - (dx < 0) * 3
        for s in range(9):
            t = s / 8
            x = round(x0 + dx * t)
            y = round(base - 5 + h * math.sin(t * math.pi * 0.6) * -0.6 + t * 6)
            put(f, x, y, 'K' if t < 0.5 and dx < 0 else 'k')
            put(f, x, y + 1, 'H')
    branches = (((20, -14, -10), (14, 12, -9), (30, 10, -6), (11, -8, -6)),
                ((24, 13, -12), (17, -12, -8), (33, -9, -5), (14, 8, -4)),
                ((26, -11, -6), (22, 11, -8), (34, 8, -4)))[variant]
    for y, dx, dy in branches:  # (where on the trunk, reach, rise)
        x = round(centre(y))
        _branch(f, x, y, x + dx, y + dy, 2 if abs(dx) > 10 else 1)
        tx, ty = x + dx, y + dy
        seg(f, tx, ty, tx + (2 if dx > 0 else -2), ty - 3, 'K')  # a twig at the tip
        seg(f, x + dx // 2, y + dy // 2, x + dx // 2 + (1 if dx > 0 else -1), y + dy // 2 - 4, 'k')
        for m in range(2):
            mx = round(x + dx * (0.45 + 0.4 * m))
            my = round(y + dy * (0.45 + 0.4 * m)) + 2
            _moss_strand(f, mx, my, 4 + int(_rand('moss', variant, y, m) * 7), y + m)
    seg(f, round(centre(top)) - 1, top, round(centre(top)) + 1, top - 2, 'K')  # the snapped crown
    for k in range(3):  # moss on the trunk's lit side
        y = base - 6 - k * 9 - variant * 2
        x = round(centre(y)) - 3
        put(f, x, y, 'n')
        put(f, x + 1, y + 1, 'M')
        put(f, x, y + 1, 'M')
    if variant == 2:  # glowcaps on the stump of a broken branch
        for x, y, ch in ((27, 40, 'p'), (28, 39, 'P'), (29, 40, 'p'), (28, 41, 'p')):
            put(f, x, y, ch)
    ripple_ring(f, cx, base + 1, 17, 3.6, variant, gap=variant)
    return f


def root_arch():
    """a drowned tree's root arching up out of the water and back in, 64x32"""
    f = Frame(64, 32)
    ellipse(f, 32, 27, 27, 3, ['w', 'W', 'W'])
    for k, (x0, x1, h, w) in enumerate(((6, 40, 19, 3), (22, 58, 15, 2), (14, 30, 8, 1))):
        for s in range(41):
            t = s / 40
            x = round(x0 + (x1 - x0) * t)
            y = round(26 - h * math.sin(t * math.pi))
            for o in range(w):
                put(f, x, y + o, 'j' if o == 0 and t < 0.5 else 'K' if o == 0 else 'k')
            put(f, x, y + w, 'H')
        top_x = (x0 + x1) // 2
        _moss_strand(f, top_x - 2, 27 - h + w, 3 + k * 2, k)
        _moss_strand(f, top_x + 4, 27 - h + w + 1, 2 + k, k + 2)
        ripple_ring(f, x0, 27, 3, 1, k)
        ripple_ring(f, x1, 27, 3, 1, k + 1)
    return f


# ----------------------------------------------------------------------- landmarks, 32x32 (four blocking tiles)
def skull_totem():
    f = Frame(32, 32)
    mound(f, 16, 29, 13, 2, MUD)
    for x in range(15, 18):  # the pole, dark old wood
        seg(f, x, 10, x, 28, 'j' if x == 15 else 'K' if x == 16 else 'k')
    seg(f, 6, 13, 26, 11, 'K', 1)  # a crossbar, tilted, with charms on cords
    seg(f, 6, 14, 26, 12, 'k')
    for hx, hy, n in ((8, 14, 4), (12, 14, 6), (21, 13, 5), (25, 12, 3)):
        seg(f, hx, hy + 1, hx, hy + n, 'd')
        put(f, hx, hy + n + 1, 'U' if hx % 2 else 's')
    ellipse(f, 16, 6, 5.2, 4.6, ['s', 'u', 'U'])  # a big horned beast skull on top
    for y in range(9, 12):
        for x in range(14, 19):
            put(f, x, y, 'u' if x < 17 else 's')  # its snout
    for ex in (14, 18):
        put(f, ex, 6, 'H')
        put(f, ex, 7, 'H')
    put(f, 15, 11, 'H')
    put(f, 17, 11, 'H')
    seg(f, 11, 4, 7, 1, 's', 2)  # horns curving up
    seg(f, 20, 4, 24, 1, 's', 2)
    put(f, 7, 1, 'U')
    put(f, 25, 1, 'U')
    seg(f, 12, 3, 20, 3, 'r')  # a red painted stripe over the brow
    for x, y in ((9, 27), (20, 28), (23, 26)):  # bones at its foot
        seg(f, x, y, x + 3, y - 1, 'u')
        put(f, x, y, 'U')
    return f


def serpent_statue():
    f = Frame(32, 32)
    ellipse(f, 16, 27, 14, 3.4, WATER)  # half-sunk in a pool
    for cx, w in ((7, 4), (14, 4)):  # two coils showing above the water, stone humps
        for x in range(cx - w, cx + w + 1):
            h = round(4 * math.sqrt(max(0.0, 1 - ((x - cx) / (w + 0.5)) ** 2)))
            for y in range(27 - h, 28):
                put(f, x, y, 'J' if y == 27 - h else 'j' if x < cx else 'K')
            put(f, x, 28, 'k')
    for y in range(8, 28):  # the neck rising in an S to the head
        t = (27 - y) / 19
        x = round(22 + 2.5 * math.sin(t * math.pi * 1.3))
        half = 2 if y > 14 else 1.6
        for o in range(-round(half), round(half) + 1):
            put(f, x + o, y, 'J' if o == -round(half) else 'j' if o < 0 else 'K' if o < round(half) else 'k')
        if y % 3 == 0:
            put(f, x + 1, y, 'k')  # carved scales
    for y in range(3, 10):  # the head, a wedge looking left, jaw open
        for x in range(13, 25):
            top = 3 + max(0, (x - 13) // 4 - 1)
            if y >= top and (y <= 6 or x > 17 + (y - 6) * 2):
                put(f, x, y, 'J' if y == top else 'j' if y < 5 else 'K')
    for x in range(14, 20):  # lower jaw
        put(f, x, 9, 'K')
        put(f, x, 10, 'k')
    put(f, 15, 7, 'J')
    put(f, 15, 8, 'J')  # fangs
    put(f, 19, 4, 'G')  # a glass eye catching the wisp light
    put(f, 20, 4, 'g')
    for x, y in ((6, 23), (13, 24), (21, 16), (23, 11)):  # moss
        put(f, x, y, 'n')
        put(f, x + 1, y, 'M')
    seg(f, 23, 19, 21, 23, 'H')  # a crack
    ripple_ring(f, 16, 27, 14, 3.4, 3)
    return f


def shed_skin():
    f = Frame(32, 32)
    mound(f, 16, 29, 14, 2, MUD)
    path = []
    for s in range(48):  # the Hydra's shed skin: one pale, papery tube lying in loops over the mud
        t = s / 47
        path.append((3 + 22 * t, 22 + 4 * math.sin(t * math.pi * 2.2)))
    for k, (x, y) in enumerate(path):
        r = 3.0 - abs(k - 20) / 30
        ellipse(f, x, y, 1.6, r, ['s', 'u', 'U'])
    for k, (x, y) in enumerate(path[::3]):  # scale rows, and holes where it tore
        put(f, round(x), round(y) - 1, 's')
        if k % 4 == 1:
            put(f, round(x) + 1, round(y), 'D')
    seg(f, 25, 21, 27, 15, 'u', 2)  # its neck up to the head
    ellipse(f, 27, 12, 3.4, 2.6, ['s', 'u', 'U'])  # one empty head, the jaw split
    put(f, 26, 11, 'D')
    seg(f, 25, 14, 29, 15, 's')
    for x, y in ((7, 18), (16, 26), (22, 19)):  # a teal sheen left on it
        put(f, x, y, 'g')
    return f


def bitten_stump():
    f = Frame(32, 32)
    mound(f, 16, 29, 13, 2, MUD)
    _trunk(f, 16, 27, 6, 6, 5, 0, 7)
    for x in range(9, 24):  # the bite: a half-moon gone from the top, the edge splintered
        d = abs(x - 16)
        bite = 6 + round(8 * math.sqrt(max(0.0, 1 - (d / 5.5) ** 2)))
        for y in range(5, bite + 1):
            f.px.pop((x, y), None)
        if (x, bite + 1) in f.px:
            f.px[(x, bite + 1)] = 'u' if x % 2 else 'J'  # pale torn wood
    for x, top in ((10, 3), (11, 5), (21, 2), (22, 4)):  # splinters standing up at the bite's ends
        seg(f, x, top, x, 7, 'K' if x < 16 else 'k')
        put(f, x, top, 'j')
    for x, y in ((12, 21), (19, 23)):  # claw scores
        seg(f, x, y, x + 1, y - 4, 'H')
    _moss_strand(f, 11, 17, 4, 1)
    for x, y, ch in ((6, 27, 'p'), (7, 26, 'P'), (24, 27, 'p'), (25, 26, 'P')):  # glowcaps at its foot
        put(f, x, y, ch)
    return f


# ----------------------------------------------------------------------- animated pieces
def pool_frames(boil):
    """the Hydra's pool, 48x48: a ring of mossy stones and mud round black water. IDLE: slow rings spread from the
    middle. BOIL (when she comes): the water heaves and bubbles"""
    frames = []
    count = 6 if boil else 4
    for i in range(count):
        f = Frame(48, 48)
        ellipse(f, 24, 26, 21, 16, MUD + ['D'])  # the mud lip
        for k in range(14):  # mossy stones round it, some gone
            if _rand('gone', k) < 0.3:
                continue
            a = k / 14 * math.tau + 0.2 + (_rand('sa', k) - 0.5) * 0.3
            sx, sy = 24 + math.cos(a) * 19, 26 + math.sin(a) * 14
            size = 1.6 + _rand('ss', k) * 1.6
            ellipse(f, sx, sy, size, size * 0.75, ['k', 'K', 'j'])
            if math.sin(a) < 0.2:
                put(f, round(sx) - 1, round(sy) - 1, 'n')
        for x in (5, 7, 9, 40, 42, 44):  # reeds on the lip
            base = 30 + (3 if x in (7, 42) else 0)
            seg(f, x, base - 6 - x % 3, x, base, 'n' if x % 2 else 'M')
            put(f, x, base - 6 - x % 3, 'l')
        ellipse(f, 24, 27, 16, 11, ['H', 'w', 'W'], light=(0.4, 0.7))  # the water, darkest at its depth
        if boil:
            heave = (0, 1, 2, 2, 1, 0)[i]
            ellipse(f, 24, 28, 8 + heave * 2, 5 + heave, ['W', 'v', 'V'])
            for b in range(7 + i * 2):  # bubbles
                a = _rand('ba', i, b) * math.tau
                r = _rand('br', i, b) * (9 + heave * 2)
                bx, by = round(24 + math.cos(a) * r), round(28 + math.sin(a) * r * 0.6)
                put(f, bx, by, 'x')
                if _rand('bs', i, b) > 0.6:
                    put(f, bx + 1, by, 'V')
                    put(f, bx, by - 1, 'V')
        else:
            for k in range(2):
                r = ((i + k * 2) % 4) * 3.2 + 2
                ripple_ring(f, 24, 28, r, r * 0.6, i + k, ch='V' if r < 10 else 'v')
            put(f, 24, 28, 'v')
        for (x0, y0, x1, y1) in ((6, 34, 11, 36), (36, 37, 41, 34), (16, 12, 20, 11)):  # bones on the lip
            seg(f, x0, y0, x1, y1, 'u')
            put(f, x0, y0, 'U')
            put(f, x1, y1, 'U')
        ellipse(f, 38, 16, 2, 1.8, ['s', 'u', 'U'])  # a skull
        put(f, 38, 16, 'H')
        frames.append(f)
    return frames


def brazier_frames():
    """a bog-folk brazier on a short post, 16x16, four flicker frames"""
    frames = []
    for i in range(4):
        f = Frame(16, 16)
        seg(f, 7, 10, 7, 14, 'l')
        seg(f, 8, 10, 8, 14, 'k')
        for x in range(4, 12):  # the bowl, an old skull-cap
            put(f, x, 9, 'u' if x < 8 else 's')
        for x in range(5, 11):
            put(f, x, 10, 's')
        sway = (0, 1, 0, -1)[i]
        tall = (0, 1, 2, 1)[i]
        for y in range(4 - tall, 9):
            half = 2 if y > 6 else 1 if y > 4 else 0
            for x in range(8 - half + (sway if y < 6 else 0), 8 + half + (sway if y < 6 else 0)):
                put(f, x, y, 'Y' if y > 6 and 6 < x < 9 else 'O' if y > 5 else 'o')
        frames.append(f)
    return frames


def wisp_frames():
    """a will-o'-wisp, 16x16: a pale green-cyan flame bobbing over the water, six frames"""
    frames = []
    for i in range(6):
        f = Frame(16, 16)
        bob = round(math.sin(i / 6 * math.tau) * 1.5)
        cy = 7 + bob
        ellipse(f, 8, cy, 2.6, 2.6, ['c', 'C', 'z'])
        for k in range(3):  # its trailing tail
            put(f, 8 - (i % 2) + k % 2, cy + 3 + k, 'c' if k < 2 else 'v')
        put(f, 8, cy - 3 - (i % 2), 'C')
        frames.append(f)
    return frames


# ----------------------------------------------------------------------- the overgrown castle
# lair_art's rock camouflage, its stones turned into clumps of moss and leaves, vines across it and reeds round its
# foot; REVEAL tears it away (falling leaves instead of dust)
MOSS_CAMO = {'1': '0f1c22', '2': '142a30', '3': '193c3e', '4': '1e4a3a', '5': '265c42', '6': '2f6b3d', '7': '3a7a45',
             '8': '4a8a45'}
MIRE_CAMO_PAL = dict(MIRE_PAL, **MOSS_CAMO)


def _vines(f, keep):
    for (x0, y0, x1, y1) in ((6, 14, 30, 30), (26, 8, 50, 22), (14, 44, 46, 38), (36, 12, 40, 52)):
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for k in range(steps + 1):
            x = round(x0 + (x1 - x0) * k / steps)
            y = round(y0 + (y1 - y0) * k / steps + math.sin(k * 0.5) * 1.3)
            if (x, y) in f.px and keep(x, y):
                f.px[(x, y)] = 'D' if k % 5 else 'e'
    for x in range(7, 58, 3):  # reeds round its foot
        if _rand('reed', x) < 0.55 and keep(x, 54):
            h = 4 + int(_rand('rh', x) * 4)
            seg(f, x, 56 - h, x, 56, 'n' if x % 2 else 'M')
            put(f, x, 56 - h, 'l')


def _recolour_camo(frames):
    """lair_art's camouflage frames use its stone keys; leaf greens here, and the hoard's glow stays"""
    stone_to_moss = {'G': '8', 'g': '6', 'm': '3', 'M': '7', 'H': '1', 'J': '5', 'j': '4', 'h': '2'}
    for f in frames:
        f.px = {k: stone_to_moss.get(v, v) for k, v in f.px.items()}
    return frames


def mire_camo_idle():
    frames = _recolour_camo(lair_art.camo_idle_frames())
    for f in frames:
        _vines(f, lambda x, y: True)
        for k in range(5):  # flowers in the moss
            x, y = 12 + int(_rand('fl', k) * 40), 12 + int(_rand('fy', k) * 36)
            if (x, y) in f.px:
                f.px[(x, y)] = 'P' if k % 2 else 'C'
    return frames


def mire_camo_reveal():
    frames = _recolour_camo(lair_art.camo_reveal_frames())
    for k, f in enumerate(frames):
        if k < 3:
            _vines(f, lambda x, y: True)
    return frames


# ----------------------------------------------------------------------- tiles
# swamp_background_tiles.png recoloured: the dark fill turns into deep water with ripple glints on its four fill
# tiles, the stone frame round the playfield into a muddy bank
BACKGROUND_RECOLOUR = {
    '1f1419': '142a30', '2f1e25': '0f1c22',  # dark fill -> deep water
    '7e5e57': '45472a', '6e5d64': '3a3b24', '9e9398': '56602f',  # the frame's brown face and rim -> mud bank
    '3e3e4c': '2b3a2a', '30303d': '1f2c22', '363645': '25321f', '3a3a48': '29362a', '48495a': '34452f',
    '2c2c38': '1b281f', '38384a': '27352a', '2e2e3a': '1d2a20', '454556': '30402c', '565869': '3e5236',
    '5a5d6b': '425637', '717586': '56602f', '596373': '3e5236', '394357': '26352c',  # rock -> drowned peat
}
DARK_FILL = [(0, 0), (1, 0), (0, 1), (1, 1)]


def background_sheet(src, out):
    from PIL import Image
    im = Image.open(src).convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            hexc = '%02x%02x%02x' % (r, g, b)
            if a and hexc in BACKGROUND_RECOLOUR:
                c = BACKGROUND_RECOLOUR[hexc]
                px[x, y] = (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)
    for tx, ty in DARK_FILL:  # ripple glints, two or three short lines per tile
        for k in range(3):
            if _rand('glint', tx, ty, k) < 0.25:
                continue
            gx = tx * 16 + 2 + int(_rand('gx', tx, ty, k) * 10)
            gy = ty * 16 + 2 + int(_rand('gy', tx, ty, k) * 12)
            for d in range(2 + int(_rand('gl', tx, ty, k) * 3)):
                px[gx + d, gy] = (0x19, 0x3c, 0x3e, 255)
    im.save(out)


def extra_tiles():
    """16x16 water tiles (background source 2): row 0 boardwalk planks running east-west (3) and its end posts (1),
    row 1 lily pads (3) and a floating log (1), row 2 reeds standing in the water (3) and bubbles (1)"""
    tiles = {}
    for v in range(3):  # boardwalk
        f = Frame(16, 16)
        for k, x0 in enumerate(range(0, 16, 4)):
            sag = 1 if _rand('sag', v, k) > 0.7 else 0
            for x in range(x0, x0 + 3):
                for y in range(3 + sag, 12 + sag):
                    put(f, x, y, 'B' if x == x0 else 'b' if y < 11 + sag else 'q')
            if _rand('gone', v, k) > 0.85:  # a missing plank
                for x in range(x0, x0 + 3):
                    for y in range(3, 13):
                        put(f, x, y, 'w')
        seg(f, 0, 12, 15, 12, 'H')
        tiles[(v, 0)] = f
    f = Frame(16, 16)  # the posts at the boardwalk's end
    for px_ in (3, 11):
        seg(f, px_, 2, px_, 13, 'b', 2)
        seg(f, px_ + 1, 2, px_ + 1, 13, 'q')
        put(f, px_, 2, 'B')
        ripple_ring(f, px_, 13, 3, 1, px_)
    tiles[(3, 0)] = f
    for v in range(3):  # lily pads
        f = Frame(16, 16)
        for k in range(2 + v % 2):
            cx, cy = 3 + int(_rand('lx', v, k) * 10), 3 + int(_rand('ly', v, k) * 10)
            ellipse(f, cx, cy, 2.6, 1.8, ['M', 'n', 'N'])
            put(f, cx + 1, cy, 'W')  # the notch
            if v == 1 and k == 0:
                put(f, cx, cy - 1, 'P')
        tiles[(v, 1)] = f
    f = Frame(16, 16)  # a floating log
    for x in range(1, 15):
        put(f, x, 7, 'K')
        put(f, x, 8, 'k')
        put(f, x, 9, 'H')
    _moss_strand(f, 6, 6, 2, 0)
    tiles[(3, 1)] = f
    for v in range(3):  # reeds in the water
        f = Frame(16, 16)
        for k in range(4 + v):
            x = 2 + int(_rand('rx', v, k) * 12)
            h = 6 + int(_rand('rh', v, k) * 7)
            seg(f, x, 14 - h, x, 14, 'n' if k % 2 else 'M')
            if k % 3 == 0:
                seg(f, x, 14 - h, x, 15 - h, 'l')
            put(f, x, 15, 'V')
        tiles[(v, 2)] = f
    f = Frame(16, 16)  # bubbles from something breathing below
    for (x, y, big) in ((5, 6, True), (10, 9, False), (7, 11, False), (11, 4, False)):
        put(f, x, y, 'x')
        if big:
            put(f, x + 1, y, 'V')
            put(f, x, y + 1, 'V')
            put(f, x + 1, y + 1, 'v')
    ripple_ring(f, 6, 7, 4, 2, 1)
    tiles[(3, 2)] = f
    return tiles


def save_tiles(tiles, path, columns, rows, base):
    """each piece drawn over `base` (the mire's first deep-water tile), so it sits in the water without a seam"""
    from PIL import Image
    im = Image.new('RGBA', (columns * 16, rows * 16), (0, 0, 0, 0))
    water = Image.open(base).convert('RGBA').crop((0, 0, 16, 16))
    for (tx, ty), f in tiles.items():
        im.paste(water, (tx * 16, ty * 16))
        for (x, y), ch in f.px.items():
            if 0 <= x < 16 and 0 <= y < 16:
                c = MIRE_PAL[ch]
                im.putpixel((tx * 16 + x, ty * 16 + y), (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255))
    im.save(path)


if __name__ == '__main__':
    out_dir = os.path.join(TILES, 'lairs')
    os.makedirs(out_dir, exist_ok=True)
    background_sheet(os.path.join(TILES, 'swamp', 'swamp_background_tiles.png'),
                     os.path.join(out_dir, 'mire_background_tiles.png'))
    save_tiles(extra_tiles(), os.path.join(out_dir, 'mire_water_tiles.png'), 4, 3,
               os.path.join(out_dir, 'mire_background_tiles.png'))
    write_spec(os.path.join(out_dir, 'mire_trees.txt'), '''
# Source of mire_trees.aseprite and mire_trees.png: Hydra's Mire's drowned giant trees (48x64, three, standing in the
# deep water past the map). Drawn by tools/sprite/parts/lair_mire_art.py.''', MIRE_PAL, (48, 64),
               [('TREE_%d' % v, 100, [drowned_tree(v)]) for v in range(3)])
    write_spec(os.path.join(out_dir, 'mire_root_arch.txt'), '''
# Source of mire_root_arch.aseprite and mire_root_arch.png: a drowned tree's roots arching out of the water, 64x32.
# Drawn by tools/sprite/parts/lair_mire_art.py.''', MIRE_PAL, (64, 32), [('IDLE', 100, [root_arch()])])
    pieces = [('SKULL_TOTEM', skull_totem()), ('SERPENT_STATUE', serpent_statue()), ('SHED_SKIN', shed_skin()),
              ('BITTEN_STUMP', bitten_stump())]
    write_spec(os.path.join(out_dir, 'mire_landmarks.txt'), '''
# Source of mire_landmarks.aseprite and mire_landmarks.png: Hydra's Mire's 32x32 landmarks (level 24), four blocking
# 16 px tiles each: a bog-folk skull totem, a half-sunk stone serpent, the Hydra's shed skin, a stump she bit through.
# Drawn by tools/sprite/parts/lair_mire_art.py.''', MIRE_PAL, (32, 32), [(n, 100, [f]) for n, f in pieces])
    write_spec(os.path.join(out_dir, 'mire_pool.txt'), '''
# Source of mire_pool.aseprite and mire_pool.png: the Hydra's pool, 48x48 (a spawn point): IDLE slow rings, BOIL the
# water heaving when she comes. Drawn by tools/sprite/parts/lair_mire_art.py.''', MIRE_PAL, (48, 48),
               [('IDLE', 300, pool_frames(False)), ('BOIL', 110, pool_frames(True))])
    write_spec(os.path.join(out_dir, 'mire_brazier.txt'), '''
# Source of mire_brazier.aseprite and mire_brazier.png: a bog-folk brazier, 16x16, four flicker frames. Drawn by
# tools/sprite/parts/lair_mire_art.py.''', MIRE_PAL, (16, 16), [('IDLE', 120, brazier_frames())])
    write_spec(os.path.join(out_dir, 'mire_wisp.txt'), '''
# Source of mire_wisp.aseprite and mire_wisp.png: a will-o'-wisp, 16x16, six bobbing frames. Drawn by
# tools/sprite/parts/lair_mire_art.py.''', MIRE_PAL, (16, 16), [('IDLE', 140, wisp_frames())])
    write_spec(os.path.join(out_dir, 'mire_castle_camo.txt'), '''
# Source of mire_castle_camo.aseprite and mire_castle_camo.png: Hydra's Mire's castle overgrown with moss, vines and
# reeds, 64x64 over the 48x48 castle (offset 8): IDLE its hoard glowing through a gap, REVEAL (one shot) torn away
# when the Bog Hydra arrives. Drawn by tools/sprite/parts/lair_mire_art.py.''', MIRE_CAMO_PAL, (64, 64),
               [('IDLE', 220, mire_camo_idle()), ('REVEAL', 90, mire_camo_reveal())])
    write_sprite_frames('mire_pool', 48, 48, [('IDLE', 300, 4, True), ('BOIL', 110, 6, True)])
    write_sprite_frames('mire_brazier', 16, 16, [('IDLE', 120, 4, True)])
    write_sprite_frames('mire_wisp', 16, 16, [('IDLE', 140, 6, True)])
    write_sprite_frames('mire_castle_camo', 64, 64,
                        [('IDLE', 220, 4, True), ('REVEAL', 90, lair_art.CAMO_REVEAL_FRAMES, False)])
    print('ok')
