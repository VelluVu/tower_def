"""Upgrade visuals: T2/T3 bolts and beams, the upgrade pips and the element spark particles.

Bolts: every frame of the T1 bolt with an echo trail behind it (T2 one echo, T3 two and a thicker body).
Beams: the T1 beam tile with dithered glow rows above and below and a brighter core (T3 wider still).
Pips: the gold upgrade pip and one tier pip per element (element core in a white ring), to replace the
code-drawn dots of UpgradePips. Sparks: a 4-frame twinkle per element for the T2+ particles.
usage: upgrade_fx.py <parts dir> <art dir>   (art dir = assets/art)"""
import os
import subprocess
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, part, write_spec
from PIL import Image

ART = sys.argv[2]
SPRITE = os.path.join(sys.argv[1], '..', 'sprite.py')
KEYS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
# projectiles fly through the canvas edge on purpose; there is no unit outline on them
Frame.check_margin = lambda self, name: None


def lum(c):
    r, g, b = int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)
    return 0.3 * r + 0.59 * g + 0.11 * b


def hexes(im):
    return {'%02x%02x%02x' % p[:3] for p in im.get_flattened_data() if p[3]}


def grey(c):
    r, g, b = int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16)
    return max(r, g, b) - min(r, g, b) < 60 and b >= r


def dimmer(colours):
    """Each colour's next darker one among the sheet's coloured (not smoke grey) colours; greys map to None."""
    order = sorted((c for c in colours if not grey(c)), key=lum)
    out = {c: order[max(0, i - 1)] for i, c in enumerate(order)}
    out.update({c: None for c in colours if grey(c)})
    return out


def run_info(path):
    out = subprocess.run([sys.executable, SPRITE, 'info', path], capture_output=True, text=True).stdout
    import re
    durs = [int(v) for v in re.search(r'durations\(ms\): ([\d,]+)', out).group(1).split(',')]
    tags = [(m.group(1), int(m.group(2)) - 1, int(m.group(3)) - 1) for m in re.finditer(r'tag (\S+) (\d+)-(\d+)', out)]
    return durs, tags


def row_frames(path, n, w, h):
    tmp = path + '.frames.png'
    subprocess.run([sys.executable, SPRITE, 'view', path, tmp, '--scale', '1'], capture_output=True)
    im = Image.open(tmp).convert('RGBA')
    im.load()
    os.remove(tmp)
    return [im.crop((i * w, 0, i * w + w, h)) for i in range(n)]


# ---------------- bolts ----------------
def bolt(element, tier):
    src = '%s/projectile/%s_bolt.aseprite' % (ART, element)
    durs, tags = run_info(src)
    frames = row_frames(src, len(durs), 16, 16)
    colours = set().union(*(hexes(f) for f in frames))
    dim = dimmer(colours)
    key = {c: KEYS[i] for i, c in enumerate(sorted(colours))}
    walk = next((a, b) for n, a, b in tags if n == 'WALK')
    out_tags = []
    for name, a, b in tags:
        fs = []
        for i in range(a, b + 1):
            im = frames[i]
            f = Frame(16, 16)
            px = {(x, y): '%02x%02x%02x' % im.getpixel((x, y))[:3]
                  for y in range(16) for x in range(16) if im.getpixel((x, y))[3]}
            flying = walk[0] <= i <= min(walk[1], 9)
            if flying:
                echoes = [(3, 1, 0)] if tier == 2 else [(3, 1, 0), (6, 2, 1)]
                for shift, steps, dither in reversed(echoes):
                    for (x, y), c in px.items():
                        X = x - shift
                        if 0 <= X and (not dither or (X + y) % 2 == 0):
                            d = c
                            for _ in range(steps):
                                d = dim[d] if d else None
                            if d:
                                f.px[(X, y)] = key[d]
                if tier == 3:
                    # a thicker body: the brightest pixels spread one row up and down
                    bright = sorted(colours, key=lum)[-2:]
                    for (x, y), c in px.items():
                        if c in bright and dim[c]:
                            for dy in (-1, 1):
                                if (x, y + dy) not in px and 0 <= y + dy < 16:
                                    f.px[(x, y + dy)] = key[dim[c]]
            for (x, y), c in px.items():
                f.px[(x, y)] = key[c]
            fs.append(f)
        out_tags.append((name, durs[a], fs))
    # WALK in the source overlaps DEATH (1-17 on fire_bolt): keep its range as the source has it
    write_spec('%s/projectile/%s_bolt_t%d.txt' % (ART, element, tier), '''
# Source of %s_bolt_t%d.aseprite and .png: the T%d %s bolt, drawn by tools/sprite/parts/upgrade_fx.py over
# %s_bolt.aseprite: %s.''' % (element, tier, tier, element, element,
                            'one echo trail behind it' if tier == 2 else 'two echo trails (the far one dithered) and a thicker body'),
               {k: c for c, k in key.items()}, (16, 16), out_tags)


# ---------------- beams ----------------
def beam(element, tier):
    im = Image.open('%s/projectile/%s_beam.png' % (ART, element)).convert('RGBA')
    px = {(x, y): '%02x%02x%02x' % im.getpixel((x, y))[:3]
          for y in range(16) for x in range(16) if im.getpixel((x, y))[3]}
    colours = sorted(set(px.values()), key=lum)
    key = {c: KEYS[i] for i, c in enumerate(colours)}
    ys = [y for _, y in px]
    y0, y1 = min(ys), max(ys)
    f = Frame(16, 16)
    rings = [(1, 0)] if tier == 2 else [(1, 0), (2, 1)]
    for gap, sparse in rings:
        for x in range(16):
            if (x + gap) % (2 + sparse) == 0:
                for y in (y0 - gap, y1 + gap):
                    if 0 <= y < 16:
                        f.px[(x, y)] = key[colours[0]]
    mid = (y0 + y1) // 2
    for (x, y), c in px.items():
        f.px[(x, y)] = key[c]
        if y in (mid, mid + 1) and tier == 3:
            f.px[(x, y)] = key[colours[-1]]
        elif y == mid and tier == 2 and (x % 2 == 0):
            f.px[(x, y)] = key[colours[-1]]
    write_spec('%s/projectile/%s_beam_t%d.txt' % (ART, element, tier), '''
# Source of %s_beam_t%d.aseprite and .png: the T%d %s beam tile (tiles along the Line2D), drawn by
# tools/sprite/parts/upgrade_fx.py over %s_beam.png: dithered glow rows above and below%s.''' % (
        element, tier, tier, element, element, ', a brighter dotted core' if tier == 2 else ' (two rings), a bright solid core'),
               {k: c for c, k in key.items()}, (16, 16), [('IDLE', 100, [f])])


for element in ('normal', 'fire', 'frost', 'poison'):
    for tier in (2, 3):
        bolt(element, tier)
        beam(element, tier)

# ---------------- pips ----------------
ELEMENTS = {  # light, main, dark
    'PHYSICAL': ('2effb8', '06c374', '107338'),
    'FIRE': ('f6757a', 'e43b44', 'a22633'),
    'FROST': ('2ce8f5', '0099db', '124e89'),
    'POISON': ('63c74d', '3e8948', '265c42'),
}
pal = {'w': 'ffffff', 'k': '181425', 'y': 'fee761', 'g': 'feae34', 'G': 'f77622'}
pips = [('GOLD', 100, [Frame(7, 7).stamp(part('''
.ggg.
gyygg
gyggG
ggggG
.GGG.'''), 1, 1)])]
for i, (name, (l, m, d)) in enumerate(ELEMENTS.items()):
    a, b, c = 'LMD'[0] + str(i), 'LMD'[1] + str(i), 'LMD'[2] + str(i)
    ka, kb, kc = '0123456789AB'[i * 3:i * 3 + 3]
    pal[ka], pal[kb], pal[kc] = l, m, d
    pips.append((name, 100, [Frame(7, 7).stamp(part('''
.www.
wABBw
wABCw
wBCCw
.www.'''.replace('A', ka).replace('B', kb).replace('C', kc)), 1, 1)]))
os.makedirs(ART + '/ui/upgrade_pips', exist_ok=True)
write_spec(ART + '/ui/upgrade_pips/upgrade_pips.txt', '''
# Source of upgrade_pips.aseprite and .png: the pips under an upgraded building (UpgradePips), drawn by
# tools/sprite/parts/upgrade_fx.py. GOLD = one upgrade since the last tier; PHYSICAL/FIRE/FROST/POISON = a tier,
# the element's colours in a white ring so a Fire pip reads on the red Fire tower. 5x5 pips, 1 px margin.''',
           pal, (7, 7), pips)

# ---------------- sparks ----------------
SPARK = ['''
.....
..b..
.bab.
..b..
.....''', '''
..c..
..b..
cbabc
..b..
..c..''', '''
.c.c.
..b..
.bab.
..b..
.c.c.''', '''
.....
.....
..b..
.....
.....''']
SPARKS = {'physical': ('ffffff', 'a2f6db', '2effb8'), 'fire': ('fee761', 'feae34', 'f77622'),
          'frost': ('ffffff', '2ce8f5', '0099db'), 'poison': ('b6d53c', '63c74d', '3e8948')}
for element, (a, b, c) in SPARKS.items():
    write_spec('%s/projectile/%s_spark_particle.txt' % (ART, element), '''
# Source of %s_spark_particle.aseprite and .png: a 4-frame twinkle for the %s element particles at T2 and up
# (an AnimatedTexture or a particle sheet). Drawn by tools/sprite/parts/upgrade_fx.py.''' % (element, element),
               {'a': a, 'b': b, 'c': c}, (7, 7), [('IDLE', 90, [Frame(7, 7).stamp(part(s), 1, 1) for s in SPARK])])
print('ok')
