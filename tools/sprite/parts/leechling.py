import math
import sys
sys.path.insert(0, sys.argv[1])
from compose import *

# Endesga 32: brown ramp b86f50/733e39/3e2731/181425, stripe f77622, sucker a22633/e43b44, mouth f6757a
PAL = {'L': 'b86f50', 'l': '733e39', 'm': '3e2731', 'd': '181425', 'K': '181425', 'o': 'f77622',
       'r': 'a22633', 'R': 'e43b44', 'p': 'f6757a'}

GROUND = 15


def leech(head_x, length, arch, raise_head=0, sucker='closed', thick=4, dark=False):
    """A side-view leech: tail at head_x - length + 1, head at head_x; the middle arched up by `arch` rows,
    the front lifted by `raise_head` rows."""
    f = Frame(18, 18)
    tail_x = head_x - length + 1
    for x in range(tail_x, head_x + 1):
        t = (x - tail_x) / max(1, length - 1)
        lift = round(arch * math.sin(math.pi * t))
        if raise_head:
            lift += round(raise_head * max(0.0, (t - 0.55) / 0.45))
        th = thick if 0 < x - tail_x < length - 1 else thick - 1
        bottom = GROUND - lift
        for i in range(th):
            y = bottom - i
            if dark:
                col = 'd' if i < th - 1 else 'm'
            elif i == th - 1:
                col = 'L' if th >= 3 else 'l'
            elif i == 0:
                col = 'd'
            else:
                col = 'm'
            # segment stripes: an orange dot on the back every third column
            if not dark and i == th - 1 and (x - tail_x) % 3 == 1 and x < head_x - 1:
                col = 'o'
            f.px[(x, y)] = col
        # a rib line under the back between the dots
        if not dark and th >= 3 and (x - tail_x) % 3 == 0:
            f.px[(x, bottom - th + 2)] = 'l'
    # the head end: a red sucker below the front, mouth when open
    hb = GROUND - (round(raise_head) if raise_head else 0)
    if sucker == 'closed':
        f.px[(head_x, hb)] = 'r'
    elif sucker == 'open':
        f.px[(head_x, hb)] = 'R'
        f.px[(head_x + 1, hb)] = 'p'
        f.px[(head_x + 1, hb - 1)] = 'r'
    elif sucker == 'latched':
        f.px[(head_x, hb)] = 'R'
        f.px[(head_x + 1, hb)] = 'R'
    if not dark:
        f.px[(head_x - 1, hb - 2)] = 'o'  # a dark eye spot
    return f


HEAD = 14
idle = [leech(HEAD, 11, 0), leech(HEAD, 11, 1), leech(HEAD, 11, 1), leech(HEAD, 11, 0)]
walk = [leech(HEAD, 12, 0), leech(HEAD, 10, 2), leech(HEAD, 8, 3), leech(HEAD, 10, 1)]
atk = [leech(HEAD - 1, 11, 1, raise_head=3, sucker='open'), leech(HEAD + 1, 12, 0, sucker='latched'),
       leech(HEAD + 1, 12, 1, sucker='latched'), leech(HEAD, 11, 0)]


def coil(size, dark):
    f = Frame(18, 18)
    cx = 8
    ring = {1: [(0, 0), (1, 0), (2, 0), (-1, -1), (3, -1), (-1, -2), (3, -2), (0, -3), (1, -3), (2, -3), (0, -1), (2, -1), (0, -2), (2, -2)],
            0: [(0, 0), (1, 0), (2, 0), (3, 0), (0, -1), (3, -1), (1, -2), (2, -2)]}[size]
    for x, y in ring:
        f.px[(cx + x, GROUND + y)] = 'd' if dark else ('L' if y <= -3 else ('l' if y <= -2 else 'm'))
    if not dark:
        f.px[(cx + 1, GROUND - 1)] = 'o'
    f.px[(cx + 3, GROUND)] = 'r'
    return f


death = [leech(HEAD, 10, 3), coil(1, False), coil(1, False), coil(0, True), leech(10, 6, 0, sucker='none', thick=2, dark=True)]

write_spec(sys.argv[2], '''
# Source of leechling.aseprite and leechling.png (python tools/sprite/sprite.py build <this> leechling.aseprite).
# Leechling: a small swamp leech that comes in groups. Endesga browns b86f50/733e39/3e2731/181425 with an orange
# f77622 dot on each segment, an orange eye spot and a red a22633/e43b44 sucker. Drawn from a centre line (length,
# arch, raised head) so it inches along: stretches flat, humps up, rears and latches on, coils up and shrivels.''',
           PAL, (18, 18), [('IDLE', 150, idle), ('WALK', 120, walk), ('ATTACK', 100, atk), ('DEATH', 100, death)])
print('ok')
