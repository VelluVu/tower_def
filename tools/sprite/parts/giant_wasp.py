import sys
sys.path.insert(0, sys.argv[1])
from compose import *

# d darkest, n/s swamp teal stripes, y/o/r yellow ramp, w/g/b wing
PAL = {'d': '181425', 'n': '17323a', 's': '1f5048', 'y': 'fee761', 'o': 'feae34', 'r': 'f77622',
       'w': 'ffffff', 'g': 'c0cbdc', 'b': '8b9bb4'}

ABDOMEN_ROWS = {0: (3, 7), 1: (2, 9), 2: (1, 9), 3: (1, 9), 4: (2, 8), 5: (4, 6)}
def band(c):
    return 'dark' if c in (1, 2, 5, 6) else 'yellow'
def shade(kind, row):
    if kind == 'yellow':
        return 'y' if row <= 1 else ('o' if row <= 3 else 'r')
    return 's' if row <= 1 else ('n' if row <= 3 else 'd')
def abdomen():
    p = []
    for row, (a, b) in ABDOMEN_ROWS.items():
        for c in range(a, b + 1):
            p.append((c, row, shade(band(c), row)))
    return p
STINGER = pts([(1, 2), (0, 3)], 'd')

THORAX = part('''
.sn.
snns
nnnn
dnnd
.dd.''')
THORAX_SPOT = pts([(2, 1)], 'o')
HEAD = part('''
.yy.
yydy
oodo
orrr
.rr.''')
# antenna from the head top, mandible at the front
ANTENNA = pts([(1, -1), (2, -2), (3, -2)], 'd')
MANDIBLE = pts([(4, 3)], 'd')

LEGS_HANG = pts([(1, 5), (0, 6), (3, 5), (3, 6)], 'd')
LEGS_TRAIL = pts([(1, 5), (0, 6), (-1, 6), (3, 5), (2, 6)], 'd')
LEGS_UP = pts([(1, -1), (0, -2), (3, -1), (3, -2)], 'd')

WING_UP = part('''
.ww..
wggw.
bgggw
.bggg
..bgg
...gg''')
WING_MID = part('''
..wwwwww.
wwgggggggg
bbbbbggggg''')
WING_DOWN = part('''
.....gggg
..gggggg.
bggggb...
bbbb.....''')
WING_FOLDED = part('''
wwwwww
bbbbbb''')

# body origin: abdomen top-left; thorax right of the waist, head in front
def body(f, x, y, legs=LEGS_HANG, curl=0, flip=False):
    parts = []
    ab_dx, ab_dy = (0, curl) if curl else (0, 0)
    f.stamp(abdomen(), x + 1 + ab_dx, y + ab_dy, flipv=flip)
    if curl == 0:
        f.stamp(STINGER, x + 1, y + (2 if flip else 3))
    f.px[(x + 11, y + (2 if not flip else 3))] = 'd'  # waist
    f.stamp(THORAX, x + 12, y, flipv=flip).stamp(THORAX_SPOT, x + 12, y + (3 if flip else 1))
    f.stamp(HEAD, x + 16, y, flipv=flip)
    if flip:
        f.stamp(pts([(1, 5), (2, 6), (3, 6)], 'd'), x + 16, y)
        f.stamp(pts([(4, 1)], 'd'), x + 16, y)
    else:
        f.stamp(ANTENNA, x + 16, y).stamp(MANDIBLE, x + 16, y)
    if legs is not None:
        f.stamp(legs, x + 12, y)

def frame():
    return Frame(24, 24)

X, Y = 1, 10
def flying(wing, bob, legs=LEGS_HANG):
    f = frame()
    y = Y + bob
    if wing is WING_DOWN:
        body(f, X, y, legs)
        f.stamp(wing, X + 4, y + 1)
    else:
        if wing is WING_UP:
            f.stamp(wing, X + 9, y - 6)
        else:
            f.stamp(wing, X + 4, y - 2)
        body(f, X, y, legs)
        # the wing base sits on the thorax
        if wing is WING_UP:
            pass
    return f

idle = [flying(WING_UP, 0), flying(WING_MID, 0), flying(WING_DOWN, -1), flying(WING_MID, 0)]
walk = [flying(WING_UP, 0, LEGS_TRAIL), flying(WING_MID, 0, LEGS_TRAIL), flying(WING_DOWN, -1, LEGS_TRAIL), flying(WING_MID, 0, LEGS_TRAIL)]

def attack(stage):
    f = frame()
    f.stamp(WING_MID if stage != 1 else WING_UP, X + 4 if stage != 1 else X + 9, Y - 2 if stage != 1 else Y - 6)
    # the abdomen swings under the body, stinger forward
    body(f, X + (1 if stage == 1 else 0), Y, LEGS_TRAIL, curl=1 if stage != 1 else 2)
    if stage == 1:
        f.stamp(pts([(4, 8), (5, 9), (6, 9)], 'd'), X + 1, Y)
    else:
        f.stamp(pts([(1, 6), (2, 7)], 'd'), X, Y)
    return f
atk = [attack(0), attack(1), attack(0)]

def falling(dy, wing):
    f = frame()
    if wing is not None:
        f.stamp(wing, X + 6, Y + dy - 1)
    body(f, X, Y + dy, LEGS_HANG)
    return f
def on_back(legs_up, dy=0):
    f = frame()
    f.stamp(WING_FOLDED, X + 5, Y + 11 + dy)
    body(f, X, Y + 6 + dy, None, flip=True)
    f.stamp(legs_up, X + 12, Y + 6 + dy)
    return f
LEGS_UP2 = pts([(1, -1), (1, -2), (3, -1), (4, -2)], 'd')
death = [falling(2, WING_FOLDED), falling(5, None), on_back(LEGS_UP, -1), on_back(LEGS_UP2), on_back(LEGS_UP2)]
for f in death[2:]:
    pass

write_spec(sys.argv[2], '''
# Source of giant_wasp.aseprite and giant_wasp.png (python tools/sprite/sprite.py build <this> giant_wasp.aseprite).
# Made by scratch generator (compose.py parts): giant wasp, the Swamp flyer. Yellow ramp feae34/fee761/f77622 with
# swamp-teal stripes 1f5048/17323a, dark 181425 legs and eye, pale wings c0cbdc/ffffff with a 8b9bb4 trailing edge.
# Hovers with a 4-frame wingbeat, curls its stinger under to sting, falls and lands on its back.''',
    PAL, (24, 24), [('IDLE', 80, idle), ('WALK', 70, walk), ('ATTACK', 100, atk), ('DEATH', 100, death)])
print('ok')
