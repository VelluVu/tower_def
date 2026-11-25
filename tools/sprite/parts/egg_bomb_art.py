"""The Egg Bomb's art (2026-11-25, the user: "draw now"): a big speckled egg with a fuse in a pebble scrape, per element.

    python tools/sprite/parts/egg_bomb_art.py tools/sprite/parts assets/art
    then build each written .txt with tools/sprite/sprite.py build

Sheets (20x20 like the Leopard Trap, the egg's foot near the bottom) go to
units/building/egg_bomb/<element>_egg_bomb.txt:
IDLE 4 (the speckles glint, the egg breathes a pixel), START_ATTACK 6 (the lit fuse burns down, the egg shakes and its
cracks glow; played over the 0.6 s fuse), ATTACK 3 (the shell bursts apart; the blast itself is the Mortar's element
blast), REBUILD 8 (a scorched scrape, then the shell grows back up piece by piece; EggBomb shows the frame for how far
the rebuild has come). T2 and T3 sheets (<element>_egg_bomb_t2/_t3) add a pebble ring in the element's colour and, at
T3, a gold band round the egg.
"""
import math
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, write_spec
from mortar_art import ELEMENTS, Palette

ART = sys.argv[2]
OUT = os.path.join(ART, 'units', 'building', 'egg_bomb')
W = H = 20

# shell light, mid, shade, dark rim, speckle; the crack glow (hot, bright); Physical is Puffe's mint (tan vanished on sand)
SHELL = {
    'physical': {'E': 'a2f6db', 'e': '2effb8', 's': '06c374', 'r': '107338', 'p': '107338', 'g': 'feae34', 'G': 'fee761'},
    'fire': {'E': 'f6757a', 'e': 'e43b44', 's': 'a22633', 'r': '5d1d2c', 'p': '5d1d2c', 'g': 'f77622', 'G': 'fee761'},
    'frost': {'E': 'ffffff', 'e': 'c0cbdc', 's': '8b9bb4', 'r': '5a6988', 'p': '0099db', 'g': '2ce8f5', 'G': 'ffffff'},
    'poison': {'E': 'b6d53c', 'e': '63c74d', 's': '3e8948', 'r': '265c42', 'p': '68386c', 'g': 'b55088', 'G': 'f6757a'},
}
# pebbles, dirt scrape, scorch, the fuse cord and its spark; the tier rings and band
FIXED = {'P': '8b9bb4', 'Q': '5a6988', 'q': '3a4466', 'd': 'b86f50', 'D': '733e39', 'k': '262b44', 'K': '3e2731',
         'c': 'b86f50', 'C': '733e39', 'x': 'ffffff', 'y': 'fee761', 'o': 'f77622', 'B': 'feae34', 'b': 'b86f50'}
RING = {'physical': ('c0cbdc', 'ffffff'), 'fire': ('f77622', 'fee761'), 'frost': ('2ce8f5', 'ffffff'), 'poison': ('b55088', 'b6d53c')}

EGG_CX, EGG_CY, EGG_RX, EGG_RY = 10.0, 10.0, 4.2, 5.2
EGG_BOTTOM = int(EGG_CY + EGG_RY)
LIGHT = (-0.6, -0.75)
# speckles on the shell, relative to the centre
SPECKS = [(-2, -3), (1, -2), (2, 1), (-1, 2), (-3, 0), (1, 4), (3, -1)]
# the cracks that glow before the burst, relative to the centre
CRACKS = [[(0, -4), (0, -3), (1, -2), (0, -1)], [(-2, 0), (-1, 1), (-2, 2)], [(2, 1), (3, 2), (2, 3)]]
# the fuse from the egg's top upward, its spark at the tip
FUSE = [(10, 4), (10, 3), (11, 2)]


def nest(frame, k, scorched=False):
    """The scrape: a dirt dip with pebbles round it (scorched black after a blast)."""
    for x in range(4, 16):
        frame.px[(x, 16)] = k('K' if scorched else 'D')
    for x in range(6, 14):
        frame.px[(x, 15)] = k('k' if scorched else 'd')
    for x, y, c in ((3, 16, 'Q'), (4, 15, 'P'), (5, 17, 'q'), (7, 17, 'Q'), (9, 17, 'P'), (11, 17, 'Q'), (13, 17, 'q'),
                    (15, 15, 'P'), (16, 16, 'Q'), (14, 17, 'P')):
        frame.px[(x, y)] = k(c)


def egg(frame, k, dx=0, dy=0, grow=1.0, glow=0, specks=True, rim_glint=None):
    """The shell, lit from the top left; grow < 1 is a shell still rebuilding (only its lower part)."""
    top = EGG_BOTTOM - (EGG_RY * 2) * grow
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            nx, ny = (x + 0.5 - EGG_CX - dx) / EGG_RX, (y + 0.5 - EGG_CY - dy) / EGG_RY
            # an egg: narrower at the top
            nx *= 1.0 + 0.18 * max(0.0, -ny)
            d = nx * nx + ny * ny
            if d > 1.0 or y < top + dy:
                continue
            v = 0.45 + 0.6 * (LIGHT[0] * nx + LIGHT[1] * ny) + 0.25 * math.sqrt(1.0 - d)
            key = 'E' if v > 0.75 else 'e' if v > 0.4 else 's'
            if d > 0.7 and nx + ny > 0.45:
                key = 'r'
            frame.px[(x, y)] = k(key)
    if specks:
        for sx, sy in SPECKS:
            p = (int(EGG_CX + sx + dx), int(EGG_CY + sy + dy))
            if p in frame.px and p[1] >= top + dy + 1:
                frame.px[p] = k('p')
    for n in range(glow):
        for cx, cy in CRACKS[n % len(CRACKS)]:
            p = (int(EGG_CX + cx + dx), int(EGG_CY + cy + dy))
            if p in frame.px:
                frame.px[p] = k('G' if n == glow - 1 else 'g')
    if rim_glint:
        frame.px[rim_glint] = k('x')


def fuse(frame, k, length, spark):
    """The cord burnt down to length cells; the spark at its tip (two frames)."""
    cells = FUSE[:length]
    for i, (x, y) in enumerate(cells):
        frame.px[(x, y)] = k('c' if i % 2 else 'C')
    if spark is not None and cells:
        x, y = cells[-1]
        for sx, sy, c in ((0, -1, 'y'), (1, -1, 'x'), (-1, 0, 'o'), (1, 0, 'y')) if spark == 0 else ((0, -1, 'x'), (-1, -1, 'y'), (1, 0, 'o')):
            if 1 <= x + sx <= W - 2 and 1 <= y + sy <= H - 2:
                frame.px[(x + sx, y + sy)] = k(c)


def tier_marks(frame, k, tier, phase):
    if tier >= 2:
        light, dark = 'T', 't'
        for i, (x, y) in enumerate(((3, 16), (5, 17), (9, 17), (13, 17), (16, 16), (4, 15), (15, 15))):
            frame.px[(x, y)] = k(light if (i + phase) % 3 == 0 else dark)
    if tier >= 3:
        for x in range(6, 15):
            y = int(EGG_CY + 1)
            if (x, y) in frame.px:
                frame.px[(x, y)] = k('B' if (x + phase) % 3 else 'b')


def sheet(element, tier):
    pal = Palette()
    colours = dict(FIXED, **SHELL[element])
    colours['T'], colours['t'] = RING[element][1], RING[element][0]

    def k(ch):
        return pal.key(colours[ch])

    def base(phase=0, **kw):
        f = Frame(W, H)
        nest(f, k, scorched=kw.pop('scorched', False))
        if kw.pop('with_egg', True):
            egg(f, k, **kw)
            tier_marks(f, k, tier, phase)
        return f

    idle = []
    for i in range(4):
        f = base(phase=i, dy=1 if i == 2 else 0, rim_glint=(8, 7) if i == 1 else None)
        fuse(f, k, 3, None)
        idle.append(f)
    start = []
    for i in range(6):
        shake = (0, 1, 0, -1, 1, -1)[i]
        f = base(phase=i, dx=shake if i >= 2 else 0, glow=min(3, i // 2 + (1 if i >= 3 else 0)))
        fuse(f, k, 3 - i // 2, i % 2)
        start.append(f)
    # the burst: the shell splits into pieces flying out, a flash in the middle
    attack = []
    for i, spread in enumerate((1, 3, 5)):
        f = Frame(W, H)
        nest(f, k, scorched=True)
        for cx, cy, c in ((-2, -3, 'E'), (2, -3, 'e'), (-3, 1, 'e'), (3, 1, 's'), (-1, 3, 's'), (2, 4, 'r'), (0, -5, 'E')):
            px, py = int(EGG_CX + cx * (1 + spread * 0.45)), int(EGG_CY + cy * (1 + spread * 0.3))
            if 1 <= px <= W - 2 and 1 <= py <= H - 2:
                f.px[(px, py)] = k(c)
                if spread < 5 and 1 <= px + 1 <= W - 2:
                    f.px[(px + 1, py)] = k(c)
        if i < 2:
            for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 0), (0, -1)):
                f.px[(int(EGG_CX) + dx, int(EGG_CY) + dy)] = k('G' if (dx, dy) == (0, 0) else 'g')
        attack.append(f)
    # the rebuild: a scorched scrape, a few shell bits, then the egg growing from its foot up
    rebuild = []
    for i in range(8):
        grow = [0.0, 0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0][i]
        f = base(phase=i, scorched=i < 3, with_egg=grow > 0.0, grow=grow, specks=grow > 0.6)
        if grow == 0.0:
            for x, y, c in ((8, 14, 'e'), (12, 14, 's'), (10, 13, 'E')) if i == 1 else ((9, 15, 'K'), (11, 15, 'K')):
                f.px[(x, y)] = k(c)
        if grow == 1.0:
            fuse(f, k, 3, None)
        rebuild.append(f)
    name = '%s_egg_bomb%s' % (element, '' if tier == 1 else '_t%d' % tier)
    header = ('# Source of %s.aseprite and .png: the %s Egg Bomb%s, drawn by tools/sprite/parts/egg_bomb_art.py.\n'
              '# 20x20 like the Leopard Trap.' % (name, element, '' if tier == 1 else ' at T%d' % tier))
    path = os.path.join(OUT, name + '.txt')
    write_spec(path, header, pal.lines(), (W, H), [('IDLE', 180, idle), ('START_ATTACK', 100, start), ('ATTACK', 80, attack),
                                                   ('REBUILD', 200, rebuild)])
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    written = [sheet(e, t) for e in ELEMENTS for t in (1, 2, 3)]
    for path in written:
        print('python tools/sprite/sprite.py build %s %s' % (path.replace('\\', '/'), path[:-4].replace('\\', '/') + '.aseprite'))


if __name__ == '__main__':
    main()
