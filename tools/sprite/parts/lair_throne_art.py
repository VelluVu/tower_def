"""Throne of Embers lair art (2026-11-26, level 60, the Ashen Wyrm's lair and the game's end; concept in the design
doc's Boss lairs): the volcano's heart in an inferno glow. 32x32 landmarks on the map (a cultist altar, a cooled lava
flow, an obsidian shrine, a chained stolen egg, the servants' forge, a broken exile chain), the caldera past the map's
edge (obsidian spires, basalt columns, the old exile chains, cultist braziers, lava bubbles), the Wyrm's throne heaped
with its stolen hoard (96x80, on the lava behind the spawns), the 48x48 magma vent (a spawn's art: IDLE churning,
BOIL heaving when it rises), the castle bound by the cultists' glowing chains (64x64 over the 48x48 castle, offset 8:
IDLE the runes pulsing, REVEAL the chains snapping) and the caldera floor past the edge (the dark fill drawn as the
lava lake and basalt ledges). Light from below: the lava lake. Endesga 32 plus the volcano's basalt greys.

usage: lair_throne_art.py <parts dir> <tiles dir>   (then tools/sprite/sprite.py build <spec> <out.aseprite>)"""
import math
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, write_spec
from scorched_decor import put, ellipse, seg, mound
import lair_art
from lair_art import _rand, write_sprite_frames

TILES = sys.argv[2]

THRONE_PAL = {
    'd': '181425', 'c': '2a2028', 'b': '54444e', 'a': '7a6872',  # basalt, dark to lit (the volcano's greys)
    'R': 'a22633', 'r': 'e43b44', 'o': 'f77622', 'O': 'feae34', 'Y': 'fee761', 'z': 'ffffff',  # lava and gold
    'i': '3a4466', 'j': '5a6988', 'J': '8b9bb4',  # iron
    'e': '0099db', 'E': '2ce8f5', 'n': '3e8948', 'N': '63c74d', 'p': '68386c', 'P': 'b55088',  # stolen eggs
    'k': '3e2731', 'l': '733e39',  # robes, wood
}
BASALT = ['c', 'b', 'a']
LAVA = ['R', 'r', 'o']


def glow_crack(f, x0, y0, x1, y1):
    seg(f, x0, y0, x1, y1, 'o')
    put(f, (x0 + x1) // 2, (y0 + y1) // 2, 'O')


def cultist_altar():
    f = Frame(32, 32)
    for k in range(36):  # a rune ring burnt into the floor
        a = k / 36 * math.tau
        if k % 4 != 0:
            put(f, round(16 + math.cos(a) * 12), round(22 + math.sin(a) * 6), 'R' if k % 3 else 'o')
    for y in range(17, 26):  # the slab
        for x in range(8, 25):
            put(f, x, y, 'a' if y == 17 else 'b' if x < 20 else 'c')
    for x in (10, 22):  # candles
        seg(f, x, 13, x, 16, 'J')
        put(f, x, 12, 'O')
        put(f, x, 11, 'Y')
    # a horned idol of the Wyrm on the slab
    ellipse(f, 16, 12, 3, 3.6, ['d', 'c', 'b'])
    seg(f, 14, 9, 11, 5, 'b')
    seg(f, 18, 9, 21, 5, 'b')
    put(f, 15, 11, 'O')
    put(f, 17, 11, 'O')
    put(f, 16, 21, 'r')  # an offering's blood
    return f


def cooled_flow():
    f = Frame(32, 32)
    for (cx, cy, rx, ry) in ((12, 22, 9, 5), (21, 19, 8, 4.5), (17, 26, 10, 3.5)):
        ellipse(f, cx, cy, rx, ry, ['d', 'c', 'b'])
    glow_crack(f, 6, 22, 14, 20)
    glow_crack(f, 16, 24, 24, 21)
    glow_crack(f, 19, 17, 25, 18)
    put(f, 10, 19, 'a')
    put(f, 22, 17, 'a')  # glassy highlights
    return f


def obsidian_shard(f, x, base, height, lean):
    for y in range(base - height, base + 1):
        t = (base - y) / height
        half = max(0, round((1 - t) * 2.4))
        mid = x + round(lean * t)
        for dx in range(-half, half + 1):
            put(f, mid + dx, y, 'a' if dx < 0 else 'b' if dx == 0 else 'd')
    put(f, x + lean, base - height, 'J')


def obsidian_shrine():
    f = Frame(32, 32)
    mound(f, 16, 29, 12, 3, BASALT)
    for (x, h_, lean) in ((9, 14, -2), (14, 22, 0), (19, 18, 1), (24, 11, 3)):
        obsidian_shard(f, x, 27, h_, lean)
    ellipse(f, 16, 21, 2.5, 2.2, ['o', 'O', 'Y'])  # the glowing heart between the shards
    return f


def chained_egg():
    f = Frame(32, 32)
    mound(f, 16, 29, 9, 2, BASALT)
    seg(f, 16, 4, 16, 27, 'l')  # the stake
    ellipse(f, 16, 18, 5.5, 7.5, ['p', 'P', 'P'])  # a stolen violet egg
    put(f, 14, 14, 'z')
    for y in (15, 21):  # chains round it, hot where they bite
        for x in range(10, 23):
            put(f, x, y + (1 if x % 4 == 0 else 0), 'j' if x % 2 else 'J')
        put(f, 16, y, 'o')
    seg(f, 10, 15, 6, 28, 'j')
    seg(f, 22, 21, 27, 28, 'j')
    return f


def servant_forge():
    f = Frame(32, 32)
    for y in range(20, 28):  # a lava trough
        for x in range(4, 16):
            put(f, x, y, 'b' if y in (20, 27) or x in (4, 15) else LAVA[min(2, (x + y) % 4)])
    for x in range(6, 14):
        put(f, x, 23, 'O')
    for x in range(18, 29):  # the anvil
        put(f, x, 20, 'J' if x < 25 else 'j')
        put(f, x, 21, 'i')
    for y in range(22, 27):
        for x in range(21, 25):
            put(f, x, y, 'i' if x > 21 else 'j')
    seg(f, 19, 27, 28, 27, 'd')
    seg(f, 25, 19, 29, 13, 'l')  # a hammer resting on it
    for x in range(27, 31):
        put(f, x, 12, 'j')
        put(f, x, 13, 'i')
    put(f, 20, 18, 'O')
    put(f, 22, 16, 'o')  # sparks
    return f


def exile_chain():
    f = Frame(32, 32)
    mound(f, 16, 29, 14, 3, BASALT)
    for k, (cx, cy) in enumerate(((7, 24), (14, 20), (21, 17))):  # three huge links, the last one snapped
        for s in range(24):
            a = s / 24 * math.tau
            if k == 2 and 0.6 < a < 1.6:
                continue
            x, y = round(cx + math.cos(a) * 5), round(cy + math.sin(a) * 3.4)
            put(f, x, y, 'J' if math.sin(a) < 0 else 'j')
            put(f, x, y + 1, 'i')
    put(f, 14, 18, 'O')
    put(f, 21, 14, 'O')  # the old dragons' runes, still faintly warm
    return f


def spire():
    """an obsidian spire rising from the caldera, 32x48"""
    f = Frame(32, 48)
    mound(f, 16, 45, 12, 3, BASALT)
    obsidian_shard(f, 15, 43, 38, 2)
    obsidian_shard(f, 9, 43, 18, -2)
    obsidian_shard(f, 22, 43, 24, 3)
    glow_crack(f, 13, 40, 15, 30)
    return f


def basalt_columns():
    """basalt columns on a ledge, 32x32"""
    f = Frame(32, 32)
    for k, x in enumerate(range(4, 28, 5)):
        top = 8 + (k * 7) % 11
        for y in range(top, 29):
            for dx in range(4):
                put(f, x + dx, y, 'a' if dx == 0 else 'b' if dx < 3 else 'c')
        for dx in range(4):
            put(f, x + dx, top, 'a')
    for x in range(3, 29):
        put(f, x, 29, 'd')
    return f


def hanging_chain():
    """an old exile chain sagging between two rocks, 48x24"""
    f = Frame(48, 24)
    for (x, w) in ((2, 6), (40, 6)):
        mound(f, x + w // 2, 22, w // 2 + 1, 10, BASALT)
    for x in range(7, 41):
        y = round(8 + math.sin((x - 7) / 33 * math.pi) * 8)
        put(f, x, y, 'J' if x % 3 else 'j')
        put(f, x, y + 1, 'i')
    put(f, 24, 17, 'o')
    return f


def brazier_frames():
    frames = []
    for k in range(6):
        f = Frame(16, 16)
        for x in range(4, 12):
            put(f, x, 11, 'b')
            put(f, x, 12, 'c')
        seg(f, 6, 13, 5, 14, 'c')
        seg(f, 9, 13, 10, 14, 'c')
        for y in range(2, 11):
            for x in range(4, 12):
                h_ = 10 - y
                width = 3.4 - h_ * 0.36 + math.sin(k * 1.3 + y * 0.9) * 0.6
                d = abs(x - 7.5 - math.sin(k * 1.1 + y * 0.6) * 0.8)
                if d < width:
                    put(f, x, y, 'Y' if d < width * 0.3 and h_ < 5 else 'O' if d < width * 0.6 else 'o' if h_ < 7 else 'r')
        frames.append(f)
    return frames


def bubble_frames():
    """a lava bubble swelling and bursting, 16x16, six frames"""
    frames = []
    for k in range(6):
        f = Frame(16, 16)
        r = [1.2, 2.0, 2.8, 3.4, 0, 0][k]
        if r:
            ellipse(f, 8, 9, r, r * 0.8, ['r', 'o', 'O'])
            put(f, 7, 8, 'Y')
        elif k == 4:
            for (x, y) in ((4, 6), (12, 5), (8, 3), (5, 11), (11, 11)):
                put(f, x, y, 'O')
            put(f, 8, 9, 'r')
        else:
            seg(f, 6, 10, 10, 10, 'o')
        frames.append(f)
    return frames


def throne():
    """the Wyrm's throne on the lava: a stepped basalt dais, a spiked obsidian back, its stolen hoard, 96x80"""
    f = Frame(96, 80)
    for step, (half, top) in enumerate(((44, 62), (34, 54), (24, 47))):  # three steps
        for y in range(top, 76):
            for x in range(48 - half, 48 + half + 1):
                if y > 74 - step * 2 and step:
                    continue
                ch = 'a' if y == top else 'b' if x < 48 + half - 4 else 'c'
                if y > top + 5 and step == 0:
                    ch = 'c' if (x + y) % 9 else 'd'
                put(f, x, y, ch)
    for x in range(4, 92):  # the lava lapping the lowest step
        put(f, x, 76, 'o' if x % 5 else 'O')
        put(f, x, 77, 'r')
    # the throne's back: obsidian spikes fanning up
    for k in range(7):
        a = math.pi * (0.2 + 0.6 * k / 6)
        x1, y1 = round(48 + math.cos(a) * 26), round(46 - math.sin(a) * 40)
        seg(f, 48 + (k - 3) * 3, 46, x1, y1, 'b' if k < 3 else 'c', 3)
        put(f, x1, y1, 'J')
    for y in range(30, 47):  # the seat
        for x in range(38, 59):
            put(f, x, y, 'c' if x > 52 else 'b')
    for x in range(38, 59):
        put(f, x, 30, 'a')
    # the hoard heaped on the steps: coins, crowns, stolen eggs
    for k in range(90):
        x = 10 + int(_rand('coin', k) * 76)
        y = 48 + int(_rand('cy', k) * 26)
        if abs(x - 48) > 40 - (y - 48) * 0.1:
            continue
        put(f, x, y, 'O' if _rand('cc', k) < 0.6 else 'Y')
        put(f, x + 1, y, 'o')
    for (cx, cy, ramp) in ((24, 58, ['n', 'N', 'N']), (66, 60, ['e', 'E', 'E']), (54, 66, ['p', 'P', 'P']), (36, 68, ['R', 'r', 'r'])):
        ellipse(f, cx, cy, 3, 4, ramp)  # stolen eggs
        put(f, cx - 1, cy - 2, 'z')
    for (cx, cy) in ((16, 66), (78, 64)):  # old crowns
        for x in range(cx - 4, cx + 5):
            put(f, x, cy, 'O')
            put(f, x, cy + 1, 'o')
        for x in range(cx - 4, cx + 5, 2):
            put(f, x, cy - 1, 'Y')
    for side in (-1, 1):  # chains of the old exile hanging off the dais
        seg(f, 48 + side * 30, 52, 48 + side * 40, 74, 'j')
    return f


def _vent(f, k, boil):
    ellipse(f, 24, 32, 17, 10, BASALT)
    for y in range(25, 40):
        for x in range(10, 39):
            d = ((x - 24) / 12) ** 2 + ((y - 32) / 6.5) ** 2
            churn = math.sin(x * 0.5 + k * 1.3) * 0.12 + math.cos(y * 0.7 - k) * 0.1
            if d <= 1.0:
                v = d + churn
                put(f, x, y, 'Y' if v < 0.15 else 'O' if v < 0.35 else 'o' if v < 0.6 else 'r' if v < 0.85 else 'R')
    if boil:  # the lava heaving up in a column, spatter flying
        top = 22 - (k % 3) * 6
        for y in range(top, 33):
            half = 2 + (32 - y) // 5
            for x in range(24 - half, 25 + half):
                put(f, x, y, 'Y' if abs(x - 24) < half // 2 else 'O')
        for s in range(6):
            a = s / 6 * math.tau + k
            put(f, round(24 + math.cos(a) * (12 + k)), round(24 + math.sin(a) * (6 + k)), 'o')


def vent_frames(boil):
    frames = []
    for k in range(6 if boil else 4):
        f = Frame(48, 48)
        _vent(f, k, boil)
        frames.append(f)
    return frames


# the castle bound by chains: stakes outside its corners, chains crossing over it, runes on the stakes
STAKES = [(4, 6), (59, 6), (4, 58), (59, 58)]
CHAINS = [((4, 6), (59, 58)), ((59, 6), (4, 58)), ((4, 32), (59, 32))]


def _chain(f, a, b, pulse, broken=0.0, k=0):
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0))
    for s in range(n + 1):
        t = s / n
        if broken and abs(t - 0.5) < broken:
            continue
        drift = (t - 0.5) * broken * 20 * (1 if t > 0.5 else -1)
        x = round(x0 + (x1 - x0) * t + drift * (x1 - x0) / max(1, n))
        y = round(y0 + (y1 - y0) * t + abs(drift) * 0.6)
        hot = ((s // 3) + pulse) % 4 == 0
        put(f, x, y, 'O' if hot else 'j' if s % 2 else 'J')
        put(f, x, y + 1, 'o' if hot else 'i')


def _stakes(f, pulse):
    for (x, y) in STAKES:
        seg(f, x, y - 4, x, y + 2, 'k')
        seg(f, x + 1, y - 4, x + 1, y + 2, 'l')
        put(f, x, y - 2, 'Y' if pulse % 2 else 'O')  # a rune


def chains_idle_frames():
    frames = []
    for k in range(4):
        f = Frame(64, 64)
        _stakes(f, k)
        for a, b in CHAINS:
            _chain(f, a, b, k)
        frames.append(f)
    return frames


def chains_reveal_frames():
    frames = []
    n = lair_art.CAMO_REVEAL_FRAMES
    for k in range(n):
        f = Frame(64, 64)
        if k < n - 3:
            _stakes(f, 1)
        if k < n - 1:
            for a, b in CHAINS:
                _chain(f, a, b, 0, broken=0.05 + k * 0.07, k=k)
        if k < 3:  # the snap: sparks at the middle of each chain
            for a, b in CHAINS:
                mx, my = (a[0] + b[0]) // 2, (a[1] + b[1]) // 2
                for s in range(5):
                    ang = s / 5 * math.tau + k
                    put(f, round(mx + math.cos(ang) * (2 + k * 2)), round(my + math.sin(ang) * (2 + k * 2)), 'Y')
        frames.append(f)
    return frames


# the caldera floor past the edge: the dark fill's top row becomes the lava lake, its second row basalt ledges
LAVA_TILES = [(0, 0), (1, 0)]
LEDGE_TILES = [(0, 1), (1, 1)]


def background_sheet(src, out):
    from PIL import Image
    im = Image.open(src).convert('RGBA')
    px = im.load()

    def set_(x, y, key):
        c = THRONE_PAL[key]
        px[x, y] = (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)

    for tx, ty in LAVA_TILES:
        for y in range(16):
            for x in range(16):
                gx, gy = tx * 16 + x, ty * 16 + y
                # cooling plates of crust drifting on the lava, bright seams between them (tiles seamlessly)
                v = math.sin(gx * 0.55 + math.sin(gy * 0.4) * 1.5) + math.cos(gy * 0.6 + gx * 0.2)
                set_(gx, gy, 'c' if v > 1.1 else 'R' if v > 0.2 else 'r' if v > -0.9 else 'o')
    for tx, ty in LEDGE_TILES:
        for y in range(16):
            for x in range(16):
                gx, gy = tx * 16 + x, ty * 16 + y
                set_(gx, gy, 'd' if _rand('ledge', gx // 3, gy // 2) < 0.7 else 'c')
        for k in range(2):  # an ember crack or two
            x0 = tx * 16 + 2 + int(_rand('lx', tx, ty, k) * 10)
            y0 = ty * 16 + 3 + int(_rand('ly', tx, ty, k) * 10)
            for d in range(3):
                set_(x0 + d, y0 + (d % 2), 'R' if d != 1 else 'o')
    im.save(out)


if __name__ == '__main__':
    out_dir = os.path.join(TILES, 'lairs')
    os.makedirs(out_dir, exist_ok=True)
    background_sheet(os.path.join(TILES, 'volcano', 'volcano_background_tiles.png'),
                     os.path.join(out_dir, 'throne_background_tiles.png'))
    pieces = [('CULTIST_ALTAR', cultist_altar()), ('COOLED_FLOW', cooled_flow()), ('OBSIDIAN_SHRINE', obsidian_shrine()),
              ('CHAINED_EGG', chained_egg()), ('SERVANT_FORGE', servant_forge()), ('EXILE_CHAIN', exile_chain())]
    write_spec(os.path.join(out_dir, 'throne_landmarks.txt'), '''
# Source of throne_landmarks.aseprite and throne_landmarks.png: Throne of Embers' 32x32 landmarks (level 60), four
# blocking 16 px tiles each: a cultist altar, a cooled lava flow, an obsidian shrine, a chained stolen egg, the
# servants' forge, a broken exile chain. Drawn by tools/sprite/parts/lair_throne_art.py.''', THRONE_PAL, (32, 32),
               [(n, 100, [f]) for n, f in pieces])
    write_spec(os.path.join(out_dir, 'throne_spire.txt'), '''
# Source of throne_spire.aseprite and throne_spire.png: an obsidian spire in the caldera, 32x48. Drawn by
# tools/sprite/parts/lair_throne_art.py.''', THRONE_PAL, (32, 48), [('IDLE', 100, [spire()])])
    write_spec(os.path.join(out_dir, 'throne_columns.txt'), '''
# Source of throne_columns.aseprite and throne_columns.png: basalt columns on a ledge, 32x32. Drawn by
# tools/sprite/parts/lair_throne_art.py.''', THRONE_PAL, (32, 32), [('IDLE', 100, [basalt_columns()])])
    write_spec(os.path.join(out_dir, 'throne_hanging_chain.txt'), '''
# Source of throne_hanging_chain.aseprite and throne_hanging_chain.png: an old exile chain sagging between rocks,
# 48x24. Drawn by tools/sprite/parts/lair_throne_art.py.''', THRONE_PAL, (48, 24), [('IDLE', 100, [hanging_chain()])])
    write_spec(os.path.join(out_dir, 'throne_brazier.txt'), '''
# Source of throne_brazier.aseprite and throne_brazier.png: a cultist brazier, 16x16, six frames. Drawn by
# tools/sprite/parts/lair_throne_art.py.''', THRONE_PAL, (16, 16), [('IDLE', 110, brazier_frames())])
    write_spec(os.path.join(out_dir, 'throne_bubble.txt'), '''
# Source of throne_bubble.aseprite and throne_bubble.png: a lava bubble swelling and bursting, 16x16, six frames.
# Drawn by tools/sprite/parts/lair_throne_art.py.''', THRONE_PAL, (16, 16), [('IDLE', 160, bubble_frames())])
    write_spec(os.path.join(out_dir, 'throne_throne.txt'), '''
# Source of throne_throne.aseprite and throne_throne.png: the Ashen Wyrm's throne on the lava with its stolen hoard,
# 96x80. Drawn by tools/sprite/parts/lair_throne_art.py.''', THRONE_PAL, (96, 80), [('IDLE', 100, [throne()])])
    write_spec(os.path.join(out_dir, 'throne_vent.txt'), '''
# Source of throne_vent.aseprite and throne_vent.png: the magma vent, 48x48 (the Ashen Wyrm's spawn art): IDLE
# churning, BOIL the lava heaving up when it rises. Drawn by tools/sprite/parts/lair_throne_art.py.''', THRONE_PAL,
               (48, 48), [('IDLE', 200, vent_frames(False)), ('BOIL', 90, vent_frames(True))])
    write_spec(os.path.join(out_dir, 'throne_castle_chains.txt'), '''
# Source of throne_castle_chains.aseprite and throne_castle_chains.png: the castle bound by the cultists' chains,
# 64x64 over the 48x48 castle (offset 8): IDLE the runes and hot links pulsing, REVEAL (one shot) the chains snapping
# when the Ashen Wyrm rises. Drawn by tools/sprite/parts/lair_throne_art.py.''', THRONE_PAL, (64, 64),
               [('IDLE', 200, chains_idle_frames()), ('REVEAL', 90, chains_reveal_frames())])
    write_sprite_frames('throne_brazier', 16, 16, [('IDLE', 110, 6, True)])
    write_sprite_frames('throne_bubble', 16, 16, [('IDLE', 160, 6, True)])
    write_sprite_frames('throne_vent', 48, 48, [('IDLE', 200, 4, True), ('BOIL', 90, 6, True)])
    write_sprite_frames('throne_castle_chains', 64, 64,
                        [('IDLE', 200, 4, True), ('REVEAL', 90, lair_art.CAMO_REVEAL_FRAMES, False)])
    print('ok')
