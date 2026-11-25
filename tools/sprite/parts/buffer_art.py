"""The Buffer's art (2026-11-24, the user: "draw it now"): the drakeling (the Bolter's, recoloured per element from the
Bolter's own element sheets) beating a small war drum in front of it.

    python tools/sprite/parts/buffer_art.py tools/sprite/parts assets/art
    then build each written .txt with tools/sprite/sprite.py build; T2/T3 by tower_tiers.py ... buffer

Sheets (18x34 like every drakeling) go to units/building/puffe/puffe_buffer/<colour>_puffe_buffer.txt:
IDLE 8 (the stick comes down on the drum twice, the skin jumps, a beat mark rises in the element's colour) and
ROAR 6 (T3's Commander's Roar: sound arcs run out from the drakeling's mouth, the drum booms).
"""
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, part, write_spec
from mortar_art import COLOUR, ELEMENTS, H, W, Palette, bolter_idle, spec_frame

ART = sys.argv[2]
OUT = os.path.join(ART, 'units', 'building', 'puffe', 'puffe_buffer')

# the drum: pale skin S s (lit top), bronze rim B b, the body's element band E e, dark wood D, cords c
DRUM_COLOURS = {'S': 'ead4aa', 's': 'e4a672', 'B': 'b86f50', 'b': 'feae34', 'D': '3e2731', 'R': '733e39', 'c': 'c0cbdc'}
ELEMENT_BAND = {
    'physical': {'E': 'feae34', 'e': 'b86f50', 'g': 'fee761'},
    'fire': {'E': 'f77622', 'e': 'a22633', 'g': 'fee761'},
    'frost': {'E': '2ce8f5', 'e': '0099db', 'g': 'ffffff'},
    'poison': {'E': 'b6d53c', 'e': '68386c', 'g': 'b6d53c'},
}
DRUM = part('''
.SSSSs.
SSSSSss
bBBBBBb
RcEecR.
RRceRRD
.DDDDD.
''')
# the skin pressed in on a beat
DRUM_HIT = part('''
.......
.sSSSs.
bBBBBBb
RcEecR.
RRceRRD
.DDDDD.
''')
DRUM_AT = (1, 16)
# the stick: raised, halfway, down on the skin (from the drakeling's claw at the left)
STICK_UP = part('''
.R
.R
R.
''')
STICK_MID = part('''
..
RR
R.
''')
STICK_DOWN = part('''
RR.
..R
''')
STICK_AT = {'up': (4, 12), 'mid': (4, 13), 'down': (4, 15)}
# a beat mark rising over the drum
BEAT = [part('''
g.g
.g.
'''), part('''
g.g
'''), part('''
.g.
''')]
# sound arcs from the mouth, out to the right, growing
ARCS = [part('''
E
E
'''), part('''
.E
E.
E.
.E
'''), part('''
..g
.E.
E..
E..
.E.
..g
''')]
MOUTH = (10, 10)


def drakeling(element):
    body = bolter_idle(element)
    pal = Palette()
    colours = dict(DRUM_COLOURS, **ELEMENT_BAND[element])
    dx, dy = DRUM_AT

    def frame(i, stick, hit, extra=()):
        stamps = [(DRUM_HIT if hit else DRUM, dx, dy, colours)]
        stick_part = {'up': STICK_UP, 'mid': STICK_MID, 'down': STICK_DOWN}[stick]
        stamps.append((stick_part, STICK_AT[stick][0], STICK_AT[stick][1], colours))
        stamps.extend((p, x, y, colours) for p, x, y in extra)
        return spec_frame(body[i % 4], stamps, pal)

    # two beats over the idle: up, down (hit and a mark), the mark rises, the stick comes back up
    idle = [
        frame(0, 'up', False),
        frame(1, 'mid', False),
        frame(2, 'down', True, [(BEAT[0], dx + 2, dy - 3)]),
        frame(3, 'mid', False, [(BEAT[1], dx + 2, dy - 5)]),
        frame(0, 'up', False, [(BEAT[2], dx + 2, dy - 7)]),
        frame(1, 'mid', False),
        frame(2, 'down', True, [(BEAT[0], dx + 2, dy - 3)]),
        frame(3, 'up', False, [(BEAT[1], dx + 2, dy - 5)]),
    ]
    mx, my = MOUTH
    roar = [
        frame(0, 'down', True),
        frame(1, 'down', True, [(ARCS[0], mx + 1, my)]),
        frame(2, 'mid', False, [(ARCS[0], mx + 1, my), (ARCS[1], mx + 2, my - 1)]),
        frame(3, 'up', False, [(ARCS[1], mx + 2, my - 1), (ARCS[2], mx + 4, my - 2)]),
        frame(0, 'mid', False, [(ARCS[2], mx + 4, my - 2)]),
        frame(1, 'up', False),
    ]
    name = (COLOUR[element] + '_' if COLOUR[element] else '') + 'puffe_buffer'
    header = ('# Source of %s.aseprite and .png: the %s Buffer drakeling, drawn by tools/sprite/parts/buffer_art.py\n'
              '# (the Bolter drakeling of this element beating a war drum). Same canvas as the other drakelings.' % (name, element))
    path = os.path.join(OUT, name + '.txt')
    write_spec(path, header, pal.lines(), (W, H), [('IDLE', 120, idle), ('ROAR', 100, roar)])
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    for element in ELEMENTS:
        print(drakeling(element).replace('\\', '/'))


if __name__ == '__main__':
    main()
