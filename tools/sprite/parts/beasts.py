"""Destroyerling (Caves, 26x26) and its rock (10x10), Bog Hydra (Swamp boss, 40x40) and the leopard cub (Leopard T2, 18x18).
usage: beasts.py <parts dir> <art root>  (art root = assets/art/units)"""
import math
import sys
sys.path.insert(0, sys.argv[1])
from compose import *
from limbs import line, leg

UNITS = sys.argv[2]
ENEMY = UNITS + '/enemy'


def blob(f, cx, cy, rx, ry, ramp, light=(-0.5, -0.7)):
    """A filled ellipse shaded from the top left: ramp is dark to light."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            d = nx * nx + ny * ny
            if d <= 1.0:
                lit = -(nx * light[0] + ny * light[1])
                edge = d > 0.75
                v = 0.5 + lit * 0.55 - (0.25 if edge else 0)
                i = max(0, min(len(ramp) - 1, int(v * len(ramp))))
                f.px[(x, y)] = ramp[i]


def thick(f, pts_, ramp, width=3):
    """A thick curve through points, lit on its upper-left side."""
    for i in range(len(pts_) - 1):
        (x0, y0), (x1, y1) = pts_[i], pts_[i + 1]
        steps = max(abs(x1 - x0), abs(y1 - y0), 1) * 2
        for s in range(steps + 1):
            t = s / steps
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for o in range(width):
                off = o - width // 2
                c = ramp[min(len(ramp) - 1, max(0, 1 + (width // 2 - o)))]
                f.px[(round(x + off), round(y))] = c


# ======================= destroyerling (26x26) =======================
DS_PAL = {'a': 'b59e85', 'b': 'cab494', 'c': 'd5bf9b', 'd': 'e0caa3', 'e': 'ecd8b1', 'R': 'ff0044', 'r': 'a22633',
          'x': '87202b', 'X': 'a22633', 'o': '3e2731', 'm': '733e39', 'l': 'b86f50', 'A': 'c0cbdc', 'B': '8b9bb4',
          'C': '5a6988', 'D': '3a4466', 'K': '181425'}
DS_HEAD = part('''
..oooo..
.ooooooo
oodddcco
odRddRco
.cdrrrcb
.cbbbbb.''')
DS_TORSO = part('''
...ccdddcb..
..cdeeeddcbb
.cdeeedddcbb
.cddddddccba
..cdddcccbba
..bccccbbaa.
..xXXXXXxx..
..xXXXXXx...''')
DS_SACK = part('''
..CBA.
.CBBAC
mlmmmm
mllmmo
mmmmmo
.mmmo.''')
ROCK = part('''
.BA.
CBBA
CCBB
.DC.''')


def ds_arm(f, sx, sy, hx, hy, near):
    c1, c2 = ('d', 'b') if near else ('b', 'a')
    line(f, sx, sy, hx, hy, c1)
    line(f, sx + 1, sy, hx + 1, hy, c2)
    f.px[(hx, hy + 1)] = c2
    f.px[(hx + 1, hy + 1)] = 'a'


def destroyerling(x=0, y=0, legs=(0, 0), lift=(0, 0), far=(6, 19), near=(19, 20), rock=None, rock_front=True):
    f = Frame(26, 26)
    leg(f, 8 + x, 18 + y, legs[1], 'b', 'a', 23, lift[1], 3, 'a')
    ds_arm(f, 7 + x, 11 + y, far[0] + x, far[1] + y, False)
    f.stamp(DS_SACK, 3 + x, 8 + y)
    f.stamp(DS_TORSO, 6 + x, 10 + y)
    f.stamp(DS_HEAD, 13 + x, 5 + y)
    leg(f, 13 + x, 18 + y, legs[0], 'c', 'a', 23, lift[0], 3, 'b')
    if rock and not rock_front:
        f.stamp(ROCK, rock[0] + x, rock[1] + y)
    ds_arm(f, 16 + x, 11 + y, near[0] + x, near[1] + y, True)
    if rock and rock_front:
        f.stamp(ROCK, rock[0] + x, rock[1] + y)
    return f


ds_idle = [destroyerling(legs=(1, -1)), destroyerling(legs=(1, -1), y=1, far=(6, 19), near=(19, 20)),
           destroyerling(legs=(1, -1), y=1), destroyerling(legs=(1, -1))]
ds_walk = [destroyerling(legs=(2, -1), far=(4, 19), near=(20, 19)),
           destroyerling(legs=(0, 0), lift=(0, 1), y=-1, far=(6, 19), near=(18, 20)),
           destroyerling(legs=(-1, 2), far=(8, 19), near=(16, 20)),
           destroyerling(legs=(0, 0), lift=(1, 0), y=-1, far=(6, 19), near=(18, 20))]
ds_atk = [destroyerling(legs=(1, -1), far=(5, 10), near=(7, 12), rock=(4, 7), rock_front=False),
          destroyerling(legs=(1, -1), y=-1, far=(11, 5), near=(14, 5), rock=(11, 2)),
          destroyerling(legs=(2, -2), x=1, far=(18, 8), near=(20, 9), rock=(19, 5)),
          destroyerling(legs=(2, -2), x=1, far=(18, 12), near=(21, 13)),
          destroyerling(legs=(1, -1))]


def ds_dead(blood):
    f = Frame(26, 26)
    f.stamp(part('''
.......oooo....
..CBA.ooddooo..
mlmmmcdeeeddcoo
mmmmcdddddddRco
.mmocbccccbbrcb
....xXXXxxbbbba'''), 3, 17)
    f.stamp(ROCK, 19, 19)
    if blood:
        for p in ((18, 22), (19, 23), (20, 23)):
            f.px[p] = 'R'
    return f


def ds_toppling():
    """Halfway onto its face: the body pitched forward, arms thrown out to catch the ground, legs trailing."""
    f = Frame(26, 26)
    leg(f, 9, 19, -3, 'b', 'a', 23, 0, 3, 'a')
    ds_arm(f, 12, 14, 19, 21, False)
    f.stamp(DS_SACK, 4, 12)
    f.stamp(DS_TORSO, 8, 13)
    f.stamp(DS_HEAD, 16, 11)
    leg(f, 13, 20, -2, 'c', 'a', 23, 0, 3, 'b')
    ds_arm(f, 18, 15, 22, 21, True)
    f.stamp(ROCK, 20, 19)
    return f


# hit, stumbles forward dropping the rock, pitches onto its face
ds_death = [destroyerling(legs=(1, -1), x=1, far=(8, 19), near=(20, 20)),
            destroyerling(legs=(2, 1), x=1, y=1, far=(10, 20), near=(21, 20)),
            ds_toppling(), ds_dead(False), ds_dead(True)]

write_spec(ENEMY + '/destroyerling/destroyerling.txt', '''
# Source of destroyerling.aseprite and destroyerling.png (python tools/sprite/sprite.py build <this> destroyerling.aseprite).
# Destroyerling: a Caves special that throws a rock at the farthest tower in range. Hunched cave folk with the
# beefling's pale skin b59e85..ecd8b1, a dark shaggy mane 3e2731 and a leather sack of rocks on its back (both
# give it a dark mass on sand), long arms, red eyes ff0044, red loincloth. Generated by tools/sprite/parts/beasts.py.
# Knuckle-walks, heaves a rock overhead and throws it, falls on its face. The thrown rock is destroyerling_rock.''',
           DS_PAL, (26, 26), [('IDLE', 150, ds_idle), ('WALK', 110, ds_walk), ('ATTACK', 110, ds_atk), ('DEATH', 120, ds_death)])

ROCK_PAL = {'A': 'c0cbdc', 'B': '8b9bb4', 'C': '5a6988', 'D': '3a4466'}
rock_frames = []
for r in range(4):
    f = Frame(10, 10)
    base = ['..BBA.', '.CBBBA', 'CCBBAA', 'CCCBBA', '.DCCB.', '..DD..']
    grid = part('\n'.join(base))
    for _ in range(r):
        grid = [(5 - y, x, c) for x, y, c in grid]
    f.stamp(grid, 2, 2)
    rock_frames.append(f)
write_spec(ENEMY + '/destroyerling/destroyerling_rock.txt', '''
# Source of destroyerling_rock.aseprite and destroyerling_rock.png: the rock a destroyerling throws, tumbling
# (a quarter turn per frame). Generated by tools/sprite/parts/beasts.py.''',
           ROCK_PAL, (10, 10), [('IDLE', 80, rock_frames)])

# ======================= Bog Hydra (40x40, boss) =======================
H_PAL = {'1': '17323a', '2': '1f5048', '3': '2d7356', '4': '4a9a5c', '5': '8fc46a', 'p': 'b08a4a', 'q': 'e0c070',
         'Q': 'f2e3a0', 'Y': 'fee761', 'K': '181425', 'M': '2f6b3d', 'N': '4a8a45', 'O': '7cbf4a', 'x': '5d1d2c',
         'r': 'a22633', 'w': 'ffffff', 'u': '68386c', 'U': 'b55088'}
SKIN = ['1', '2', '3', '4', '5']
HEAD_SHUT = part('''
.2344...
234445K.
2344Y444
.2233333
..1qqq2.''')
HEAD_OPEN = part('''
.2344....
234445K..
2344Y4444
.22xrr...
.2xrwr...
..1qqq2..''')
HEAD_DEAD = part('''
..2333..
.233333.
1223K333
.1122qq.''')


def hydra(sway=(0, 0, 0), strike=None, y=0, legs=0, droop=0, sink=0, open_=None, fallen=None):
    """fallen: {head index: (x, y)} heads lying on the ground (dead), drawn in front of the body."""
    fallen = fallen or {}
    f = Frame(40, 40)
    by = 26 + y + sink
    # far legs
    for lx in (12, 24):
        line(f, lx + legs, by + 4, lx + legs - 1, min(36, by + 8), '1')
        line(f, lx + legs + 1, by + 4, lx + legs, min(36, by + 8), '2')
    heads = [((13, by - 2), (8, 13)), ((19, by - 4), (19, 7)), ((25, by - 2), (29, 12))]
    order = [0, 2, 1]
    # fallen side necks lie behind the body, out to the side and down to the ground
    for i, (hx, hy) in fallen.items():
        if i != 1:
            base = heads[i][0]
            thick(f, [base, ((base[0] + 2 * hx) // 3, by + 3), (hx, hy + 1)], SKIN, 3)
    for i in order:
        if i in fallen:
            continue
        base, top = heads[i]
        hx, hy = top[0] + sway[i], top[1] + droop * (i + 1) + y
        if strike == i:
            hx, hy = min(hx + 5, 30), hy + 7
        mid = ((base[0] + hx) // 2 + (2 if i == 1 else -1), (base[1] + hy) // 2)
        thick(f, [base, mid, (hx, hy + 2)], SKIN, 3)
        head = HEAD_DEAD if droop >= 3 else (HEAD_OPEN if strike == i or open_ == i else HEAD_SHUT)
        f.stamp(head, hx - 2, hy - 1)
    blob(f, 19, by + 2, 11, 6, SKIN)
    # belly and moss
    for xx in range(12, 27):
        f.px[(xx, by + 7)] = 'p' if xx in (12, 26) else 'q'
    for xx in range(14, 25):
        f.px[(xx, by + 6)] = 'q' if xx % 3 else 'Q'
    for (mx, my, c) in ((14, -3, 'M'), (15, -3, 'N'), (16, -4, 'O'), (17, -4, 'N'), (21, -4, 'N'), (22, -4, 'O'),
                        (23, -3, 'M'), (18, -3, 'M'), (25, -2, 'N'), (11, -1, 'M'), (26, -1, 'M')):
        f.px[(mx, by + my)] = c
    f.px[(16, by - 5)] = 'u'
    f.px[(17, by - 5)] = 'U'
    f.px[(22, by - 5)] = 'U'
    # fallen heads on the ground; the middle neck drapes straight down the front of the body
    for i, (hx, hy) in fallen.items():
        if i == 1:
            thick(f, [heads[1][0], (hx, hy + 1)], SKIN, 3)
        f.stamp(HEAD_DEAD, hx - 3, hy - 1)
    # near legs
    for lx in (15, 27):
        line(f, lx - legs, by + 5, lx - legs + 1, min(37, by + 9), '3')
        line(f, lx - legs + 1, by + 5, lx - legs + 2, min(37, by + 9), '2')
        f.px[(lx - legs + 2, min(37, by + 9))] = '1'
    return f


hy_idle = [hydra((0, 0, 0)), hydra((-1, 0, 1)), hydra((-1, 1, 1), y=0), hydra((0, 1, 0)), hydra((1, 0, -1)),
           hydra((0, -1, 0))]
hy_walk = [hydra((0, 0, 0), legs=-1), hydra((-1, 0, 1), y=-1, legs=0), hydra((-1, 1, 1), legs=1),
           hydra((0, 1, 0), y=-1, legs=0)]
hy_atk = [hydra((-2, -1, -2)), hydra((0, 0, 0), strike=2), hydra((0, 0, 0), strike=1), hydra((0, 0, 0), strike=0),
          hydra((0, 0, 0))]
# rears in pain, then the heads crash down one by one (left, right, middle) and the body settles into the bog
LEFT_DOWN, RIGHT_DOWN, MID_DOWN = (5, 33), (33, 33), (26, 35)
hy_death = [hydra((-1, -2, -1), y=-1, open_=1),
            hydra((0, 1, 1), droop=1, open_=1, fallen={0: LEFT_DOWN}),
            hydra((0, 2, 0), droop=1, sink=1, fallen={0: LEFT_DOWN, 2: RIGHT_DOWN}),
            hydra((0, 0, 0), sink=2, fallen={0: LEFT_DOWN, 2: RIGHT_DOWN, 1: MID_DOWN}),
            hydra((0, 0, 0), sink=3, legs=1, fallen={0: LEFT_DOWN, 2: RIGHT_DOWN, 1: MID_DOWN}),
            hydra((0, 0, 0), sink=3, legs=1, fallen={0: LEFT_DOWN, 2: RIGHT_DOWN, 1: MID_DOWN})]



def bog_line(f, width, line_y=33, cx=19):
    """Hides everything under the bog's surface and draws the ripple ring around the sinking body."""
    for p in [p for p in f.px if p[1] >= line_y]:
        del f.px[p]
    for x in range(cx - width, cx + width + 1):
        f.px[(x, line_y)] = '3' if abs(x - cx) >= width - 1 else '2'
    for x in range(cx - width + 2, cx + width - 1):
        f.px[(x, line_y + 1)] = '1'
    return f


def acid(f, x, y, big=True):
    for (dx, dy, c) in ((0, 0, 'O'), (1, 0, '5'), (0, 1, '4'), (1, 1, 'O')) if big else ((0, 0, 'O'), (1, 0, '5')):
        f.px[(x + dx, y + dy)] = c
    return f


# SPIT: the middle head rears back and spits a glob of acid (Bog Spit; the shot itself is hydra_acid)
hy_spit = [hydra((-1, -2, -1), y=-1), acid(hydra((0, -1, 0), open_=1), 26, 9), acid(hydra((0, -1, 0), open_=1), 30, 10, False),
           hydra((0, 0, 0))]
# SUBMERGE: sinks into the bog until only a ripple is left; EMERGE is the same backwards
hy_sub = [bog_line(hydra((0, 0, 0), y=2), 12), bog_line(hydra((1, 1, 1), y=7), 13), bog_line(hydra((1, 2, 1), y=13), 12),
          bog_line(hydra((2, 2, 2), y=19), 10), bog_line(Frame(40, 40), 7), bog_line(Frame(40, 40), 4)]
hy_emerge = [bog_line(Frame(40, 40), 5), bog_line(hydra((2, 2, 2), y=19), 10), bog_line(hydra((1, 1, 1), y=12), 12),
             bog_line(hydra((0, 1, 0), y=6), 13), hydra((0, 0, 0))]

write_spec(ENEMY + '/bog_hydra/bog_hydra.txt', '''
# Source of bog_hydra.aseprite and bog_hydra.png (python tools/sprite/sprite.py build <this> bog_hydra.aseprite).
# Bog Hydra: the Swamp boss. A squat mossy bog body with three serpent heads on long necks, the swamp teal ramp
# 17323a..8fc46a, pale belly e0c070/f2e3a0, yellow eyes fee761, moss and purple toadstools on its back. Same 40x40
# canvas as the Broodmother. Generated by tools/sprite/parts/beasts.py (a lit ellipse body, thick curved necks).
# Heads sway, it waddles, the three heads strike one after another (it hits as many towers as it has heads),
# the necks droop and it sinks into the bog. SPIT: the middle head spits acid; SUBMERGE sinks it into the bog
# until only a ripple is left, EMERGE brings it back up.''',
           H_PAL, (40, 40), [('IDLE', 150, hy_idle), ('WALK', 140, hy_walk), ('ATTACK', 110, hy_atk), ('DEATH', 130, hy_death),
                             ('SPIT', 110, hy_spit), ('SUBMERGE', 120, hy_sub), ('EMERGE', 120, hy_emerge)])

# ======================= leopard cub (18x18, Leopard T2 summon) =======================
L_PAL = {'a': 'b86f50', 'b': 'f77622', 'c': 'feae34', 'd': 'fee761', 'e': 'ead4aa', 's': '733e39', 'S': '423021',
         'n': 'ff9398', 'K': '181425', 'w': 'ffffff', 'r': 'ff0044', 'u': 'c0cbdc'}
CUB_RAMP = ['a', 'b', 'c', 'c', 'd']
CUB_HEAD = part('''
.c..c.
cdccdc
cdccccc
ccKccKn
.ceeee.''')
CUB_HEAD_BITE = part('''
.c..c..
cdccdc.
cdccccc
ccKccKn
.cer.ww
..ewww.''')


def cub(legs=(0, 0, 0, 0), y=0, x=0, bite=False, tail=0, crouch=0):
    f = Frame(18, 18)
    by = 10 + y + crouch
    # tail
    line(f, 4 + x, by - 1, 2 + x, by - 3 - tail, 'b')
    f.px[(2 + x, by - 4 - tail)] = 'S'
    # far legs
    for i, lx in enumerate((6, 11)):
        line(f, lx + x, by + 2, lx + x + legs[i * 2 + 1], 15 - crouch * 0, 'a')
    blob(f, 8.5 + x, by, 4.5, 2.6, CUB_RAMP)
    for (sx, sy) in ((6, -1), (9, -1), (8, 1), (11, 0), (5, 1), (10, 1), (7, 0)):
        f.px[(sx + x, by + sy)] = 'S'
    f.px[(7 + x, by + 2)] = 'e'
    f.px[(8 + x, by + 2)] = 'e'
    f.stamp(CUB_HEAD_BITE if bite else CUB_HEAD, 10 + x, by - 6 + (1 if bite else 0))
    # near legs
    for i, lx in enumerate((7, 12)):
        line(f, lx + x, by + 2, lx + x + legs[i * 2], 15, 'c')
        f.px[(lx + x + legs[i * 2] + 1, 15)] = 'c'
    return f


cub_idle = [cub(), cub(tail=1), cub(tail=1, y=0), cub()]
cub_walk = [cub(legs=(2, -1, -2, 1)), cub(legs=(0, 0, 0, 0), y=-1, tail=1), cub(legs=(-2, 1, 2, -1)),
            cub(legs=(0, 0, 0, 0), y=-1, tail=1)]
cub_atk = [cub(crouch=1, legs=(-1, -1, -1, -1)), cub(y=-2, x=0, legs=(-2, -2, 2, 2), tail=1), cub(x=0, bite=True),
           cub(x=0, bite=True), cub()]


def puff(n):
    f = Frame(18, 18)
    rings = [[(7, 13), (8, 12), (9, 12), (10, 13), (6, 14), (11, 14), (8, 14), (9, 14)],
             [(5, 13), (6, 11), (8, 10), (10, 10), (12, 11), (13, 13), (7, 14), (11, 14)],
             [(4, 12), (6, 9), (9, 8), (12, 9), (14, 12)]]
    for (px_, py_) in rings[n]:
        f.px[(px_, py_)] = 'u' if n < 2 else 'd'
        f.px[(px_ + 1, py_)] = 'w' if n < 2 else 'e'
    return f


cub_death = [cub(crouch=1), cub(crouch=2, tail=-1), puff(0), puff(1), puff(2)]

write_spec(UNITS + '/building/leopard_trap/leopard_cub.txt', '''
# Source of leopard_cub.aseprite and leopard_cub.png (python tools/sprite/sprite.py build <this> leopard_cub.aseprite).
# Leopard cub: Leopard T2 spawns one on each snap; it chases enemies, bites a few times (bleed) and leaves.
# A golden coat b86f50/f77622/feae34/fee761 (the trap's tan vanishes on sand) with dark spots 423021, pink nose ff9398. Side view facing right.
# Generated by tools/sprite/parts/beasts.py. Sits with a flicking tail, bounds, pounces and bites,
# and leaves in a puff of dust (DEATH).''',
           L_PAL, (18, 18), [('IDLE', 150, cub_idle), ('WALK', 80, cub_walk), ('ATTACK', 90, cub_atk), ('DEATH', 100, cub_death)])
print('ok')
