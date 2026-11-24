"""The game's mouse cursors (2026-11-24, the user: a game cursor "that changes when panning or stuff", "or animated",
then "improve the cursor", then "so it doesn't get lost in the level or map colors"): one sheet of 20x20 frames for GameCursor (scenes/ui/game_cursor/game_cursor.gd), which
scales it to the window and plays the frames. Shapes are drawn as fills only, then one pass traces a 1 px dark outline
round everything, so every cursor shares the same outline, and a second pass lays a pale see-through halo round
the outline: the dark line shows on sand and snow, the halo on swamp, caves and night lairs. Drakeling mint lit from the top left, gold accents, ivory
talons; Endesga 32.

    (hotspots after the 1 px shift into the cell, see SHIFT)
    row 0 POINTER   4 frames  hotspot (2, 2)   the arrow; frames 1-3 a glint running down its lit edge (now and then)
    row 1 BUILD     4 frames  hotspot (2, 2)   the arrow with a gold plus pulsing beside it (placing a building)
    row 2 TARGET    4 frames  hotspot (8, 8)   four red corner brackets closing in and out (over an enemy)
    row 3 INVALID   2 frames  hotspot (8, 8)   a red no-entry sign blinking (a building cannot go here)
    row 4 GRAB      2 frames  hotspot (8, 8)   a drakeling claw, open, then gripping (panning)
    row 5 POINTING  2 frames  hotspot (6, 2)   a claw pointing a talon (over buttons); frame 1 pressed
    row 6 PRESSED   1 frame   hotspot (2, 2)   the arrow pressed (a mouse button held)

    python tools/art/cursors.py [--preview out.png]
"""
import math
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "art", "ui", "cursors", "cursors.png")
CELL = 20
# every shape is drawn as on a 16 px cell, then moved this far in, so the outline and the halo fit round it
SHIFT = 1
# the halo's colour and how much it covers (see-through, so it reads as a glow and not as a sticker edge)
HALO = (239, 255, 250, 190)
COLUMNS = 4
ROWS = 7

# the mint sits one step above the drakelings' own ramp, so it stays brighter than grass and swamp
PAL = {'o': '181425', 'k': '0b9b55', 'd': '06c374', 'm': '2effb8', 'l': '68ffd0', 'w': 'effffa',
       'g': 'f77622', 'G': 'feae34', 'Y': 'fee761', 'r': 'a22633', 'R': 'e43b44', 'p': 'f6757a',
       'e': 'c28569', 'E': 'ead4aa', 'W': 'ffffff', 'b': '733e39', 'B': 'b86f50'}

# the arrow's fill (the outline is traced): lit edge w, light l, body m, shade d; the gold tip G
ARROW = [
    "G        ",
    "Gw       ",
    "Gwm      ",
    "lwmm     ",
    "lmmmm    ",
    "lmmmmm   ",
    "lmmmmmd  ",
    "lmmmmmdd ",
    "lmmmmmmdd",
    "lmmmmd   ",
    "lm  md   ",
    "l    md  ",
    "     md  ",
    "      md ",
]
# the glint's path down the lit edge, one pixel pair per frame
GLINT = [(1, 1), (0, 4), (0, 7)]

CLAW_OPEN = [
    " E   E   E    ",
    " E   E   E    ",
    " l   l   l  E ",
    " lm  lm  lm E ",
    " lm  lm  lm l ",
    " lmm lmm lmml ",
    " lmmmmmmmmmml ",
    " lmmmmmmmmmmd ",
    " lmmmmmmmmmd  ",
    " dmmmmmmmmmd  ",
    "  dmmmmmmmd   ",
    "  ddmmmmmdd   ",
    "   kkkkkkk    ",
]
CLAW_GRIP = [
    "              ",
    "              ",
    "              ",
    "  lmd lmd lmd ",
    " llmmdlmmdlmmd",
    " lmmmmmmmmmmmd",
    " lmmmmmmmmmmmd",
    " lmmmmmmmmmmd ",
    " dmmmmmmmmmmd ",
    "  dmEmmEmmEd  ",
    "  dkEkkEkkEd  ",
    "   kkkkkkkk   ",
]
POINTING = [
    "    E      ",
    "    E      ",
    "    lm     ",
    "    lm     ",
    "    lm     ",
    "    lmm    ",
    " E  lmmlm  ",
    " lmmlmmlmm ",
    " lmmmmmmmmd",
    " lmmmmmmmmd",
    "  lmmmmmmd ",
    "  dmmmmmmd ",
    "   dmmmmd  ",
    "   kkkkkk  ",
]
# a gold plus beside the arrow, pulsing (placing a building)
PLUS_SMALL = [
    "     ",
    "  G  ",
    " GYG ",
    "  G  ",
    "     ",
]
PLUS_BIG = [
    "  g  ",
    "  Y  ",
    "gYWYg",
    "  Y  ",
    "  g  ",
]


def rgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


class Cell:
    def __init__(self):
        self.px = {}

    def grid(self, grid, ox=0, oy=0):
        for y, line in enumerate(grid):
            for x, ch in enumerate(line):
                if ch != ' ':
                    self.px[(SHIFT + ox + x, SHIFT + oy + y)] = ch

    def put(self, x, y, ch):
        self.px[(SHIFT + x, SHIFT + y)] = ch

    def recolour(self, mapping):
        self.px = {k: mapping.get(v, v) for k, v in self.px.items()}

    def outlined(self):
        """every empty pixel next to a filled one (4 neighbours, and the diagonals at corners) becomes the outline"""
        out = dict(self.px)
        for (x, y) in list(self.px):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in self.px and 0 <= n[0] < CELL and 0 <= n[1] < CELL:
                    out[n] = 'o'
        return out

    def haloed(self):
        """the outlined shape, plus the halo: every empty pixel next to the outline (4 neighbours)"""
        out = self.outlined()
        for (x, y), ch in list(out.items()):
            if ch != 'o':
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in out and 0 <= n[0] < CELL and 0 <= n[1] < CELL:
                    out[n] = 'h'
        return out


def arrow(cell, ox=1, oy=1):
    cell.grid(ARROW, ox, oy)


def brackets(cell, reach):
    """four L brackets round the middle (7, 7), `reach` pixels out, with a red dot in the middle"""
    c = 7
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0, y0 = c + sx * reach, c + sy * reach
            for k in range(3):
                cell.put(x0 - sx * k, y0, 'R' if k else 'p')
                cell.put(x0, y0 - sy * k, 'R' if k else 'p')
    cell.put(c, c, 'R')


def no_entry(cell, dark):
    ring, slash = ('r', 'r') if dark else ('R', 'R')
    for y in range(CELL):
        for x in range(CELL):
            d = math.hypot(x - 7, y - 7)
            if 4.6 <= d <= 6.4:
                cell.put(x, y, ring)
            elif d < 4.6 and abs((x - 7) - (y - 7)) <= 0.8:  # top left to bottom right, as the sign has it
                cell.put(x, y, slash)
    cell.put(5, 3, 'p')  # a highlight on the ring


def main(args):
    im = Image.new("RGBA", (CELL * COLUMNS, CELL * ROWS), (0, 0, 0, 0))
    cells = {}

    for i in range(4):  # POINTER: plain, then the glint
        c = Cell()
        arrow(c)
        if i:
            gx, gy = GLINT[i - 1]
            c.put(1 + gx, 1 + gy, 'W')
            c.put(1 + gx, 2 + gy, 'Y')
        cells[(i, 0)] = c
    for i in range(4):  # BUILD: the hammer taps
        c = Cell()
        arrow(c)
        c.grid(PLUS_BIG if i % 2 else PLUS_SMALL, 10, 1)
        cells[(i, 1)] = c
    for i, reach in enumerate((6, 5, 4, 5)):  # TARGET
        c = Cell()
        brackets(c, reach)
        cells[(i, 2)] = c
    for i in range(2):  # INVALID
        c = Cell()
        no_entry(c, i == 1)
        cells[(i, 3)] = c
    c = Cell()
    c.grid(CLAW_OPEN, 1, 1)
    cells[(0, 4)] = c
    c = Cell()
    c.grid(CLAW_GRIP, 1, 1)
    cells[(1, 4)] = c
    c = Cell()
    c.grid(POINTING, 1, 1)
    cells[(0, 5)] = c
    c = Cell()  # pressed: a shade darker, a pixel lower
    c.grid(POINTING, 1, 2)
    c.recolour({'l': 'm', 'm': 'd', 'd': 'k', 'E': 'e'})
    cells[(1, 5)] = c
    c = Cell()
    arrow(c)
    c.recolour({'w': 'l', 'l': 'm', 'm': 'd', 'd': 'k', 'G': 'g'})
    cells[(0, 6)] = c

    for (cx, cy), cell in cells.items():
        for (x, y), ch in cell.haloed().items():
            if 0 <= x < CELL and 0 <= y < CELL:
                im.putpixel((cx * CELL + x, cy * CELL + y), HALO if ch == 'h' else rgb(PAL[ch]))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.save(OUT)
    if "--preview" in args:
        # the sheet on the game's grounds side by side: grass, sand, swamp, cave night, lava, sea
        out = args[args.index("--preview") + 1]
        grounds = ['3e8948', 'e4a672', '265c42', '181425', 'e43b44', '0099db']
        back = Image.new("RGBA", (im.width * len(grounds), im.height), (0, 0, 0, 255))
        for i, ground in enumerate(grounds):
            tile = Image.new("RGBA", im.size, rgb(ground))
            tile.alpha_composite(im)
            back.paste(tile, (i * im.width, 0))
        back.resize((back.width * 4, back.height * 4), Image.NEAREST).save(out)
    print("cursors.png %dx%d" % im.size)


if __name__ == "__main__":
    main(sys.argv[1:])
