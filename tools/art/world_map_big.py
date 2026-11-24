"""The bigger world map (2026-11-24, the user's picks): 2x2 screens, 600x336 art pixels at the game's 2x scale, drawn
from today's 300x168 world_map.png as the layout. The shapes come from a pixel-art 2x upscale (Scale2x: coasts and
mountains stay smooth), the 1 px outlines are thinned back to 1 px, the small icons (bushes, pools, boulders, huts)
are drawn again at the finer size, and each area's land gets its own fine texture: the forest's trees, the swamp's
dead trees and bog pools, the Wasted Lands' furrows and stumps, the desert's dune ripples, the volcano's cracks and
lava streaks; water gets glints and foam along the shore. Which area a pixel belongs to: the nearest level node
(game_world_map.tscn). Endesga 32 only, like the old map.

    python tools/art/world_map_big.py [--preview out.png]

Writes assets/art/ui/world_map_big.png and its .aseprite (one layer, for the user to refine by hand: rerunning
overwrites both, so stop rerunning once the .aseprite has hand edits).
"""
import math
import os
import re
import subprocess
import sys
import zlib
from collections import Counter, deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "assets", "art", "ui", "world_map.png")
OUT_PNG = os.path.join(ROOT, "assets", "art", "ui", "world_map_big.png")
OUT_ASEPRITE = os.path.join(ROOT, "assets", "art", "ui", "world_map_big.aseprite")
MAP_SCENE = os.path.join(ROOT, "scenes", "ui", "game_world_map", "game_world_map.tscn")
ASEPRITE_EXE = "C:/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe"
LEVELS_PER_AREA = 12
# the Map control shows the big map at 1200x672 (2 units per art pixel, 4 per pixel of the old map); the node offsets
# are in that space, a node 20x20
NODE_SPACE_SCALE = 4
NODE_HALF = 10


def rgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


C = {k: rgb(v) for k, v in {
    'water': '0099db', 'deep': '124e89', 'glint': '2ce8f5', 'foam': 'c0cbdc', 'white': 'ffffff',
    'rock1': 'c0cbdc', 'rock2': '8b9bb4', 'rock3': '5a6988', 'rock4': '3a4466', 'rock5': '262b44', 'night': '181425',
    'forest': '265c42', 'grass': '3e8948', 'meadow': '63c74d', 'shade': '193c3e',
    'sand': 'ead4aa', 'sand2': 'e8b796', 'dirt': 'e4a672', 'dirt2': 'c28569', 'furrow': 'b86f50', 'clay': 'd77643',
    'brown': '733e39', 'outline': '3e2731', 'red': 'a22633', 'lava': 'e43b44', 'ember': 'f77622', 'gold': 'feae34',
    'rust': 'be4a2f', 'purple': '68386c', 'pink': 'b55088', 'rose': 'f6757a', 'tan': 'e8b796',
}.items()}
OUTLINES = {C['outline'], C['night']}
WATERS = {C['water']}
# region colours: what a big flat area of that colour is; anything else small inside one is an icon
GROUND = {C['forest'], C['grass'], C['meadow'], C['sand'], C['dirt'], C['red'], C['lava'], C['water'],
          C['rock2'], C['rock3'], C['rock4'], C['rock5'], C['furrow'], C['sand2']}
ICON_MAX_PIXELS = 18
ICON_MAX_SIZE = 7
# rocks and oases may be bigger and are still redrawn (boulder heaps, pools with a shore)
BIG_ICON_COLOURS = {C['rock4'], C['rock5'], C['water']}
BIG_ICON_MAX_PIXELS = 48
BIG_ICON_MAX_SIZE = 10


def h(*key):
    return zlib.crc32(repr(key).encode())


def rnd(*key):
    return (h(*key) % 10007) / 10007.0


# ----------------------------------------------------------------------- the layout
def node_centres():
    """level -> its centre in old map pixels"""
    text = open(MAP_SCENE, encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'\[node name="Level_(\d+)" type="Panel" parent="MapView/Map"[^\n]*\]\n(.*?)\n\n',
                         text, re.S):
        left = float(re.search(r'offset_left = ([-\d.]+)', m.group(2)).group(1))
        top = float(re.search(r'offset_top = ([-\d.]+)', m.group(2)).group(1))
        out[int(m.group(1))] = ((left + NODE_HALF) / NODE_SPACE_SCALE, (top + NODE_HALF) / NODE_SPACE_SCALE)
    return out


def area_map(width, height, nodes, scale):
    """every pixel's area (0 caves and forest, 1 swamp, 2 Wasted Lands, 3 desert, 4 volcano): the nearest node's"""
    points = [((x * scale, y * scale), (level - 1) // LEVELS_PER_AREA) for level, (x, y) in nodes.items()]
    out = [[0] * width for _ in range(height)]
    for y in range(height):
        for x in range(width):
            best = min(points, key=lambda p: (p[0][0] - x) ** 2 + (p[0][1] - y) ** 2)
            out[y][x] = best[1]
    return out


def find_icons(src):
    """small blobs that differ from the colour around them: (pixels, colours, the ground colour round it)"""
    w, h_ = src.size
    px = src.load()
    seen = set()
    icons = []
    for y in range(h_):
        for x in range(w):
            if (x, y) in seen:
                continue
            colour = px[x, y]
            # one component of pixels that are not this blob's surrounding ground
            group, todo = [], deque([(x, y)])
            seen.add((x, y))
            while todo and len(group) <= BIG_ICON_MAX_PIXELS * 2:
                c = todo.popleft()
                group.append(c)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    n = (c[0] + dx, c[1] + dy)
                    if 0 <= n[0] < w and 0 <= n[1] < h_ and n not in seen and px[n] == colour:
                        seen.add(n)
                        todo.append(n)
            big = colour in BIG_ICON_COLOURS
            if colour in OUTLINES or len(group) > (BIG_ICON_MAX_PIXELS if big else ICON_MAX_PIXELS):
                continue
            xs, ys = [c[0] for c in group], [c[1] for c in group]
            limit = BIG_ICON_MAX_SIZE if big else ICON_MAX_SIZE
            if max(xs) - min(xs) >= limit or max(ys) - min(ys) >= limit:
                continue
            ring = Counter()
            gs = set(group)
            for gx, gy in group:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        n = (gx + dx, gy + dy)
                        if n not in gs and 0 <= n[0] < w and 0 <= n[1] < h_:
                            ring[px[n]] += 1
            ground = ring.most_common(1)[0][0] if ring else colour
            if ground == colour or ground not in GROUND:
                continue
            icons.append((group, colour, ground))
    return icons


# ----------------------------------------------------------------------- scale2x
def scale2x(src):
    w, h_ = src.size
    p = src.load()
    out = Image.new("RGB", (w * 2, h_ * 2))
    o = out.load()
    for y in range(h_):
        for x in range(w):
            e = p[x, y]
            b = p[x, max(0, y - 1)]
            hh = p[x, min(h_ - 1, y + 1)]
            d = p[max(0, x - 1), y]
            f = p[min(w - 1, x + 1), y]
            if b != hh and d != f:
                e0 = d if d == b else e
                e1 = f if b == f else e
                e2 = d if d == hh else e
                e3 = f if hh == f else e
            else:
                e0 = e1 = e2 = e3 = e
            o[2 * x, 2 * y], o[2 * x + 1, 2 * y], o[2 * x, 2 * y + 1], o[2 * x + 1, 2 * y + 1] = e0, e1, e2, e3
    return out


# ----------------------------------------------------------------------- drawing
class Canvas:
    def __init__(self, image):
        self.im = image
        self.px = image.load()
        self.w, self.h = image.size

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return None

    def put(self, x, y, colour):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = colour


def thin_outlines(cv):
    """the 2x upscale doubled every 1 px outline: an outline pixel that does not touch the land it outlines from
    outside (water or another region) goes back to the colour next to it"""
    change = []
    for y in range(cv.h):
        for x in range(cv.w):
            c = cv.px[x, y]
            if c not in OUTLINES:
                continue
            neigh = [cv.get(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            others = [n for n in neigh if n is not None and n not in OUTLINES]
            if not others:
                continue
            if any(n in WATERS for n in others):
                continue  # the row next to the water stays
            # inner row of a doubled line: next to land only, and next to another outline pixel on the far side
            land = Counter(others).most_common(1)[0][0]
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if cv.get(x + dx, y + dy) in OUTLINES and cv.get(x - dx, y - dy) == land:
                    change.append((x, y, land))
                    break
    for x, y, colour in change:
        cv.px[x, y] = colour


def tree(cv, x, y, palette, key):
    """a small round tree, 5 wide, its trunk foot at x, y"""
    leaf_dark, leaf, leaf_light, trunk = palette
    shape = ["  1  ", " 122 ", "11222", "01110", " 000 "]
    if rnd(key, 'small') < 0.4:
        shape = [" 12 ", "1122", "0110", " 00 "]
    top = y - len(shape)
    for row, line in enumerate(shape):
        for col, ch in enumerate(line):
            if ch == ' ':
                continue
            colour = {'0': leaf_dark, '1': leaf, '2': leaf_light}[ch]
            cv.put(x - len(line) // 2 + col, top + row, colour)
    cv.put(x, y, trunk)


def dead_tree(cv, x, y, key):
    """a bare swamp tree: trunk and two crooked branches"""
    trunk = C['outline']
    for k in range(5):
        cv.put(x, y - k, trunk)
    cv.put(x - 1, y - 3, trunk)
    cv.put(x - 2, y - 4, trunk)
    cv.put(x + 1, y - 4, trunk)
    cv.put(x + 2, y - 5, trunk)
    if rnd(key, 'moss') < 0.5:
        cv.put(x - 2, y - 3, C['grass'])


def bog_pool(cv, x, y, key):
    rx = 2 + int(rnd(key, 'rx') * 3)
    for dy in range(-2, 3):
        for dx in range(-rx - 1, rx + 2):
            d = (dx / (rx + 0.5)) ** 2 + (dy / 2.2) ** 2
            if d <= 1.0:
                cv.put(x + dx, y + dy, C['shade'] if d > 0.6 or dy < 0 else C['deep'])
    cv.put(x - rx + 1, y, C['glint'])


def pool(cv, x, y, key, r=3):
    for dy in range(-r, r + 1):
        for dx in range(-r - 1, r + 2):
            d = (dx / (r + 0.8)) ** 2 + (dy / (r + 0.3)) ** 2
            if d <= 1.0:
                cv.put(x + dx, y + dy, C['water'] if d < 0.62 else C['sand'] if dy > 0 else C['outline'])
    cv.put(x - 1, y - 1, C['glint'])


def boulder(cv, x, y, key):
    for dy, line in enumerate([" 12 ", "1223", "3333"]):
        for dx, ch in enumerate(line):
            if ch != ' ':
                cv.put(x - 2 + dx, y - 2 + dy, {'1': C['rock2'], '2': C['rock3'], '3': C['rock4']}[ch])


def hut(cv, x, y, key):
    for dy, line in enumerate(["  0  ", " 001 ", "00011", " 232 ", " 242 "]):
        for dx, ch in enumerate(line):
            if ch != ' ':
                cv.put(x - 2 + dx, y - 4 + dy, {'0': C['rust'], '1': C['brown'], '2': C['dirt2'], '3': C['furrow'],
                                                '4': C['outline']}[ch])


TREE_FOREST = (C['shade'], C['forest'], C['grass'], C['outline'])
TREE_GRASS = (C['forest'], C['grass'], C['meadow'], C['outline'])


def redraw_icons(cv, icons, areas):
    """paint each old icon over with its ground, then draw a fresh one in its place"""
    for group, colour, ground in icons:
        for gx, gy in group:
            for dx in (0, 1):
                for dy in (0, 1):
                    cv.put(gx * 2 + dx, gy * 2 + dy, ground)
    for group, colour, ground in icons:
        xs, ys = [c[0] for c in group], [c[1] for c in group]
        x, y = round(sum(xs) / len(xs) * 2 + 1), round(sum(ys) / len(ys) * 2 + 1)
        area = areas[min(cv.h - 1, y)][min(cv.w - 1, x)]
        key = (x, y)
        size = max(max(xs) - min(xs), max(ys) - min(ys)) + 1
        if colour == C['water'] and ground not in (C['forest'], C['grass']):
            pool(cv, x, y, key, max(2, size - 1))  # an oasis with its shore
        elif colour in (C['deep'], C['water'], C['shade'], C['meadow'], C['grass'], C['forest'])                 and ground in (C['forest'], C['grass'], C['meadow']):
            if area == 1:
                dead_tree(cv, x, y + 2, key)
            else:
                tree(cv, x, y + 3, TREE_FOREST if ground == C['forest'] else TREE_GRASS, key)
        elif colour in (C['rock4'], C['rock5']) and size >= 4:
            for k in range(2 + size // 3):  # a heap of boulders where the old blob was
                boulder(cv, x + round((rnd(key, k, 'bx') - 0.5) * size * 1.6), y + round((rnd(key, k, 'by') - 0.5) * size), (key, k))
        elif colour in (C['rock3'], C['rock4'], C['rock5']):
            boulder(cv, x, y + 1, key)
        elif colour in (C['brown'], C['outline']) and area == 2 and len(group) >= 3:
            hut(cv, x, y + 2, key)
        elif colour in (C['brown'], C['outline'], C['rock2']):
            pass  # specks along coasts and edges: the ground is enough
        else:
            for gx, gy in group:  # anything else stays as it was
                for dx in (0, 1):
                    for dy in (0, 1):
                        cv.put(gx * 2 + dx, gy * 2 + dy, colour)


def flat(cv, x, y, colour, r=2):
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if cv.get(x + dx, y + dy) != colour:
                return False
    return True


def texture(cv, areas):
    """fine detail on flat ground, per colour and area"""
    base = cv.im.copy()
    bp = base.load()
    cvb = Canvas(base)
    trees = []
    for y in range(cv.h):
        for x in range(cv.w):
            c = bp[x, y]
            area = areas[y][x]
            r = rnd(x, y, 'tex')
            if c == C['water']:
                if r < 0.012 and flat(cvb, x, y, c, 2):
                    cv.put(x, y, C['glint'])
                    cv.put(x + 1, y, C['glint'])
                    if rnd(x, y, 'g3') < 0.5:
                        cv.put(x + 2, y, C['glint'])
                # foam on the water next to land
                elif any(bp[nx, ny] not in WATERS and bp[nx, ny] != C['deep'] for nx, ny in
                         ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)) if 0 <= nx < cv.w and 0 <= ny < cv.h):
                    if rnd(x, y, 'foam') < 0.18:
                        cv.put(x, y, C['foam'])
            elif c == C['forest']:
                if area == 1:  # swamp: darker mud patches, reeds, dead trees, little pools
                    if r < 0.0015 and flat(cvb, x, y, c, 4):
                        bog_pool(cv, x, y, (x, y))
                    elif r < 0.02 and flat(cvb, x, y, c, 2):
                        trees.append(('dead', x, y))
                    elif r < 0.06:
                        cv.put(x, y, C['shade'])
                elif r < 0.09 and flat(cvb, x, y, c, 2) and (x + y * 3) % 4 == 0:
                    trees.append(('forest', x, y))
                elif r < 0.12:
                    cv.put(x, y, C['shade'])
            elif c == C['grass']:
                if area == 1 and r < 0.05:
                    cv.put(x, y, C['forest'])
                elif r < 0.012 and flat(cvb, x, y, c, 2):
                    trees.append(('grass', x, y))
                elif r < 0.06:
                    cv.put(x, y, C['forest'] if rnd(x, y, 'tuft') < 0.6 else C['meadow'])
            elif c == C['meadow']:
                if r < 0.05:
                    cv.put(x, y, C['grass'])
                elif r < 0.058:
                    cv.put(x, y, C['white'] if rnd(x, y, 'fl') < 0.5 else C['gold'])
            elif c in (C['sand'], C['sand2']):
                # dune ripples: short arcs in rows
                if (y + round(math.sin(x * 0.18 + y * 0.05) * 2)) % 7 == 0 and rnd(x // 6, y, 'rip') < 0.5:
                    cv.put(x, y, C['sand2'] if c == C['sand'] else C['dirt'])
                elif r < 0.004:
                    cv.put(x, y, C['furrow'])
            elif c == C['dirt']:
                if area == 2 and r < 0.03:
                    cv.put(x, y, C['dirt2'])
                elif r < 0.025:
                    cv.put(x, y, C['sand2'])
            elif c == C['red']:
                if r < 0.01 and flat(cvb, x, y, c, 2):  # cracks
                    for k in range(2 + int(rnd(x, y, 'cl') * 4)):
                        cv.put(x + k, y + round(math.sin(k + x) * 0.8), C['outline'])
                elif r < 0.03:
                    cv.put(x, y, C['rust'])
            elif c == C['lava']:
                if (x * 2 + y) % 11 == 0 and r < 0.5:
                    cv.put(x, y, C['ember'])
                elif r < 0.02:
                    cv.put(x, y, C['gold'])
            elif c in (C['rock2'], C['rock3'], C['rock4']):
                darker = {C['rock2']: C['rock3'], C['rock3']: C['rock4'], C['rock4']: C['rock5']}[c]
                if r < 0.012 and flat(cvb, x, y, c, 2):  # cracks and strata
                    for k in range(2 + int(rnd(x, y, 'st') * 3)):
                        cv.put(x + k, y + (k // 2), darker)
                elif r < 0.03 and c != C['rock2'] and bp[x, max(0, y - 1)] == c:
                    cv.put(x, y, {C['rock3']: C['rock2'], C['rock4']: C['rock3']}[c])
    for kind, x, y in sorted(trees, key=lambda t: t[2]):
        if kind == 'dead':
            dead_tree(cv, x, y, (x, y))
        else:
            tree(cv, x, y, TREE_FOREST if kind == 'forest' else TREE_GRASS, (x, y))


# terraced rock in the old map's own style (2026-11-24, the user: the pointed peaks looked "detached and hurt the
# eye"): seen from above like every other mountain on the map, no outline, flat lit tops in rock2 with dash marks,
# cliff faces dropping south in rock3, rock4 and rock5 at the foot, loose boulders round it
TERRACE = 5
# the range's heights in GREAT_CAVE_RANGE were for peaks; as flat topped rock they stand this much of it
RANGE_HEIGHT_SHARE = 0.55
FACE_COLOURS = (C['rock3'], C['rock4'], C['rock4'], C['rock5'], C['rock5'])
# the range's footprints widen by this much, so its rocks run together into one massif
RANGE_SPREAD = 1.35


def rock_mass(cv, blobs, key, mesa=()):
    """draws rock masses: `blobs` are (x, south edge y, half width, height) footprints, flattened ellipses whose
    elevation domes up to `height` px; blobs listed in `mesa` rise steeply into a flat top (tall cliff faces). The
    elevation comes in TERRACE px steps and is drawn oblique, back to front, so every step shows its cliff face.
    Returns the screen pixels it drew and each column's footprint, for what is drawn on it after."""
    foot = {}
    for i, (bx, south, half, height) in enumerate(blobs):
        ry = max(4.0, half * 0.55)
        cy = south - ry
        phase = rnd(key, i, 'phase') * 6.0
        for y in range(int(cy - ry - 2), south + 2):
            for x in range(int(bx - half - 3), int(bx + half + 4)):
                wobble = 1.0 + 0.08 * math.sin(math.atan2(y - cy, x - bx) * 5 + phase) + (rnd(x // 3, y // 3, key) - 0.5) * 0.06
                r = math.hypot((x - bx) / half, (y - cy) / ry) / wobble
                if r >= 1.0:
                    continue
                if i in mesa:
                    # a flat top with a lower shelf round it, two big steps like the map's other rocks; the top sits
                    # off the middle (north east) and the steps' edges wander, so no two rocks look like rings
                    angle = math.atan2(y - cy, x - bx)
                    rt = math.hypot((x - bx - half * 0.18) / half, (y - cy + ry * 0.2) / ry) / wobble
                    upper = 0.5 + 0.12 * math.sin(angle * 3 + phase * 2.3) + 0.06 * math.sin(angle * 7 + phase)
                    lower = 0.82 + 0.08 * math.sin(angle * 4 + phase * 1.3)
                    e = height * (1.0 if rt < upper else 0.6 if r < lower else 0.25)
                else:
                    e = height * (1.0 - r * r) ** 0.8
                foot[(x, y)] = max(foot.get((x, y), 0.0), e)
    drawn = {}
    for (x, y) in sorted(foot, key=lambda p: p[1]):  # back to front
        e = TERRACE * round(foot[(x, y)] / TERRACE) + 2  # every mass stands at least 2 px proud of the ground
        top = y - e
        for k in range(e, -1, -1):  # the face, from the ground up to below the top
            sy = y - k
            depth = e - k  # px below the top edge
            colour = FACE_COLOURS[min(len(FACE_COLOURS) - 1, depth * len(FACE_COLOURS) // max(4, e + 1))]
            drawn[(x, sy)] = colour
        drawn[(x, top)] = 'top'
    tops = {p for p, c in drawn.items() if c == 'top'}
    for (x, y), c in drawn.items():
        if c == 'top':
            # a top pixel with a face right below it is the step's lit rim; the west rim of a top is in shadow
            colour = C['rock2']
            if (x - 1, y) not in tops and (x - 1, y) in drawn:
                colour = C['rock3']
            elif rnd(x // 2, y, key, 'dash') < 0.05 and (x + 1, y) in tops:
                colour = C['rock3']
            elif rnd(x, y, key, 'speck') < 0.015:
                colour = C['rock1']
            cv.put(x, y, colour)
        else:
            cv.put(x, y, c)
    for (x, y) in list(tops):  # dash marks as two pixel streaks, like the old map's
        if (x + 1, y) in tops and cv.get(x, y) == C['rock3'] and cv.get(x - 1, y) == C['rock2']:
            cv.put(x + 1, y, C['rock3'])
    return drawn, foot


def scatter_boulders(cv, drawn, key, chance=0.06):
    """loose boulders on the ground and in the water just south of a rock mass, like round the map's other rocks"""
    edge = [(x, y) for (x, y) in drawn if (x, y + 1) not in drawn]
    for (x, y) in edge:
        if rnd(x, y, key, 'boulder') < chance:
            bx, by = x + int((rnd(x, key, 'bx') - 0.5) * 6), y + 2 + int(rnd(y, key, 'by') * 4)
            if all((bx + dx, by + dy) not in drawn for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0)):
                boulder(cv, bx, by, (key, x, y))


def mountain_range(cv):
    """the range round the great cave, out over the west coast into the sea (the user, 2026-11-24)"""
    blobs = [(x, south, half * RANGE_SPREAD, height * RANGE_HEIGHT_SHARE) for x, south, half, height in GREAT_CAVE_RANGE]
    drawn, _ = rock_mass(cv, blobs, 'range', mesa=range(len(blobs)))
    scatter_boulders(cv, drawn, 'range')


def great_cave(cv, cx, base):
    """the Broodmother's great cave at the swamp's edge (2026-11-24): a rock bigger than the southern one, flat
    topped like it, its dark mouth cut into the tall south face (base = the mouth's floor) with stalactite teeth, a
    red glow from the nest inside, a torch on each side and rubble"""
    half = GREAT_CAVE_HALF
    drawn, _ = rock_mass(cv, [(cx, base, half, GREAT_CAVE_HEIGHT)], 'great cave', mesa=(0,))
    scatter_boulders(cv, drawn, 'great cave', 0.04)
    mouth_half, mouth_height = 9, 15
    for y in range(base - mouth_height, base + 1):
        w = round(mouth_half * math.sqrt(max(0.0, 1 - ((base - y) / (mouth_height + 0.5)) ** 2)))
        for x in range(cx - w - 1, cx + w + 2):
            cv.put(x, y, C['night'] if abs(x - cx) < w else C['rock5'])
    for k in range(3, 8):  # the nest's red glow deep inside
        cv.put(cx - 3 + k % 5, base - 1 - k // 4, C['red'] if k % 2 else C['purple'])
    cv.put(cx - 1, base - 3, C['rose'])
    cv.put(cx + 2, base - 2, C['rose'])
    for x in range(cx - 6, cx + 7, 3):  # teeth
        top = base - mouth_height + 1 + abs(x - cx) // 4
        cv.put(x, top, C['rock3'])
        cv.put(x, top + 1, C['rock4'])
        if (x - cx) % 6 == 0:
            cv.put(x, top + 2, C['rock4'])
    for tx in (cx - mouth_half - 4, cx + mouth_half + 4):  # torches
        for k in range(3):
            cv.put(tx, base - k, C['brown'])
        cv.put(tx, base - 3, C['ember'])
        cv.put(tx, base - 4, C['gold'])
        cv.put(tx - 1, base - 3, C['ember'])
    for k in range(7):
        boulder(cv, cx - half + int(rnd('rubble', k) * half * 2), base + 2 + int(rnd('rubble y', k) * 2), ('r', k))


def dirt_yard(cv, cx, base, track_to):
    """trampled dirt in front of the great cave, ruts and pebbles, and a track from it to `track_to`"""
    for y in range(base - 1, base + 14):
        for x in range(cx - 26, cx + 27):
            d = ((x - cx) / 25.5) ** 2 + ((y - base - 5) / 8.5) ** 2
            if d > 1.0 or (d > 0.8 and rnd(x, y, 'edge') < 0.5):
                continue
            cv.put(x, y, C['dirt2'] if rnd(x, y, 'dirt') < 0.12 else C['dirt'])
    tx, ty = track_to
    sx, sy = cx + 18, base + 6
    steps = max(abs(tx - sx), abs(ty - sy))
    for k in range(steps + 1):
        x = round(sx + (tx - sx) * k / steps)
        y = round(sy + (ty - sy) * k / steps + math.sin(k * 0.25) * 1.5)
        for o in (-1, 0, 1):
            if rnd(x, y, o, 'track') < 0.85:
                cv.put(x, y + o, C['dirt'] if o else C['dirt2'])
    for k in range(4):  # ruts and pebbles
        y = base + 3 + k * 2
        for x in range(cx - 14 + k * 3, cx + 12 - k * 2):
            if (x + k) % 4 == 0:
                cv.put(x, y, C['dirt2'])
    for k in range(14):
        cv.put(cx - 22 + int(rnd('peb', k) * 44), base + 2 + int(rnd('peby', k) * 10), C['rock3'] if k % 3 else C['sand'])


def swamp_behind(src, cx, base):
    """the swamp starts right behind the great cave: the old map's grass there turns to swamp ground (in old map
    pixels, so the trees, icons and texture all come out as swamp)"""
    px = src.load()
    for y in range(max(0, (base - SWAMP_DEPTH) // 2), (base - 12) // 2):
        for x in range(max(0, (cx - SWAMP_WEST) // 2), min(src.width, (cx + SWAMP_EAST) // 2)):
            edge = (base - 12) // 2 - round(2 * math.sin(x * 0.5) + 1)
            if y > edge:
                continue
            if px[x, y] in (C['grass'], C['meadow']):
                px[x, y] = C['forest']

# boss lairs drawn on the map: (kind, art x, art y of the mouth's floor); the node sits in front of the mouth
GREAT_CAVE = (84, 200)
GREAT_CAVE_HALF = 30
GREAT_CAVE_HEIGHT = 26
# the range round it: (x, base, half width, height) in art pixels, west over the coast into the sea; clear of
# Serpent Road and Mire Gate's nodes and the trail between them
GREAT_CAVE_RANGE = [(60, 184, 12, 26), (40, 192, 14, 30), (22, 200, 12, 22), (8, 210, 9, 14), (48, 208, 13, 22),
                    (30, 214, 10, 16), (102, 176, 9, 18)]
# the dirt track from the cave's yard runs east to Barricade Bridge's node
GREAT_CAVE_TRACK_TO = (130, 180)
# how far the swamp reaches behind the cave, in art pixels from its middle and floor
SWAMP_DEPTH = 80
SWAMP_WEST = 70
SWAMP_EAST = 46


def furrows(cv):
    """the Wasted Lands' field stripes came out 2 px thick: every second row of a stripe goes back to the field"""
    for y in range(cv.h - 1, 0, -1):
        for x in range(cv.w):
            if cv.px[x, y] == C['furrow'] and cv.px[x, y - 1] == C['furrow'] and (y % 2 == 1):
                below = cv.get(x, y + 1)
                cv.px[x, y] = below if below in (C['dirt'], C['grass'], C['sand']) else C['dirt']


def main(args):
    src = Image.open(SOURCE).convert("RGB")
    swamp_behind(src, GREAT_CAVE[0], GREAT_CAVE[1])
    nodes = node_centres()
    icons = find_icons(src)
    big = scale2x(src)
    cv = Canvas(big)
    areas = area_map(cv.w, cv.h, nodes, 2)
    cx, base = GREAT_CAVE
    for y in range(max(0, base - SWAMP_DEPTH), base - 12):  # behind the great cave is swamp, whatever node is nearer
        for x in range(max(0, cx - SWAMP_WEST), min(cv.w, cx + SWAMP_EAST)):
            areas[y][x] = 1
    thin_outlines(cv)
    furrows(cv)
    redraw_icons(cv, icons, areas)
    texture(cv, areas)
    mountain_range(cv)
    dirt_yard(cv, GREAT_CAVE[0], GREAT_CAVE[1], GREAT_CAVE_TRACK_TO)
    great_cave(cv, GREAT_CAVE[0], GREAT_CAVE[1])
    big.save(OUT_PNG)
    if "--preview" in args:
        out = args[args.index("--preview") + 1]
        big.resize((big.width * 2, big.height * 2), Image.NEAREST).save(out)
    if "--no-aseprite" not in args and os.path.exists(ASEPRITE_EXE):
        subprocess.run([ASEPRITE_EXE, "-b", OUT_PNG, "--save-as", OUT_ASEPRITE], check=True, capture_output=True)
    print("world_map_big.png %dx%d, %d icons redrawn" % (big.width, big.height, len(icons)))


if __name__ == "__main__":
    main(sys.argv[1:])
