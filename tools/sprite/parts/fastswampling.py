import sys
sys.path.insert(0, sys.argv[1])
from compose import *

PAL = {'c': '2a1a33', 'd': '45254f', 'e': '68386c', 'g': '8e4f7a', 'i': 'b55088',
       'f': '7a9a1e', 'j': 'b6d53c', 'k': 'e6f07a', 'm': 'fee761', 'b': '181425', 'l': 'f6757a'}

HEAD = part('''
.gg..
ggmbe
eeeee
ddddd''')
HEAD_OPEN = part('''
.gg..
ggmbe
eel..
.ddd.''')
HEAD_DEAD = part('''
.gg..
ggbbe
eeeee
ddddd''')
BODY = part('''
.jkjjkje
eeieeiee
.ddddddd''')
BODY_BREATH = part('''
.jkjjkje
eeieeiee
.ddddddd
..dddd..''')
TAIL_UP = part('''
g...
ge..
.eee
..dd''')
TAIL_MID = part('''
....
g...
geee
.ddd''')
TAIL_LOW = part('''
....
....
eeee
gddd''')

def legs(pose, bx, by):
    if pose == 'A':   # front reaching forward, rear pushed back
        p = [(6, 3, 'd'), (7, 4, 'd'), (8, 4, 'c'), (1, 3, 'd'), (0, 4, 'd'), (-1, 4, 'c')]
    elif pose == 'B':  # both under the body
        p = [(6, 3, 'd'), (6, 4, 'd'), (7, 4, 'c'), (1, 3, 'd'), (1, 4, 'd'), (2, 4, 'c')]
    else:              # front pushed back, rear reaching forward
        p = [(6, 3, 'd'), (5, 4, 'd'), (6, 4, 'c'), (1, 3, 'd'), (2, 4, 'd'), (3, 4, 'c')]
    return [(x + bx, y + by, c) for x, y, c in p]

BX, BY = 4, 12
def gecko(pose='B', tail=TAIL_MID, head=HEAD, body=BODY, dx=0, head_dy=0, body_dy=0):
    f = Frame(18, 18)
    bx, by = BX + dx, BY + body_dy
    f.stamp(tail, bx - 3, by - 1)
    f.stamp(body, bx, by)
    f.stamp(head, bx + 8, by - 1 + head_dy)
    for x, y, c in legs(pose, BX + dx, BY):
        f.px[(x, y)] = c
    return f

idle = [gecko('B', TAIL_MID), gecko('B', TAIL_MID, body=BODY_BREATH), gecko('B', TAIL_UP, body=BODY_BREATH), gecko('B', TAIL_UP)]
walk = [gecko('A', TAIL_MID), gecko('B', TAIL_LOW, body_dy=-1), gecko('C', TAIL_MID),
        gecko('C', TAIL_UP), gecko('B', TAIL_LOW, body_dy=-1), gecko('A', TAIL_UP)]
atk = [gecko('C', TAIL_MID, body=BODY_BREATH), gecko('A', TAIL_LOW, head=HEAD_OPEN, head_dy=-1),
       gecko('A', TAIL_LOW, head=HEAD_OPEN), gecko('B', TAIL_MID)]

def flipped(lift, legs_bent):
    # belly up: the body upside down, legs in the air
    f = Frame(18, 18)
    bx, by = BX, 13 - lift
    f.stamp(TAIL_LOW, bx - 3, by - 1, flipv=True)
    f.stamp(BODY, bx, by, flipv=True)
    f.stamp(HEAD_DEAD, bx + 8, by - 1 + 1, flipv=True)
    # legs in the air, two rows tall and lighter than the body so they read on its dark back; bent ones curl in
    leg = [(1, -1, 'g'), (1, -2, 'g'), (2 if legs_bent else 0, -3, 'i'),
           (6, -1, 'g'), (6, -2, 'g'), (5 if legs_bent else 7, -3, 'i')]
    for x, y, c in leg:
        f.px[(bx + x, by + y)] = c
    return f

def rolling():
    f = gecko('A', TAIL_UP, head=HEAD_DEAD, body_dy=-1)
    return f
death = [rolling(), flipped(2, False), flipped(0, False), flipped(0, True), flipped(0, True)]

write_spec(sys.argv[2], '''
# Source of fastswampling.aseprite and fastswampling.png (python tools/sprite/sprite.py build <this> fastswampling.aseprite).
# Fastswampling: a toxic swamp gecko, purple ramp 2a1a33/45254f/68386c/8e4f7a with b55088 spots, an acid
# b6d53c/e6f07a stripe down the back, fee761 eye. Built from parts (head, body, tail, three leg poses) so the
# shapes hold between frames. Scurries, lunges to bite with its mouth open, flips belly up.''',
    PAL, (18, 18), [('IDLE', 150, idle), ('WALK', 70, walk), ('ATTACK', 100, atk), ('DEATH', 100, death)])
print('ok')
