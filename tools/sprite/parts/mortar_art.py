"""The Mortar's art (2026-11-24, the user: "draw it now"): the drakeling (the Bolter's, recoloured per element from the
Bolter's own element sheets) behind a stubby iron mortar standing on the tower top; the shells and their blasts.

    python tools/sprite/parts/mortar_art.py tools/sprite/parts assets/art
    then build each written .txt with tools/sprite/sprite.py build (the script prints the commands)

Drakeling sheets (18x34, like every drakeling; IDLE 4, START_ATTACK 4: the tube tilts up and the shell glows in the
muzzle, STOP_ATTACK 5: the flash, the kick and the smoke) go to units/building/puffe/puffe_mortar/<colour>_puffe_mortar.txt.
Shells (8x8, FLY 4: the band and the glint turn) and blasts (36x36, BLAST 6: flash, fireball, ring, smoke) per element
go to projectile/<element>_mortar_shell.txt and <element>_mortar_blast.txt.
"""
import math
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, part, write_spec
from PIL import Image

ART = sys.argv[2]
PUFFE = os.path.join(ART, 'units', 'building', 'puffe')
OUT = os.path.join(PUFFE, 'puffe_mortar')
PROJ = os.path.join(ART, 'projectile')
ELEMENTS = ('physical', 'fire', 'frost', 'poison')
COLOUR = {'physical': '', 'fire': 'red', 'frost': 'blue', 'poison': 'green'}
BOLTER_SHEET = {'physical': 'puffe.png', 'fire': 'puffe_bolter/puffe_bolter_red.png',
                'frost': 'puffe_bolter/puffe_bolter_blue.png', 'poison': 'puffe_bolter/puffe_bolter_green.png'}
W, H = 18, 34

# the iron tube: dark bore K, iron ramp D M L H (lit from the top left, light enough to read on the dark tower top),
# bronze band B b
IRON = {'K': '181425', 'D': '3a4466', 'M': '5a6988', 'L': '8b9bb4', 'H': 'c0cbdc', 'B': 'b86f50', 'b': 'e4a672'}
# per element: the glow in the muzzle and the flash (g light, G mid, R deep), the smoke stays grey
GLOW = {
    'physical': {'g': 'ffffff', 'G': 'fee761', 'R': 'feae34'},
    'fire': {'g': 'fee761', 'G': 'f77622', 'R': 'e43b44'},
    'frost': {'g': 'ffffff', 'G': '2ce8f5', 'R': '0099db'},
    'poison': {'g': 'b6d53c', 'G': '63c74d', 'R': 'b55088'},
}
SMOKE = {'s': 'c0cbdc', 'S': '8b9bb4', 'x': '5a6988'}

# the tube at rest and raised to fire; it stands in front of the drakeling's right side
TUBE_REST = part('''
...HHHL
..HKKKM
..LKKKD
..bbBBD
.LHMMD.
LHMMD..
LHMD...
DDD....
''')
TUBE_RAISED = part('''
..HHHL.
.HKKKM.
.LKKKD.
.bbBBD.
.LHMD..
LHMMD..
LHMD...
DDD....
''')
# where the tube's top-left goes on the canvas
TUBE_AT = (10, 13)
# the shell's glow in the raised tube's bore while loading, by step (placed at the bore)
LOAD_GLOW = [part('''
...
.R.
'''), part('''
.R.
RGR
'''), part('''
.g.
GgG
RGR
''')]
FLASH = [part('''
..g..
.gGg.
gGgGg
.RGR.
'''), part('''
.G.
GgG
.R.
''')]
PUFFS = [part('''
.ss.
sSSs
.Sx.
'''), part('''
.ss..
sssS.
.SSSx
..xx.
'''), part('''
..s..
.sSs.
..x..
'''), part('''
.s
Sx
''')]


def bolter_idle(element):
    """The Bolter drakeling's four IDLE frames in this element: {(x, y): hex} each."""
    sheet = Image.open(os.path.join(PUFFE, BOLTER_SHEET[element])).convert('RGBA')
    frames = []
    for i in range(4):
        fx, fy = (i % 4) * W, (i // 4) * H
        px = {}
        for y in range(H):
            for x in range(W):
                r, g, b, a = sheet.getpixel((fx + x, fy + y))
                if a:
                    px[(x, y)] = '%02x%02x%02x' % (r, g, b)
        frames.append(px)
    return frames


def spec_frame(body, stamps, palette):
    """A Frame: the body's hex pixels, then (part, dx, dy, colours) stamped over it."""
    frame = Frame(W, H)
    for (x, y), colour in body.items():
        frame.px[(x, y)] = palette.key(colour)
    for p, dx, dy, colours in stamps:
        frame.stamp([(x, y, palette.key(colours[ch])) for x, y, ch in p], dx, dy)
    return frame


class Palette:
    KEYS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

    def __init__(self):
        self.keys = {}

    def key(self, colour):
        if colour not in self.keys:
            self.keys[colour] = self.KEYS[len(self.keys)]
        return self.keys[colour]

    def lines(self):
        return {k: c for c, k in self.keys.items()}


def drakeling(element):
    body = bolter_idle(element)
    pal = Palette()
    glow = dict(IRON, **GLOW[element], **SMOKE)
    tx, ty = TUBE_AT
    rest = (TUBE_REST, tx, ty, glow)
    raised = (TUBE_RAISED, tx, ty, glow)
    idle = [spec_frame(body[i], [rest], pal) for i in range(4)]
    # loading: the tube rises, the shell glows up in the muzzle
    start = [
        spec_frame(body[0], [rest], pal),
        spec_frame(body[1], [raised, (LOAD_GLOW[0], tx + 2, ty + 1, glow)], pal),
        spec_frame(body[2], [raised, (LOAD_GLOW[1], tx + 2, ty + 1, glow)], pal),
        spec_frame(body[3], [raised, (LOAD_GLOW[2], tx + 2, ty, glow)], pal),
    ]
    # firing: a flash over the muzzle, the tube kicks down a pixel, smoke rises from the muzzle and drifts off
    kick = (TUBE_RAISED, tx, ty + 1, glow)
    stop = [
        spec_frame(body[0], [kick, (FLASH[0], tx + 1, ty - 3, glow)], pal),
        spec_frame(body[1], [kick, (FLASH[1], tx + 2, ty - 2, glow), (PUFFS[0], tx + 3, ty - 5, glow)], pal),
        spec_frame(body[2], [raised, (PUFFS[1], tx + 2, ty - 7, glow)], pal),
        spec_frame(body[3], [rest, (PUFFS[2], tx + 3, ty - 9, glow)], pal),
        spec_frame(body[0], [rest, (PUFFS[3], tx + 4, ty - 10, glow)], pal),
    ]
    name = (COLOUR[element] + '_' if COLOUR[element] else '') + 'puffe_mortar'
    header = ('# Source of %s.aseprite and .png: the %s Mortar drakeling, drawn by tools/sprite/parts/mortar_art.py\n'
              '# (the Bolter drakeling of this element behind an iron mortar). Same canvas and tags as the other drakelings.'
              % (name, element))
    path = os.path.join(OUT, name + '.txt')
    write_spec(path, header, pal.lines(), (W, H), [('IDLE', 100, idle), ('START_ATTACK', 100, start), ('STOP_ATTACK', 100, stop)])
    return path


SHELL_COLOURS = {
    'physical': {'D': '262b44', 'M': '3a4466', 'L': '5a6988', 'H': 'c0cbdc', 'e': 'b86f50', 'E': 'e4a672'},
    'fire': {'D': '3e2731', 'M': '733e39', 'L': 'a22633', 'H': 'fee761', 'e': 'e43b44', 'E': 'f77622'},
    'frost': {'D': '124e89', 'M': '0099db', 'L': '2ce8f5', 'H': 'ffffff', 'e': '124e89', 'E': '2ce8f5'},
    'poison': {'D': '193c3e', 'M': '265c42', 'L': '3e8948', 'H': 'b6d53c', 'e': '68386c', 'E': 'b55088'},
}
# a ball lit from the top left; its band (e E) turns as it tumbles
SHELL_BALL = part('''
.DMD.
DMLHM
DMLLM
DDMMD
.DDD.
''')
SHELL_BANDS = [
    [(1, 2, 'e'), (2, 2, 'E'), (3, 2, 'E')],
    [(1, 3, 'e'), (2, 2, 'E'), (3, 1, 'E')],
    [(2, 1, 'E'), (2, 2, 'E'), (2, 3, 'e')],
    [(1, 1, 'e'), (2, 2, 'E'), (3, 3, 'e')],
]


def shell(element):
    colours = SHELL_COLOURS[element]
    pal = Palette()
    frames = []
    for band in SHELL_BANDS:
        frame = Frame(8, 8)
        frame.stamp([(x, y, pal.key(colours[ch])) for x, y, ch in SHELL_BALL], 1, 1)
        frame.stamp([(x, y, pal.key(colours[ch])) for x, y, ch in band], 1, 1)
        frames.append(frame)
    name = '%s_mortar_shell' % element
    path = os.path.join(PROJ, name + '.txt')
    write_spec(path, '# Source of %s.aseprite and .png: the %s Mortar shell (tools/sprite/parts/mortar_art.py).' % (name, element),
               pal.lines(), (8, 8), [('FLY', 80, frames)])
    return path


BLAST_COLOURS = {
    # core, flame, deep, dark; smoke light, mid, dark; embers
    'physical': ['ffffff', 'fee761', 'f77622', '733e39', 'c0cbdc', '8b9bb4', '5a6988', 'feae34'],
    'fire': ['fee761', 'feae34', 'f77622', 'a22633', 'c0cbdc', '8b9bb4', '5a6988', 'f77622'],
    'frost': ['ffffff', '2ce8f5', '0099db', '124e89', 'ffffff', 'c0cbdc', '8b9bb4', '2ce8f5'],
    # acid and purple fumes: green alone vanishes on grass
    'poison': ['fee761', 'b6d53c', 'b55088', '68386c', 'b6d53c', 'b55088', '68386c', 'b6d53c'],
}
BLAST = 36
# per frame: fireball radius (0 = none) and how much of its centre has burnt out; smoke puffs (count, distance, radius)
BLAST_STEPS = [
    (4, 0.0, None),
    (8, 0.0, None),
    (12, 0.0, (5, 13, 2)),
    (13, 0.6, (6, 12, 3)),
    (0, 0.0, (7, 14, 3)),
    (0, 0.0, (5, 15, 2)),
]


def lobed(angle, phase):
    """A ragged edge: the radius factor at this angle."""
    return 1.0 + 0.14 * math.sin(5 * angle + phase) + 0.07 * math.sin(3 * angle + 1.0 + phase)


def put(frame, pal, x, y, colour):
    if 1 <= x < BLAST - 1 and 1 <= y < BLAST - 1:
        frame.px[(x, y)] = pal.key(colour)


def fireball(frame, pal, colours, radius, hollow, phase):
    c = BLAST / 2.0
    for y in range(BLAST):
        for x in range(BLAST):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            d = math.hypot(dx, dy)
            edge = radius * lobed(math.atan2(dy, dx), phase)
            if d > edge or d < hollow * edge:
                continue
            # hotter at the centre and the top left, darker to the bottom right and the rim
            t = d / edge + 0.2 * (dx + dy) / max(radius, 1)
            if t < 0.35:
                key = colours[0]
            elif t < 0.7:
                key = colours[1]
            elif t < 0.95:
                key = colours[2]
            else:
                key = colours[3]
            put(frame, pal, x, y, key)


def puff(frame, pal, colours, cx, cy, r, thin):
    for y in range(cy - r - 1, cy + r + 2):
        for x in range(cx - r - 1, cx + r + 2):
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy > r * r + r:
                continue
            # a fading puff thins out to a checkerboard
            if thin and (x + y) % 2:
                continue
            side = (dx + dy) / max(r, 1)
            key = colours[4] if side < -0.4 else colours[5] if side < 0.6 else colours[6]
            put(frame, pal, x, y, key)


def blast(element):
    colours = BLAST_COLOURS[element]
    pal = Palette()
    c = BLAST // 2
    frames = []
    for step, (radius, hollow, puffs) in enumerate(BLAST_STEPS):
        frame = Frame(BLAST, BLAST)
        if puffs:
            count, dist, r = puffs
            for k in range(count):
                angle = k * math.tau / count + 0.3 * step
                px, py = round(c + math.cos(angle) * dist * 0.85), round(c + math.sin(angle) * dist * 0.75)
                puff(frame, pal, colours, px, py, r, step == len(BLAST_STEPS) - 1)
        if radius:
            fireball(frame, pal, colours, radius, hollow, step * 0.7)
        # embers fly out on the middle frames
        if step in (2, 3, 4):
            for k in range(6):
                angle = k * math.tau / 6 + 0.5 + step
                dist = 10 + step * 2
                put(frame, pal, round(c + math.cos(angle) * dist), round(c + math.sin(angle) * dist), colours[7])
        frames.append(frame)
    name = '%s_mortar_blast' % element
    path = os.path.join(PROJ, name + '.txt')
    write_spec(path, '# Source of %s.aseprite and .png: the %s Mortar shell blast, 1 tile in radius at its widest '
               '(tools/sprite/parts/mortar_art.py).' % (name, element), pal.lines(), (BLAST, BLAST), [('BLAST', 70, frames)])
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    written = []
    for element in ELEMENTS:
        written.append(drakeling(element))
        written.append(shell(element))
        written.append(blast(element))
    for path in written:
        print('python tools/sprite/sprite.py build %s %s' % (path, path[:-4] + '.aseprite'))


if __name__ == '__main__':
    main()
