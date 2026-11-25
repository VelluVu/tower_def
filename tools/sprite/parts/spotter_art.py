"""The Spotter's art (2026-11-24, the user: "draw it now"): the drakeling (the Bolter's, recoloured per element from
the Bolter's own element sheets) with a brass eyepiece, holding a long arbalest; its heavy bolts.

    python tools/sprite/parts/spotter_art.py tools/sprite/parts assets/art
    then build each written .txt with tools/sprite/sprite.py build; T2/T3 by tower_tiers.py ... spotter

Drakeling sheets (18x34 like every drakeling) go to units/building/puffe/puffe_spotter/<colour>_puffe_spotter.txt:
IDLE 4 (the eyepiece glints), START_ATTACK 4 (the arbalest comes up, the string is drawn, the bolt's head glows in the
element's colour), STOP_ATTACK 5 (the string snaps, the arbalest kicks, the flash fades).
Bolts (16x16, pointing right like every homing bolt: WALK 4 in flight with a streak, DEATH 5 the impact, FADE 4 the
bolt thinning out after a lost target) per element go to projectile/<element>_spotter_bolt.txt.
"""
import math
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, part, write_spec
from mortar_art import COLOUR, ELEMENTS, H, W, Palette, bolter_idle, spec_frame

ART = sys.argv[2]
OUT = os.path.join(ART, 'units', 'building', 'puffe', 'puffe_spotter')
PROJ = os.path.join(ART, 'projectile')

# the bolt's head and glow per element: g light, G mid, R deep
HEAD = {
    'physical': {'g': 'ffffff', 'G': 'c0cbdc', 'R': '5a6988'},
    'fire': {'g': 'fee761', 'G': 'f77622', 'R': 'e43b44'},
    'frost': {'g': 'ffffff', 'G': '2ce8f5', 'R': '0099db'},
    'poison': {'g': 'b6d53c', 'G': 'b55088', 'R': '68386c'},
}
# arbalest: wood R r, steel bow B, string s, iron shaft M; brass eyepiece Y y; the glint w
FIXED = {'R': '733e39', 'r': 'b86f50', 'B': 'c0cbdc', 's': 'ead4aa', 'M': '5a6988', 'Y': 'feae34', 'y': 'b86f50', 'w': 'ffffff'}

# the arbalest pointing right, string drawn back (top-left at the chest)
ARBALEST = part('''
.......B.
......Bs.
rrRMMMMMG
......Bs.
.......B.
''')
ARBALEST_DRAWN = part('''
.......B.
.....sB..
rrRMMMMMg
.....sB..
.......B.
''')
# the string has snapped forward: the bow flexes out
ARBALEST_LOOSED = part('''
........B
.......sB
rrRMMMMM.
.......sB
........B
''')
EYEPIECE = part('''
Y
y
''')
GLINT = part('''
w
''')
FLASH = [part('''
.g.
gGg
.g.
'''), part('''
G
''')]


def eye_row(body):
    """The row of the eyes, 4 under the horn tips: the head moves with the idle's bob."""
    return min(y for (x, y) in body) + 4


def drakeling(element):
    body = bolter_idle(element)
    pal = Palette()
    colours = dict(FIXED, **HEAD[element])

    def frame(i, bow, dx=0, dy=0, extra=()):
        ey = eye_row(body[i])
        placed = [(EYEPIECE, 12, ey, colours), (bow, 7 + dx, ey + 3 + dy, colours)]
        for p, px, py in extra:
            placed.append((p, px, ey + py, colours))
        return spec_frame(body[i], placed, pal)

    idle = [frame(0, ARBALEST), frame(1, ARBALEST), frame(2, ARBALEST, extra=[(GLINT, 12, 0)]), frame(3, ARBALEST)]
    start = [frame(0, ARBALEST), frame(1, ARBALEST, dy=-1), frame(2, ARBALEST_DRAWN, dy=-1),
             frame(3, ARBALEST_DRAWN, dy=-1, extra=[(GLINT, 12, 0)])]
    stop = [frame(0, ARBALEST_LOOSED, dy=-1, extra=[(FLASH[0], 14, 2)]), frame(1, ARBALEST_LOOSED, dx=-1, dy=-1, extra=[(FLASH[1], 16, 2)]),
            frame(2, ARBALEST, dx=-1), frame(3, ARBALEST), frame(0, ARBALEST)]
    name = (COLOUR[element] + '_' if COLOUR[element] else '') + 'puffe_spotter'
    header = ('# Source of %s.aseprite and .png: the %s Spotter drakeling, drawn by tools/sprite/parts/spotter_art.py\n'
              '# (the Bolter drakeling of this element with a brass eyepiece and a long arbalest). Same canvas and tags as the\n'
              '# other drakelings.' % (name, element))
    path = os.path.join(OUT, name + '.txt')
    write_spec(path, header, pal.lines(), (W, H), [('IDLE', 100, idle), ('START_ATTACK', 100, start), ('STOP_ATTACK', 100, stop)])
    return path


BOLT = 16
# the bolt pointing right: fletching f F, shaft M D, head in the element (top-left at (2, 6))
BOLT_SHAPE = part('''
FF........gG.
.fMMMMMMMMGgR
FF........GR.
''')
STREAKS = [part('''
.
G
'''), part('''
R
.
'''), part('''
.
R
'''), part('''
G
.
''')]
BOLT_FIXED = {'F': 'e4a672', 'f': 'b86f50', 'M': '8b9bb4', 'D': '5a6988'}


def bolt(element):
    colours = dict(BOLT_FIXED, **HEAD[element])
    pal = Palette()

    def k(ch):
        return pal.key(colours[ch])

    walk = []
    for i in range(4):
        frame = Frame(BOLT, BOLT)
        frame.stamp([(x, y, k(ch)) for x, y, ch in BOLT_SHAPE], 2, 6)
        # a short streak of the element trailing behind the fletching
        frame.stamp([(x, y, k(ch)) for x, y, ch in STREAKS[i]], 1, 6)
        walk.append(frame)
    # the impact at the head: a burst that opens to a ring of sparks
    death = []
    cx, cy = 12, 7
    for step, radius in enumerate((1.5, 2.6, 3.6, 4.4, 5.0)):
        frame = Frame(BOLT, BOLT)
        for y in range(1, BOLT - 1):
            for x in range(1, BOLT - 1):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d > radius:
                    continue
                if step >= 3 and (d < radius - 1.2 or (x + y) % 2):
                    continue
                key = 'g' if d < radius * 0.45 else 'G' if d < radius * 0.8 else 'R'
                frame.px[(x, y)] = k(key)
        if step < 2:
            frame.stamp([(x, y, k(ch)) for x, y, ch in BOLT_SHAPE if x < 9], 2 - step, 6)
        death.append(frame)
    # a lost target: the bolt flies on and thins out
    fade = []
    for step in range(4):
        frame = Frame(BOLT, BOLT)
        for x, y, ch in BOLT_SHAPE:
            if step and (x + y + step) % (4 - step + 1) == 0:
                continue
            if step == 3 and (x + y) % 2:
                continue
            frame.px[(x + 2, y + 6)] = k(ch)
        fade.append(frame)
    name = '%s_spotter_bolt' % element
    path = os.path.join(PROJ, name + '.txt')
    write_spec(path, '# Source of %s.aseprite and .png: the %s Spotter\'s heavy bolt, pointing right '
               '(tools/sprite/parts/spotter_art.py).' % (name, element), pal.lines(), (BOLT, BOLT),
               [('WALK', 80, walk), ('DEATH', 70, death), ('FADE', 80, fade)])
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    written = []
    for element in ELEMENTS:
        written.append(drakeling(element))
        written.append(bolt(element))
    for path in written:
        print('python tools/sprite/sprite.py build %s %s' % (path.replace('\\', '/'), path[:-4].replace('\\', '/') + '.aseprite'))


if __name__ == '__main__':
    main()
