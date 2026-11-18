"""T2 and T3 sprites for the element drakelings, drawn over their T1 sheets frame by frame.

T2: an element crest on the head (it follows the head's bob) and a few element sparks orbiting the body.
T3: a bigger crown, more sparks and an element ring glowing at the feet.
The canvas, frame count, durations and tags stay the T1 sprite's, so the scenes' SpriteFrames regions fit.
usage: tower_tiers.py <parts dir> <puffe art dir>   (writes <t1 name>_t2.txt and _t3.txt next to each T1 sheet)"""
import math
import os
import re
import subprocess
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, write_spec
from PIL import Image

# the T1 sheets' own attack effects reach the canvas edge; the pixels added here stay 1 px inside it
Frame.check_margin = lambda self, name: None

ROOT = sys.argv[2]
SPRITE = os.path.join(sys.argv[1], '..', 'sprite.py')
SHEETS = {
    'physical': ['puffe', 'puffe_nova/puffe_nova', 'puffe_beamer/puffe_beamer'],
    'fire': ['puffe_bolter/puffe_bolter_red', 'puffe_nova/red_puffe_nova', 'puffe_beamer/red_puffe_beamer'],
    'frost': ['puffe_bolter/puffe_bolter_blue', 'puffe_nova/blue_puffe_nova', 'puffe_beamer/blue_puffe_beamer'],
    'poison': ['puffe_bolter/puffe_bolter_green', 'puffe_nova/green_puffe_nova', 'puffe_beamer/green_puffe_beamer'],
}
# per element: crest T2, crown T3 (rows bottom-up are drawn upwards from the head top), spark colours, ring colours
ELEMENT = {
    'physical': {
        'crest': ['A.A', 'BAB', 'CgC'],
        'crown': ['g.g.g', 'gGgGg', 'GgggG', 'AGGGA', '.BBB.'],
        'spark': ['ffffff', 'c0cbdc'], 'ring': ['feae34', 'c0cbdc', 'ffffff'],
        'pal': {'A': 'ffffff', 'B': 'c0cbdc', 'C': '8b9bb4', 'g': 'feae34', 'G': 'f77622'},
    },
    'fire': {
        'crest': ['.y.', 'yoy', 'ror'],
        'crown': ['..y..', '.yoy.', 'y.o.y', 'yooy.', 'rorro'],
        'spark': ['fee761', 'f77622'], 'ring': ['f77622', 'e43b44', 'feae34'],
        'pal': {'o': 'f77622', 'y': 'fee761', 'r': 'e43b44'},
    },
    'frost': {
        'crest': ['w.w', 'cwc', 'bcb'],
        'crown': ['w...w', 'w.w.w', 'cwcwc', 'bcccb', '.bbb.'],
        'spark': ['ffffff', '2ce8f5'], 'ring': ['2ce8f5', '0099db', 'ffffff'],
        'pal': {'w': 'ffffff', 'c': '2ce8f5', 'b': '0099db'},
    },
    'poison': {
        'crest': ['u.u', 'gUg', 'GgG'],
        'crown': ['U...U', 'u.U.u', 'gugug', 'GgggG', '.GGG.'],
        'spark': ['63c74d', 'b55088'], 'ring': ['63c74d', '3e8948', 'b55088'],
        'pal': {'g': '63c74d', 'G': '3e8948', 'u': '68386c', 'U': 'b55088'},
    },
}
KEYS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!$%&*+-/:;<>?@^_~'


def tags_of(aseprite):
    out = subprocess.run([sys.executable, SPRITE, 'info', aseprite], capture_output=True, text=True).stdout
    durs = [int(v) for v in re.search(r'durations\(ms\): ([\d,]+)', out).group(1).split(',')]
    tags = [(m.group(1), int(m.group(2)) - 1, int(m.group(3)) - 1) for m in re.finditer(r'tag (\S+) (\d+)-(\d+)', out)]
    return durs, tags


def frames_of(aseprite, n, w, h):
    """Every frame in order, from Aseprite's own row export (the packed .png skips repeated frames)."""
    tmp = aseprite + '.frames.png'
    subprocess.run([sys.executable, SPRITE, 'view', aseprite, tmp, '--scale', '1'], capture_output=True)
    im = Image.open(tmp).convert('RGBA')
    im.load()
    os.remove(tmp)
    return [im.crop((i * w, 0, i * w + w, h)) for i in range(n)]


def head_top(im):
    for y in range(im.height):
        xs = [x for x in range(4, 14) if im.getpixel((x, y))[3]]
        if len(xs) >= 3:
            return y, round(sum(xs) / len(xs))
    return 8, 9


def body_box(im):
    pts = [(x, y) for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[3]]
    ys = sorted(y for _, y in pts)
    return min(ys), max(ys)


def build(base, element, tier):
    w, h = 18, 34
    src = os.path.join(ROOT, base + '.aseprite')
    durs, tags = tags_of(src)
    frames = frames_of(src, len(durs), w, h)
    el = ELEMENT[element]
    # palette: every colour of the T1 sheet plus the element's
    colours = {}
    for im in frames:
        for p in im.get_flattened_data():
            if p[3]:
                colours.setdefault('%02x%02x%02x' % p[:3], None)
    for c in list(el['pal'].values()) + el['spark'] + el['ring']:
        colours.setdefault(c, None)
    key = {c: KEYS[i] for i, c in enumerate(colours)}
    el_key = {k: key[v] for k, v in el['pal'].items()}
    head0, _ = head_top(frames[0])
    out_tags = []
    for name, a, b in tags:
        fs = []
        for i in range(a, b + 1):
            im = frames[i]
            f = Frame(w, h)
            # T3 ring behind the drakeling at its feet
            if tier == 3:
                _, bottom = body_box(frames[0])
                cy = bottom - 1
                for k in range(28):
                    ang = k / 28 * 2 * math.pi
                    x, y = round(9 + 7 * math.cos(ang)), round(cy + 2 * math.sin(ang))
                    if 1 <= x <= 16 and 1 <= y <= 32 and (k + i) % 4 != 0:
                        f.px[(x, y)] = key[el['ring'][(k // 3 + i) % 2]]
            for y in range(h):
                for x in range(w):
                    p = im.getpixel((x, y))
                    if p[3]:
                        f.px[(x, y)] = key['%02x%02x%02x' % p[:3]]
            top, cx = head_top(im)
            # keep the crest on the head: follow the head's bob, not the attack effects above it
            if abs(top - head0) > 2:
                top = head0
            crest = el['crown'] if tier == 3 else el['crest']
            cw = len(crest[0])
            for r, row in enumerate(reversed(crest)):
                for c, ch in enumerate(row):
                    if ch != '.':
                        X, Y = cx - cw // 2 + c, top - 1 - r
                        if 1 <= X <= 16 and 1 <= Y:
                            f.px[(X, Y)] = el_key[ch]
            # sparks orbit the body; a front spark covers the body, a back one only fills empty pixels
            n = 2 if tier == 2 else 4
            mid = (top + body_box(frames[0])[1]) // 2 + 1
            for s in range(n):
                ang = (i / max(1, b - a + 1) + s / n) * 2 * math.pi + s
                x, y = round(9 + 7 * math.cos(ang)), round(mid + 4 * math.sin(ang * 1.0) - 2)
                front = math.sin(ang) > 0
                for dx, col in ((0, el['spark'][0]), (1 if math.cos(ang) < 0 else -1, el['spark'][1])):
                    X = x + dx
                    if 1 <= X <= 16 and 1 <= y <= 32 and (front or (X, y) not in f.px):
                        f.px[(X, y)] = key[col]
            fs.append(f)
        out_tags.append((name, durs[a], fs))
    # the mint Bolter's T1 is puffe/puffe.aseprite; its tiers go with the other Bolters
    name = 'puffe_bolter/puffe_bolter' if base == 'puffe' else base
    out = os.path.join(ROOT, '%s_t%d.txt' % (name, tier))
    write_spec(out, '''
# Source of %s_t%d.aseprite and .png: the %s %s drakeling at T%d, drawn by tools/sprite/parts/tower_tiers.py over
# the T1 sheet %s.png (%s). Same canvas, frames and tags as T1.''' % (
        os.path.basename(name), tier, element, base.split('/')[0].replace('puffe_', ''), tier, os.path.basename(base),
        'element crest and orbiting sparks' if tier == 2 else 'element crown, more sparks and a ring at the feet'),
        {k: c for c, k in key.items()}, (w, h), out_tags)
    return out


for element, bases in SHEETS.items():
    for base in bases:
        for tier in (2, 3):
            print(build(base, element, tier))
