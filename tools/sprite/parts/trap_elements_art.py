"""Fire, Frost and Poison versions of the Leopard Trap, repainted from lebu_trap.aseprite's pixel roles.

Each source colour has a role (spots, fur shade, fur, light fur, belly, claw slash, slash dust, eyes, nose) and each
element maps the roles onto its own Endesga 32 ramp: Fire an ember leopard (orange fur, dark red spots, flame
slashes), Frost a snow leopard (pale grey-blue fur, slate spots, ice slashes), Poison a bog leopard (purple
fur, an acid belly, acid slashes).

Writes <element>_lebu_trap.txt, .aseprite and .png next to lebu_trap.aseprite. Same canvas, frames and tags; the
.png keeps lebu_trap.png's cell layout.

usage: trap_elements_art.py <parts dir> <leopard_trap art dir> [element...]"""
import os
import re
import subprocess
import sys
sys.path.insert(0, sys.argv[1])
from compose import Frame, write_spec
from PIL import Image

ROOT = sys.argv[2]
SPRITE = os.path.join(sys.argv[1], '..', 'sprite.py')
KEYS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
SOURCE = 'lebu_trap'

# lebu_trap's colours by role
ROLES = {
    'spot': ['423021'],
    'spot_soft': ['733e39', '835f42'],
    'shade': ['a37752'],
    'fur_dark': ['c48f62', 'd99e6d', 'dca06e'],
    'fur': ['e4a672', 'e7b286', 'e8b796'],
    'fur_light': ['ebbf9a', 'efccae'],
    'belly': ['f3d8c2', 'f7e5d6'],
    'dust': ['fbf2ea'],
    'claw': ['c0cbdc'],
    'eye': ['ffffff'],
    'nose': ['ff9398'],
}

ELEMENTS = {
    'fire': dict(spot='3e2731', spot_soft='733e39', shade='a22633', fur_dark='be4a2f', fur='f77622',
                 fur_light='feae34', belly='fee761', dust='f77622', claw='fee761', eye='fee761', nose='e43b44'),
    'frost': dict(spot='262b44', spot_soft='3a4466', shade='5a6988', fur_dark='8b9bb4', fur='c0cbdc',
                  fur_light='ffffff', belly='ffffff', dust='0099db', claw='2ce8f5', eye='2ce8f5', nose='ff9398'),
    'poison': dict(spot='2a1a33', spot_soft='45254f', shade='68386c', fur_dark='8e4f7a', fur='b55088',
                   fur_light='f6757a', belly='b6d53c', dust='63c74d', claw='b6d53c', eye='fee761', nose='2a1a33'),
}


def hexof(p):
    return '%02x%02x%02x' % p[:3]


def tags_of(aseprite):
    out = subprocess.run([sys.executable, SPRITE, 'info', aseprite], capture_output=True, text=True).stdout
    size = re.search(r'(\d+)x(\d+)', out)
    durs = [int(v) for v in re.search(r'durations\(ms\): ([\d,]+)', out).group(1).split(',')]
    tags = [(m.group(1), int(m.group(2)) - 1, int(m.group(3)) - 1) for m in re.finditer(r'tag (\S+) (\d+)-(\d+)', out)]
    return (int(size.group(1)), int(size.group(2))), durs, tags


def frames_of(aseprite, n, w, h):
    """Every frame in order (layers merged), from Aseprite's own row export."""
    tmp = aseprite + '.frames.png'
    subprocess.run([sys.executable, SPRITE, 'view', aseprite, tmp, '--scale', '1'], capture_output=True)
    im = Image.open(tmp).convert('RGBA')
    im.load()
    os.remove(tmp)
    return [im.crop((i * w, 0, i * w + w, h)) for i in range(n)]


def repaint(im, swap, w, h):
    px = {}
    for y in range(h):
        for x in range(w):
            p = im.getpixel((x, y))
            if p[3]:
                c = hexof(p)
                if c not in swap:
                    raise SystemExit('%s: colour %s at %d,%d has no role' % (SOURCE, c, x, y))
                px[(x, y)] = swap[c]
    return px


def clean(im):
    return bytes(b for p in im.get_flattened_data() for b in (p if p[3] else (0, 0, 0, 0)))


def mirror_layout(base_png, out_png, frames, painted, w, h):
    """Writes the sheet so each cell holds the repainted version of the frame in the base sheet's cell."""
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
            for (x, y), c in painted[raw.index(data)].items():
                out.putpixel((cx * w + x, cy * h + y), tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,))
    out.save(out_png)


def build(element):
    target = ELEMENTS[element]
    swap = {c: target[role] for role, cs in ROLES.items() for c in cs}
    src = os.path.join(ROOT, SOURCE + '.aseprite')
    (w, h), durs, tags = tags_of(src)
    frames = frames_of(src, len(durs), w, h)
    painted = [repaint(im, swap, w, h) for im in frames]
    colours = list(dict.fromkeys(target.values()))
    key = {c: KEYS[i] for i, c in enumerate(colours)}
    out_tags = []
    for tag, a, b in tags:
        fs = []
        for i in range(a, b + 1):
            f = Frame(w, h)
            f.px = {p: key[c] for p, c in painted[i].items()}
            fs.append(f)
        out_tags.append((tag, durs[a], fs))
    name = '%s_%s' % (element, SOURCE)
    spec = os.path.join(ROOT, name + '.txt')
    write_spec(spec, '''
# Source of %s.aseprite: the %s Leopard Trap, repainted by tools/sprite/parts/trap_elements_art.py from
# %s.aseprite's pixel roles. Same canvas, frames and tags; %s.png keeps %s.png's cell layout.''' % (
        name, element.capitalize(), SOURCE, name, SOURCE), {k: c for c, k in key.items()}, (w, h), out_tags)
    aseprite = os.path.join(ROOT, name + '.aseprite')
    subprocess.run([sys.executable, SPRITE, 'build', spec, aseprite, '--ref', src], check=True, capture_output=True)
    mirror_layout(os.path.join(ROOT, SOURCE + '.png'), os.path.join(ROOT, name + '.png'), frames, painted, w, h)
    return aseprite


def build_icon(element):
    """<element>_lebu_trap_icon.png (and .aseprite): the paw print icon in the element's colours."""
    target = ELEMENTS[element]
    swap = {c: target[role] for role, cs in ICON_ROLES.items() for c in cs}
    src = Image.open(os.path.join(ROOT, SOURCE + '_icon.png')).convert('RGBA')
    w, h = src.size
    px = repaint(src, swap, w, h)
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for p, c in px.items():
        out.putpixel(p, tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,))
    name = '%s_%s_icon' % (element, SOURCE)
    colours = list(dict.fromkeys(px.values()))
    key = {c: KEYS[i] for i, c in enumerate(colours)}
    f = Frame(w, h)
    f.px = {p: key[c] for p, c in px.items()}
    spec = os.path.join(ROOT, name + '.txt')
    write_spec(spec, '''
# Source of %s.aseprite: the %s Leopard Trap icon, repainted by tools/sprite/parts/trap_elements_art.py from
# %s_icon.png.''' % (name, element.capitalize(), SOURCE), {k: c for c, k in key.items()}, (w, h), [('IDLE', 100, [f])])
    subprocess.run([sys.executable, SPRITE, 'build', spec, os.path.join(ROOT, name + '.aseprite')], check=True,
                   capture_output=True)
    out.save(os.path.join(ROOT, name + '.png'))
    preview = os.path.join(ROOT, name + '.preview.png')
    if os.path.exists(preview):
        os.remove(preview)
    return name + '.png'


# lebu_trap_icon's colours by role (a spotted paw print)
ICON_ROLES = {'spot': ['3e2731'], 'shade': ['b86f50'], 'fur': ['e4a672']}

for element in (sys.argv[3:] or ELEMENTS):
    print(build(element))
    print(build_icon(element))
