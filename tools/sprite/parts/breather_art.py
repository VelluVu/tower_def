"""The Breather's art (2026-11-24, the user: "draw it now"): the drakeling (the Bolter's, recoloured per element from
the Bolter's own element sheets) with a bronze gorget, breathing its element; the puffs its breath is made of.

    python tools/sprite/parts/breather_art.py tools/sprite/parts assets/art
    then build each written .txt with tools/sprite/sprite.py build; T2/T3 by tower_tiers.py ... breather

Drakeling sheets (18x34 like every drakeling) go to units/building/puffe/puffe_breather/<colour>_puffe_breather.txt:
IDLE 4 (a wisp curls from the nostrils), START_ATTACK 4 (it breathes in: the cheeks and the throat swell and glow),
ATTACK 3 (the jaw hangs open, the element blazes in the mouth and spills out), STOP_ATTACK 5 (the jaw shuts, smoke
rises from the nostrils). Puffs (10x10, FLY 5: a small puff swells, then thins out and fades) per element go to
projectile/<element>_breath_puff.txt.
"""
import math
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, part, write_spec
from mortar_art import COLOUR, ELEMENTS, H, W, Palette, bolter_idle, spec_frame

ART = sys.argv[2]
OUT = os.path.join(ART, 'units', 'building', 'puffe', 'puffe_breather')
PROJ = os.path.join(ART, 'projectile')

# the breath's colours in the mouth: g brightest, G mid, R deep; K the open mouth's dark; the gorget's bronze B b, D
BREATH = {
    'physical': {'g': 'ffffff', 'G': 'c0cbdc', 'R': '8b9bb4'},
    'fire': {'g': 'fee761', 'G': 'f77622', 'R': 'e43b44'},
    'frost': {'g': 'ffffff', 'G': '2ce8f5', 'R': '0099db'},
    'poison': {'g': 'b6d53c', 'G': 'b55088', 'R': '68386c'},
}
FIXED = {'K': '181425', 'B': 'b86f50', 'b': 'feae34', 'D': '733e39', 's': 'c0cbdc', 'S': '8b9bb4'}

# the gorget across the chest (its top-left 5 rows under the eyes, 1 left of the mouth)
GORGET = part('''
.bBBBBD.
bBDDDDBD
''')
# the open jaw, top-left at the mouth's left end
JAW_OPEN = [part('''
KgGK
KGgK
.RR.
'''), part('''
KGgK
KgGK
.GR.
'''), part('''
KggK
KGGK
.RG.
''')]
# the breath spilling out under the jaw (left in the sprite; the puffs carry it to the target)
SPILL = [part('''
.G.
GRG
'''), part('''
G.G
.R.
'''), part('''
.R.
G.G
''')]
# the throat swelling while it breathes in, by step
THROAT = [part('''
.RR.
'''), part('''
.GG.
RGGR
'''), part('''
.gg.
GggG
.RR.
''')]
# smoke wisps from the nostrils, rising
WISPS = [part('''
s.s
.S.
'''), part('''
.s.
s.s
'''), part('''
s.
.s
'''), part('''
.s
''')]


def eye_row(body):
    """The row of the eyes, 4 under the horn tips: the head moves with the idle's bob."""
    return min(y for (x, y) in body) + 4


def drakeling(element):
    body = bolter_idle(element)
    pal = Palette()
    colours = dict(FIXED, **BREATH[element])

    def frame(i, stamps):
        ey = eye_row(body[i])
        mouth = (7, ey + 2)
        placed = [(GORGET, 5, ey + 5, colours)]
        for p, dx, dy in stamps:
            placed.append((p, mouth[0] + dx, mouth[1] + dy, colours))
        return spec_frame(body[i], placed, pal)

    idle = [frame(0, []), frame(1, []), frame(2, [(WISPS[2], 1, -3)]), frame(3, [(WISPS[3], 2, -4)])]
    # breathing in: the throat swells and glows under the jaw
    start = [frame(0, []), frame(1, [(THROAT[0], 0, 3)]), frame(2, [(THROAT[1], 0, 3)]), frame(3, [(THROAT[2], 0, 3)])]
    attack = [frame(i, [(JAW_OPEN[i], 0, 0), (SPILL[i], 1 if i != 1 else 1, 3)]) for i in range(3)]
    stop = [frame(0, [(WISPS[0], 0, -2)]), frame(1, [(WISPS[1], 0, -3)]), frame(2, [(WISPS[1], 1, -4)]),
            frame(3, [(WISPS[2], 1, -5)]), frame(0, [(WISPS[3], 2, -6)])]
    name = (COLOUR[element] + '_' if COLOUR[element] else '') + 'puffe_breather'
    header = ('# Source of %s.aseprite and .png: the %s Breather drakeling, drawn by tools/sprite/parts/breather_art.py\n'
              '# (the Bolter drakeling of this element with a bronze gorget, breathing its element). Same canvas and tags as the\n'
              '# other drakelings.' % (name, element))
    path = os.path.join(OUT, name + '.txt')
    write_spec(path, header, pal.lines(), (W, H),
               [('IDLE', 100, idle), ('START_ATTACK', 100, start), ('ATTACK', 80, attack), ('STOP_ATTACK', 100, stop)])
    return path


PUFF = 10
# light, mid, deep, dark: flame / frost mist / acid gas with purple fumes (green alone vanishes on grass) / a roar's dust
PUFF_COLOURS = {
    'physical': ['ffffff', 'c0cbdc', '8b9bb4', '5a6988'],
    'fire': ['fee761', 'feae34', 'f77622', 'e43b44'],
    'frost': ['ffffff', '2ce8f5', '0099db', '124e89'],
    'poison': ['b6d53c', '63c74d', 'b55088', '68386c'],
}
# per frame: radius, and whether it has thinned to a checkerboard
PUFF_STEPS = [(1.5, False), (2.6, False), (3.5, False), (3.8, True), (2.6, True)]


def breath_puff(element):
    colours = PUFF_COLOURS[element]
    pal = Palette()
    frames = []
    c = PUFF / 2.0
    for step, (radius, thin) in enumerate(PUFF_STEPS):
        frame = Frame(PUFF, PUFF)
        for y in range(1, PUFF - 1):
            for x in range(1, PUFF - 1):
                dx, dy = x + 0.5 - c, y + 0.5 - c
                d = math.hypot(dx, dy)
                # a ragged edge, so the puffs do not read as balls
                edge = radius * (1.0 + 0.18 * math.sin(4 * math.atan2(dy, dx) + step))
                if d > edge:
                    continue
                if thin and (x + y) % 2:
                    continue
                # lit at the top left, cooling to the bottom right and as it fades
                t = d / edge + 0.25 * (dx + dy) / max(radius, 1) + 0.18 * step
                key = colours[0] if t < 0.45 else colours[1] if t < 0.8 else colours[2] if t < 1.1 else colours[3]
                frame.px[(x, y)] = pal.key(key)
        frames.append(frame)
    name = '%s_breath_puff' % element
    path = os.path.join(PROJ, name + '.txt')
    write_spec(path, '# Source of %s.aseprite and .png: one puff of the %s Breather\'s breath (tools/sprite/parts/breather_art.py).'
               % (name, element), pal.lines(), (PUFF, PUFF), [('FLY', 80, frames)])
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    written = []
    for element in ELEMENTS:
        written.append(drakeling(element))
        written.append(breath_puff(element))
    for path in written:
        print('python tools/sprite/sprite.py build %s %s' % (path.replace('\\', '/'), path[:-4].replace('\\', '/') + '.aseprite'))


if __name__ == '__main__':
    main()
