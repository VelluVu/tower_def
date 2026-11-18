"""Repaints the world map for sixty levels (the user, 2026-11-18): the northern bridge becomes the mossy swamp
bridge, the player's way on, and the swamp goes on over it: on the far bank (the volcano's red land pushed back, so
no lava reaches the bridge) and down the river onto the north of the middle land; the rest of the middle land and
the orange strip along the sand become the Wasted Lands, the humans' worked land (ploughed dirt, felled forest with
stumps, a quarry, some green left); the pale sand stays the ash desert. The middle bridge keeps the humans' barricade
and flag, the southern bridge stays broken. Then places the level nodes 13-60 along each area's route (levels 1-12
keep theirs).

    python tools/wasted_lands_map.py --preview out.png     (draws the result with the nodes on it; changes nothing)
    python tools/wasted_lands_map.py                       (writes world_map.png, its .aseprite and the node positions)

Runs once: it refuses a map whose northern bridge is already mossy.
"""
import math
import os
import re
import subprocess
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PNG = os.path.join(ROOT, "assets", "art", "ui", "world_map.png")
ASEPRITE = os.path.join(ROOT, "assets", "art", "ui", "world_map.aseprite")
ASEPRITE_EXE = "C:/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe"
MAP_SCENE = os.path.join(ROOT, "scenes", "ui", "game_world_map", "game_world_map.tscn")


def rgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


GRASS, GRASS_LIGHT, SWAMP, SWAMP_DARK = rgb("3e8948"), rgb("63c74d"), rgb("265c42"), rgb("193c3e")
TREE_DARK, OUTLINE = rgb("3e2731"), rgb("181425")
ORANGE, PALE = rgb("e4a672"), rgb("ead4aa")
DIRT, DIRT_DARK, CLAY = rgb("b86f50"), rgb("733e39"), rgb("be4a2f")
WATER, POOL_WATER = rgb("0099db"), rgb("124e89")
STONE_LIGHT, STONE, STONE_DARK, STONE_DEEP = rgb("8b9bb4"), rgb("5a6988"), rgb("3a4466"), rgb("262b44")
RED_LAND = rgb("a22633")
# (x, y, rx, ry) of the sand that pushes the red land away from the northern bridge's east end
RED_PUSH = (104, 44, 26.0, 16.0)
# the swamp on the far bank of the northern bridge and down the river to the middle land: wobbly ovals (x, y, rx, ry)
EAST_SWAMP = [(106, 46, 15.0, 9.0), (100, 60, 12.0, 10.0), (95, 73, 9.0, 7.0)]
GREENS = {GRASS, GRASS_LIGHT, SWAMP, SWAMP_DARK, TREE_DARK}

# the middle land (flooded through greens from here) and the orange strip of the sand band
MIDDLE_SEED = (120, 110)
ORANGE_SEED = (100, 70)
# the swamp takes the middle land north of this wobbly line
def swamp_line(x):
    return 97.0 + 2.5 * math.sin(x / 3.7) + 1.5 * math.sin(x / 1.9)


# the northern bridge's planks, rails and posts: wet wood with moss on it
NORTH_BRIDGE = (88, 43, 99, 46)
BRIDGE_MOSS = {rgb("b86f50"): DIRT_DARK, rgb("c28569"): GRASS, rgb("733e39"): TREE_DARK, rgb("e4a672"): GRASS_LIGHT,
               rgb("be4a2f"): DIRT_DARK}

# swamp dressing on the east bank, like tools/widen_swamp_map.py: a dark pool with a water eye, small trees
POOL_SHAPE = ["..aaa..", ".aabaa.", "aabbbaa", ".aaaaa."]
TREE_SHAPE = [".c.", "ccd", "ddd"]
SWAMP_POOLS = [(92, 84), (112, 79), (120, 90), (102, 45), (95, 58)]
SWAMP_TREES = [(86, 89), (103, 76), (108, 91), (126, 84), (98, 94), (112, 40), (106, 54), (91, 67)]
# the quarry in the orange strip and a log pile on the middle land
QUARRY = (156, 109, 6.5, 4.0)
LOG_PILES = [(101, 117), (126, 66)]
KEEP_TREE_ONE_IN = 3

# level nodes: (first level, route through the area in map pixels); the nodes are spread evenly along the route and
# nudged onto the area's own ground. A node is 10x10 map pixels (20x20 in the 600x336 map view).
ROUTES = [
    (13, [(46, 88), (30, 70), (22, 45), (40, 30), (64, 26), (82, 34), (70, 52), (70, 68)]),
    (21, [(107, 45), (100, 60), (94, 76), (112, 86)]),
    (25, [(96, 108), (110, 124), (128, 112), (140, 122), (152, 140), (160, 158), (166, 136), (160, 116), (150, 98),
          (138, 84), (126, 70)]),
    (37, [(130, 50), (148, 58), (165, 70), (182, 82), (170, 98), (186, 110), (200, 125), (186, 140), (205, 145)]),
    (49, [(232, 134), (218, 115), (250, 120), (270, 100), (262, 70), (240, 45), (205, 38), (180, 45), (196, 62),
          (212, 80), (232, 85)]),
]
NODE = 10
SPACING = 13
LEVEL_COUNT = 60


def flood(px, size, seed, colours):
    w, h = size
    seen = {seed}
    stack = [seed]
    while stack:
        x, y = stack.pop()
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and px[n] in colours:
                seen.add(n)
                stack.append(n)
    return seen


def noise(x, y, seed=0.0):
    """smooth patches in 0..1"""
    v = (math.sin(x / 5.3 + seed) + math.sin(y / 4.1 + seed * 1.7) + math.sin((x + y) / 7.9 + seed * 0.6)
         + math.sin((x - y) / 6.2 + seed * 2.3))
    return (v + 4.0) / 8.0


def furrow(x, y):
    """short broken dashes of a ploughed field"""
    return y % 3 == 0 and (x // 3 + y // 3) % 3 != 0


def stamp(px, x0, y0, shape, colours, on=None):
    """draws the shape; with `on`, only over pixels of that colour"""
    for dy, row in enumerate(shape):
        for dx, ch in enumerate(row):
            if ch in colours and (on is None or px[x0 + dx, y0 + dy] == on):
                px[x0 + dx, y0 + dy] = colours[ch]


def in_ovals(x, y, ovals):
    for cx, cy, rx, ry in ovals:
        angle = math.atan2(y - cy, x - cx)
        d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 - 0.12 * math.sin(angle * 3.0 + cx) - 0.07 * math.sin(angle * 6.0 + cy)
        if d < 1.0:
            return True
    return False


def components(cells):
    left = set(cells)
    out = []
    while left:
        start = left.pop()
        group = [start]
        stack = [start]
        while stack:
            x, y = stack.pop()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in left:
                    left.remove(n)
                    group.append(n)
                    stack.append(n)
        out.append(group)
    return out


def repaint(im):
    px = im.load()
    if px[(90, 44)] == DIRT_DARK:
        sys.exit("the northern bridge is already mossy: this script has run on this map")
    middle = flood(px, im.size, MIDDLE_SEED, GREENS - {TREE_DARK})
    orange = flood(px, im.size, ORANGE_SEED, {ORANGE})
    swamp = set(p for p in middle if p[1] < swamp_line(p[0]))
    wasted = middle - swamp
    # the northern bridge landed straight on the volcano's red land (the user: the lava should not reach the bridge):
    # the sand pushes the red back around its east end, with a dithered seam
    bx, by, brx, bry = RED_PUSH
    for y in range(int(by - bry) - 2, int(by + bry) + 3):
        for x in range(int(bx - brx) - 2, int(bx + brx) + 3):
            if px[x, y] != RED_LAND:
                continue
            angle = math.atan2(y - by, x - bx)
            d = ((x - bx) / brx) ** 2 + ((y - by) / bry) ** 2 - 0.1 * math.sin(angle * 4.0) - 0.06 * math.sin(angle * 7.0)
            if d < 0.9 or (d < 1.0 and (x + y) % 2 == 0):
                px[x, y] = PALE
    # the swamp over the northern bridge: the far bank and down the river, over the sand and the orange strip
    for y in range(25, 90):
        for x in range(80, 130):
            if px[x, y] in (PALE, ORANGE) and in_ovals(x, y, EAST_SWAMP):
                px[x, y] = SWAMP
                swamp.add((x, y))
    orange -= swamp
    # ---- the swamp over the bridge
    for x, y in swamp:
        if px[x, y] in (GRASS, GRASS_LIGHT):
            # a two-pixel dithered seam toward the wasted land
            seam = swamp_line(x) - y < 2.0 and (x + y) % 2 == 0
            px[x, y] = GRASS if seam else SWAMP
    for x, y in SWAMP_POOLS:
        stamp(px, x, y, POOL_SHAPE, {"a": SWAMP_DARK, "b": POOL_WATER}, SWAMP)
    for x, y in SWAMP_TREES:
        stamp(px, x, y, TREE_SHAPE, {"c": GRASS_LIGHT, "d": GRASS}, SWAMP)
    x0, y0, x1, y1 = NORTH_BRIDGE
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if px[x, y] in BRIDGE_MOSS:
                px[x, y] = BRIDGE_MOSS[px[x, y]]
    # ---- the wasted middle land: felled forest, ploughed patches, some green left
    trees = [g for g in components(p for p in wasted if px[p] in (SWAMP, SWAMP_DARK, TREE_DARK)) if len(g) >= 4]
    trees.sort(key=lambda g: min(g))
    for i, group in enumerate(trees):
        if i % KEEP_TREE_ONE_IN == 0:
            continue
        for p in group:
            px[p] = GRASS
        cx = sorted(p[0] for p in group)[len(group) // 2]
        cy = max(p[1] for p in group)
        # a stump: its cut face over its bark
        px[cx, cy - 1] = ORANGE
        px[cx, cy] = DIRT_DARK
    # the light meadow patches had straight cut edges (one ran flat along the rocks): each becomes a wobbly oval
    for patch in components(p for p in wasted if px[p] == GRASS_LIGHT):
        xs, ys = [p[0] for p in patch], [p[1] for p in patch]
        cx, cy = (min(xs) + max(xs)) / 2.0, (min(ys) + max(ys)) / 2.0
        rx, ry = max(2.0, (max(xs) - min(xs)) / 2.0), max(2.0, (max(ys) - min(ys)) / 2.0)
        for x, y in patch:
            angle = math.atan2(y - cy, x - cx)
            edge = 0.78 + 0.08 * math.sin(angle * 3.0 + cx) + 0.06 * math.sin(angle * 5.0 + cy)
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > edge:
                px[x, y] = GRASS
    for x, y in wasted:
        c = px[x, y]
        if c == GRASS and noise(x, y, 1.0) > 0.66:
            px[x, y] = DIRT_DARK if furrow(x, y) else DIRT
        elif c == GRASS_LIGHT and noise(x, y, 4.0) > 0.55:
            px[x, y] = GRASS
    # ---- the orange strip: worked dirt with dusty patches and a little grass
    for x, y in orange:
        n = noise(x, y, 2.5)
        if n > 0.5:
            continue  # dust
        if n < 0.3:
            px[x, y] = GRASS if (x * 7 + y * 3) % 4 else DIRT
        else:
            px[x, y] = DIRT_DARK if furrow(x, y) else DIRT
    # the quarry: a stepped pit of grey stone
    qx, qy, rx, ry = QUARRY
    for y in range(int(qy - ry) - 1, int(qy + ry) + 2):
        for x in range(int(qx - rx) - 1, int(qx + rx) + 2):
            d = ((x - qx) / rx) ** 2 + ((y - qy) / ry) ** 2
            if d <= 1.0:
                inner = ((x - qx) / (rx * 0.6)) ** 2 + ((y - qy) / (ry * 0.55)) ** 2
                if inner <= 0.35:
                    px[x, y] = STONE_DEEP
                elif inner <= 1.0:
                    px[x, y] = STONE_DARK if y < qy else STONE
                else:
                    px[x, y] = STONE_LIGHT if y > qy else STONE
    for x, y in LOG_PILES:
        for dy, width in ((0, 4), (1, 5), (2, 4)):
            for dx in range(width):
                px[x + dx - (1 if dy == 1 else 0), y + dy] = DIRT_DARK
            px[x + width - 1 - (1 if dy == 1 else 0), y + dy] = ORANGE
    return {"swamp": swamp, "wasted": wasted | orange, "orange": orange}


def ground_of(px, size, areas):
    """map pixel sets each node range may sit on"""
    pale = flood(px, size, (180, 100), {PALE})
    red_colours = {rgb("a22633"), rgb("e43b44"), rgb("be4a2f"), rgb("8b2330")}
    red = flood(px, size, (200, 60), red_colours)
    west_swamp = flood(px, size, (40, 50), GREENS)
    return {13: west_swamp, 21: areas["swamp"], 25: areas["wasted"], 37: pale, 49: red}


def place_nodes(px, size, areas):
    grounds = ground_of(px, size, areas)
    placed = {}
    taken = []
    starts = [r[0] for r in ROUTES] + [LEVEL_COUNT + 1]
    for i, (first, route) in enumerate(ROUTES):
        count = starts[i + 1] - first
        ground = grounds[first]
        lengths = [math.dist(route[j], route[j + 1]) for j in range(len(route) - 1)]
        total = sum(lengths)
        for k in range(count):
            t = total * k / max(1, count - 1)
            j = 0
            while j < len(lengths) - 1 and t > lengths[j]:
                t -= lengths[j]
                j += 1
            a, b = route[j], route[j + 1]
            f = min(1.0, t / lengths[j]) if lengths[j] else 0.0
            want = (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
            best = None
            for r in range(0, 14):
                for dx in range(-r, r + 1):
                    for dy in range(-r, r + 1):
                        if max(abs(dx), abs(dy)) != r:
                            continue
                        cx, cy = int(want[0]) + dx, int(want[1]) + dy
                        box = [(cx - NODE // 2 + u, cy - NODE // 2 + v) for u in range(NODE) for v in range(NODE)]
                        on = sum(1 for p in box if p in ground)
                        if on < NODE * NODE * 0.7:
                            continue
                        if any(math.dist((cx, cy), q) < SPACING for q in taken):
                            continue
                        best = (cx, cy)
                        break
                    if best:
                        break
                if best:
                    break
            if best is None:
                best = (int(want[0]), int(want[1]))
                print("level %d: no free spot near %s, placed anyway" % (first + k, want))
            taken.append(best)
            placed[first + k] = best
    return placed


def write_nodes(placed):
    """the Panel offsets in the 600x336 map view: a node is 20x20, its centre at twice the map pixel"""
    text = open(MAP_SCENE, encoding="utf8").read()
    for number, (cx, cy) in placed.items():
        left, top = cx * 2 - 10, cy * 2 - 10
        pattern = (r'(\[node name="Level_%03d" type="Panel"[^\n]*\n(?:[^\[\n][^\n]*\n)*?)offset_left = [-\d.]+\n'
                   r'offset_top = [-\d.]+\noffset_right = [-\d.]+\noffset_bottom = [-\d.]+') % number
        text, n = re.subn(pattern, lambda m: m.group(1) + "offset_left = %.1f\noffset_top = %.1f\noffset_right = %.1f\n"
                          "offset_bottom = %.1f" % (left, top, left + 20, top + 20), text, count=1)
        if n != 1:
            sys.exit("no node for level %d in the map scene" % number)
    with open(MAP_SCENE, "w", encoding="utf8", newline="\n") as f:
        f.write(text)


def current_nodes():
    text = open(MAP_SCENE, encoding="utf8").read()
    nodes = {}
    for m in re.finditer(r'\[node name="Level_(\d+)" type="Panel"[^\n]*\n((?:[^\[\n][^\n]*\n)*)', text):
        o = re.search(r"offset_left = ([-\d.]+)\noffset_top = ([-\d.]+)", m.group(2))
        nodes[int(m.group(1))] = ((float(o.group(1)) + 10) / 2, (float(o.group(2)) + 10) / 2)
    return nodes


def preview(im, placed, out):
    k = 4
    big = im.convert("RGBA").resize((im.width * k, im.height * k), Image.NEAREST)
    d = ImageDraw.Draw(big)
    nodes = current_nodes()
    nodes.update(placed)
    for number, (cx, cy) in sorted(nodes.items()):
        x, y = cx * k, cy * k
        r = NODE * k / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=(16, 115, 56, 255), outline=(24, 20, 37, 255), width=3)
        d.text((x - 7, y - 5), str(number), fill=(255, 255, 255, 255))
    big.save(out)


def main(argv):
    # the map is opaque; RGB so the pixels compare with the colours above
    im = Image.open(PNG).convert("RGB")
    areas = repaint(im)
    placed = place_nodes(im.load(), im.size, areas)
    if "--preview" in argv:
        preview(im, placed, argv[argv.index("--preview") + 1])
        return
    im.save(PNG)
    subprocess.run([ASEPRITE_EXE, "-b", PNG, "--save-as", ASEPRITE], check=True)
    write_nodes(placed)
    print("world map repainted, nodes 13-%d placed" % LEVEL_COUNT)


if __name__ == "__main__":
    main(sys.argv)
