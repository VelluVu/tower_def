"""Wall stages and element overlays, repainted from the stone wall's pixel roles so every connector shape matches.

The stone wall (assets/art/units/building/wall/wall.png, 16 connector tags) has eight greys; each is a role:
outside ground (3c? no: 565869/5f6273 checker), mortar 3c3b4c, walkway 454556/4e4e5f, parapet bricks
717586/9da5b6/a6afc0. A stage repaints the roles (and adds crenels or stakes); an element overlay draws only
its details (embers, ice crust, moss) on a transparent sheet with the same tags, to layer over any stage.
usage: walls.py <parts dir> <wall art dir>"""
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, write_spec
from PIL import Image

DIR = sys.argv[2]
TAGS = ['CONNECTOR_LRDU', 'CONNECTOR_LRD', 'CONNECTOR_LRU', 'CONNECTOR_LU', 'CONNECTOR_LUD', 'CONNECTOR_LD',
        'CONNECTOR_RUD', 'CONNECTOR_RD', 'CONNECTOR_UR', 'CONNECTOR_X', 'HORIZONTAL', 'HORIZONTAL_END_R',
        'HORIZONTAL_END_L', 'VERTICAL', 'VERTICAL_END_U', 'VERTICAL_END_D']
GREYS = ['3c3b4c', '454556', '4e4e5f', '565869', '5f6273', '717586', '9da5b6', 'a6afc0']
# role per grey: M mortar, w/W walkway, g/G outside ground, b/B/T brick shade, mid, top
ROLE = dict(zip(GREYS, ['M', 'w', 'W', 'g', 'G', 'b', 'B', 'T']))

sheet = Image.open(DIR + '/wall.png').convert('RGBA')
cols = sheet.width // 18


def roles(i):
    ox, oy = (i % cols) * 18, (i // cols) * 18
    out = {}
    for y in range(18):
        for x in range(18):
            p = sheet.getpixel((ox + x, oy + y))
            if p[3]:
                out[(x, y)] = ROLE['%02x%02x%02x' % p[:3]]
    return out


FRAMES = [roles(i) for i in range(16)]
BRICK = set('bBT')


def nb(r, x, y):
    return [r.get((x + dx, y + dy)) for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1))]


def h(x, y, t):
    return (x * 73856093 ^ y * 19349663 ^ t * 83492791) & 0xffff


def stage(name, pal, header, crenels=False, stakes=False):
    tags = []
    for t, r in enumerate(FRAMES):
        f = Frame(18, 18)
        for (x, y), c in r.items():
            ch = c
            if crenels and c == 'W':
                l, rr, u, d = nb(r, x, y)
                if (l in BRICK and rr in BRICK) or (u in BRICK and d in BRICK):
                    ch = 'C'
            if crenels and c == 'T':
                ch = 'H'
            if stakes and c in BRICK:
                # each brick becomes a stake top: a light ring with a dark core on its lower pixel
                ch = {'T': 'H', 'B': 'T', 'b': 'b'}[c]
            f.px[(x, y)] = ch
        tags.append((TAGS[t], 100, [f]))
    write_spec(DIR + '/%s.txt' % name, header, pal, (18, 18), tags)


stage('wall_palisade', {'M': '3e2731', 'w': '733e39', 'W': '8a5a3c', 'g': 'a37752', 'G': 'b86f50', 'b': '733e39',
                        'B': 'b86f50', 'T': 'e4a672', 'H': 'ead4aa'},
      '''# Source of wall_palisade.aseprite and wall_palisade.png: wall stage 1 (Up 0), a wooden palisade. Repainted
# from wall.png's pixel roles by tools/sprite/parts/walls.py: stake tops e4a672/ead4aa on dark wood 3e2731,
# a plank walkway, trampled earth around it. Same 16 connector tags as wall.aseprite.''', stakes=True)

stage('wall_battlements', {'M': '262b44', 'w': '3a4466', 'W': '454556', 'g': '565869', 'G': '5f6273',
                           'b': '5a6988', 'B': '8b9bb4', 'T': 'a6afc0', 'H': 'c0cbdc', 'C': '181425'},
      '''# Source of wall_battlements.aseprite and wall_battlements.png: wall stage 3, stone with battlements. Repainted
# from wall.png's pixel roles by tools/sprite/parts/walls.py: brighter merlons c0cbdc and dark crenel gaps 181425
# between them, a darker walkway. Same 16 connector tags as wall.aseprite.''', crenels=True)

stage('wall_castle', {'M': '3a4466', 'w': '8b9bb4', 'W': '5a6988', 'g': '565869', 'G': '5f6273',
                      'b': 'c0cbdc', 'B': 'e0caa3', 'T': 'ecd8b1', 'H': 'ffffff', 'C': '262b44'},
      '''# Source of wall_castle.aseprite and wall_castle.png: wall stage 4, the castle wall. Repainted from wall.png's
# pixel roles by tools/sprite/parts/walls.py: pale dressed stone ecd8b1/ffffff merlons with crenels, blue-grey
# mortar, a paved walkway. Same 16 connector tags as wall.aseprite.''', crenels=True)


def overlay(name, pal, header, paint):
    tags = []
    for t, r in enumerate(FRAMES):
        f = Frame(18, 18)
        paint(f, r, t)
        tags.append((TAGS[t], 100, [f]))
    write_spec(DIR + '/%s.txt' % name, header, pal, (18, 18), tags)


def embers(f, r, t):
    for (x, y), c in r.items():
        if c == 'M' and any(n in BRICK for n in nb(r, x, y)) and h(x, y, t) % 5 == 0:
            f.px[(x, y)] = 'o'
            if r.get((x + 1, y)) == 'M':
                f.px[(x + 1, y)] = 'y' if h(x, y, t) % 2 else 'o'
        if c == 'W' and h(x, y, t) % 23 == 0:
            f.px[(x, y)] = 'r'


def ice(f, r, t):
    for (x, y), c in r.items():
        if c == 'T':
            f.px[(x, y)] = 'w' if h(x, y, t) % 3 else 'c'
        elif c == 'B' and h(x, y, t) % 2 == 0:
            f.px[(x, y)] = 'c'
        elif c == 'M' and r.get((x, y - 1)) in BRICK and r.get((x, y + 1)) not in BRICK and h(x, y, t) % 3 == 0:
            # icicles hang from the south side of a parapet
            f.px[(x, y)] = 'b'
            if r.get((x, y + 1)) in ('w', 'W', 'g', 'G'):
                f.px[(x, y + 1)] = 'b'


def moss(f, r, t):
    for (x, y), c in r.items():
        k = h(x, y, t)
        if c == 'M' and k % 3 == 0:
            f.px[(x, y)] = 'm' if k % 2 else 'n'
        elif c == 'b' and k % 4 == 0:
            f.px[(x, y)] = 'n'
        elif c == 'T' and k % 7 == 0:
            f.px[(x, y)] = 'l'
        if c == 'M' and r.get((x, y + 1)) in ('w', 'W', 'g', 'G') and k % 5 == 0:
            f.px[(x, y + 1)] = 'm'
            if r.get((x, y + 2)) in ('w', 'W', 'g', 'G'):
                f.px[(x, y + 2)] = 'd'


def iron(f, r, t):
    """Fortress: iron caps on the parapet tops with pale rivets, dark iron bands in the mortar under the bricks,
    a few gold studs on the brick faces."""
    for (x, y), c in r.items():
        k = h(x, y, t)
        if c == 'T':
            f.px[(x, y)] = 'r' if k % 4 == 0 else 'a'
        elif c == 'M' and r.get((x, y - 1)) in BRICK:
            f.px[(x, y)] = 'i'
        elif c == 'B' and k % 9 == 0:
            f.px[(x, y)] = 'y'


overlay('wall_fire_overlay', {'o': 'f77622', 'y': 'feae34', 'r': 'e43b44'},
        '''# Source of wall_fire_overlay.aseprite and .png: Fire wall details, embers glowing in the mortar next to the
# bricks. Transparent except the details; layer it over any wall stage (same 16 connector tags).
# Generated by tools/sprite/parts/walls.py from wall.png's pixel roles.''', embers)
overlay('wall_frost_overlay', {'w': 'ffffff', 'c': 'c0f0ff', 'b': '2ce8f5'},
        '''# Source of wall_frost_overlay.aseprite and .png: Frost wall details, an ice crust on the parapet tops and
# icicles hanging from the south sides. Transparent except the details; layer it over any wall stage.
# Generated by tools/sprite/parts/walls.py from wall.png's pixel roles.''', ice)
overlay('wall_poison_overlay', {'m': '3e8948', 'n': '265c42', 'l': '63c74d', 'd': '193c3e'},
        '''# Source of wall_poison_overlay.aseprite and .png: Poison wall details, moss in the mortar and on the bricks
# with dripping strands. Transparent except the details; layer it over any wall stage.
# Generated by tools/sprite/parts/walls.py from wall.png's pixel roles.''', moss)
print('ok')
overlay('wall_fortress_overlay', {'a': '8b9bb4', 'r': 'c0cbdc', 'i': '262b44', 'y': 'feae34'},
        '''# Source of wall_fortress_overlay.aseprite and .png: Fortress wall details, iron caps with rivets on the
# parapet tops, iron bands under the bricks and a few gold studs. Transparent except the details; layer it over any
# wall stage. Generated by tools/sprite/parts/walls.py from wall.png's pixel roles.''', iron)
