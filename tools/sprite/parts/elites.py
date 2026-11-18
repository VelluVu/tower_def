"""Elite versions of the enemies that come as elites (SpawnGroupData.elites), drawn over their own frames.

Gold is the elite sign. The armoured humans get golden armour: their steel ramp becomes a gold ramp and a glint
sweeps across it from frame to frame. The other enemies keep their colours and get ornaments: crowns, a halo, a
plume, horns, gold markings, a gold hem or a gold ridge along the back. An ornament is anchored on the head pixels
of each frame, so it follows the bob, and is left out when the head is hidden (a burrow, a belly-up corpse).

Writes <name>_elite.txt, .aseprite and .png next to each enemy's sheet. The .png is laid out cell for cell like the
enemy's own .png (each cell holds the elite version of the frame in the same cell), so Elite can point the scene's
SpriteFrames regions at it. Same canvas, frames and tags as the base sprite.

usage: elites.py <parts dir> <enemy art dir> [name...]"""
import os
import re
import subprocess
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, write_spec
from PIL import Image

ROOT = sys.argv[2]
SPRITE = os.path.join(sys.argv[1], '..', 'sprite.py')
KEYS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!$%&*+-/:;<>?@^_~'

# Endesga 32 gold, dark to light, then the glint
GOLD = ['733e39', 'f77622', 'feae34', 'fee761', 'ffffff']
STEEL_TO_GOLD = {'3a4466': '733e39', '5a6988': 'f77622', '8b9bb4': 'feae34', 'c0cbdc': 'fee761'}
RUST_TO_GOLD = {'4a2a22': '733e39', '6e3424': 'f77622', '9a4a2a': 'feae34', 'be6a3a': 'fee761'}
PLATE_TO_GOLD = {'3e2620': '733e39', '6e3a28': 'f77622', '9a5a3a': 'feae34', 'c88a5c': 'fee761'}
SKIN = ['e8b796', 'c28569']

# ornaments: rows top to bottom, '.' empty; letters are colours below
INK = {'y': 'fee761', 'g': 'feae34', 'G': 'f77622', 'R': 'e43b44', 'r': 'a22633', 'w': 'ffffff', 'b': 'c0cbdc',
       'c': '2ce8f5'}
CROWN = ['y.y.y', 'gRgRg']
CROWN_SMALL = ['y.y', 'gRg']
CIRCLET = ['gRg']
HALO = ['gyyyg']
CROWN_PLAIN = ['y.y', 'ggg']
PLUME = ['.rR', 'rR.']
STAR = ['.y.', 'ywy', '.y.']
HORNS = ['w...w', 'b...b']

# per enemy:
#   swap: base colour -> elite colour
#   sheen: base colours whose pixels get the travelling glint (one gold step brighter on a moving diagonal)
#   ornament, anchor: the ornament, placed over the head found from the anchor colours (topmost pixels of
#       those colours, or the rightmost `span` columns of them with side='right'); climb: go up through the
#       opaque pixels above (hair, helm, hat) to the head's top; gap: empty rows between head and ornament
#       (negative: the ornament's bottom rows overlap the head)
#   hem: colours whose lowest pixel in each column becomes gold (a gold trim on a robe)
#   ridge: colours whose topmost pixel in each column becomes gold (gilded plates along a back)
ELITES = {
    'armored_knight': dict(swap=STEEL_TO_GOLD, sheen=list(STEEL_TO_GOLD)),
    'soldier': dict(swap=STEEL_TO_GOLD, sheen=list(STEEL_TO_GOLD), ornament=PLUME, anchor=SKIN, climb=True),
    'sapper': dict(swap=STEEL_TO_GOLD, sheen=list(STEEL_TO_GOLD), ornament=PLUME, anchor=SKIN, climb=True),
    'cavalry': dict(swap=STEEL_TO_GOLD, sheen=list(STEEL_TO_GOLD), ornament=PLUME, anchor=SKIN, climb=True,
                    hem=['0099db', '124e89']),
    'archer': dict(swap={'a22633': 'feae34'}, ornament=CROWN_PLAIN, anchor=SKIN, climb=True, hem=['3e8948', '265c42']),
    'scout': dict(ornament=CROWN_SMALL, anchor=SKIN, climb=True, hem=['3e8948', '265c42']),
    'wizard': dict(ornament=STAR, anchor=SKIN, climb=True, gap=-2, hem=['68386c', 'b55088']),
    'priest': dict(ornament=HALO, anchor=SKIN, climb=True, gap=1),
    'assault_dog': dict(swap={'a22633': 'f77622', 'e43b44': 'feae34'}, sheen=['a22633', 'e43b44'],
                        ridge=['3a4466', '5a6988', '8b9bb4', 'c0cbdc']),
    'giant_eagle': dict(ornament=CROWN, anchor=['ffffff'], side='right', span=5, climb=True),
    'giant_wasp': dict(ornament=CROWN_SMALL, anchor=['feae34', 'fee761', 'f77622'], side='right', span=4, climb=True),
    'fastswampling': dict(swap={'b55088': 'fee761'}, ornament=HORNS, anchor=['fee761'], climb=True, gap=-1,
                          ridge=['7a9a1e', 'b6d53c', 'e6f07a']),
    'leaper_frog': dict(swap={'f77622': 'fee761'}, ornament=CROWN, anchor=['e43b44'], climb=True),
    'swampling': dict(swap={'b55088': 'fee761', '45254f': 'f77622'}, ornament=CROWN, anchor=['fee761'], climb=True),
    'swbeefling': dict(swap={'b55088': 'fee761', '68386c': 'f77622'}, ornament=HORNS, anchor=['fee761'], climb=True,
                       gap=-1),
    'leechling': dict(swap={'f77622': 'fee761'}, ridge=['b86f50', '733e39'], ornament=CROWN_PLAIN,
                      anchor=['b86f50', '733e39', '3e2731'], side='right', span=3, climb=True),
    'plaguepig': dict(swap={'c0cbdc': 'fee761', 'b55088': 'feae34'}, ornament=CROWN, anchor=['181425'], climb=True),
    'bloater': dict(swap={'63c74d': 'feae34'}, ornament=CROWN, anchor=['181425'], climb=True),
    # ---- the Scorched Lands (2026-11-17): the dead's rust turns to gold, the volcano's creatures get molten veins
    'bone_thrall': dict(swap=RUST_TO_GOLD, sheen=list(RUST_TO_GOLD)),
    'bone_rider': dict(swap=RUST_TO_GOLD, sheen=list(RUST_TO_GOLD), ornament=PLUME, anchor=['ece6d8', 'c8bfae'], climb=True),
    'revenant_knight': dict(swap=PLATE_TO_GOLD, sheen=list(PLATE_TO_GOLD)),
    'rusted_ballista': dict(swap=RUST_TO_GOLD, sheen=list(RUST_TO_GOLD)),
    'ash_runner': dict(swap={'9a4a2a': 'f77622', 'be6a3a': 'feae34'}, sheen=['9a4a2a', 'be6a3a'],
                       ridge=['ece6d8', 'c8bfae', '9a8f80']),
    'scarab': dict(swap={'5ec8a8': 'fee761', '2a9a8a': 'feae34', '1e6a64': 'f77622'}, sheen=['5ec8a8', '2a9a8a', '1e6a64']),
    'ash_drake': dict(ornament=CROWN_SMALL, anchor=['f77622'], climb=True),
    'grave_caller': dict(ornament=STAR, anchor=['ece6d8', 'c8bfae'], climb=True, gap=-2, hem=['1e3a3a', '2d5a50']),
    'cinder_imp': dict(swap={'2a2028': 'feae34'}, sheen=['2a2028']),
    'magma_salamander': dict(veins=['2a2028', '3e3038', '54444e', '6a5a64']),
    'obsidian_golem': dict(veins=['1e1a26', '2c2432', '54485a', '181420', '0f0b14']),
    'magma_blob': dict(veins=['e43b44', 'a22633', '5d1d2c']),
    'lava_spitter': dict(veins=['2c2432', '3e3038', '54444e', '6a5a64', '7a6872']),
    'ember_wisp': dict(swap={'f77622': 'fee761', 'feae34': 'ffffff', 'e43b44': 'f77622'}),
    'phoenix': dict(ornament=CROWN, anchor=['fee761'], side='right', span=5, climb=True),
    'ember_cultist': dict(ornament=CROWN_PLAIN, anchor=SKIN, climb=True, hem=['a22633', '8b2330']),
}

SHEEN_PERIOD = 12
# molten veins: every VEIN_EVERY-th inner pixel of the body glows, fixed per pixel so the veins hold between frames
VEIN_EVERY = 4


def hexof(p):
    return '%02x%02x%02x' % p[:3]


def tags_of(aseprite):
    out = subprocess.run([sys.executable, SPRITE, 'info', aseprite], capture_output=True, text=True).stdout
    size = re.search(r'(\d+)x(\d+)', out)
    durs = [int(v) for v in re.search(r'durations\(ms\): ([\d,]+)', out).group(1).split(',')]
    tags = [(m.group(1), int(m.group(2)) - 1, int(m.group(3)) - 1) for m in re.finditer(r'tag (\S+) (\d+)-(\d+)', out)]
    return (int(size.group(1)), int(size.group(2))), durs, tags


def frames_of(aseprite, n, w, h):
    """Every frame in order, from Aseprite's own row export."""
    tmp = aseprite + '.frames.png'
    subprocess.run([sys.executable, SPRITE, 'view', aseprite, tmp, '--scale', '1'], capture_output=True)
    im = Image.open(tmp).convert('RGBA')
    im.load()
    os.remove(tmp)
    return [im.crop((i * w, 0, i * w + w, h)) for i in range(n)]


def head_top(px, w, h, cfg):
    """(x, y) of the head's top centre, or None when no anchor pixel shows."""
    anchor = set(cfg.get('anchor', []))
    found = [(x, y) for (x, y), c in px.items() if c in anchor]
    if not found:
        return None
    if cfg.get('side') == 'right':
        right = max(x for x, _ in found)
        found = [(x, y) for x, y in found if x > right - cfg.get('span', 4)]
    top = min(y for _, y in found)
    row = [x for x, y in found if y <= top + 1]
    cx = round(sum(row) / len(row))
    if cfg.get('climb'):
        while (cx, top - 1) in px:
            top -= 1
    return cx, top


def elite_frame(im, index, cfg, w, h, keep_ornament=True):
    base = {(x, y): hexof(im.getpixel((x, y))) for y in range(h) for x in range(w) if im.getpixel((x, y))[3]}
    swap = cfg.get('swap', {})
    px = {p: swap.get(c, c) for p, c in base.items()}
    # the glint: a two-pixel diagonal band moving down-right each frame, one gold step brighter
    for (x, y), c in base.items():
        if c in cfg.get('sheen', []) and (x + y - 2 * index) % SHEEN_PERIOD in (0, 1):
            now = px[(x, y)]
            if now in GOLD[:-1]:
                px[(x, y)] = GOLD[GOLD.index(now) + 1]
    for colours, lowest in ((cfg.get('hem'), True), (cfg.get('ridge'), False)):
        if not colours:
            continue
        for x in range(w):
            ys = [y for y in range(h) if base.get((x, y)) in colours]
            if ys:
                y = max(ys) if lowest else min(ys)
                # only on the outline: the trim edges the shape, it never cuts through it
                if ((x, y + 1) if lowest else (x, y - 1)) not in base:
                    px[(x, y)] = 'feae34' if lowest else ('fee761' if x % 2 else 'feae34')
    veins = cfg.get('veins')
    if veins:
        for (x, y), c in base.items():
            inner = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if base.get((x + dx, y + dy)) in veins)
            if c in veins and inner == 4 and (x * 3 + y * 5) % VEIN_EVERY == 0:
                px[(x, y)] = 'fee761' if (x + y) % 3 else 'f77622'
    ornament = cfg.get('ornament')
    head = head_top(base, w, h, cfg) if ornament and keep_ornament else None
    if head is not None:
        cx, top = head
        ow = len(ornament[0])
        bottom = top - 1 - cfg.get('gap', 0)
        for r, row in enumerate(reversed(ornament)):
            for c, ch in enumerate(row):
                X, Y = cx - ow // 2 + c, bottom - r
                if ch != '.' and 1 <= X <= w - 2 and 1 <= Y <= h - 2:
                    px[(X, Y)] = INK[ch]
    return px


def build(name, cfg):
    folder = os.path.join(ROOT, name)
    src = os.path.join(folder, name + '.aseprite')
    (w, h), durs, tags = tags_of(src)
    frames = frames_of(src, len(durs), w, h)
    # lying down the head is no longer on top: the ornament goes with the first death frame
    lying = {i for tag, a, b in tags if tag == 'DEATH' for i in range(a + 1, b + 1)}
    elite = [elite_frame(im, i, cfg, w, h, i not in lying) for i, im in enumerate(frames)]
    colours = {}
    for px in elite:
        for c in px.values():
            colours.setdefault(c, None)
    key = {c: KEYS[i] for i, c in enumerate(colours)}
    out_tags = []
    for tag, a, b in tags:
        fs = []
        for i in range(a, b + 1):
            f = Frame(w, h)
            f.px = {p: key[c] for p, c in elite[i].items()}
            fs.append(f)
        out_tags.append((tag, durs[a], fs))
    spec = os.path.join(folder, name + '_elite.txt')
    write_spec(spec, '''
# Source of %s_elite.aseprite: the elite %s, drawn by tools/sprite/parts/elites.py over %s.aseprite
# (%s). Same canvas, frames and tags; %s_elite.png keeps %s.png's cell layout.''' % (
        name, name.replace('_', ' '), name, describe(cfg), name, name), {k: c for c, k in key.items()}, (w, h), out_tags)
    aseprite = os.path.join(folder, name + '_elite.aseprite')
    subprocess.run([sys.executable, SPRITE, 'build', spec, aseprite], check=True, capture_output=True)
    mirror_layout(os.path.join(folder, name + '.png'), os.path.join(folder, name + '_elite.png'), frames, elite, w, h)
    preview = os.path.join(folder, name + '_elite.preview.png')
    if os.path.exists(preview):
        os.remove(preview)
    return aseprite


def describe(cfg):
    parts = []
    if cfg.get('sheen') and cfg.get('swap') == STEEL_TO_GOLD:
        parts.append('golden armour with a travelling glint')
    elif cfg.get('swap'):
        parts.append('gold markings')
    names = {id(CROWN): 'a crown', id(CROWN_SMALL): 'a small crown', id(CIRCLET): 'a circlet', id(HALO): 'a halo', id(CROWN_PLAIN): 'a small crown',
             id(PLUME): 'a plume', id(STAR): 'a gold star', id(HORNS): 'bone horns'}
    if cfg.get('ornament'):
        parts.append(names[id(cfg['ornament'])])
    if cfg.get('hem'):
        parts.append('a gold hem')
    if cfg.get('ridge'):
        parts.append('a gold ridge along the back')
    if cfg.get('veins'):
        parts.append('glowing lava veins')
    return ', '.join(parts)


def clean(im):
    """The frame's pixels with every transparent one zeroed, so two exports of one frame compare equal."""
    return bytes(b for p in im.get_flattened_data() for b in (p if p[3] else (0, 0, 0, 0)))


def mirror_layout(base_png, elite_png, frames, elite, w, h):
    """Rewrites the elite sheet so each cell holds the elite version of the frame in the base sheet's cell."""
    sheet = Image.open(base_png).convert('RGBA')
    out = Image.new('RGBA', sheet.size, (0, 0, 0, 0))
    raw = [clean(im) for im in frames]
    for cy in range(sheet.height // h):
        for cx in range(sheet.width // w):
            cell = sheet.crop((cx * w, cy * h, cx * w + w, cy * h + h))
            if not cell.getbbox():
                continue
            data = clean(cell)
            if data not in raw:
                raise SystemExit('%s: cell %d,%d is no frame of the .aseprite (export the sheet again)' % (base_png, cx, cy))
            for (x, y), c in elite[raw.index(data)].items():
                out.putpixel((cx * w + x, cy * h + y), tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,))
    out.save(elite_png)


for name in (sys.argv[3:] or ELITES):
    print(build(name, ELITES[name]))
