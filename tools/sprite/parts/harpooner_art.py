"""The Harpooner's art (2026-11-24, the user: "draw it now"): the drakeling (the Bolter's, recoloured per element from
the Bolter's own element sheets) with a heavy harpoon gun and a coil of chain under it; its barbed harpoons.

    python tools/sprite/parts/harpooner_art.py tools/sprite/parts assets/art
    then build each written .txt with tools/sprite/sprite.py build; T2/T3 by tower_tiers.py ... harpooner

Drakeling sheets (18x34 like every drakeling) go to units/building/puffe/puffe_harpooner/<colour>_puffe_harpooner.txt:
IDLE 4 (the chain coil sways), START_ATTACK 4 (the gun comes up, the barbs glow in the element's colour), STOP_ATTACK 5
(the harpoon is gone, the gun kicks, the chain pays out from the muzzle, then a new harpoon is loaded).
Harpoons (16x16, pointing right like every homing bolt: WALK 4 in flight, the chain rattling behind, DEATH 5 the barbs
biting in, FADE 4 the harpoon thinning out after a lost target) per element go to projectile/<element>_harpoon.txt.
The chain between a tethered enemy and the tower is drawn in code (HarpoonTether).
"""
import math
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, part, write_spec
from mortar_art import COLOUR, ELEMENTS, H, W, Palette, bolter_idle, spec_frame
from spotter_art import HEAD, eye_row

ART = sys.argv[2]
OUT = os.path.join(ART, 'units', 'building', 'puffe', 'puffe_harpooner')
PROJ = os.path.join(ART, 'projectile')

# harpoon gun: wood stock W w, iron barrel M D, chain c C (light, dark); the barbed head in the element (g G R)
FIXED = {'W': '733e39', 'w': 'b86f50', 'M': '5a6988', 'D': '3a4466', 'c': 'c0cbdc', 'C': '8b9bb4'}

# the gun pointing right, loaded: the barbed head sticks out of the barrel (top-left at the chest)
GUN = part('''
.........G.
wwWMMMMMDgG
.cCc.....R.
..cC.......
''')
GUN_SWAY = part('''
.........G.
wwWMMMMMDgG
.cCc.....R.
.Cc........
''')
GUN_GLOW = part('''
.........g.
wwWMMMMMDgg
.cCc.....G.
..cC.......
''')
# fired: the barrel is empty and the chain pays out of the muzzle
GUN_FIRED = part('''
...........
wwWMMMMMDcC
.c.........
...........
''')
GUN_RELOAD = part('''
...........
wwWMMMMMDg.
.cC........
..c........
''')


def drakeling(element):
    body = bolter_idle(element)
    pal = Palette()
    colours = dict(FIXED, **HEAD[element])

    def frame(i, gun, dx=0, dy=0):
        ey = eye_row(body[i])
        return spec_frame(body[i], [(gun, 6 + dx, ey + 3 + dy, colours)], pal)

    idle = [frame(0, GUN), frame(1, GUN), frame(2, GUN_SWAY), frame(3, GUN_SWAY)]
    start = [frame(0, GUN), frame(1, GUN, dy=-1), frame(2, GUN_GLOW, dy=-1), frame(3, GUN_GLOW, dy=-1)]
    stop = [frame(0, GUN_FIRED, dx=-1, dy=-1), frame(1, GUN_FIRED, dx=-1), frame(2, GUN_FIRED),
            frame(3, GUN_RELOAD), frame(0, GUN)]
    name = (COLOUR[element] + '_' if COLOUR[element] else '') + 'puffe_harpooner'
    header = ('# Source of %s.aseprite and .png: the %s Harpooner drakeling, drawn by tools/sprite/parts/harpooner_art.py\n'
              '# (the Bolter drakeling of this element with a heavy harpoon gun and a chain coil). Same canvas and tags as the\n'
              '# other drakelings.' % (name, element))
    path = os.path.join(OUT, name + '.txt')
    write_spec(path, header, pal.lines(), (W, H), [('IDLE', 100, idle), ('START_ATTACK', 100, start), ('STOP_ATTACK', 100, stop)])
    return path


BOLT = 16
# the harpoon pointing right: chain c C behind the shaft M D, the barbed head in the element (top-left at (1, 6))
HARPOON = part('''
..........G..
....MMMMMMDgG
..........R..
''')
# the chain trailing behind, two phases so it rattles in flight
CHAINS = [part('''
cC..
..cC
'''), part('''
..cC
cC..
''')]
BOLT_FIXED = {'M': '8b9bb4', 'D': '5a6988', 'c': 'c0cbdc', 'C': '8b9bb4'}


def harpoon(element):
    colours = dict(BOLT_FIXED, **HEAD[element])
    pal = Palette()

    def k(ch):
        return pal.key(colours[ch])

    walk = []
    for i in range(4):
        frame = Frame(BOLT, BOLT)
        frame.stamp([(x, y, k(ch)) for x, y, ch in HARPOON], 2, 6)
        frame.stamp([(x, y, k(ch)) for x, y, ch in CHAINS[i % 2]], 2, 6 + (i // 2) * 0)
        walk.append(frame)
    # the barbs bite in: a burst at the head that opens to a ring of sparks, the shaft sinking in
    death = []
    cx, cy = 10, 7
    for step, radius in enumerate((1.5, 2.4, 3.2, 3.9, 4.4)):
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
        if step < 3:
            frame.stamp([(x, y, k(ch)) for x, y, ch in HARPOON if x < 10], 2 + step, 6)
            frame.stamp([(x, y, k(ch)) for x, y, ch in CHAINS[step % 2]], 2 + step, 6)
        death.append(frame)
    # a lost target: the harpoon flies on and thins out
    fade = []
    for step in range(4):
        frame = Frame(BOLT, BOLT)
        for x, y, ch in list(HARPOON) + list(CHAINS[0]):
            if step and (x + y + step) % (4 - step + 1) == 0:
                continue
            if step == 3 and (x + y) % 2:
                continue
            frame.px[(x + 2, y + 6)] = k(ch)
        fade.append(frame)
    name = '%s_harpoon' % element
    path = os.path.join(PROJ, name + '.txt')
    write_spec(path, '# Source of %s.aseprite and .png: the %s Harpooner\'s barbed harpoon, pointing right '
               '(tools/sprite/parts/harpooner_art.py).' % (name, element), pal.lines(), (BOLT, BOLT),
               [('WALK', 80, walk), ('DEATH', 70, death), ('FADE', 80, fade)])
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    written = []
    for element in ELEMENTS:
        written.append(drakeling(element))
        written.append(harpoon(element))
    for path in written:
        print('python tools/sprite/sprite.py build %s %s' % (path.replace('\\', '/'), path[:-4].replace('\\', '/') + '.aseprite'))


if __name__ == '__main__':
    main()
