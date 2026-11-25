"""The Hoard Keeper's art (2026-11-25): the drakeling (the Bolter's, recoloured per element from the Bolter's own
element sheets) guarding a pile of gold coins in front of it.

    python tools/sprite/parts/hoard_art.py tools/sprite/parts assets/art
    then build each written .txt with tools/sprite/sprite.py build

Sheets (18x34 like every drakeling) go to units/building/puffe/puffe_hoard/<colour>_puffe_hoard.txt:
IDLE 8 (a glint runs over the pile, a gem in the element's colour winks) and PAY 6 (a coin flips up off the pile when
the Keeper pays out at a wave's end).
"""
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import part, write_spec
from mortar_art import COLOUR, ELEMENTS, H, W, Palette, bolter_idle, spec_frame

ART = sys.argv[2]
OUT = os.path.join(ART, 'units', 'building', 'puffe', 'puffe_hoard')

# gold G g o (light to dark), a white glint w, the element's gem E e
GOLD = {'G': 'fee761', 'g': 'feae34', 'o': 'f77622', 'd': '733e39', 'w': 'ffffff'}
GEM = {
    'physical': {'E': 'c0cbdc', 'e': '5a6988'},
    'fire': {'E': 'e43b44', 'e': 'a22633'},
    'frost': {'E': '2ce8f5', 'e': '0099db'},
    'poison': {'E': 'b6d53c', 'e': '3e8948'},
}
PILE = part('''
...GG....
..GgGEg..
.gGggeGg.
gGgogGgog
ogoooogoo
.ddddddd.
''')
PILE_AT = (4, 18)
GLINTS = [(6, 18), (9, 19), (11, 21), (7, 21)]
COIN = [part('''
.G.
GgG
.o.
'''), part('''
G
g
o
'''), part('''
.G.
GgG
.o.
''')]


def drakeling(element):
    body = bolter_idle(element)
    pal = Palette()
    colours = dict(GOLD, **GEM[element])
    px, py = PILE_AT

    def frame(i, glint=None, coin=None):
        stamps = [(PILE, px, py, colours)]
        if glint is not None:
            stamps.append((part('w'), GLINTS[glint][0], GLINTS[glint][1], colours))
        if coin is not None:
            stamps.append((COIN[coin[0]], coin[1], coin[2], colours))
        return spec_frame(body[i % 4], stamps, pal)

    idle = [frame(i, glint=(i // 2) % 4 if i % 2 == 0 else None) for i in range(8)]
    pay = [frame(0, coin=(0, 8, 16)), frame(1, coin=(1, 9, 13)), frame(2, coin=(2, 8, 11)),
           frame(3, coin=(1, 9, 12), glint=0), frame(0, coin=(0, 8, 15)), frame(1, glint=1)]
    name = (COLOUR[element] + '_' if COLOUR[element] else '') + 'puffe_hoard'
    header = ('# Source of %s.aseprite and .png: the %s Hoard Keeper drakeling, drawn by tools/sprite/parts/hoard_art.py\n'
              '# (the Bolter drakeling of this element guarding a pile of gold). Same canvas as the other drakelings.' % (name, element))
    path = os.path.join(OUT, name + '.txt')
    write_spec(path, header, pal.lines(), (W, H), [('IDLE', 140, idle), ('PAY', 90, pay)])
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    for element in ELEMENTS:
        print(drakeling(element).replace('\\', '/'))


if __name__ == '__main__':
    main()
