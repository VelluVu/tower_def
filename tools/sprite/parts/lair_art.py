"""Boss lair art (2026-11-24): set pieces for the area boss levels, starting with the Broodmother's Brood Cavern
(Caves 12). 32x32 landmarks (four blocking 16 px tiles each, like area_landmarks.py), a 16x16 animated miner's torch
and the 48x48 breathing nest pit (a spawn point's art). Light from the top left, no black outlines, Endesga 32.

usage: lair_art.py <parts dir> <tiles dir>   (then tools/sprite/sprite.py build <spec> <out.aseprite>)"""
import math
import os
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, write_spec
from scorched_decor import put, ellipse, seg, mound, shard

TILES = sys.argv[2]

BROOD_PAL = {
    'H': '181425', 'h': '262b44', 'j': '3a4466', 'J': '5a6988', 'g': '8b9bb4', 'G': 'c0cbdc',  # cave stone, silk
    'D': '3e2731', 'P': '68386c', 'p': 'b55088', 'q': 'f6757a', 'Q': 'ffc6c3',  # egg membrane
    'r': 'a22633', 'R': 'e43b44',  # veins, the nest's glow
    'd': '733e39', 'l': 'b86f50', 'L': 'e4a672',  # timber
    's': 'b59e85', 'u': 'd5bf9b', 'e': 'ecd8b1',  # bone
    'b': '124e89', 'c': '0099db', 'y': '2ce8f5', 'z': 'ffffff',  # crystal
    'o': 'f77622', 'O': 'feae34', 'Y': 'fee761', 'f': 'be4a2f',  # flame, rust
}
GRAVEL = ['J', 'j', 'h']
STONE = ['h', 'j', 'J', 'g']
EGG = ['D', 'P', 'p', 'q']
BONE = ['s', 'u', 'e']


def egg(f, cx, cy, rx, ry, swell=0.0):
    """one egg sac: a membrane with a dark shape curled inside, a vein and a wet highlight"""
    ellipse(f, cx, cy, rx + swell, ry + swell, EGG)
    ellipse(f, cx + 1, cy + 1, max(1.2, rx * 0.4), max(1.2, ry * 0.4), ['D', 'P'])
    seg(f, cx - rx + 2, cy + 1, cx - 1, cy + ry - 2, 'r')
    put(f, cx - rx // 2, cy - ry // 2, 'Q')
    put(f, cx - rx // 2 + 1, cy - ry // 2, 'q')


def egg_cluster():
    f = Frame(32, 32)
    mound(f, 16, 29, 14, 3, GRAVEL)
    for (x0, y0, x1, y1) in ((3, 4, 10, 15), (28, 3, 21, 13), (16, 2, 15, 8)):  # silk strands holding the pile
        seg(f, x0, y0, x1, y1, 'G')
    for cx, cy, rx, ry in ((9, 22, 6, 6), (21, 21, 6, 7), (15, 13, 5, 6), (26, 25, 4, 4), (5, 26, 3, 3)):
        egg(f, cx, cy, rx, ry)
    for x, y in ((12, 28), (13, 29), (22, 29)):  # slime drips
        put(f, x, y, 'q')
    return f


def mine_scaffold():
    f = Frame(32, 32)
    mound(f, 16, 29, 14, 2, GRAVEL)
    for x in range(4, 7):  # the standing post
        seg(f, x, 6, x, 27, 'l' if x == 4 else 'd')
    for x in range(20, 23):  # the snapped post: a stump and a splinter
        seg(f, x, 20, x, 27, 'l' if x == 20 else 'd')
    seg(f, 20, 19, 21, 17, 'L')
    for y in range(5, 8):  # the crossbeam, sagging where its post broke
        seg(f, 3, y, 14, y, 'L' if y == 5 else 'l' if y == 6 else 'd')
        seg(f, 14, y, 24, y + 7, 'l' if y == 5 else 'd')
    seg(f, 7, 18, 13, 8, 'd', 2)  # brace
    seg(f, 11, 8, 11, 11, 'j')  # the lantern on its hook, still lit
    for y in range(12, 16):
        for x in range(10, 14):
            put(f, x, y, 'J' if x in (10, 13) or y in (12, 15) else 'O')
    put(f, 11, 13, 'Y')
    for y in range(19, 25):  # the abandoned cart, ore still in it
        for x in range(9 + (y - 19) // 3, 20 - (y - 19) // 3):
            put(f, x, y, 'g' if y == 19 else 'f' if (x * 3 + y) % 7 == 0 else 'J' if x < 14 else 'j')
    for x, ch in ((10, 'c'), (11, 'y'), (12, 'j'), (13, 'c'), (15, 'J'), (16, 'c'), (17, 'y'), (18, 'j')):
        put(f, x, 18, ch)
    put(f, 12, 17, 'c'); put(f, 16, 17, 'y')
    for wx in (11, 17):
        ellipse(f, wx, 26, 1.6, 1.6, ['H', 'h', 'J'])
    for x, y, ch in ((19, 27, 'c'), (20, 26, 'y'), (22, 28, 'J'), (8, 28, 'g'), (24, 27, 'c')):  # spilled ore
        put(f, x, y, ch)
    return f


def giant_ribs():
    f = Frame(32, 32)
    mound(f, 16, 29, 15, 3, GRAVEL)
    for i, x in enumerate((5, 10, 15, 20, 25)):  # ribs arching up and in over the spine, the far ones lower
        h = (12, 17, 20, 17, 12)[i]
        lean = (3, 2, 0, -2, -3)[i]
        for k in range(h):
            yy = 26 - k
            xx = x + round(lean * math.sin(k / h * 2.2))
            put(f, xx - 1, yy, 's')
            put(f, xx, yy, 'e' if k < h - 2 else 'u')
            put(f, xx + 1, yy, 'u' if k < h - 2 else 's')
        put(f, x + lean // 2, 26 - h, 'u')
    for x in range(3, 29):  # the spine, knobbed
        put(f, x, 26, 'u')
        put(f, x, 27, 's' if x % 3 else 'u')
    shard(f, 14, 26, 16, 12, 2)  # crystals grown up through the cage
    shard(f, 22, 26, 23, 17, 1)
    shard(f, 8, 26, 7, 19, 1)
    for x, y in ((16, 12), (23, 17), (7, 19)):
        put(f, x, y, 'z')
    return f


def silk_boulder():
    f = Frame(32, 32)
    mound(f, 16, 29, 14, 2, GRAVEL)
    ellipse(f, 15, 19, 11, 9, ['h', 'j', 'J', 'g', 'G'])
    for k, ch in ((-6, 'G'), (2, 'g'), (8, 'G')):  # silk wrapped round it
        seg(f, 5 + k, 27, 19 + k, 10, ch)
    seg(f, 4, 17, 26, 21, 'G')
    for y in range(6, 18):  # a cocooned miner hanging from the top, slowly turning
        w = 3 if 8 < y < 16 else 2
        for x in range(24 - w // 2, 25 + w // 2):
            put(f, x, y, 'e' if x == 24 - w // 2 else 'G' if (x + y) % 3 else 'g')
    seg(f, 24, 2, 24, 5, 'G')
    seg(f, 4, 13, 8, 22, 'd')  # a pick left leaning on the rock
    seg(f, 2, 13, 6, 12, 'J')
    for x, y, ch in ((26, 27, 'O'), (27, 27, 'o'), (25, 28, 'f'), (28, 28, 'f')):  # the miner's helmet
        put(f, x, y, ch)
    return f


def crystal_cluster():
    f = Frame(32, 32)
    mound(f, 16, 29, 13, 3, GRAVEL)
    for (bx, tx, ty, half) in ((15, 14, 4, 3), (9, 6, 12, 2), (21, 24, 9, 2), (12, 11, 17, 1), (25, 27, 18, 1)):
        shard(f, bx, 27, tx, ty, half)
        put(f, tx, ty, 'z')
    for x, y in ((4, 24), (28, 22), (17, 2)):  # sparkles in the dark
        put(f, x, y, 'y')
    return f


def shard_colours():
    """scorched_decor.shard draws with its obsidian keys (P p q); map them to crystal here"""
    return {'P': 'b', 'p': 'c', 'q': 'y'}


def recolour(f, mapping, keep=()):
    f.px = {k: mapping.get(v, v) if k not in keep else v for k, v in f.px.items()}
    return f


def torch_frames():
    frames = []
    for i in range(4):
        f = Frame(16, 16)
        seg(f, 7, 8, 7, 14, 'l')
        seg(f, 8, 8, 8, 14, 'd')
        seg(f, 6, 8, 9, 8, 'J')
        sway = (0, 1, 0, -1)[i]
        tall = (0, 1, 1, 0)[i]
        for y in range(3 - tall, 8):
            half = 1 if y > 4 else 0
            for x in range(7 - half + (sway if y < 5 else 0), 9 + half + (sway if y < 5 else 0)):
                put(f, x, y, 'Y' if y > 5 and x in (7, 8) else 'O' if y > 4 else 'o')
        put(f, 7 + sway, 2 - tall, 'o') if i % 2 else None
        frames.append(f)
    return frames


def nest_frames():
    frames = []
    for i in range(4):
        breath = (0.0, 0.6, 1.0, 0.6)[i]
        f = Frame(48, 48)
        ellipse(f, 24, 26, 21, 16, ['h', 'j', 'J', 'g'])  # the rock lip
        ellipse(f, 24, 27, 17, 12, ['H', 'h', 'j'], light=(0.5, 0.7))  # the pit, lit on its far wall
        ellipse(f, 24, 29, 12 + breath, 7 + breath, EGG)  # the membrane floor breathing
        for k in range(5):  # veins
            a = k * 1.25 + 0.4
            seg(f, 24, 29, 24 + round(11 * math.cos(a)), 29 + round(6 * math.sin(a)), 'r')
        ellipse(f, 24, 29, 3 + breath, 2, ['r', 'R'])
        put(f, 21, 26, 'Q')
        for sx, sy in ((7, 22), (40, 24), (12, 38), (35, 39), (24, 11)):  # hatched shells on the lip
            put(f, sx, sy, 'e')
            put(f, sx + 1, sy, 'u')
            put(f, sx, sy + 1, 's')
        for (x0, y0, x1, y1) in ((5, 31, 10, 33), (37, 33, 42, 30), (17, 12, 21, 11)):  # bones
            seg(f, x0, y0, x1, y1, 'u')
            put(f, x0, y0, 'e')
            put(f, x1, y1, 'e')
        frames.append(f)
    return frames


# ======================= the camouflaged castle =======================
# 64x64, the castle's 48x48 in the middle (offset 8): rock slabs over the castle so it reads as part of the cave, its
# hoard glowing through a crack; REVEAL crumbles it outward stone by stone (one shot), the castle shows underneath.
CAMO_PAL = dict(BROOD_PAL, **{'1': '262b44', '2': '31353b', '3': '3a3e45', '4': '4a5058', '5': '515661',
                              '6': '5e656e', '7': '6a717a', '8': '8b9bb4', 'm': '193c3e', 'M': '265c42'})
CAMO_RAMP = ['2', '3', '4', '5', '6', '7', '8']
CAMO_OFFSET = 8
CAMO_TOWERS = ((9, 9), (39, 9), (9, 39), (39, 39))
CAMO_CRACK = [(20, 17), (22, 20), (21, 23), (24, 25), (26, 24), (28, 27), (27, 30)]
CAMO_REVEAL_FRAMES = 9


def _rand(*key):
    import zlib
    return (zlib.crc32(repr(key).encode()) % 10007) / 10007.0


def _camo_height(x, y):
    """the mound's height over castle pixel x, y (0 outside): four high boulders on the towers, a lower slab between
    them, its outline broken up a little so it reads as rock, not a box"""
    h = 0.0
    for tx, ty in CAMO_TOWERS:
        d = math.hypot(x - tx, y - ty) + (_rand('bump', tx, ty, int(math.atan2(y - ty, x - tx) * 3)) - 0.5) * 2.0
        if d < 11.0:
            h = max(h, 0.5 + 0.5 * (1 - d / 11.0) ** 0.7)
    edge = min(x - 5, 43 - x, y - 5, 43 - y) + (_rand('rim', x // 3, y // 3) - 0.5) * 3.0
    if edge >= 0:
        h = max(h, min(0.42, 0.18 + edge * 0.05))
    if h == 0 and _castle_cover(x, y):
        h = 0.12  # a thin skin of rock over the castle's own outline, so none of it shows
    return h


def _castle_cover(x, y):
    """the castle's opaque pixels (first frame of puffe_castle.png) grown by one"""
    global _CASTLE
    if '_CASTLE' not in globals():
        from PIL import Image
        im = Image.open(os.path.join(TILES, 'props', 'puffe_castle.png')).convert('RGBA')
        opaque = set((px, py) for px in range(48) for py in range(48) if im.getpixel((px, py))[3])
        _CASTLE = set((px + dx, py + dy) for px, py in opaque for dx in (-1, 0, 1) for dy in (-1, 0, 1))
    return (x, y) in _CASTLE


def _camo_cells():
    seeds = []
    for i in range(140):
        x, y = _rand('sx', i) * 50 - 1, _rand('sy', i) * 50 - 1
        if _camo_height(round(x), round(y)) > 0 and all(math.hypot(x - a, y - b) > 4.2 for a, b, _ in seeds):
            seeds.append((x, y, _rand('shade', i)))
    return seeds


def _camo_stones():
    """castle pixel -> (stone index, colour key); crack lines between stones"""
    seeds = _camo_cells()
    out = {}
    for y in range(48):
        for x in range(48):
            h = _camo_height(x, y)
            if h <= 0:
                continue
            ds = sorted((math.hypot(x - sx, y - sy), i) for i, (sx, sy, _) in enumerate(seeds))
            (d1, i1), (d2, _) = ds[0], ds[1]
            slope = _camo_height(x + 2, y + 2) - _camo_height(x - 2, y - 2)
            light = 0.42 + slope * 2.6 + (seeds[i1][2] - 0.5) * 0.35 - (0.25 if _camo_height(x + 1, y + 1) == 0 else 0)
            light += (h - 0.45) * 0.9
            if d2 - d1 < 1.0:
                ch = '1' if light < 0.5 else '2'
            else:
                ch = CAMO_RAMP[max(0, min(len(CAMO_RAMP) - 1, int(light * len(CAMO_RAMP))))]
                if seeds[i1][2] > 0.82 and light > 0.45 and _rand('moss', x // 2, y // 2) > 0.45:
                    ch = 'M' if light > 0.6 else 'm'
            out[(x, y)] = (i1, ch)
    for tx, ty in CAMO_TOWERS:  # little stalagmites on the tower mounds
        for k, (ox, oy) in enumerate(((-3, -2), (2, -4), (1, 2))):
            bx, by = tx + ox, ty + oy
            for j in range(3):
                out[(bx, by - j)] = (out.get((bx, by), (0, ''))[0], '8' if j == 2 else '7' if j else '5')
                if j == 0:
                    out[(bx + 1, by)] = (out.get((bx, by), (0, ''))[0], '3')
    for (x0, y0, x1, y1) in ((31, 5, 37, 11),):  # a strand of silk over one boulder
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for k in range(steps + 1):
            c = (round(x0 + (x1 - x0) * k / steps), round(y0 + (y1 - y0) * k / steps))
            if c in out:
                out[c] = (out[c][0], 'G' if k % 3 else 'g')
    return out


def _camo_glow(f, pulse, widen=0):
    glow = ('o', 'O', 'Y', 'O')[pulse]
    for (x0, y0), (x1, y1) in zip(CAMO_CRACK, CAMO_CRACK[1:]):
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for k in range(steps + 1):
            x, y = round(x0 + (x1 - x0) * k / steps), round(y0 + (y1 - y0) * k / steps)
            for w in range(-widen, widen + 1):
                put(f, x + CAMO_OFFSET + w, y + CAMO_OFFSET, glow if w == 0 else 'o')
            put(f, x + CAMO_OFFSET + 1, y + CAMO_OFFSET, 'H')


def camo_idle_frames():
    stones = _camo_stones()
    frames = []
    for pulse in range(4):
        f = Frame(64, 64)
        for (x, y), (_, ch) in stones.items():
            put(f, x + CAMO_OFFSET, y + CAMO_OFFSET, ch)
        _camo_glow(f, pulse)
        frames.append(f)
    return frames


def camo_reveal_frames():
    stones = _camo_stones()
    seeds = _camo_cells()
    cx, cy = 24, 24
    fall = {i: min(1.0, math.hypot(sx - cx, sy - cy) / 34.0) * 0.55 + _rand('fall', i) * 0.35
            for i, (sx, sy, _) in enumerate(seeds)}
    darker = {k: CAMO_RAMP[max(0, CAMO_RAMP.index(k) - 2)] for k in CAMO_RAMP}
    frames = []
    for k in range(CAMO_REVEAL_FRAMES):
        f = Frame(64, 64)
        t = (k + 1) / (CAMO_REVEAL_FRAMES - 1) * 1.15
        for (x, y), (i, ch) in stones.items():
            sx, sy, _ = seeds[i]
            if t < fall[i]:
                put(f, x + CAMO_OFFSET, y + CAMO_OFFSET, '1' if k > 0 and _rand('crk', x, y) < 0.08 * k else ch)
                continue
            p = (t - fall[i]) / 0.4
            if p >= 1.0 or _rand('crumb', x, y) < p * 0.7:
                continue
            ang = math.atan2(sy - cy, sx - cx)
            ox, oy = math.cos(ang) * p * 7, math.sin(ang) * p * 7 + p * p * 4
            put(f, round(x + ox) + CAMO_OFFSET, round(y + oy) + CAMO_OFFSET, darker.get(ch, '2'))
        for d in range(int(70 * max(0.0, 1.0 - abs(t - 0.6) * 1.4))):  # dust rising from the falling slabs
            a = _rand('da', k, d) * math.tau
            r = 14 + _rand('dr', k, d) * (8 + k * 1.6)
            put(f, round(32 + math.cos(a) * r), round(32 + math.sin(a) * r * 0.8), 'G' if _rand('dc', k, d) > 0.6 else 'g')
        if k < 3:
            _camo_glow(f, 2, widen=k)
        frames.append(f)
    return frames


def write_sprite_frames(name, fw, fh, tags):
    """the SpriteFrames .tres over lairs/<name>.png (packed ceil(sqrt(n)) columns, as sprite.py exports it), into
    scenes/level/lair/frames/"""
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(TILES))))
    count = sum(n for _, _, n, _ in tags)
    columns = math.ceil(math.sqrt(count))
    out = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (count + 2), '',
           '[ext_resource type="Texture2D" path="res://assets/art/tiles/lairs/%s.png" id="1_sheet"]' % name, '']
    for i in range(count):
        out += ['[sub_resource type="AtlasTexture" id="AtlasTexture_%d"]' % i, 'atlas = ExtResource("1_sheet")',
                'region = Rect2(%d, %d, %d, %d)' % (i % columns * fw, i // columns * fh, fw, fh), '']
    animations, i = [], 0
    for tag, ms, n, loop in tags:
        frames = ', '.join('{"duration": 1.0, "texture": SubResource("AtlasTexture_%d")}' % (i + k) for k in range(n))
        i += n
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}'
                          % (frames, 'true' if loop else 'false', tag, repr(round(1000.0 / ms, 3))))
    out += ['[resource]', 'animations = [' + ', '.join(animations) + ']', '']
    folder = os.path.join(root, 'scenes', 'level', 'lair', 'frames')
    os.makedirs(folder, exist_ok=True)
    open(os.path.join(folder, name + '_frames.tres'), 'w', encoding='utf-8', newline='\n').write('\n'.join(out))


if __name__ == '__main__':
    out_dir = os.path.join(TILES, 'lairs')
    os.makedirs(out_dir, exist_ok=True)
    crystal = shard_colours()
    pieces = [('EGG_CLUSTER', egg_cluster()), ('MINE_SCAFFOLD', mine_scaffold()),
              ('GIANT_RIBS', recolour(giant_ribs(), crystal)), ('SILK_BOULDER', silk_boulder()),
              ('CRYSTAL_CLUSTER', recolour(crystal_cluster(), crystal))]
    write_spec(os.path.join(out_dir, 'brood_landmarks.txt'), '''
# Source of brood_landmarks.aseprite and brood_landmarks.png: the Brood Cavern's 32x32 landmarks (Caves 12, the
# Broodmother's lair), four blocking 16 px tiles each: an egg sac cluster, the miners' broken scaffolding and cart, giant
# ribs with crystals, a silk-wrapped boulder with a cocooned miner, a glowing crystal cluster. Drawn by
# tools/sprite/parts/lair_art.py.''', BROOD_PAL, (32, 32), [(n, 100, [f]) for n, f in pieces])
    write_spec(os.path.join(out_dir, 'brood_torch.txt'), '''
# Source of brood_torch.aseprite and brood_torch.png: a dead miner's torch, 16x16, four flicker frames. Drawn by
# tools/sprite/parts/lair_art.py.''', BROOD_PAL, (16, 16), [('IDLE', 120, torch_frames())])
    write_spec(os.path.join(out_dir, 'brood_nest.txt'), '''
# Source of brood_nest.aseprite and brood_nest.png: the Broodmother's nest pit, 48x48 (a spawn point), its membrane
# floor breathing over four frames. Drawn by tools/sprite/parts/lair_art.py.''', BROOD_PAL, (48, 48),
               [('IDLE', 250, nest_frames())])
    write_spec(os.path.join(out_dir, 'brood_castle_camo.txt'), '''
# Source of brood_castle_camo.aseprite and brood_castle_camo.png: the Brood Cavern's castle under rock slabs, 64x64 over
# the 48x48 castle (offset 8): IDLE its hoard glowing through a crack, REVEAL (one shot) crumbling away when the
# Broodmother arrives. Drawn by tools/sprite/parts/lair_art.py.''', CAMO_PAL, (64, 64),
               [('IDLE', 220, camo_idle_frames()), ('REVEAL', 90, camo_reveal_frames())])
    write_sprite_frames('brood_torch', 16, 16, [('IDLE', 120, 4, True)])
    write_sprite_frames('brood_nest', 48, 48, [('IDLE', 250, 4, True)])
    write_sprite_frames('brood_castle_camo', 64, 64, [('IDLE', 220, 4, True), ('REVEAL', 90, CAMO_REVEAL_FRAMES, False)])
    print('ok')
