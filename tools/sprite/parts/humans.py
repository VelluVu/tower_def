import sys
sys.path.insert(0, sys.argv[1])
from compose import *

PAL_SOLDIER = {'A': 'c0cbdc', 'B': '8b9bb4', 'C': '5a6988', 'D': '3a4466', 's': 'e8b796', 't': 'c28569', 'K': '181425',
               'b': '0099db', 'n': '124e89', 'g': 'feae34', 'l': 'b86f50', 'm': '733e39', 'o': '3e2731', 'r': 'a22633'}
PAL_SCOUT = {'A': 'c0cbdc', 'B': '8b9bb4', 's': 'e8b796', 't': 'c28569', 'K': '181425', 'l': 'b86f50', 'm': '733e39',
             'o': '3e2731', 'h': '3e8948', 'j': '265c42', 'r': 'a22633'}

FEET = 15


def leg(f, hx, hy, off, col, boot, lift=0):
    foot = FEET - lift
    for y in range(hy, foot + 1):
        t = (y - hy) / max(1, foot - hy)
        f.px[(hx + round(off * t), y)] = boot if y == foot else col
    # a toe forward on the foot
    f.px[(hx + off + 1, foot)] = boot


class Human:
    def __init__(self, head, torso, far_arm, legs_col, far_col, boot, hip_y):
        self.head, self.torso, self.far_arm = head, torso, far_arm
        self.legs_col, self.far_col, self.boot, self.hip_y = legs_col, far_col, boot, hip_y

    def frame(self, x=0, y=0, legs=(0, 0), lift=(0, 0), head_dx=0, extra=None):
        f = Frame(18, 18)
        leg(f, 7 + x, self.hip_y + y, legs[1], self.far_col, self.boot, lift[1])
        f.stamp(self.far_arm, 5 + x, 8 + y)
        f.stamp(self.torso, 5 + x, 7 + y)
        f.stamp(self.head, 5 + x + head_dx, 1 + y)
        leg(f, 9 + x, self.hip_y + y, legs[0], self.legs_col, self.boot, lift[0])
        if extra:
            extra(f, x, y)
        return f


# ---------- soldier: kettle helm, blue tabard with a gold buckle, spear ----------
S_HEAD = part('''
........
...AAB..
..AABBC.
.BAACCCD
...sKsK.
...ssst.''')
S_TORSO = part('''
CnbbbAB
.nbbbn.
.nbbbnt
.mmgmm.
.nbbn..''')
S_FAR_ARM = part('''
s
s
t''')
soldier = Human(S_HEAD, S_TORSO, S_FAR_ARM, 'm', 'o', 'o', 12)


def spear_up(dy=0, dx=0):
    def draw(f, x, y):
        for yy in range(4, 15):
            f.px[(12 + x + dx, yy + y + dy)] = 'l'
        f.px[(12 + x + dx, 2 + y + dy)] = 'A'
        f.px[(12 + x + dx, 3 + y + dy)] = 'B'
        f.px[(11 + x, 9 + y)] = 't'
    return draw


def spear_level(reach):
    def draw(f, x, y):
        for xx in range(4 + reach, 14 + reach):
            f.px[(xx + x, 9 + y)] = 'l'
        f.px[(14 + reach + x, 9 + y)] = 'B'
        f.px[(15 + reach + x, 9 + y)] = 'A'
        f.px[(11 + x, 9 + y)] = 't'
    return draw


s_idle = [soldier.frame(legs=(1, -1), extra=spear_up()), soldier.frame(legs=(1, -1), extra=spear_up()),
          soldier.frame(legs=(1, -1), extra=spear_up(-1)), soldier.frame(legs=(1, -1), extra=spear_up())]
s_walk = [soldier.frame(legs=(2, -1), extra=spear_up()), soldier.frame(legs=(0, 0), lift=(0, 1), y=-1, extra=spear_up()),
          soldier.frame(legs=(-1, 2), extra=spear_up()), soldier.frame(legs=(0, 0), lift=(1, 0), y=-1, extra=spear_up())]
s_atk = [soldier.frame(legs=(1, -1), x=-1, extra=spear_level(-2)), soldier.frame(legs=(2, -2), extra=spear_level(0)),
         soldier.frame(legs=(2, -2), x=1, extra=spear_level(0)), soldier.frame(legs=(1, -1), extra=spear_level(-1)),
         soldier.frame(legs=(1, -1), extra=spear_up())]

S_LYING = part('''
.AB...........
AABssnbbbbmmo.
.CDstnnngmmmoo''')
S_LYING_SPEAR = pts([(x, 15) for x in range(3, 14)], 'l')


def s_dead(blood):
    f = Frame(18, 18)
    f.stamp(S_LYING_SPEAR, 0, 0)
    f.stamp(S_LYING, 2, 12)
    f.px[(5, 13)] = 'K'
    if blood:
        f.px[(8, 15)] = 'r'
        f.px[(9, 15)] = 'r'
    return f


s_death = [soldier.frame(legs=(1, -1), x=-1, head_dx=-1, extra=spear_up(1, 1)),
           soldier.frame(legs=(1, -1), x=-1, y=2, head_dx=-1), s_dead(False), s_dead(True), s_dead(True)]

write_spec(sys.argv[2] + '/soldier.txt', '''
# Source of soldier.aseprite and soldier.png (python tools/sprite/sprite.py build <this> soldier.aseprite).
# Soldier: the Humans' basic unit, kettle helm c0cbdc/8b9bb4/5a6988, blue tabard 0099db/124e89 with a gold belt
# buckle feae34, spear b86f50. Stands three-quarter to the right, weight on the near leg, spear in the near hand.
# Built from parts (head, torso, arms, legs drawn hip to foot). Marches, thrusts, falls on its back.''',
           PAL_SOLDIER, (18, 18), [('IDLE', 200, s_idle), ('WALK', 110, s_walk), ('ATTACK', 100, s_atk), ('DEATH', 110, s_death)])

# ---------- scout: green hood, leather, dagger ----------
C_HEAD = part('''
.......
..jhhh.
.jhhhhh
.jjsKsK
.jjssst
..jjjj.''')
C_TORSO = part('''
.mllm.
.mlml.
.mllm.
.oooo.''')
C_FAR_ARM = part('''
.
s
t''')
scout = Human(C_HEAD, C_TORSO, C_FAR_ARM, 'm', 'o', 'o', 11)


def dagger(hx, hy, up=True):
    def draw(f, x, y):
        # the arm from the shoulder to the hand
        f.px[(hx - 1 + x, hy - 1 + y)] = 'l'
        f.px[(hx + x, hy + y)] = 't'
        if up:
            f.px[(hx + x, hy - 1 + y)] = 'B'
            f.px[(hx + x, hy - 2 + y)] = 'A'
        else:
            f.px[(hx + 1 + x, hy + y)] = 'B'
            f.px[(hx + 2 + x, hy + y)] = 'A'
    return draw


c_idle = [scout.frame(legs=(1, -1), extra=dagger(11, 10)), scout.frame(legs=(1, -1), extra=dagger(11, 10)),
          scout.frame(legs=(1, -1), extra=dagger(11, 9)), scout.frame(legs=(1, -1), extra=dagger(11, 10))]
NEAR = [2, 1, -1, -2, -1, 1]
c_walk = []
for n in NEAR:
    up = n in (1, -1)
    c_walk.append(scout.frame(legs=(n, -n), lift=(1 if n == -1 else 0, 1 if n == 1 else 0), y=-1 if up else 0, head_dx=1,
                              extra=dagger(11, 9 if up else 10)))
c_atk = [scout.frame(legs=(1, -1), x=-1, extra=dagger(9, 8)),
         scout.frame(legs=(2, -2), x=1, head_dx=1, extra=dagger(12, 10, False)),
         scout.frame(legs=(2, -2), x=1, head_dx=1, extra=dagger(12, 10, False)),
         scout.frame(legs=(1, -1), extra=dagger(11, 10)), scout.frame(legs=(1, -1), extra=dagger(11, 10))]
C_LYING = part('''
.jh...........
jhhssmllmmmo..
.jjstmlmooomo.''')


def c_dead(blood):
    f = Frame(18, 18)
    f.stamp(C_LYING, 2, 12)
    f.px[(5, 13)] = 'K'
    f.px[(14, 14)] = 'B'
    f.px[(15, 14)] = 'A'
    if blood:
        f.px[(8, 15)] = 'r'
        f.px[(9, 15)] = 'r'
    return f


c_death = [scout.frame(legs=(1, -1), x=-1, head_dx=-1), scout.frame(legs=(1, -1), x=-1, y=2, head_dx=-1),
           c_dead(False), c_dead(True), c_dead(True)]

write_spec(sys.argv[2] + '/scout.txt', '''
# Source of scout.aseprite and scout.png (python tools/sprite/sprite.py build <this> scout.aseprite).
# Scout: the Humans' fast unit, green hood 3e8948/265c42, leather 733e39/b86f50, a dagger. Leans into its run,
# three-quarter to the right. Built from parts (head, torso, arms, legs drawn hip to foot).
# Runs, stabs, falls on its back.''',
           PAL_SCOUT, (18, 18), [('IDLE', 200, c_idle), ('WALK', 80, c_walk), ('ATTACK', 80, c_atk), ('DEATH', 100, c_death)])
print('ok')
