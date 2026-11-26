"""The Fallen Elder lair art (2026-11-26, level 48, the Bone Colossus's lair; concept in the design doc's Boss lairs):
the dragon graveyard of the old war at a moonless necromantic night. 32x32 landmarks on the map (a ritual circle, a
rusted ballista wreck, a drake-bone totem, an old-war shield wall, a skull pile, the elder's broken crown), the
graveyard past the map's edge (giant ribs, a half-sunk skull, a spine, war standards, ritual stones, grave-fires), the
elder's empty grave (a 96x64 dragon-shaped hollow behind the spawn), the 48x48 grave pit (a spawn's art: IDLE a faint
green pulse, BOIL caving in when he rises), the castle buried in a dune (64x64 over the 48x48 castle, offset 8: IDLE
sand trickling, REVEAL the sand sliding off) and the night sand past the edge. Light from the top left, no black
outlines, Endesga 32. The night itself is the level's LairLighting.

usage: lair_grave_art.py <parts dir> <tiles dir>   (then tools/sprite/sprite.py build <spec> <out.aseprite>)"""
import math
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, write_spec
from scorched_decor import put, ellipse, seg, mound
import lair_art
from lair_art import _rand, write_sprite_frames

TILES = sys.argv[2]

GRAVE_PAL = {
    'H': '181425', 'h': '3e2731',  # dark
    'S': 'ead4aa', 's': 'e4a672', 'd': 'c28569', 'D': 'b86f50',  # sand, lit to shaded
    'w': 'ffffff', 'W': 'c0cbdc', 'v': '8b9bb4', 'x': '5a6988',  # bone
    'k': '262b44', 'I': '3a4466', 'j': '5a6988',  # stone
    'm': '193c3e', 'n': '3e8948', 'N': '63c74d', 'Y': 'fee761',  # grave-fire green
    'l': '733e39', 'o': 'be4a2f',  # old wood, rust
    'O': 'feae34', 'q': 'f77622', 'E': '2ce8f5',  # the crown's gold and gem
    'p': '68386c', 'P': 'b55088', 'c': 'a22633',  # old war cloth
}
SAND = ['S', 's', 'd']
BONE = ['x', 'v', 'W', 'w']
STONE = ['k', 'I', 'j']


def skull(f, cx, cy, small=True):
    """a small skull, eye holes and jaw"""
    ellipse(f, cx, cy, 2.2 if small else 3.2, 1.8 if small else 2.6, ['v', 'W', 'w'])
    put(f, cx - 1, cy, 'H')
    put(f, cx + 1, cy, 'H')
    put(f, cx, cy + 2, 'v')


def ritual_stone(f, x, base, height, lit):
    for y in range(base - height, base + 1):
        put(f, x, y, 'j')
        put(f, x + 1, y, 'I')
        put(f, x + 2, y, 'k')
    put(f, x + 1, base - height, 'j')
    put(f, x + 1, base - height // 2, 'Y' if lit else 'N')  # the rune
    put(f, x + 1, base - height // 2 + 1, 'n')


def ritual_circle():
    f = Frame(32, 32)
    for k in range(40):  # the drawn rune ring
        a = k / 40 * math.tau
        if k % 5 != 0:
            put(f, round(16 + math.cos(a) * 10), round(19 + math.sin(a) * 6), 'n')
    for k in range(6):
        a = k / 6 * math.tau + 0.3
        ritual_stone(f, round(15 + math.cos(a) * 12), round(20 + math.sin(a) * 7), 5, k % 2 == 0)
    skull(f, 16, 19, small=False)
    for (x, y) in ((12, 20), (20, 18), (17, 23)):
        put(f, x, y, 'N')  # embers of grave-fire
    return f


def ballista_wreck():
    f = Frame(32, 32)
    mound(f, 16, 29, 13, 3, SAND)
    seg(f, 4, 26, 26, 14, 'l', 2)  # the stock, tipped over
    seg(f, 5, 27, 27, 15, 'h')
    for k in range(13):  # the bent bow arm, rusted iron
        a = k / 12 * math.pi
        put(f, round(20 + math.cos(a) * 9), round(13 - math.sin(a) * 5 + (2 if k > 8 else 0)), 'o' if k % 3 else 'l')
    seg(f, 11, 13, 28, 13, 'W')  # a slack string
    for k in range(14):  # a wheel half in the sand
        a = math.pi + k / 13 * math.pi
        put(f, round(8 + math.cos(a) * 4), round(24 + math.sin(a) * 4), 'h')
    seg(f, 8, 20, 8, 24, 'l')
    seg(f, 20, 22, 26, 25, 'W')
    put(f, 27, 25, 'v')  # a bolt in the sand
    return f


def bone_totem():
    f = Frame(32, 32)
    mound(f, 16, 29, 6, 2, SAND)
    for y in range(9, 28):  # stacked vertebrae
        for x in range(14, 19):
            ch = 'W' if x < 16 else 'v' if x < 18 else 'x'
            if y % 3 == 0:
                ch = 'x' if x in (14, 18) else 'v'
            put(f, x, y, ch)
    for y in (12, 18, 24):  # spurs
        put(f, 12, y, 'W')
        put(f, 13, y, 'v')
        put(f, 19, y, 'v')
        put(f, 20, y, 'x')
    # a drake skull on top, horns up
    ellipse(f, 16, 6, 4, 2.8, BONE)
    put(f, 14, 6, 'H')
    put(f, 18, 6, 'H')
    put(f, 14, 5, 'N')  # green light in the sockets
    put(f, 18, 5, 'N')
    seg(f, 13, 4, 10, 1, 'W')
    seg(f, 19, 4, 22, 1, 'W')
    for y in range(13, 20):  # torn old-war ribbons
        put(f, 20 + (y % 2), y, 'p' if y < 17 else 'P')
    return f


def shield_wall():
    f = Frame(32, 32)
    for k, x in enumerate((3, 10, 17, 24)):
        lean = (k % 2) * 1
        top = 10 + (k * 3) % 5
        for y in range(top, 27):
            for dx in range(5):
                ch = 'c' if dx < 2 else 'h' if dx < 4 else 'l'
                if (dx + y + k) % 7 == 0:
                    ch = 'o'  # rust
                put(f, x + dx + (lean if y < top + 4 else 0), y, ch)
        put(f, x + 2, top + 5, 'O')  # a dull boss
        seg(f, x + 2, top - 6, x + 1, top, 'l')  # a spear behind it
        put(f, x + 2, top - 7, 'v')
    mound(f, 16, 29, 15, 4, SAND)
    return f


def skull_pile():
    f = Frame(32, 32)
    mound(f, 16, 29, 12, 4, SAND)
    for (x, y) in ((9, 25), (14, 26), (19, 25), (23, 26), (11, 21), (16, 21), (21, 21), (14, 17), (18, 17), (16, 13)):
        skull(f, x, y)
    seg(f, 6, 27, 10, 23, 'W')
    seg(f, 24, 22, 27, 27, 'v')
    return f


def elder_crown():
    f = Frame(32, 32)
    mound(f, 16, 29, 13, 5, SAND)
    # a giant crown lying tilted, half under the sand, one spike snapped off
    for x in range(5, 27):
        y = 22 - (x - 5) // 6
        put(f, x, y, 'O')
        put(f, x, y + 1, 'q')
        put(f, x, y + 2, 'q')
    for k, x in enumerate((6, 12, 18, 24)):
        base = 22 - (x - 5) // 6
        h_ = 7 if k != 2 else 3
        for d in range(h_):
            put(f, x, base - d, 'O' if d < h_ - 1 else 'Y')
            put(f, x + 1, base - d, 'q')
        put(f, x, base - h_, 'Y')
    put(f, 19, 16, 'q')
    put(f, 21, 22, 'q')  # the snapped spike in the sand
    put(f, 22, 22, 'O')
    put(f, 15, 20, 'E')
    put(f, 16, 20, 'E')  # the gem
    put(f, 15, 19, 'w')
    return f


def giant_ribs():
    """an old-war dragon's ribcage arching out of the sand, 48x48"""
    f = Frame(48, 48)
    mound(f, 24, 45, 22, 3, SAND)
    seg(f, 4, 42, 44, 40, 'v', 2)  # the spine along the sand
    for k, x in enumerate(range(8, 44, 7)):
        height = 26 + (k % 3) * 4 - abs(k - 2) * 3
        for t in range(40):
            a = t / 39 * math.pi * 0.85
            px = round(x + math.sin(a) * 8 - 4)
            py = round(41 - math.sin(a * 1.1) * height * (1 - t / 80))
            put(f, px, py, 'W' if t < 20 else 'v')
            put(f, px + 1, py, 'x')
        if k == 3:
            put(f, x + 2, 41 - height + 6, 'w')
    return f


def big_skull():
    """an old-war dragon's skull sunk to the eyes, 48x32"""
    f = Frame(48, 32)
    mound(f, 24, 29, 22, 4, SAND)
    ellipse(f, 20, 20, 10, 7, BONE)
    for k in range(18):  # the snout
        put(f, 28 + k, 19 + k // 9, 'W' if k < 12 else 'v')
        put(f, 28 + k, 20 + k // 9, 'v')
        if k % 3 == 0:
            put(f, 28 + k, 22 + k // 9, 'w')  # teeth
    ellipse(f, 18, 18, 2.4, 2, ['H', 'H', 'h'])  # the eye socket
    put(f, 18, 18, 'N')
    seg(f, 13, 15, 4, 4, 'W', 2)
    seg(f, 16, 14, 10, 2, 'v')  # horns
    return f


def spine():
    """a dragon's spine arching in and out of the sand, 48x24"""
    f = Frame(48, 24)
    for x in range(2, 46):
        y = round(18 - math.sin((x - 2) / 44 * math.pi * 2) * 6)
        if y > 19:
            continue
        put(f, x, y, 'W' if x % 3 else 'x')
        put(f, x, y + 1, 'v')
        if x % 3 == 0:
            put(f, x, y - 1, 'W')
            put(f, x, y - 2, 'v')  # spinal spurs
    mound(f, 12, 22, 6, 2, SAND)
    mound(f, 36, 22, 6, 2, SAND)
    return f


def standard_frames():
    """a broken war standard, a torn purple banner, 16x32, four waving frames"""
    frames = []
    for k in range(4):
        f = Frame(16, 32)
        seg(f, 4, 6, 3, 30, 'l')
        put(f, 4, 5, 'o')
        for x in range(5, 12):
            wave = round(math.sin(k * 1.57 + x * 0.7) * 1.1)
            for y in range(7 + wave, 16 + wave - (x - 5) // 2):
                if _rand('torn', x, y) < 0.12 and y > 11 + wave:
                    continue
                put(f, x, y, 'P' if y < 9 + wave else 'p')
        frames.append(f)
    return frames


def ritual_stone_frames():
    """a tall ritual stone, its rune pulsing green, 16x32"""
    frames = []
    for k in range(4):
        f = Frame(16, 32)
        mound(f, 8, 30, 5, 2, SAND)
        for y in range(6, 29):
            for x in range(5, 11):
                ch = 'j' if x < 7 else 'I' if x < 10 else 'k'
                if y == 6 and x in (5, 10):
                    continue
                put(f, x, y, ch)
        glow = ['n', 'N', 'Y', 'N'][k]
        for (x, y) in ((7, 11), (8, 12), (7, 13), (8, 15), (7, 16), (8, 17), (7, 19)):
            put(f, x, y, glow)
        frames.append(f)
    return frames


def grave_fire_frames():
    """grave-fire in a bone brazier, 16x16, six frames"""
    frames = []
    for k in range(6):
        f = Frame(16, 16)
        for x in range(4, 12):
            put(f, x, 12, 'W' if x < 8 else 'v')
            put(f, x, 13, 'x')
        for y in range(3, 12):
            for x in range(4, 12):
                h_ = 11 - y
                width = 3.4 - h_ * 0.36 + math.sin(k * 1.3 + y * 0.9) * 0.6
                d = abs(x - 7.5 - math.sin(k * 1.1 + y * 0.6) * 0.8)
                if d < width:
                    put(f, x, y, 'Y' if d < width * 0.3 and h_ < 5 else 'N' if d < width * 0.7 else 'n')
        frames.append(f)
    return frames


def elder_grave():
    """the elder's empty grave, 96x64: the hollow its body left in the sand, wings spread, neck and tail curling"""
    f = Frame(96, 64)
    depth = {}

    def blob(cx, cy, rx, ry):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 1.0:
                    depth[(x, y)] = max(depth.get((x, y), 0.0), 1.0 - d)

    blob(48, 34, 16, 9)  # the body
    for k in range(20):  # the neck, curving to the head on the left
        t = k / 19
        blob(32 - t * 18, 30 - math.sin(t * math.pi) * 8, 4.5 - t * 1.5, 3.2 - t)
    blob(12, 26, 5, 3.4)  # the head
    for k in range(26):  # the tail, curling right
        t = k / 25
        blob(64 + t * 24, 38 + math.sin(t * math.pi * 1.3) * 7, 4 - t * 3, 3 - t * 2.2)
    for side in (-1, 1):  # the wings, spread up and down
        for k in range(16):
            t = k / 15
            blob(46 + t * 14, 34 + side * (8 + t * 16), 7 - t * 4, 3 - t * 1.6)
        for r in range(3):  # wing bones fanning out
            for k in range(12):
                t = k / 11
                blob(50 + r * 6 + t * 6, 34 + side * (10 + t * (14 - r * 3)), 1.6, 1.0)
    for (x, y), d in depth.items():
        if not (1 <= x <= 94 and 1 <= y <= 62):
            continue
        # lip lit on the far (bottom-right) slope, shadow on the near (top-left) one, dark floor
        up = depth.get((x - 1, y - 1), 0.0)
        ch = 'h' if d > 0.55 else 'D' if d > 0.25 else 'd'
        if d < 0.25 and up > d:
            ch = 'D'
        put(f, x, y, ch)
    for (x, y) in ((44, 33), (52, 36), (30, 29), (70, 39), (55, 24), (58, 46)):  # scattered small bones
        put(f, x, y, 'W')
        put(f, x + 1, y, 'v')
    return f


def _pit(f, k, boil):
    ellipse(f, 24, 30, 15, 9, ['D', 'd', 's'])
    for y in range(24, 37):
        for x in range(12, 37):
            d = ((x - 24) / 11) ** 2 + ((y - 30) / 6.5) ** 2
            if d <= 1.0:
                put(f, x, y, 'h' if d > 0.35 else 'H')
    pulse = [0.4, 0.7, 1.0, 0.7][k % 4] if not boil else 1.2 + (k % 2) * 0.3
    for y in range(26, 35):
        for x in range(16, 33):
            d = ((x - 24) / 7) ** 2 + ((y - 30) / 3.8) ** 2
            if d < 0.45 * pulse:
                put(f, x, y, 'Y' if d < 0.12 * pulse else 'N' if d < 0.28 * pulse else 'n')
    for k2, a in enumerate((0.3, 1.4, 2.6, 3.7, 4.9)):  # ritual stakes round the pit
        x, y = round(24 + math.cos(a) * 17), round(30 + math.sin(a) * 11)
        seg(f, x, y - 5, x, y, 'l')
        put(f, x, y - 6, 'W')
        put(f, x, y - 5, 'N' if (k + k2) % 3 == 0 else 'v')
    if boil:  # sand pouring in from the rim, cracks round it
        for s in range(6):
            a = s / 6 * math.tau + k * 0.4
            for t in range(4):
                x = round(24 + math.cos(a) * (13 - t * 2 - (k % 2)))
                y = round(30 + math.sin(a) * (8 - t * 1.2))
                put(f, x, y, 's' if t % 2 else 'S')
        for s in range(4):
            a = s / 4 * math.tau + 0.7
            seg(f, round(24 + math.cos(a) * 15), round(30 + math.sin(a) * 9),
                round(24 + math.cos(a) * 20), round(30 + math.sin(a) * 13), 'h')


def grave_pit_frames(boil):
    frames = []
    for k in range(6 if boil else 4):
        f = Frame(48, 48)
        _pit(f, k, boil)
        frames.append(f)
    return frames


# the castle under a dune: the castle's tower centres in the 64x64 overlay (castle offset 8)
TOWER_TOPS = [(16, 16), (48, 16)]


def _dune_height(x, y):
    """how high the sand stands at a pixel over the castle: a rounded mound drifted up from the west (its top a little
    west of the castle's middle), the two north tower tops poking out; 0 = no sand"""
    if any((x - tx) ** 2 + (y - ty) ** 2 < 30 for tx, ty in TOWER_TOPS):
        return 0.0
    nx, ny = (x - 30) / (30.0 if x < 30 else 27.0), (y - 36) / 27.0
    d = nx * nx + ny * ny + (_rand('dune', x // 3, y // 2) - 0.5) * 0.08
    return max(0.0, 1.0 - d)


def _dune(f, keep, k):
    for y in range(2, 63):
        for x in range(1, 63):
            h_ = _dune_height(x, y)
            if h_ <= keep:
                continue
            # lit facing the top left, shaded facing the bottom right, ripples curving round the mound
            slope = (_dune_height(x - 1, y - 1) - _dune_height(x + 1, y + 1))
            ripple = round(h_ * 14 + math.sin(x * 0.3) * 0.8) % 4 == 0
            ch = 'd' if slope > 0.03 else 'S' if slope < -0.03 else 's'
            if ripple:
                ch = 'd' if ch != 'd' else 'D'
            if h_ < 0.08:
                ch = 'D' if slope > 0 else 'd'  # the toe of the drift
            put(f, x, y, ch)
    if keep <= 0.0:  # grains trickling off the tower tops
        for tx, ty in TOWER_TOPS:
            put(f, tx + 5, ty + 2 + k % 3, 's')


def dune_idle_frames():
    frames = []
    for k in range(4):
        f = Frame(64, 64)
        _dune(f, 0.0, k)
        frames.append(f)
    return frames


def dune_reveal_frames():
    frames = []
    n = lair_art.CAMO_REVEAL_FRAMES
    for k in range(n):
        f = Frame(64, 64)
        _dune(f, k / (n - 1.5), k)
        for g in range(10 - k):  # sand pouring off the walls
            x = 6 + int(_rand('gx', k, g) * 52)
            y = 58 + k // 3 + int(_rand('gy', k, g) * 3)
            put(f, x, min(62, y), 's')
        frames.append(f)
    return frames


# the background's dark fill past the map becomes night sand, cold blue-grey with ripples
NIGHT_SAND = {'1f1419': '3a4466', '2f1e25': '262b44'}
DARK_FILL = [(0, 0), (1, 0), (0, 1), (1, 1)]


def background_sheet(src, out):
    from PIL import Image
    im = Image.open(src).convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            hexc = '%02x%02x%02x' % (r, g, b)
            if a and hexc in NIGHT_SAND:
                c = NIGHT_SAND[hexc]
                if hexc == '1f1419' and (y + round(math.sin(x * 0.4) * 1.5)) % 6 == 0:
                    c = '262b44'  # dune ripples
                px[x, y] = (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)
    for tx, ty in DARK_FILL:  # a few pale bone chips
        for k in range(3):
            if _rand('chip', tx, ty, k) < 0.5:
                continue
            gx = tx * 16 + 2 + int(_rand('cx', tx, ty, k) * 12)
            gy = ty * 16 + 2 + int(_rand('cy', tx, ty, k) * 12)
            px[gx, gy] = (0x8b, 0x9b, 0xb4, 255)
    im.save(out)


if __name__ == '__main__':
    out_dir = os.path.join(TILES, 'lairs')
    os.makedirs(out_dir, exist_ok=True)
    background_sheet(os.path.join(TILES, 'green_land', 'background_tiles.png'),
                     os.path.join(out_dir, 'grave_background_tiles.png'))
    pieces = [('RITUAL_CIRCLE', ritual_circle()), ('BALLISTA_WRECK', ballista_wreck()), ('BONE_TOTEM', bone_totem()),
              ('SHIELD_WALL', shield_wall()), ('SKULL_PILE', skull_pile()), ('ELDER_CROWN', elder_crown())]
    write_spec(os.path.join(out_dir, 'grave_landmarks.txt'), '''
# Source of grave_landmarks.aseprite and grave_landmarks.png: The Fallen Elder's 32x32 landmarks (level 48), four
# blocking 16 px tiles each: a grave callers' ritual circle, a rusted ballista wreck, a drake-bone totem, an old-war
# shield wall, a skull pile, the elder's broken crown. Drawn by tools/sprite/parts/lair_grave_art.py.''', GRAVE_PAL,
               (32, 32), [(n, 100, [f]) for n, f in pieces])
    write_spec(os.path.join(out_dir, 'grave_ribs.txt'), '''
# Source of grave_ribs.aseprite and grave_ribs.png: an old-war dragon's ribcage arching out of the sand, 48x48. Drawn
# by tools/sprite/parts/lair_grave_art.py.''', GRAVE_PAL, (48, 48), [('IDLE', 100, [giant_ribs()])])
    write_spec(os.path.join(out_dir, 'grave_skull.txt'), '''
# Source of grave_skull.aseprite and grave_skull.png: an old-war dragon's skull sunk to the eyes, 48x32. Drawn by
# tools/sprite/parts/lair_grave_art.py.''', GRAVE_PAL, (48, 32), [('IDLE', 100, [big_skull()])])
    write_spec(os.path.join(out_dir, 'grave_spine.txt'), '''
# Source of grave_spine.aseprite and grave_spine.png: a dragon's spine arching in and out of the sand, 48x24. Drawn by
# tools/sprite/parts/lair_grave_art.py.''', GRAVE_PAL, (48, 24), [('IDLE', 100, [spine()])])
    write_spec(os.path.join(out_dir, 'grave_standard.txt'), '''
# Source of grave_standard.aseprite and grave_standard.png: a broken old-war standard, 16x32, four waving frames. Drawn
# by tools/sprite/parts/lair_grave_art.py.''', GRAVE_PAL, (16, 32), [('IDLE', 170, standard_frames())])
    write_spec(os.path.join(out_dir, 'grave_stone.txt'), '''
# Source of grave_stone.aseprite and grave_stone.png: a ritual stone, its rune pulsing green, 16x32, four frames. Drawn
# by tools/sprite/parts/lair_grave_art.py.''', GRAVE_PAL, (16, 32), [('IDLE', 220, ritual_stone_frames())])
    write_spec(os.path.join(out_dir, 'grave_fire.txt'), '''
# Source of grave_fire.aseprite and grave_fire.png: grave-fire in a bone brazier, 16x16, six frames. Drawn by
# tools/sprite/parts/lair_grave_art.py.''', GRAVE_PAL, (16, 16), [('IDLE', 110, grave_fire_frames())])
    write_spec(os.path.join(out_dir, 'grave_elder_grave.txt'), '''
# Source of grave_elder_grave.aseprite and grave_elder_grave.png: the elder's empty grave, the hollow its body left in
# the sand, 96x64. Drawn by tools/sprite/parts/lair_grave_art.py.''', GRAVE_PAL, (96, 64), [('IDLE', 100, [elder_grave()])])
    write_spec(os.path.join(out_dir, 'grave_pit.txt'), '''
# Source of grave_pit.aseprite and grave_pit.png: the elder's grave pit, 48x48 (a boss spawn's art): IDLE a faint green
# pulse, BOIL caving in when the Bone Colossus rises. Drawn by tools/sprite/parts/lair_grave_art.py.''', GRAVE_PAL,
               (48, 48), [('IDLE', 240, grave_pit_frames(False)), ('BOIL', 100, grave_pit_frames(True))])
    write_spec(os.path.join(out_dir, 'grave_castle_dune.txt'), '''
# Source of grave_castle_dune.aseprite and grave_castle_dune.png: the castle buried in a dune, 64x64 over the 48x48
# castle (offset 8): IDLE sand trickling off the tower tops, REVEAL (one shot) the sand sliding off when the Bone
# Colossus rises. Drawn by tools/sprite/parts/lair_grave_art.py.''', GRAVE_PAL, (64, 64),
               [('IDLE', 200, dune_idle_frames()), ('REVEAL', 90, dune_reveal_frames())])
    write_sprite_frames('grave_standard', 16, 32, [('IDLE', 170, 4, True)])
    write_sprite_frames('grave_stone', 16, 32, [('IDLE', 220, 4, True)])
    write_sprite_frames('grave_fire', 16, 16, [('IDLE', 110, 6, True)])
    write_sprite_frames('grave_pit', 48, 48, [('IDLE', 240, 4, True), ('BOIL', 100, 6, True)])
    write_sprite_frames('grave_castle_dune', 64, 64,
                        [('IDLE', 200, 4, True), ('REVEAL', 90, lair_art.CAMO_REVEAL_FRAMES, False)])
    print('ok')
