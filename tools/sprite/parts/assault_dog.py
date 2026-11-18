import sys
sys.path.insert(0, sys.argv[1])
from compose import *

PAL = {'d': '181425', 's': '3a4466', 'm': '5a6988', 'l': '8b9bb4', 'h': 'c0cbdc', 'r': 'a22633', 'R': 'e43b44', 'n': '3e2731'}

BODY = part('''
.lllll..
mmmmmmml
smmmmmmm
ss...smm
......ss''')
HEAD = part('''
.s....
lls...
llld..
mmmmmd
.ss...''')
HEAD_OPEN = part('''
.s....
lls...
llld..
mmmmmd
.RR...
.sss..''')
HEAD_DEAD = part('''
......
.s....
llss..
mmmmmd
.ss...''')
TAIL_UP = pts([(-1, 0), (-2, -1)], 'l')
TAIL_WAG = pts([(-1, 0), (-2, 0)], 'l')
TAIL_DOWN = pts([(-1, 1), (-2, 2)], 'm')

def leg(f, hx, hy, off, col, foot_y=7, bx=0, by=0):
    for y in range(hy, foot_y + 1):
        t = (y - hy) / max(1, foot_y - hy)
        x = hx + round(off * t)
        f.px[(bx + x, by + y)] = col

BX, BY = 3, 10
def dog(legs=(1, -1, 0, -1), tail=TAIL_UP, head=HEAD, dx=0, dy=0, head_dx=0, head_dy=0, foot_y=6):
    f = Frame(18, 18)
    bx, by = BX + dx, BY + dy
    fn, ff, hn, hf = legs
    # far legs first (darker), then the body, then the near legs
    leg(f, 6, 5, ff, 's', foot_y - dy, bx, by)
    leg(f, 1, 4, hf, 's', foot_y - dy, bx, by)
    f.stamp(tail, bx, by)
    f.stamp(BODY, bx, by)
    f.stamp(head, bx + 5 + head_dx, by - 3 + head_dy)
    f.px[(bx + 5, by)] = 'R'
    f.px[(bx + 5, by + 1)] = 'r'
    leg(f, 7, 5, fn, 'm', foot_y - dy, bx, by)
    leg(f, 0, 4, hn, 'm', foot_y - dy, bx, by)
    return f

idle = [dog(), dog(tail=TAIL_WAG), dog(), dog(tail=TAIL_WAG, head_dy=1)]
walk = [dog((1, -1, -1, 1), TAIL_UP), dog((0, 0, 0, 0), TAIL_WAG, head_dy=-1),
        dog((-1, 1, 1, -1), TAIL_UP), dog((0, 0, 0, 0), TAIL_WAG, head_dy=-1)]
atk = [dog((-1, -1, 1, 1), TAIL_DOWN, dy=1, head_dy=1),
       dog((2, 2, -1, -1), TAIL_UP, head=HEAD_OPEN, dx=1, dy=-2, foot_y=4),
       dog((1, 1, -1, -1), TAIL_UP, head=HEAD_OPEN, dx=2, dy=-1),
       dog((1, 0, 0, -1), TAIL_UP, dx=1),
       dog()]

def lying(eye_closed=True, legs_out=2):
    f = Frame(18, 18)
    bx, by = BX, BY + 2
    # on its side: legs stick out forward, body low
    for hx, hy, col in ((6, 4, 's'), (1, 3, 's')):
        for i in range(legs_out + 1):
            f.px[(bx + hx + i, by + hy)] = col
    f.stamp(TAIL_DOWN, bx, by)
    f.stamp(BODY, bx, by)
    f.stamp(HEAD_DEAD if eye_closed else HEAD, bx + 5, by - 2)
    f.px[(bx + 5, by + 1)] = 'r'
    for hx, hy in ((7, 4), (2, 3)):
        for i in range(legs_out + 1):
            f.px[(bx + hx + i, by + hy)] = 'm'
    return f

death = [dog((0, 0, 0, 0), TAIL_DOWN, head_dy=-1), dog((1, 1, 0, 0), TAIL_DOWN, dy=2, head_dy=1, foot_y=6),
         lying(True, 1), lying(True, 2), lying(True, 2)]

write_spec(sys.argv[2], '''
# Source of assault_dog.aseprite and assault_dog.png (python tools/sprite/sprite.py build <this> assault_dog.aseprite).
# Assault dog: the humans' war hound, steel-grey ramp 3a4466/5a6988/8b9bb4, a red collar a22633/e43b44, dark eye
# and nose 181425. Deep chest, tucked waist, pointed ear, tail up. Built from parts (body, head, tail, four legs
# drawn hip to foot) so it holds together between frames. Trots, crouches and leaps to bite, falls on its side.''',
    PAL, (18, 18), [('IDLE', 150, idle), ('WALK', 70, walk), ('ATTACK', 80, atk), ('DEATH', 100, death)])
print('ok')
