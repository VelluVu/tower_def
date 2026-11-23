import sys
sys.path.insert(0, sys.argv[1])
from compose import *

# Endesga 32 pink skin ramp e8b796/c28569 with cool hue-shifted shadows 68386c/3e2731, rot patches b55088, house swamp acid 7a9a1e/b6d53c/e6f07a
# for the boils, f6757a snout, c0cbdc tusk, 181425 eye
PAL = {'L': 'e8b796', 'M': 'c28569', 'D': '68386c', 'K': '3e2731', 'P': 'b55088', 'g': '7a9a1e', 'a': 'b6d53c',
       'A': 'e6f07a', 'n': 'f6757a', 't': 'c0cbdc', 'e': '181425'}

GROUND = 24


def shade(nx, ny):
    # light from the top left, a dark rim along the bottom
    v = -(0.55 * nx + 0.85 * ny)
    if ny > 0.82:
        return 'K'
    if v > 0.62:
        return 'L'
    if v > -0.62:
        return 'M'
    return 'D'


def ellipse(f, cx, cy, rx, ry):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if nx * nx + ny * ny <= 1.0:
                f.px[(x, y)] = shade(nx, ny)


def stubby_leg(f, x, top, col, length, dx=0):
    for y in range(top, top + length):
        f.px[(x + (dx if y == top + length - 1 else 0), y)] = col
        f.px[(x + 1 + (dx if y == top + length - 1 else 0), y)] = col
    f.px[(x + dx, top + length - 1)] = 'K'
    f.px[(x + 1 + dx, top + length - 1)] = 'K'


BOILS = [(7, 12), (11, 14), (5, 16), (13, 11)]
PATCHES = [(9, 17), (10, 17), (15, 18)]


def pig(x=0, y=0, legs=(0, 0, 0, 0), lift=(0, 0, 0, 0), head=(0, 0), mouth=False, boil_pop=-1, eye='e'):
    """legs/lift: near front, far front, near hind, far hind."""
    f = Frame(26, 26)
    cx, cy = 11 + x, 15 + y
    leg_top = 20 + y
    # far legs behind the body
    stubby_leg(f, 15 + x, leg_top, 'D', GROUND - leg_top + 1 - lift[1], legs[1])
    stubby_leg(f, 5 + x, leg_top, 'D', GROUND - leg_top + 1 - lift[3], legs[3])
    # curly tail
    f.px[(cx - 9, cy - 2)] = 'M'
    f.px[(cx - 9, cy - 3)] = 'M'
    f.px[(cx - 8, cy - 4)] = 'D'
    ellipse(f, cx, cy, 9.0, 6.0)
    for i, (bx, by) in enumerate(BOILS):
        if i == boil_pop:
            f.px[(bx + x, by + y)] = 'A'
            f.px[(bx + x + 1, by + y)] = 'g'
            f.px[(bx + x, by + y - 1)] = 'a'
            continue
        f.px[(bx + x, by + y)] = 'a'
        f.px[(bx + x + 1, by + y)] = 'g'
        f.px[(bx + x, by + y - 1)] = 'A'
    for px, py in PATCHES:
        f.px[(px + x, py + y)] = 'P'
    # head: a round front with an ear, snout, tusk and eye
    hx, hy = cx + 9 + head[0], cy + head[1]
    # a shadow where the head meets the body
    for ny in range(-2, 3):
        f.px[(hx - 4, hy + ny)] = 'D'
    ellipse(f, hx, hy, 3.6, 3.6)
    # ear: a flap leaning forward, pink inside
    f.px[(hx - 2, hy - 4)] = 'M'
    f.px[(hx - 1, hy - 4)] = 'n'
    f.px[(hx - 2, hy - 5)] = 'D'
    f.px[(hx - 1, hy - 5)] = 'M'
    f.px[(hx, hy - 5)] = 'D'
    f.px[(hx, hy - 1)] = eye
    # snout: a pink disc with a nostril
    for sy in range(-1, 2):
        f.px[(hx + 3, hy + sy)] = 'n'
    f.px[(hx + 4, hy)] = 'n'
    f.px[(hx + 4, hy - 1)] = 'n'
    f.px[(hx + 4, hy + 1)] = 'D'
    f.px[(hx + 3, hy)] = 'D'
    if mouth:
        f.px[(hx + 2, hy + 3)] = 'K'
        f.px[(hx + 3, hy + 2)] = 'K'
    f.px[(hx + 2, hy + 2)] = 't'
    f.px[(hx + 3, hy + 1)] = 't'
    # near legs in front
    stubby_leg(f, 17 + x, leg_top, 'M', GROUND - leg_top + 1 - lift[0], legs[0])
    stubby_leg(f, 7 + x, leg_top, 'M', GROUND - leg_top + 1 - lift[2], legs[2])
    return f


idle = [pig(), pig(y=0, boil_pop=1), pig(y=1), pig(boil_pop=2)]
walk = [pig(legs=(1, -1, -1, 1)), pig(lift=(1, 0, 0, 1), y=-1), pig(legs=(-1, 1, 1, -1)),
        pig(legs=(-1, 1, 1, -1), lift=(0, 1, 1, 0), y=-1), pig(legs=(1, -1, -1, 1), boil_pop=0), pig(lift=(1, 0, 0, 1), y=-1)]
atk = [pig(x=-1, legs=(-1, -1, 1, 1), head=(0, 1)), pig(x=0, legs=(1, 1, -1, -1), head=(0, 1), mouth=True),
       pig(x=0, legs=(1, 1, -1, -1), head=(0, 0), mouth=True), pig()]


def on_side(puddle, legs_up=3):
    f = Frame(26, 26)
    cx, cy = 11, 19
    ellipse(f, cx, cy, 9.0, 4.5)
    # keeled over: the four stubby legs stick stiffly up off the swollen belly, the far pair darker
    for lx, col, lean in ((5, 'D', -1), (13, 'D', 0), (8, 'M', 0), (16, 'M', 1)):
        for i in range(legs_up):
            x = lx + (lean if i == legs_up - 1 else 0)
            f.px[(x, 15 - i)] = col
            f.px[(x + 1, 15 - i)] = col
        f.px[(lx + (lean if legs_up > 1 else 0), 15 - legs_up + 1)] = 'K'
        f.px[(lx + 1 + (lean if legs_up > 1 else 0), 15 - legs_up + 1)] = 'K'
    for bx, by in BOILS[:3]:
        f.px[(bx, by + 5)] = 'a'
        f.px[(bx + 1, by + 5)] = 'g'
    hx, hy = cx + 9, cy
    ellipse(f, hx, hy, 3.4, 3.0)
    f.px[(hx, hy - 1)] = 'K'
    f.px[(hx + 1, hy - 1)] = 'K'
    for sy in range(0, 2):
        f.px[(hx + 3, hy + sy)] = 'n'
    f.px[(hx + 2, hy + 1)] = 't'
    for i in range(puddle):
        f.px[(9 + i, GROUND)] = 'g' if i % 3 else 'a'
    return f


death = [pig(head=(0, -1), eye='K', boil_pop=1), pig(y=2, lift=(2, 2, 2, 2), head=(0, 1), eye='K'), on_side(0, 2),
         on_side(3), on_side(6), on_side(8)]

write_spec(sys.argv[2], '''
# Source of plaguepig.aseprite and plaguepig.png (python tools/sprite/sprite.py build <this> plaguepig.aseprite).
# Plaguepig: a bloated diseased swamp boar, the Swamp tank. Pink skin e8b796/c28569 with cool shadows 68386c/3e2731,
# lit from the top left, rot patches b55088, acid boils 7a9a1e/b6d53c/e6f07a that throb, f6757a snout, c0cbdc tusk. Built from parts
# (barrel body, round head with ear, stubby legs). Trots, charges with its head low, keels over and oozes.''',
           PAL, (26, 26), [('IDLE', 150, idle), ('WALK', 110, walk), ('ATTACK', 100, atk), ('DEATH', 120, death)])
print('ok')
