"""World map level node tokens, one per area plus a boss token, drawn from shapes (Endesga 32, light from the top
left, the theme's dark outline). usage: map_nodes.py <out spec.txt>  (then python tools/sprite/sprite.py build).
Writes one 20x20 cell per token side by side (the boss token is 24x24, last); a preview helper renders them."""
import math
import sys

OUT = "0a1712"
PAL = {
    # outline, mouth dark
    "A": OUT, "K": "181425", "k": "262b44",
    # stone (caves)
    "1": "3a4466", "2": "5a6988", "3": "8b9bb4", "4": "c0cbdc",
    # greens (moss, lily pad)
    "g": "193c3e", "G": "265c42", "h": "3e8948", "H": "63c74d",
    # flower
    "p": "b55088", "P": "f6757a", "y": "fee761",
    # wood, banner
    "w": "3e2731", "W": "733e39", "x": "b86f50", "X": "e4a672", "r": "a22633", "R": "e43b44",
    # bone, sand
    "b": "c28569", "B": "ead4aa", "c": "e4a672",
    # obsidian lava
    "o": "f77622", "O": "feae34", "l": "e43b44",
    # pond water under the lily pad
    "q": "124e89", "Q": "0099db",
}


def blank(size):
    return [["." for _ in range(size)] for _ in range(size)]


def ellipse(cx, cy, rx, ry):
    return lambda x, y: ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0


def fill_shaded(grid, inside, ramp, cx, cy, bias=0.0):
    """Light from the top left: the ramp's last colour faces it, the first faces away."""
    size = len(grid)
    for y in range(size):
        for x in range(size):
            if inside(x, y):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                light = -(dx + dy * 1.2) / (size * 0.55) + bias
                index = max(0, min(len(ramp) - 1, int((light + 1.0) * 0.5 * len(ramp))))
                grid[y][x] = ramp[index]


def outline_outside(grid):
    """The outline round the shape instead of on its edge: thin parts (bones, horns) keep their fill."""
    size = len(grid)
    ring = []
    for y in range(size):
        for x in range(size):
            if grid[y][x] != ".":
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < size and 0 <= ny < size and grid[ny][nx] != ".":
                    ring.append((x, y))
                    break
    for x, y in ring:
        grid[y][x] = "A"


def outline(grid):
    size = len(grid)
    edge = []
    for y in range(size):
        for x in range(size):
            if grid[y][x] == ".":
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if not (0 <= nx < size and 0 <= ny < size) or grid[ny][nx] == ".":
                    edge.append((x, y))
                    break
    for x, y in edge:
        grid[y][x] = "A"


def put(grid, x, y, c):
    if 0 <= y < len(grid) and 0 <= x < len(grid):
        grid[y][x] = c


def cave():
    g = blank(20)
    mound = lambda x, y: ellipse(10, 12, 9.5, 9)(x, y) and y <= 18
    fill_shaded(g, mound, "1234", 10, 11, 0.1)
    # the mouth: a dark arch at the bottom, its rim lit on the left
    mouth = lambda x, y: ellipse(10, 18, 4.6, 7)(x, y) and y >= 12
    for y in range(20):
        for x in range(20):
            if mouth(x, y) and g[y][x] != ".":
                g[y][x] = "K" if x >= 8 or y > 14 else "k"
    for x in range(7, 14):
        if g[11][x] != "." and not mouth(x, 11):
            g[11][x] = "1"
    # moss over the top left
    for x, y in ((5, 4), (6, 4), (7, 3), (8, 3), (4, 5), (5, 5), (6, 5), (9, 3), (3, 7), (4, 6)):
        put(g, x, y, "h")
    for x, y in ((6, 3), (5, 4), (7, 3)):
        put(g, x, y, "H")
    outline(g)
    return g


def lily():
    g = blank(20)
    # a little pool under the pad, so it reads on the green swamp
    pool = ellipse(10, 12, 9.5, 7.5)
    fill_shaded(g, pool, "qQ", 10, 12, 0.3)
    pad = ellipse(9.5, 10.5, 7.5, 5.5)
    fill_shaded(g, pad, "hHH", 9.5, 10.5)
    for y in range(20):
        for x in range(20):
            if pad(x, y) and not pad(x, y + 1):
                g[y][x] = "G"
    # the notch: a wedge from the middle to the lower right, the water shows through
    for y in range(20):
        for x in range(20):
            a = math.atan2(y + 0.5 - 10.5, x + 0.5 - 9.5)
            if 0.3 < a < 0.8 and pad(x, y):
                g[y][x] = "Q"
    for x, y in ((7, 10), (5, 9), (9, 8), (11, 9), (6, 12)):
        g[y][x] = "h"
    # the flower, a plus of petals with a yellow heart
    for x, y, c in ((6, 6, "P"), (5, 7, "P"), (7, 7, "p"), (6, 8, "p"), (6, 7, "y"), (5, 6, "P"), (7, 6, "P")):
        put(g, x, y, c)
    outline(g)
    return g


def banner():
    g = blank(20)
    # the mound the post stands in
    mound = lambda x, y: ellipse(10, 18.5, 7.5, 3)(x, y) and y <= 19
    fill_shaded(g, mound, "WxxX", 10, 18)
    # post and cross bar, two pixels thick
    for y in range(1, 18):
        g[y][9] = "x"
        g[y][10] = "W"
    for x in range(2, 18):
        g[2][x] = "X" if x < 10 else "x"
        g[3][x] = "x" if x < 10 else "W"
    g[1][9] = "X"
    g[1][10] = "x"
    # the banner: a wide red cloth hanging over the post, swallowtail bottom, a light left fold
    for y in range(4, 16):
        for x in range(3, 17):
            if y >= 13 and 8 <= x <= 11 and y - 13 >= abs(x - 9.5) - 1.5:
                continue
            if y == 15 and x in (3, 16):
                continue
            g[y][x] = "R" if x < 7 else "r"
    for y in range(4, 13):
        g[y][4] = "P" if y < 9 else "R"
    for y in range(4, 15):
        g[y][16] = "l" if y < 15 else g[y][16]
    # the dark emblem: the human crown, three points over a band
    for x, y in ((7, 7), (10, 7), (13, 7), (7, 8), (8, 8), (10, 8), (12, 8), (13, 8),
                 (7, 9), (8, 9), (9, 9), (10, 9), (11, 9), (12, 9), (13, 9), (7, 10), (8, 10), (9, 10), (10, 10), (11, 10), (12, 10), (13, 10)):
        g[y][x] = "w"
    for x in (8, 10, 12):
        g[10][x] = "y"
    outline(g)
    return g


def skull_at(g, cx, top, eye):
    """A skull 12 wide: a round dome, eye holes, a narrower jaw with teeth."""
    dome = lambda x, y: ellipse(cx, top + 5, 6, 5)(x, y) and y <= top + 8
    jaw = lambda x, y: cx - 3.5 <= x + 0.5 <= cx + 3.5 and top + 8 < y <= top + 11
    fill_shaded(g, lambda x, y: dome(x, y) or jaw(x, y), "cBB", cx - 1, top + 4)
    for dx, dy in ((-3, 0), (-2, 0), (-3, 1), (-2, 1), (1, 0), (2, 0), (1, 1), (2, 1)):
        g[top + 5 + dy][int(cx) + dx] = eye
    g[top + 7][int(cx) - 1] = "K"
    g[top + 7][int(cx)] = "K"
    for dx in (-2, 0, 1):
        g[top + 10][int(cx) + dx] = "b"


def bone_line(g, x0, y0, x1, y1):
    """A bone three pixels thick (lit top row, shadowed bottom) from (x0, y0) to (x1, y1), with knobbed ends."""
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(steps + 1):
        x = round(x0 + (x1 - x0) * i / steps)
        y = round(y0 + (y1 - y0) * i / steps)
        put(g, x, y, "B")
        put(g, x, y + 1, "c")
    for x, y in ((x0, y0), (x1, y1)):
        for dx, dy in ((-1, -1), (-1, 1)):
            put(g, x + dx if x < 10 else x - dx, y + dy, "B")


def bones():
    g = blank(20)
    # crossed bones behind a skull, the old war's dead
    bone_line(g, 3, 12, 16, 17)
    bone_line(g, 16, 12, 3, 17)
    # the outline needs the bones' outer pixels: keep them on the canvas

    skull_at(g, 10, 1, "K")
    outline_outside(g)
    return g


def obsidian():
    g = blank(20)
    # a faceted stone: wide at the bottom, a flat top facet
    def stone(x, y):
        return ellipse(10, 12, 9.5, 9)(x, y) and y >= 3 and y <= 18 and abs(x + 0.5 - 10) <= 4 + (y - 3) * 0.75
    fill_shaded(g, stone, "Kk12", 9, 9, -0.2)
    # the lava cracks: one zigzag down the face, a branch to the right
    for x, y in ((9, 5), (9, 6), (10, 7), (10, 8), (9, 9), (9, 10), (10, 11), (11, 12), (11, 13), (10, 14), (10, 15), (10, 16),
                 (11, 10), (12, 10), (13, 11), (14, 12)):
        g[y][x] = "o"
    for x, y in ((10, 8), (9, 9), (11, 12), (10, 15)):
        g[y][x] = "O"
    for x, y in ((14, 12), (9, 5)):
        g[y][x] = "l"
    outline(g)
    return g


def boss():
    g = blank(24)
    # a big horned skull with burning eyes: the goal of an area
    dome = lambda x, y: ellipse(12, 11, 7.5, 6.5)(x, y) and y <= 15
    jaw = lambda x, y: 7.5 <= x + 0.5 <= 16.5 and 15 < y <= 19
    fill_shaded(g, lambda x, y: dome(x, y) or jaw(x, y), "cBB", 11, 9)
    for x0 in (7, 14):
        for dx in range(3):
            for dy in range(2):
                g[11 + dy][x0 + dx] = "l"
        g[11][x0 + (0 if x0 < 12 else 2)] = "O"
    g[14][11] = "K"
    g[14][12] = "K"
    for x in (9, 11, 12, 14):
        g[18][x] = "b"
    # horns: three pixels thick at the root, curling out and up to the top corners
    horn = [(6, 9, 2), (5, 8, 2), (4, 7, 2), (3, 6, 2), (3, 5, 2), (3, 4, 1), (4, 3, 1), (5, 2, 1)]
    for x, y, thick in horn:
        for side in (x, 23 - x):
            for t in range(thick):
                put(g, side, y + t, ("B" if t == 0 else "c") if side < 12 else ("c" if t == 0 else "b"))
    outline_outside(g)
    return g


TOKENS = [("caves", cave), ("swamp", lily), ("wasted_lands", banner), ("ash_desert", bones), ("volcano", obsidian), ("boss", boss)]
## Each token sits in a CELL x CELL square (the 20 px ones centred), one row per token, one column per state:
## normal, hover (a step lighter), pressed (one pixel lower), disabled (dark and grey).
CELL = 24
STATES = ("normal", "hover", "pressed", "disabled")
ENDESGA = ["be4a2f", "d77643", "ead4aa", "e4a672", "b86f50", "733e39", "3e2731", "a22633", "e43b44", "f77622", "feae34",
           "fee761", "63c74d", "3e8948", "265c42", "193c3e", "124e89", "0099db", "2ce8f5", "ffffff", "c0cbdc", "8b9bb4",
           "5a6988", "3a4466", "262b44", "181425", "ff0044", "68386c", "b55088", "f6757a", "e8b796", "c28569"]
KEYS = "abcdefghijklmnopqrstuvwxyzBCDEFGHIJLMNOPQRSTUVWXYZ0123456789"


def build():
    return [(name, fn()) for name, fn in TOKENS]


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def nearest(color, avoid=None):
    return min((c for c in ENDESGA if c != avoid), key=lambda c: sum((a - b) ** 2 for a, b in zip(rgb(c), color)))


## Hover: each colour one step up its own ramp, so the hue holds.
HOVER = {"1": "2", "2": "3", "3": "4", "K": "k", "k": "1", "g": "G", "G": "h", "h": "H", "p": "P", "w": "W", "W": "x",
         "x": "X", "r": "R", "R": "P", "b": "c", "c": "B", "o": "O", "O": "y", "l": "o", "q": "Q"}


def greyed(h):
    r, g, b = rgb(h)
    v = (r * 0.3 + g * 0.59 + b * 0.11) * 0.55
    return nearest((v * 0.9, v, v * 1.1))


def state(grid, which):
    """A CELL square of hex colours (None = clear) for one state of a token."""
    size = len(grid)
    pad = (CELL - size) // 2
    out = [[None] * CELL for _ in range(CELL)]
    for y in range(size):
        for x in range(size):
            c = grid[y][x]
            if c == ".":
                continue
            h = PAL[c]
            if which == "hover":
                h = PAL[HOVER.get(c, c)]
            elif which == "disabled" and c != "A":
                h = greyed(h)
            ty = y + pad + (1 if which == "pressed" else 0)
            if ty < CELL:
                out[ty][x + pad] = h
    return out


if __name__ == "__main__":
    out = sys.argv[1]
    tokens = build()
    rows = [[None] * (CELL * len(STATES)) for _ in range(CELL * len(tokens))]
    for row, (_, grid) in enumerate(tokens):
        for col, which in enumerate(STATES):
            cell = state(grid, which)
            for y in range(CELL):
                for x in range(CELL):
                    rows[row * CELL + y][col * CELL + x] = cell[y][x]
    colors = sorted({c for r in rows for c in r if c})
    key = {c: KEYS[i] for i, c in enumerate(colors)}
    lines = ["# Source of the world map node tokens (python tools/sprite/parts/map_nodes.py <this>, then sprite.py build).",
             "# One row per token (%s), %d px cells, columns: %s. MapLevelElement reads it." % (", ".join(n for n, _ in tokens), CELL, ", ".join(STATES)),
             "size = %dx%d" % (CELL * len(STATES), CELL * len(tokens))] + ["%s = %s" % (key[c], c) for c in colors] + ["---", "@IDLE 100"]
    lines += ["".join(key[c] if c else "." for c in r) for r in rows]
    open(out, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
