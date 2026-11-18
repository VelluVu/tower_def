"""The enemies' shots: the archer's arrow (points right, the shot rotates it), the wizard's spell bolt (4-frame pulse)
and the Bog Hydra's acid glob (2-frame wobble).
usage: enemy_shots.py <parts dir> <projectile art dir>"""
import math
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, part, write_spec

OUT = sys.argv[2]
Frame.check_margin = lambda self, name: None

write_spec(OUT + '/enemy_arrow.txt', '''
# Source of enemy_arrow.aseprite and .png: the archer's arrow, pointing right (EnemyShot rotates it along its
# flight). White fletching, b86f50 shaft, steel head. Drawn by tools/sprite/parts/enemy_shots.py.''',
           {'w': 'ffffff', 'l': 'b86f50', 'A': 'c0cbdc', 'B': '8b9bb4'}, (12, 5),
           [('IDLE', 100, [Frame(12, 5).stamp(part('''
.w.......A
wwlllllllBA
.w.......A'''), 0, 1)])])

frames = []
for i in range(4):
    f = Frame(8, 8)
    pulse = 2.2 + 0.5 * math.sin(i / 4 * 2 * math.pi)
    for y in range(8):
        for x in range(8):
            d = math.hypot(x - 3.5, y - 3.5)
            if d < pulse * 0.45:
                f.px[(x, y)] = 'w'
            elif d < pulse * 0.8:
                f.px[(x, y)] = 'c'
            elif d < pulse + 0.4:
                f.px[(x, y)] = 'q'
    # two sparks circling the orb
    for k in range(2):
        a = i / 4 * 2 * math.pi + k * math.pi
        f.px[(round(3.5 + 3.4 * math.cos(a)), round(3.5 + 3.4 * math.sin(a)))] = 'y'
    frames.append(f)
write_spec(OUT + '/wizard_bolt.txt', '''
# Source of wizard_bolt.aseprite and .png: the wizard's spell, a pulsing orb (white core, cyan 2ce8f5, purple
# b55088 rim) with two circling sparks fee761. 4 frames. Drawn by tools/sprite/parts/enemy_shots.py.''',
           {'w': 'ffffff', 'c': '2ce8f5', 'q': 'b55088', 'y': 'fee761'}, (8, 8), [('IDLE', 80, frames)])
# the Bog Hydra's acid: a wobbling glob with a drip trailing behind (it flies in an arc, unrotated)
acid_frames = [Frame(8, 8).stamp(part('''
..aab.
.abbcc
abbccd
.bccd.
..dd..'''), 1, 1), Frame(8, 8).stamp(part('''
.aabb.
abbcc.
abccd.
.bcdd.
...d..'''), 1, 1)]
write_spec(OUT + '/hydra_acid.txt', '''
# Source of hydra_acid.aseprite and .png: the Bog Hydra's acid glob (Bog Spit), acid green b6d53c/7cbf4a with
# a pale e6f07a shine and a dark 4a9a5c drip. 2 frames. Drawn by tools/sprite/parts/enemy_shots.py.''',
           {'a': 'e6f07a', 'b': 'b6d53c', 'c': '7cbf4a', 'd': '4a9a5c'}, (8, 8), [('IDLE', 120, acid_frames)])
print('ok')
