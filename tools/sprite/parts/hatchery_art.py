"""The Hatchery's art (2026-11-25, the user: "draw now"): the brooding drakeling (the Bolter's, recoloured per element
from the Bolter's own element sheets) on a twig nest with a clutch of eggs; its guard hatchlings.

    python tools/sprite/parts/hatchery_art.py tools/sprite/parts assets/art
    then build each written .txt with tools/sprite/sprite.py build; T2/T3 by tower_tiers.py ... hatchery

Drakeling sheets (18x34 like every drakeling) go to units/building/puffe/puffe_hatchery/<colour>_puffe_hatchery.txt:
IDLE 4 (the eggs rock now and then), START_ATTACK 4 (the middle egg shakes and cracks), STOP_ATTACK 5 (it bursts,
shell bits fly, a fresh egg settles in). The Hatchery plays START_ATTACK then STOP_ATTACK when a guard hatches.
Guards (18x18 like the small enemies, facing right, feet on rows 15-16) per element go to
units/building/puffe/puffe_hatchery/<colour>_hatchery_guard.txt: a stocky, vitamin-pumped hatchling with a gold
sweatband: IDLE 4 (breathing, the band's knot flutters), WALK 4, ATTACK 4 (wind-up, a claw swipe), DEATH 5 (it keels
over and flattens out), HATCH 5 (an egg rocks, cracks and the hatchling pops out with shell bits at its feet).
"""
import math
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, part, squash, write_spec
from mortar_art import COLOUR, ELEMENTS, H, W, Palette, bolter_idle, spec_frame

ART = sys.argv[2]
OUT = os.path.join(ART, 'units', 'building', 'puffe', 'puffe_hatchery')

# the drakelings' own ramps, dark to light (read from the Bolter's element sheets), and a pale belly
RAMP = {
    'physical': ['107338', '0b9b55', '06c374', '02eb93', '2effb8', '68ffd0', 'a2f6db', 'effffa'],
    'fire': ['461a29', '5d1d2c', '74202e', '8b2330', 'a22633', 'c3303b', 'e43b44', 'f6757a'],
    'frost': ['1a4637', '1d5d4e', '207466', '238b7e', '26a295', '30c3b8', '3be4db', '75f6f1'],
    'poison': ['333d23', '3d502a', '476331', '507638', '5b893f', '6ca54e', '7ec15e', 'a7dc8f'],
}
BELLY = {'physical': 'effffa', 'fire': 'f1e0e1', 'frost': 'e0f1f0', 'poison': 'e7eee3'}
# the eggs: shell light, mid, shade and spots, picked to stand out on their own drakeling: gold for the mint one,
# ember-cracked charcoal for Fire, snow white for Frost, purple for Poison
EGG = {
    'physical': {'E': 'fee761', 'e': 'feae34', 's': 'f77622', 'p': '0b9b55'},
    'fire': {'E': '8b9bb4', 'e': '5a6988', 's': '3a4466', 'p': 'f77622'},
    'frost': {'E': 'ffffff', 'e': 'c0cbdc', 's': '8b9bb4', 'p': '0099db'},
    'poison': {'E': 'b55088', 'e': '68386c', 's': '45254f', 'p': 'b6d53c'},
}
# the nest: dark twig T, twig t, straw w; the crack k
NEST_COLOURS = {'T': '733e39', 't': 'b86f50', 'w': 'e4a672', 'k': '3e2731'}
# guard extras: horn n N, eye white x, pupil o, gold band y Y, claws c
GUARD_FIXED = {'n': 'ead4aa', 'N': 'b86f50', 'x': 'ffffff', 'o': '181425', 'y': 'feae34', 'Y': 'f77622', 'c': 'ead4aa'}

NEST = part('''
..t.TtT.tTw.t...
.TtwtTwtTtwTwtT.
TtTtwTtTtwtTtwTt
.TTtTTwTTtTTtTT.
''')
NEST_AT = (1, 21)
# one egg, 4x5, its top-left on the nest's top row minus 4
EGG_SHAPE = part('''
.Ee.
EEep
eEes
.ss.
''')
EGG_CRACKED = part('''
.Ek.
EkEp
eEks
.ss.
''')
EGG_OPEN = part('''
E..e
e..s
.ss.
''')
EGGS_X = (3, 7, 11)
EGG_Y = NEST_AT[1] - 3
SHELL_BITS = [part('''
E...e
.....
e...E
'''), part('''
E.....e
.......
.......
e.....E
''')]


def nest_stamps(colours, middle='whole', middle_dx=0, side_dx=(0, 0)):
    """The nest and its three eggs; the middle one whole, cracked, open or gone."""
    stamps = []
    for i, x in enumerate(EGGS_X):
        if i == 1:
            shape = {'whole': EGG_SHAPE, 'cracked': EGG_CRACKED, 'open': EGG_OPEN}.get(middle)
            if shape is None:
                continue
            stamps.append((shape, x + middle_dx, EGG_Y + (1 if middle == 'open' else 0), colours))
        else:
            stamps.append((EGG_SHAPE, x + side_dx[0 if i == 0 else 1], EGG_Y, colours))
    stamps.append((NEST, NEST_AT[0], NEST_AT[1], colours))
    return stamps


def drakeling(element):
    body = bolter_idle(element)
    pal = Palette()
    colours = dict(NEST_COLOURS, **EGG[element])

    def frame(i, **kw):
        extra = kw.pop('extra', [])
        return spec_frame(body[i], nest_stamps(colours, **kw) + extra, pal)

    idle = [frame(0), frame(1, side_dx=(0, 1)), frame(2), frame(3, side_dx=(-1, 0))]
    start = [frame(0, middle_dx=1), frame(1, middle_dx=-1), frame(2, middle='cracked', middle_dx=1),
             frame(3, middle='cracked', middle_dx=-1)]
    stop = [frame(0, middle='open', extra=[(SHELL_BITS[0], 6, EGG_Y - 2, colours)]),
            frame(1, middle='open', extra=[(SHELL_BITS[1], 5, EGG_Y - 3, colours)]),
            frame(2, middle='gone'),
            frame(3, middle='gone'),
            frame(0)]
    name = (COLOUR[element] + '_' if COLOUR[element] else '') + 'puffe_hatchery'
    header = ('# Source of %s.aseprite and .png: the %s Hatchery drakeling, drawn by tools/sprite/parts/hatchery_art.py\n'
              '# (the Bolter drakeling of this element brooding a clutch of eggs on a twig nest). Same canvas and tags as the\n'
              '# other drakelings.' % (name, element))
    path = os.path.join(OUT, name + '.txt')
    write_spec(path, header, pal.lines(), (W, H), [('IDLE', 140, idle), ('START_ATTACK', 90, start), ('STOP_ATTACK', 100, stop)])
    return path


GW, GH = 18, 18
LIGHT = (-0.6, -0.75)


def shade(nx, ny, depth):
    """A ramp index 1-6 for a point of an ellipse: lit from the top left, rounder toward the middle."""
    v = 0.32 + 0.6 * (LIGHT[0] * nx + LIGHT[1] * ny) + 0.3 * depth
    return max(1, min(6, int(round(1 + v * 5))))


def blob(px, cx, cy, rx, ry, keys, belly=None):
    """Fills a shaded ellipse into px ((x, y) -> key); belly (a test on x, y) paints the pale belly over it."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = nx * nx + ny * ny
            if d > 1.0:
                continue
            key = keys[shade(nx, ny, math.sqrt(1.0 - d))]
            # the rim on the shadow side
            if d > 0.62 and nx + ny > 0.35:
                key = keys[1]
            if belly is not None and belly(x, y) and d < 0.8:
                key = 'b'
            px[(x, y)] = key


def guard_pose(lean=0, bob=0, arm='rest', legs=0, knot=0, blink=False):
    """One guard frame as (x, y) -> key, facing right. lean shifts the head and arm forward, bob the whole upper body."""
    px = {}
    k = [str(i) for i in range(8)]
    # tail, behind: three cells curling down to the ground
    for x, y in ((3, 13 + bob), (2, 14 + bob), (2, 15), (3, 12 + bob)):
        px[(x, y)] = k[2]
    px[(1, 15)] = k[1]
    # legs: back and front, the feet on row 16 (legs 1/2 step apart for the walk)
    back, front = [(6, 14), (6, 15), (5, 16), (6, 16)], [(10, 14), (10, 15), (10, 16), (11, 16)]
    if legs == 1:
        back, front = [(6, 14), (5, 15), (4, 16), (5, 16)], [(10, 14), (11, 15), (11, 16), (12, 16)]
    elif legs == 2:
        back, front = [(6, 14), (7, 15), (7, 16), (8, 16)], [(10, 14), (9, 15), (8, 16), (9, 16)]
    for x, y in back:
        px[(x, y)] = k[1]
    # body: a stocky barrel, belly to the front
    blob(px, 8.0, 11.5 + bob, 4.0, 3.6, k, belly=lambda x, y: x >= 9 and y >= 11 + bob)
    for x, y in front:
        px[(x, y)] = k[2] if y < 16 else k[1]
    # the folded wing on the back
    for x, y, c in ((4, 8, 1), (5, 8, 2), (3, 9, 1), (4, 9, 3), (5, 9, 2), (4, 10, 2), (3, 10, 1)):
        px[(x, y + bob)] = k[c]
    # head: big and round, a short snout to the right
    hx, hy = 11.5 + lean, 6.0 + bob
    blob(px, hx, hy, 3.3, 3.0, k)
    sx = int(hx + 3)
    for x, y, c in ((sx, int(hy) + 1, 4), (sx + 1, int(hy) + 1, 3), (sx, int(hy) + 2, 2), (sx + 1, int(hy) + 2, 1)):
        px[(x, y)] = k[c]
    # nostril
    px[(sx + 1, int(hy))] = k[2]
    # horns
    hy0 = int(hy - 3)
    for x, y, c in ((int(hx) - 1, hy0, 'N'), (int(hx) - 2, hy0 - 1, 'n'), (int(hx) + 1, hy0, 'N'), (int(hx) + 1, hy0 - 1, 'n')):
        px[(x, y)] = c
    # the gold sweatband across the brow, its knot fluttering behind
    for x in range(int(hx) - 2, int(hx) + 3):
        px[(x, hy0 + 2)] = 'y'
    px[(int(hx) - 3, hy0 + 2)] = 'Y'
    px[(int(hx) - 4, hy0 + 2 + knot)] = 'Y'
    px[(int(hx) - 4, hy0 + 3 + knot)] = 'y'
    # eye: white with the pupil to the front (a blink is a line)
    ex, ey = int(hx) + 1, hy0 + 3
    if blink:
        px[(ex, ey)] = k[1]
        px[(ex + 1, ey)] = k[1]
    else:
        px[(ex, ey)] = 'x'
        px[(ex + 1, ey)] = 'o'
    # the arm: a big bicep, the forearm and claws
    if arm == 'rest':
        cells = [(10, 10, 5), (11, 10, 4), (11, 11, 3), (12, 12, 3)]
        claws = [(13, 12), (13, 13)]
    elif arm == 'raise':
        cells = [(10, 10, 5), (11, 9, 5), (12, 8, 4), (12, 7, 3)]
        claws = [(13, 6), (12, 6)]
    else:
        # the swipe: the arm thrown forward and down, claws far out
        cells = [(10, 10, 5), (11, 10, 5), (12, 11, 4), (13, 11, 3), (14, 12, 3)]
        claws = [(15, 11), (15, 12), (15, 13)]
    for x, y, c in cells:
        px[(x + lean, y + bob)] = k[c]
    for x, y in claws:
        px[(x + lean, y + bob)] = 'c'
    return {p: c for p, c in px.items() if 1 <= p[0] <= GW - 2 and 1 <= p[1] <= GH - 2}


def to_frame(px, colours, pal):
    frame = Frame(GW, GH)
    for (x, y), c in px.items():
        frame.px[(x, y)] = pal.key(colours[c])
    return frame


def guard(element):
    pal = Palette()
    colours = {str(i): c for i, c in enumerate(RAMP[element])}
    colours.update(GUARD_FIXED)
    colours['b'] = BELLY[element]
    colours.update(EGG[element])
    colours['k'] = NEST_COLOURS['k']

    def f(**kw):
        return to_frame(guard_pose(**kw), colours, pal)

    idle = [f(), f(bob=0, knot=1), f(bob=1, knot=1), f(bob=0, blink=True)]
    walk = [f(legs=1), f(legs=0, bob=1, knot=1), f(legs=2), f(legs=0, bob=1, knot=1)]
    attack = [f(lean=-1, arm='raise'), f(lean=-1, arm='raise', bob=-1), f(lean=1, arm='swipe'), f(lean=0, arm='rest', knot=1)]
    # death: tips back, then flattens out on the ground and thins away
    base = to_frame(guard_pose(), colours, pal)
    tipped = to_frame(guard_pose(lean=-1, bob=1, blink=True), colours, pal)
    death = [tipped, squash(tipped, 0.75), squash(tipped, 0.5, dx=-1), squash(tipped, 0.3, dx=-1)]
    last = squash(tipped, 0.3, dx=-1)
    last.px = {p: c for p, c in last.px.items() if (p[0] + p[1]) % 2 == 0}
    death.append(last)
    # hatch: an egg on the ground rocks, cracks, opens; the hatchling stands up out of the shell
    def egg(shape, dx=0, dy=0):
        frame = Frame(GW, GH)
        big = [(x * 2 + ox, y * 2 + oy, c) for x, y, c in shape for ox in (0, 1) for oy in (0, 1)]
        frame.stamp([(x, y, pal.key(colours[c])) for x, y, c in big], 5 + dx, 8 + dy)
        return frame
    hatch = [egg(EGG_SHAPE), egg(EGG_SHAPE, dx=1), egg(EGG_CRACKED, dx=-1), egg(EGG_OPEN, dy=2)]
    out = Frame(GW, GH)
    out.px = dict(base.px)
    for x, y in ((3, 16), (4, 15), (13, 16), (14, 15)):
        out.px[(x, y)] = pal.key(colours['E'])
    hatch.append(out)
    name = (COLOUR[element] + '_' if COLOUR[element] else '') + 'hatchery_guard'
    header = ('# Source of %s.aseprite and .png: the %s Hatchery guard, a vitamin-pumped hatchling with a gold sweatband,\n'
              '# drawn by tools/sprite/parts/hatchery_art.py. Faces right, feet on rows 15-16 like the small enemies.' % (name, element))
    path = os.path.join(OUT, name + '.txt')
    write_spec(path, header, pal.lines(), (GW, GH), [('IDLE', 160, idle), ('WALK', 110, walk), ('ATTACK', 90, attack),
                                                     ('DEATH', 110, death), ('HATCH', 120, hatch)])
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    written = []
    for element in ELEMENTS:
        written.append(drakeling(element))
        written.append(guard(element))
    for path in written:
        print('python tools/sprite/sprite.py build %s %s' % (path.replace('\\', '/'), path[:-4].replace('\\', '/') + '.aseprite'))


if __name__ == '__main__':
    main()
