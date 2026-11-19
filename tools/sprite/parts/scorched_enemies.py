"""The Scorched Lands roster (levels 37-48): the ash desert's raised dead and the volcano's fire creatures.

Most are drawn over an existing enemy's frames (same canvas, frames, durations and tags, so the motion holds): a new
palette by colour role plus overlays (rib stripes, ember eyes, horns, lava cracks). The rusted ballista and the Ashen
Wyrm are drawn from parts. Writes <name>/<name>.txt, .aseprite and .png under the enemy art folder; then
tools/sprite/parts/icon_from_spec.py makes each icon (see build_icons below).

usage: scorched_enemies.py <parts dir> <enemy art dir> [name...]"""
import math
import os
import re
import subprocess
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, part, write_spec
from limbs import line
from PIL import Image

ROOT = sys.argv[2]
SPRITE = os.path.join(sys.argv[1], '..', 'sprite.py')
KEYS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!$%&*+-/:;<>?@^_~'

BONE = ['3a3430', '5e5448', '9a8f80', 'c8bfae', 'ece6d8']
RUST = ['4a2a22', '6e3424', '9a4a2a', 'be6a3a']
EMBER = 'f77622'
GLOW = 'fee761'


# ----------------------------------------------------------------------------------------- reading frames
def info(aseprite):
    out = subprocess.run([sys.executable, SPRITE, 'info', aseprite], capture_output=True, text=True).stdout
    w, h = map(int, re.search(r'(\d+)x(\d+)\s+mode', out).groups())
    durs = [int(v) for v in re.search(r'durations\(ms\): ([\d,]+)', out).group(1).split(',')]
    tags = [(m.group(1), int(m.group(2)) - 1, int(m.group(3)) - 1) for m in re.finditer(r'tag (\S+) (\d+)-(\d+)', out)]
    return w, h, durs, tags


def frames_of(aseprite, n, w, h):
    tmp = aseprite + '.frames.png'
    subprocess.run([sys.executable, SPRITE, 'view', aseprite, tmp, '--scale', '1'], capture_output=True)
    im = Image.open(tmp).convert('RGBA')
    im.load()
    os.remove(tmp)
    out = []
    for i in range(n):
        f = im.crop((i * w, 0, i * w + w, h))
        out.append({(x, y): '%02x%02x%02x' % f.getpixel((x, y))[:3] for y in range(h) for x in range(w) if f.getpixel((x, y))[3]})
    return out


def save(name, header, size, tags):
    """tags: [(tag, ms, [pixel dicts of hex colours])]"""
    colours = {}
    for _, _, frames in tags:
        for px in frames:
            for c in px.values():
                colours.setdefault(c, None)
    key = {c: KEYS[i] for i, c in enumerate(colours)}
    out_tags = []
    for tag, ms, frames in tags:
        fs = []
        for px in frames:
            f = Frame(*size)
            f.px = {p: key[c] for p, c in px.items()}
            fs.append(f)
        out_tags.append((tag, ms, fs))
    folder = os.path.join(ROOT, name)
    os.makedirs(folder, exist_ok=True)
    spec = os.path.join(folder, name + '.txt')
    write_spec(spec, header, {k: c for c, k in key.items()}, size, out_tags)
    subprocess.run([sys.executable, SPRITE, 'build', spec, os.path.join(folder, name + '.aseprite')], check=True, capture_output=True)
    preview = os.path.join(folder, name + '.preview.png')
    if os.path.exists(preview):
        os.remove(preview)
    print(name)


# ----------------------------------------------------------------------------------------- overlays
def near(px, p, colours, n=4):
    x, y = p
    around = ((1, 0), (-1, 0), (0, 1), (0, -1)) if n == 4 else ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1))
    return sum(1 for dx, dy in around if px.get((x + dx, y + dy)) in colours)


def ribs(colours, light, dark):
    """rows of the given (base) colours alternate a light and a dark rib"""
    def apply(base, px, i):
        for (x, y), c in base.items():
            if c in colours:
                px[(x, y)] = light if y % 2 == 0 else dark
    return apply


def stripes_x(colours, dark, every=2):
    """every other column of the given (base) colours goes dark: ribs seen from the side"""
    def apply(base, px, i):
        for (x, y), c in base.items():
            if c in colours and x % every == 0:
                px[(x, y)] = dark
    return apply


def eyes(eye, skin, glow):
    """an eye pixel (eye colour between skin pixels) glows"""
    def apply(base, px, i):
        for p, c in base.items():
            if c == eye and near(base, p, skin) >= 2:
                px[p] = glow
    return apply


def cracks(colours, glow, every=5):
    """a few lava cracks through the given (base) colours, fixed per pixel so they hold between frames"""
    def apply(base, px, i):
        for (x, y), c in base.items():
            if c in colours and (x * 7 + y * 3) % every == 0 and near(base, (x, y), colours, 8) >= 6:
                px[(x, y)] = glow
    return apply


def horns(skin, colour, gap=0):
    """two short horns on the head's top (the topmost skin pixels)"""
    def apply(base, px, i):
        top = [p for p, c in base.items() if c in skin]
        if not top:
            return
        y0 = min(y for _, y in top)
        xs = sorted(x for x, y in top if y == y0)
        if not xs:
            return
        for x in (xs[0], xs[-1]):
            for dy in (1, 2):
                if y0 - dy >= 1:
                    px[(x, y0 - dy)] = colour
    return apply


def derive(name, src, mapping, overlays, header):
    path = os.path.join(ROOT, src[0], src[1] + '.aseprite')
    w, h, durs, tags = info(path)
    frames = frames_of(path, len(durs), w, h)
    out = []
    for tag, a, b in tags:
        fs = []
        for i in range(a, b + 1):
            base = frames[i]
            px = {p: mapping.get(c, c) for p, c in base.items()}
            for overlay in overlays:
                overlay(base, px, i)
            fs.append(px)
        out.append((tag, durs[a], fs))
    save(name, header, (w, h), out)


# ----------------------------------------------------------------------------------------- the raised dead
def bone_thrall():
    skin = ['e8b796', 'c28569']
    derive('bone_thrall', ('soldier', 'soldier'), {
        'e8b796': BONE[4], 'c28569': BONE[3], 'c0cbdc': RUST[3], '8b9bb4': RUST[2], '5a6988': RUST[1], '3a4466': RUST[0],
        'feae34': BONE[2], '0099db': BONE[1], '124e89': BONE[0]},
        [ribs(['0099db', '124e89'], BONE[3], BONE[0]), eyes('181425', skin, EMBER)], '''
# Bone thrall: the ash desert's basic unit, an old-war soldier's skeleton raised by the Wyrm: bone ramp ece6d8..3a3430,
# ribs where the tabard was, a rusted kettle helm 9a4a2a/be6a3a, ember eyes f77622. Drawn by
# tools/sprite/parts/scorched_enemies.py over soldier.aseprite (same frames and tags).''')


def ash_runner():
    derive('ash_runner', ('assault_dog', 'assault_dog'), {
        'c0cbdc': BONE[4], '8b9bb4': BONE[3], '5a6988': BONE[2], '3a4466': BONE[1], 'a22633': RUST[2], 'e43b44': RUST[3]},
        [stripes_x(['8b9bb4'], BONE[1], 3), eyes('181425', ['c0cbdc', '8b9bb4', '5a6988', '3a4466'], EMBER)], '''
# Ash runner: the ash desert's fast unit, a raised war hound's skeleton, ribs showing down its flanks, a rusted collar,
# ember eyes. Drawn by tools/sprite/parts/scorched_enemies.py over assault_dog.aseprite.''')


def scarab():
    derive('scarab', ('swarmling', 'swarmling'), {
        'ecd8b1': '5ec8a8', 'd5bf9b': '2a9a8a', 'b59e85': '1e6a64', 'b86f50': 'd8b040', '733e39': '9a6a20',
        '3e2731': '3a2a18', 'a22633': '1a3a40', 'ff0044': 'f6c34a'}, [], '''
# Scarab: the ash desert's group unit, an iridescent teal and gold beetle 5ec8a8/2a9a8a/1e6a64, gold legs d8b040.
# Drawn by tools/sprite/parts/scorched_enemies.py over swarmling.aseprite.''')


def revenant_knight():
    derive('revenant_knight', ('armored_knight', 'armored_knight'), {
        'c0cbdc': 'c88a5c', '8b9bb4': '9a5a3a', '5a6988': '6e3a28', '3a4466': '3e2620', 'a22633': '3a3430',
        'e43b44': '5e5448', 'feae34': '9a8f80', 'f77622': '6e6250', '181425': EMBER}, [], '''
# Revenant knight: the ash desert's tank, an old-war knight in rusted plate c88a5c..3e2620 with a faded rag of a
# tabard, embers behind the visor. Drawn by tools/sprite/parts/scorched_enemies.py over armored_knight.aseprite.''')


def ash_drake():
    derive('ash_drake', ('batling', 'batling'), {
        'ecd8b1': BONE[4], 'd5bf9b': BONE[3], 'b59e85': BONE[2], '68386c': '3e3a3c', 'b55088': '5e5458',
        'f6757a': '7a6e70', 'a22633': '4a2a22', 'ff0044': EMBER}, [], '''
# Ash drake: the Scorched Lands' flyer, a dragon of the old war raised from its bones: bone body, torn ash-grey wings
# 3e3a3c/5e5458, ember eyes. Drawn by tools/sprite/parts/scorched_enemies.py over batling.aseprite.''')


def grave_caller():
    derive('grave_caller', ('wizard', 'wizard'), {
        '68386c': '1e3a3a', 'b55088': '2d5a50', '3e2731': '14201e', 'e8b796': BONE[4], 'c28569': BONE[3],
        'feae34': '63c74d', '2ce8f5': '8fd060', '0099db': '3e8948', 'fee761': 'd0f080'},
        [eyes('181425', ['e8b796', 'c28569'], '8fd060')], '''
# Grave caller: raises the fallen. A skull-faced necromancer in a dark teal robe 1e3a3a/2d5a50, a green grave-light orb
# 8fd060/3e8948 on its staff, green eyes. Drawn by tools/sprite/parts/scorched_enemies.py over wizard.aseprite.''')


def bone_colossus():
    belly = ['b08a4a', 'e0c070', 'f2e3a0']
    derive('bone_colossus', ('bog_hydra', 'bog_hydra'), {
        '17323a': BONE[0], '1f5048': BONE[1], '2d7356': BONE[2], '4a9a5c': BONE[3], '8fc46a': BONE[4],
        'fee761': EMBER, '2f6b3d': BONE[0], '4a8a45': BONE[1], '7cbf4a': BONE[2], '68386c': RUST[1], 'b55088': RUST[2]},
        [ribs(belly, BONE[3], BONE[0])], '''
# Bone Colossus: the ash desert's boss (level 42), the raised skeleton of the elder dragon that drove the Wyrm out long
# ago: three bone necks and skulls, a rib cage for a belly, ember eyes. Drawn by tools/sprite/parts/scorched_enemies.py
# over bog_hydra.aseprite (same tags: SPIT throws bone shards, SUBMERGE/EMERGE sink it into the sand).''')


def bone_rider():
    skin = ['e8b796', 'c28569']
    derive('bone_rider', ('cavalry', 'cavalry'), {
        'e4a672': BONE[4], 'b86f50': BONE[3], '733e39': BONE[2], '3e2731': BONE[1],
        'e8b796': BONE[4], 'c28569': BONE[3], 'c0cbdc': RUST[3], '8b9bb4': RUST[2], '5a6988': RUST[1], '3a4466': RUST[0],
        '0099db': BONE[1], '124e89': BONE[0], 'feae34': BONE[2], 'a22633': RUST[1]},
        [eyes('181425', skin, EMBER)], '''
# Bone rider: the ash desert's fast, tough special (the cavalry's raised dead): a pale bone horse, a
# skeleton rider in a rusted helm and rags, a tattered rust pennon on the lance, ember eyes. Drawn by
# tools/sprite/parts/scorched_enemies.py over cavalry.aseprite (same frames and tags).''')


# ----------------------------------------------------------------------------------------- the volcano
def cinder_imp():
    skin = ['b59e85', 'bfa98c', 'cab494', 'd5bf9b', 'e0caa3', 'ead4aa', 'ecd8b1', 'eddbb7', 'efdebd']
    ramp = ['5d1d2c', '74202e', '8b2330', 'a22633', 'be3a34', 'd0453a', 'e43b44', 'ea5a3c', 'f06a48']
    mapping = dict(zip(skin, ramp))
    mapping.update({'a22633': '2a2028', 'f6757a': EMBER})
    derive('cinder_imp', ('weakling', 'weakling_aseprite'), mapping, [horns(skin, '2a2028')], '''
# Cinder imp: the volcano's basic unit, a small ember-red imp 5d1d2c..f06a48 with black horns and a charred
# loincloth, yellow eyes. Drawn by tools/sprite/parts/scorched_enemies.py over the weakling's frames.''')


def magma_salamander():
    derive('magma_salamander', ('fastswampling', 'fastswampling'), {
        '2a1a33': '2a2028', '45254f': '3e3038', '68386c': '54444e', '8e4f7a': '6a5a64', 'b55088': EMBER,
        '7a9a1e': 'be4a2f', 'b6d53c': EMBER, 'e6f07a': GLOW, 'f6757a': 'e43b44'}, [], '''
# Magma salamander: the volcano's fast unit, a black salamander 181425..54444e with a glowing lava stripe down its
# back and ember spots; swims the lava. Drawn by tools/sprite/parts/scorched_enemies.py over fastswampling.aseprite.''')


def ember_wisp():
    derive('ember_wisp', ('swarmling', 'swarmling'), {
        'ecd8b1': GLOW, 'd5bf9b': 'feae34', 'b59e85': EMBER, 'b86f50': 'e43b44', '733e39': 'a22633', '3e2731': '5d1d2c',
        'a22633': EMBER, 'ff0044': 'ffffff', 'fee761': 'ffffff'}, [], '''
# Ember wisp: the volcano's group unit, a little flame sprite fee761/feae34/f77622 with red embers for feet; comes back
# once from its spark. Drawn by tools/sprite/parts/scorched_enemies.py over swarmling.aseprite.''')


def obsidian_golem():
    glass = ['124e89', '0099db', '2ce8f5', '3a4466', '262b44']
    derive('obsidian_golem', ('crystal_brute', 'crystal_brute'), {
        '124e89': '1e1a26', '0099db': '2c2432', '2ce8f5': '54485a', '3a4466': '181420', '262b44': '0f0b14',
        'c0cbdc': '7a6a7e', '45254f': 'a22633', '68386c': 'e43b44', 'b55088': EMBER, 'f6757a': 'feae34',
        'ffc6c3': GLOW, 'ff0044': GLOW}, [cracks(glass, EMBER, 6)], '''
# Obsidian golem: the volcano's tank, black volcanic glass 0f0b14..54485a with glowing lava crystals on its back and
# lava cracks; breaks into two magma blobs. Drawn by tools/sprite/parts/scorched_enemies.py over crystal_brute.aseprite.''')


def magma_blob():
    derive('magma_blob', ('leechling', 'leechling'), {
        'b86f50': 'e43b44', '733e39': 'a22633', '3e2731': '5d1d2c', '181425': '2a2028', 'f77622': GLOW,
        'a22633': EMBER, 'e43b44': 'feae34', 'f6757a': GLOW}, [], '''
# Magma blob: what crawls out of a broken obsidian golem, a slug of molten rock e43b44/a22633 with a glowing crust.
# Drawn by tools/sprite/parts/scorched_enemies.py over leechling.aseprite.''')


def phoenix():
    derive('phoenix', ('giant_eagle', 'giant_eagle'), {
        'ffffff': GLOW, 'c0cbdc': 'feae34', '8b9bb4': EMBER, 'feae34': 'ffffff', 'f77622': GLOW,
        'b86f50': 'e43b44', '733e39': 'a22633', '3e2731': '5d1d2c', 'a22633': EMBER}, [], '''
# Phoenix: the volcano's late flyer, a firebird in red, orange and gold e43b44/f77622/fee761; rises once from its
# ashes unless the killing hit is Frost. Drawn by tools/sprite/parts/scorched_enemies.py over giant_eagle.aseprite.''')


def ember_cultist():
    derive('ember_cultist', ('priest', 'priest'), {
        'ffffff': 'a22633', 'c0cbdc': '8b2330', '8b9bb4': '5d1d2c', '5a6988': '3e1a24', '3a4466': '2a1420',
        'feae34': EMBER}, [], '''
# Ember cultist: one of the humans who chose the Wyrm, in a crimson robe a22633..2a1420 with flame trim, a burning
# sun staff; wards its neighbours with fire. Drawn by tools/sprite/parts/scorched_enemies.py over priest.aseprite.''')


def lava_spitter():
    skin = ['b59e85', 'cab494', 'd5bf9b', 'e0caa3', 'ecd8b1']
    derive('lava_spitter', ('destroyerling', 'destroyerling'), {
        'b59e85': '2c2432', 'cab494': '3e3038', 'd5bf9b': '54444e', 'e0caa3': '6a5a64', 'ecd8b1': '7a6872',
        '87202b': EMBER, 'a22633': GLOW, '3a4466': 'a22633', '5a6988': 'e43b44', '8b9bb4': EMBER, 'c0cbdc': GLOW,
        'b86f50': 'e43b44', '733e39': 'a22633', '3e2731': '2a2028', 'ff0044': GLOW},
        [cracks(skin, EMBER, 7)], '''
# Lava spitter: the volcano's artillery, a hunched basalt brute 2c2432..7a6872 with lava cracks and a molten belly,
# hurling globs of lava. Drawn by tools/sprite/parts/scorched_enemies.py over destroyerling.aseprite.''')


def lava_glob():
    """the lava spitter's shot, from the destroyerling's rock"""
    src = Image.open(os.path.join(ROOT, 'destroyerling', 'destroyerling_rock.png')).convert('RGBA')
    mapping = {'3a4466': 'a22633', '5a6988': 'e43b44', '8b9bb4': EMBER, 'c0cbdc': GLOW}
    out = src.copy()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src.getpixel((x, y))
            new = mapping.get('%02x%02x%02x' % (r, g, b))
            if a and new:
                out.putpixel((x, y), (int(new[0:2], 16), int(new[2:4], 16), int(new[4:6], 16), a))
    out.save(os.path.join(ROOT, 'lava_spitter', 'lava_glob.png'))
    print('lava_glob')


def line_pts(put, x0, y0, x1, y1, c):
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for s in range(steps + 1):
        put(round(x0 + (x1 - x0) * s / steps), round(y0 + (y1 - y0) * s / steps), c)


def bone_shard():
    """the Bone Colossus's spit, the hydra's acid recoloured by brightness onto the bone ramp"""
    path = os.path.join(os.path.dirname(os.path.dirname(ROOT)), 'projectile', 'hydra_acid.png')
    src = Image.open(path).convert('RGBA')
    out = src.copy()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src.getpixel((x, y))
            if a:
                light = (r * 299 + g * 587 + b * 114) / 255000
                c = BONE[min(len(BONE) - 1, int(light * len(BONE)))]
                out.putpixel((x, y), (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a))
    out.save(os.path.join(ROOT, 'bone_colossus', 'bone_shard.png'))
    print('bone_shard')


# ----------------------------------------------------------------------------------------- the rusted ballista
BAL = {'L': '8a7e6a', 'M': '6e6250', 'D': '5e5448', 'd': '3a3430', 'R': 'be6a3a', 'r': '9a4a2a', 'q': '6e3424',
       'i': '4a2a22', 's': 'c8bfae', 'b': 'ece6d8', 'B': '9a8f80', 'o': EMBER, 'y': GLOW}
BAL_CART = part("""
LLLLLLLLLLLLLLLbb
MMMMMMMMMMMMMMMbo
DMdDDDDDDDDdDDDBB
dddddddddddddddd.""")
BAL_WHEEL = [part("""
.rRr.
r.i.r
Riiir
r.i.r
.rrr."""), part("""
.rRr.
ri.ir
r.i.r
ri.ir
.rrr.""")]
BAL_BOLT = part("""
LLLLLLLLLLLRo""")


def stamp(px, p, dx, dy, colours=BAL):
    for x, y, ch in p:
        X, Y = x + dx, y + dy
        if 1 <= X <= 24 and 1 <= Y <= 24:
            px[(X, Y)] = colours[ch]


def ballista_frame(spin=0, bob=0, pull=0, bolt=True, tilt=0):
    px = {}
    top = 11 + bob
    # the bow: a rusted bar standing at the front, its string drawn back to the nut
    for y in range(top - 5, top + 6):
        px[(18, y)] = BAL['R'] if y < top else BAL['r']
    px[(18, top - 6)] = BAL['q']
    px[(18, top + 6)] = BAL['q']
    nut = 11 - pull
    line_pts(lambda x, y, c: px.__setitem__((x, y), c), 17, top - 5, nut, top, BAL['s'])
    line_pts(lambda x, y, c: px.__setitem__((x, y), c), 17, top + 5, nut, top, BAL['s'])
    # the stock along the middle, the bolt on it
    for x in range(4, 18):
        px[(x, top)] = BAL['M'] if x != nut else BAL['d']
    if bolt:
        stamp(px, BAL_BOLT, nut, top - 1)
    # the cart under it and the wheels
    stamp(px, BAL_CART, 4, top + 2 + tilt)
    stamp(px, BAL_WHEEL[spin % 2], 5, top + 6)
    stamp(px, BAL_WHEEL[(spin + 1) % 2 if tilt else spin % 2], 14, top + 6 + tilt)
    return px


def ballista_dead(stage):
    px = {}
    stamp(px, BAL_CART, 3 + stage, 18 + min(stage, 1))
    stamp(px, BAL_WHEEL[0], 1 + stage * 2, 19)
    for x in range(8, 19):
        px[(x, 17 + min(stage, 1))] = BAL['r'] if x % 3 else BAL['q']
    if stage >= 1:
        px[(19 + stage, 18 + min(stage, 1))] = BAL['B']
        px[(20 + stage, 19)] = BAL['r']
    return px


def rusted_ballista():
    tags = [('IDLE', 200, [ballista_frame(0), ballista_frame(0, pull=1)]),
            ('WALK', 140, [ballista_frame(s, bob=s % 2) for s in range(4)]),
            ('ATTACK', 120, [ballista_frame(0, pull=2), ballista_frame(0, pull=4), ballista_frame(0, pull=0, bolt=False),
                             ballista_frame(0, pull=1, bolt=False)]),
            ('DEATH', 140, [ballista_frame(0, tilt=1), ballista_frame(1, bob=1, tilt=2, bolt=False), ballista_dead(0),
                            ballista_dead(1), ballista_dead(2)])]
    save('rusted_ballista', """
# Rusted ballista: the ash desert's siege special, an old-war ballista rolled by the Wyrm's will: grey-brown old wood
# 3a3430..8a7e6a on a cart, a rusted bow 6e3424..be6a3a with a bone-white string, two spoked wheels, a skull on the
# prow with an ember eye; its bolt goes through a line of towers. Drawn from parts by
# tools/sprite/parts/scorched_enemies.py.""", (26, 26), tags)


# ----------------------------------------------------------------------------------------- the Ashen Wyrm (40x40)
ASH = ['2a2028', '3e3038', '5e5458', '847a80', 'a89ea4']
MEMBRANE = ['3e2731', '5d1d2c', '74202e']
FIRE = ['a22633', 'e43b44', EMBER, GLOW]
WYRM_HEAD = {
    'shut': '''
ww..........
.ww.HH......
..wHHHHHH...
.HHHHHHHHHh.
HHHYHHHHHhhh
.HHHHHHhjjhh
...hhhhhhh..''',
    'open': '''
ww...........
.ww.HH.......
..wHHHHHH....
.HHHHHHHHHh..
HHHYHHHHhhhh.
.HHHHHHh.....
...hhhhhojjj.
....hhhhhh...''',
    'dead': '''
ww..........
.ww.HH......
..wHHHHHH...
.HHHHHHHHHh.
HHHKHHHHHhhh
.HHHHHHhhhhh
...hhhhhhh..''',
}
HEAD_COLOURS = {'w': BONE[3], 'H': ASH[3], 'h': ASH[2], 'Y': GLOW, 'j': FIRE[1], 'o': FIRE[2], 'K': ASH[0]}


def blob(px, cx, cy, rx, ry, ramp, light=(-0.5, -0.7)):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            d = nx * nx + ny * ny
            if d <= 1.0:
                lit = -(nx * light[0] + ny * light[1])
                v = 0.5 + lit * 0.55 - (0.25 if d > 0.75 else 0)
                px[(x, y)] = ramp[max(0, min(len(ramp) - 1, int(v * len(ramp))))]


def thick(px, pts_, ramp, width=3):
    for i in range(len(pts_) - 1):
        (x0, y0), (x1, y1) = pts_[i], pts_[i + 1]
        steps = max(abs(x1 - x0), abs(y1 - y0), 1) * 2
        for s in range(steps + 1):
            t = s / steps
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for o in range(width):
                px[(round(x + o - width // 2), round(y))] = ramp[min(len(ramp) - 1, max(0, 1 + (width // 2 - o)))]


def fill_triangle(px, a, b, c, colour):
    xs, ys = [a[0], b[0], c[0]], [a[1], b[1], c[1]]

    def side(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    for y in range(min(ys), max(ys) + 1):
        for x in range(min(xs), max(xs) + 1):
            s1, s2, s3 = side(a, b, (x, y)), side(b, c, (x, y)), side(c, a, (x, y))
            if (s1 >= 0 and s2 >= 0 and s3 >= 0) or (s1 <= 0 and s2 <= 0 and s3 <= 0):
                px[(x, y)] = colour


# per pose: the wrist and three finger tips, from the shoulder; the membrane fans from the shoulder between them
# and runs back to the body, scalloped between the finger tips
WING = {
    'up': ((-3, -9), [(-10, -15), (-3, -16), (5, -13)]),
    'mid': ((-6, -5), [(-15, -8), (-12, -2), (-5, 2)]),
    'down': ((-5, 4), [(-12, 10), (-6, 12), (1, 10)]),
    'folded': ((-3, -3), [(-8, -3), (-6, 0), (-2, 1)]),
}


def wing(px, sx, sy, pose, near=True):
    (wx, wy), tips = WING[pose]
    wrist = (sx + wx, sy + wy)
    pts_ = [(sx + tx, sy + ty) for tx, ty in tips]
    shade = MEMBRANE if near else [MEMBRANE[0], MEMBRANE[0], MEMBRANE[1]]
    fill_triangle(px, (sx, sy), wrist, pts_[0], shade[1])
    for i in range(len(pts_) - 1):
        # a dent between two finger tips: the membrane reaches only part of the way out
        mid = ((pts_[i][0] + pts_[i + 1][0]) // 2 + (sx - pts_[i][0]) // 6, (pts_[i][1] + pts_[i + 1][1]) // 2 + (sy - pts_[i][1]) // 6)
        fill_triangle(px, (sx, sy), pts_[i], mid, shade[i % 2 + 1])
        fill_triangle(px, (sx, sy), mid, pts_[i + 1], shade[(i + 1) % 2 + 1])
    fill_triangle(px, (sx, sy), pts_[-1], (sx + 6, sy + 1), shade[0])
    bone = BONE[3] if near else BONE[1]
    line_pts(lambda x, y, c: px.__setitem__((x, y), c), sx, sy, wrist[0], wrist[1], bone)
    for t in pts_:
        line_pts(lambda x, y, c: px.__setitem__((x, y), c), wrist[0], wrist[1], t[0], t[1], BONE[2] if near else BONE[1])
    px[wrist] = BONE[4] if near else BONE[2]


def wyrm(wing='mid', y=0, legs='tucked', step=0, head='shut', head_dy=0, breath=0, lie=0, glow=True, dx=0):
    px = {}
    by = 22 + y + lie
    sx, sy = 20 + dx, by - 4
    # far wing behind the body
    if wing != 'folded':
        wing_drawn = wing
        globals()['wing'](px, sx - 3, sy + 1, wing_drawn, near=False)
    # tail
    # the tail curls up when the body leans back to breathe, so it stays on the canvas
    thick(px, [(12 + dx, by + 1), (6 + dx, by + 4 - lie // 2), (max(2, 2 + dx), by + 1 - (0 if lie else 2) + min(0, dx))], ASH, 2)
    # legs
    if legs == 'tucked':
        for lx in (14 + dx, 23 + dx):
            line_pts(lambda x, yy, c: px.__setitem__((x, yy), c), lx, by + 4, lx - 2, by + 6, ASH[1])
    elif legs == 'down':
        for k, lx in enumerate((14, 23)):
            off = (step if k == 0 else -step)
            line_pts(lambda x, yy, c: px.__setitem__((x, yy), c), lx, by + 3, lx + off, min(37, by + 9), ASH[1])
            px[(lx + off + 1, min(37, by + 9))] = ASH[0]
    # body and belly cracks
    blob(px, 18 + dx, by, 10, 6, ASH[1:])
    for x in range(11 + dx, 26 + dx):
        if glow and (x % 3):
            px[(x, by + 4)] = FIRE[1] if x % 2 else FIRE[2]
    for x in (14 + dx, 18 + dx, 22 + dx):
        if glow:
            px[(x, by + 3)] = FIRE[0]
    # spines along the back
    for x in range(12 + dx, 25 + dx, 3):
        px[(x, by - 5)] = BONE[2]
    # neck and head
    hx, hy = 27 + dx, by - 13 + head_dy + lie
    thick(px, [(24 + dx, by - 2), (27 + dx, by - 6 + head_dy // 2), (hx + 1, hy + 4)], ASH[1:], 3)
    for r, row in enumerate(part(WYRM_HEAD[head]) and WYRM_HEAD[head].strip('\n').split('\n')):
        for c, ch in enumerate(row):
            if ch != '.':
                px[(hx + c, hy + r)] = HEAD_COLOURS[ch]
    # breath: a widening cone of fire from the jaw, forward and down at the ground (the towers)
    if breath:
        mx, my = hx + 12, hy + 6
        for k in range(breath * 4):
            spread = k // 3
            for dy in range(-spread, spread + 1):
                x, yy = mx + k, my + k // 2 + dy
                if 1 <= x <= 38 and 1 <= yy <= 38:
                    px[(x, yy)] = FIRE[3 - min(3, abs(dy) + k // 5)]
    # near wing over the body
    globals()['wing'](px, sx, sy, wing, near=True)
    return {p: c for p, c in px.items() if 1 <= p[0] <= 38 and 1 <= p[1] <= 38}


def ashen_wyrm():
    fly = [wyrm('up', y=-1), wyrm('mid'), wyrm('down', y=1), wyrm('mid')]
    tags = [
        ('IDLE', 180, [wyrm('folded', legs='down', y=7), wyrm('folded', legs='down', y=7, head_dy=1),
                       wyrm('folded', legs='down', y=7, head_dy=1), wyrm('folded', legs='down', y=7)]),
        ('WALK', 120, fly),
        ('GROUND_WALK', 140, [wyrm('folded', legs='down', y=7, step=s) for s in (-2, 0, 2, 0)]),
        ('ATTACK', 110, [wyrm('mid', head_dy=-2, dx=-3), wyrm('mid', head='open', head_dy=1, breath=1, dx=-6),
                         wyrm('mid', head='open', head_dy=1, breath=2, dx=-6), wyrm('mid', head='open', head_dy=1, breath=3, dx=-6),
                         wyrm('mid', head='open', head_dy=1, breath=2, dx=-6)]),
        ('LAND', 140, [wyrm('up', y=1), wyrm('mid', y=3, legs='down'), wyrm('down', y=5, legs='down'),
                       wyrm('folded', y=7, legs='down')]),
        ('ROAR', 130, [wyrm('folded', legs='down', y=7, head_dy=-3), wyrm('folded', legs='down', y=7, head='open', head_dy=-4),
                       wyrm('up', legs='down', y=7, head='open', head_dy=-4), wyrm('folded', legs='down', y=7, head_dy=-2)]),
        ('DEATH', 160, [wyrm('folded', legs='down', y=7, head='open', head_dy=-2), wyrm('down', legs='down', y=8, head_dy=2),
                        wyrm('down', y=8, head='dead', head_dy=4, lie=2, glow=True), wyrm('down', y=8, head='dead', head_dy=5, lie=3, glow=False),
                        wyrm('down', y=8, head='dead', head_dy=5, lie=3, glow=False)]),
    ]
    save('ashen_wyrm', '''
# Ashen Wyrm: the archenemy and final boss (level 48), a fallen elder dragon of ash: body 1e1a26..6a5a64, lava glowing
# through the cracks of its belly, bone horns and spines, dark red wings 3e2731/5d1d2c/74202e. WALK flies (phase 1),
# LAND comes down, GROUND_WALK and IDLE walk and stand on the ground, ATTACK breathes fire forward, ROAR calls the ash
# drakes, DEATH crashes. Drawn from parts by tools/sprite/parts/scorched_enemies.py.''', (40, 40), tags)


# ----------------------------------------------------------------------------------------- the Magma Titan
OBS = ['0f0b14', '1e1a26', '2c2432', '54485a', '7a6a7e']


def titan(far=(9, 26), near_=(31, 26), y=0, step=0, head_dy=0, core=1, rock=None, shock=0, sink=0, glow=True):
    """the Magma Titan facing right: obsidian plates over a molten core. far/near_ are the fists (the far arm is drawn
    behind the body), rock a held or flying magma rock, shock a ring of lava at the feet, sink pulls it into a pool"""
    px = {}
    lava = FIRE if glow else [OBS[2], OBS[2], OBS[3], OBS[3]]
    hips, sh_far, sh_near = (20, 27 + y), (12, 15 + y), (28, 15 + y)

    def arm(shoulder, fist):
        elbow = ((shoulder[0] + fist[0]) // 2 + (2 if fist[0] > shoulder[0] else -2), (shoulder[1] + fist[1]) // 2 + 1)
        thick(px, [shoulder, elbow, fist], OBS[1:], 4)
        blob(px, fist[0], fist[1], 3, 3, OBS[1:])
        px[(fist[0], fist[1])] = lava[2]

    arm(sh_far, (far[0], far[1] + y))
    # legs and feet
    for lx, off in ((17, -step), (23, step)):
        thick(px, [(lx, hips[1]), (lx + off, 35)], OBS[1:], 4)
        blob(px, lx + off + 1, 36, 3, 1.5, OBS[1:])
    # torso, shoulder plates, head
    blob(px, 20, 20 + y, 9, 8, OBS[1:])
    for sx, sy in (sh_far, sh_near):
        blob(px, sx, sy - 1, 4.5, 3.5, OBS[2:])
    blob(px, 22, 9 + y + head_dy, 4, 3.5, OBS[2:])
    #a heavy brow over the eyes, inside the head's outline, and a lava seam over the crown
    for x in range(22, 26):
        px[(x, 8 + y + head_dy)] = OBS[0]
    for x in (20, 21, 22):
        px[(x, 6 + y + head_dy + (1 if x == 20 else 0))] = lava[1]
    for x in (23, 25):
        px[(x, 9 + y + head_dy)] = GLOW if glow else OBS[3]
    # lava cracks and the core
    for a, b in (((16, 14), (19, 20)), ((19, 20), (17, 25)), ((24, 15), (26, 22)), ((13, 13), (11, 16)), ((29, 13), (30, 16))):
        line_pts(lambda x, yy, c: px.__setitem__((x, yy), c), a[0], a[1] + y, b[0], b[1] + y, lava[1])
    if core:
        blob(px, 21, 20 + y, 1.5 + core, 1.5 + core, [lava[0], lava[1], lava[2], lava[3]], light=(0.0, 0.0))
        px[(21, 20 + y)] = lava[3]
    arm(sh_near, (near_[0], near_[1] + y))
    if rock:
        blob(px, rock[0], rock[1], 2.5, 2.5, [FIRE[1], FIRE[2], FIRE[3]])
    if shock:
        for x in range(20 - 6 * shock, 21 + 6 * shock):
            if (x + shock) % 3:
                px[(x, 37 - (abs(x - 20) % 2))] = FIRE[2] if abs(x - 20) < 4 * shock else FIRE[1]
    if sink:
        moved = {}
        for (x, yy), c in px.items():
            if yy + sink <= 35:
                moved[(x, yy + sink)] = c
        px = moved
        pool = OBS if sink > 10 else FIRE
        blob(px, 20, 36, 8 + sink // 3, 2, [pool[1], pool[2], pool[3]], light=(0.0, 0.5))
    return {p: c for p, c in px.items() if 1 <= p[0] <= 38 and 1 <= p[1] <= 38}


def magma_titan():
    tags = [
        ('IDLE', 180, [titan(core=1), titan(core=2), titan(core=2, y=1), titan(core=1, y=1)]),
        ('WALK', 150, [titan(step=-2, near_=(32, 25), far=(8, 27)), titan(y=1), titan(step=2, near_=(30, 27), far=(10, 25)), titan(y=1)]),
        ('ATTACK', 110, [titan(near_=(31, 8)), titan(near_=(33, 5), head_dy=-1), titan(near_=(34, 31), core=2, shock=1),
                         titan(near_=(32, 28))]),
        ('SLAM', 120, [titan(far=(16, 5), near_=(26, 4), head_dy=-1), titan(far=(14, 2), near_=(28, 2), head_dy=-1, core=2),
                       titan(far=(12, 33), near_=(30, 33), y=1, core=2, shock=1), titan(far=(12, 33), near_=(30, 33), y=1, shock=2),
                       titan(y=1)]),
        ('HURL', 120, [titan(near_=(17, 6), rock=(17, 3)), titan(near_=(14, 4), rock=(13, 2), head_dy=-1),
                       titan(near_=(35, 13), rock=(37, 10), core=2), titan(near_=(33, 18)), titan()]),
        ('ROAR', 130, [titan(head_dy=-1, core=2), titan(far=(5, 17), near_=(35, 17), head_dy=-2, core=3),
                       titan(far=(4, 15), near_=(36, 15), head_dy=-2, core=3), titan(head_dy=-1, core=2)]),
        ('DEATH', 160, [titan(head_dy=1, core=3), titan(far=(8, 30), near_=(30, 31), y=2, core=2, sink=3),
                        titan(far=(8, 30), near_=(30, 31), y=2, core=1, sink=7), titan(far=(8, 30), near_=(30, 31), y=2, core=0, sink=11),
                        titan(far=(8, 30), near_=(30, 31), y=2, core=0, sink=15, glow=False),
                        titan(far=(8, 30), near_=(30, 31), y=2, core=0, sink=19, glow=False)]),
    ]
    save('magma_titan', '''
# Magma Titan: the volcano's mid-boss (level 57, Magma Heart), a hulking giant of black obsidian plates 0f0b14..7a6a7e
# over a molten core, lava glowing through the cracks, ember eyes. ATTACK smashes a fist down, SLAM brings both down
# (cracking the ground), HURL throws a magma rock, ROAR calls up the magma, DEATH sinks into a pool of lava that cools.
# Drawn from parts by tools/sprite/parts/scorched_enemies.py.''', (40, 40), tags)


ALL = {
    'magma_titan': magma_titan,
    'bone_thrall': bone_thrall, 'ash_runner': ash_runner, 'scarab': scarab, 'revenant_knight': revenant_knight,
    'ash_drake': ash_drake, 'grave_caller': grave_caller, 'rusted_ballista': rusted_ballista,
    'bone_colossus': bone_colossus, 'bone_rider': bone_rider, 'cinder_imp': cinder_imp, 'magma_salamander': magma_salamander,
    'ember_wisp': ember_wisp, 'obsidian_golem': obsidian_golem, 'magma_blob': magma_blob, 'phoenix': phoenix,
    'ember_cultist': ember_cultist, 'lava_spitter': lava_spitter, 'ashen_wyrm': ashen_wyrm,
}

if __name__ == '__main__':
    for name in (sys.argv[3:] or ALL):
        ALL[name]()
    if not sys.argv[3:] or 'lava_spitter' in sys.argv[3:]:
        lava_glob()
    if not sys.argv[3:] or 'bone_colossus' in sys.argv[3:]:
        bone_shard()
