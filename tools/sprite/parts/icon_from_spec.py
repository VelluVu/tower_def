"""Writes a 16x16 icon grid from a sprite spec's first frame: the body cropped to fit (the front, right side,
when it is wider than 16), centred, or a fixed window. usage: icon_from_spec.py <sprite spec> <icon grid out> <png path for the header> [x0 y0]"""
import sys

spec, out, png = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(spec, encoding='utf-8').read().split('\n')
w, h = [int(v) for v in next(l for l in lines if l.startswith('size')).split('=')[1].strip().split('x')]
sep = lines.index('---')
palette = [l for l in lines[:sep] if '=' in l and not l.startswith('size') and not l.startswith('#')]
body = lines[sep + 1:]
first_tag = next(i for i, l in enumerate(body) if l.startswith('@'))
frame = body[first_tag + 1:first_tag + 1 + h]
cells = {(x, y): c for y, r in enumerate(frame) for x, c in enumerate(r) if c != '.'}
xs = [x for x, _ in cells]
ys = [y for _, y in cells]
x1 = max(xs)
x0 = max(min(xs), x1 - 15)
y0, y1 = min(ys), max(ys)
if y1 - y0 > 15:
    y0 = y1 - 15
if len(sys.argv) > 5:
    # a fixed 16x16 window (top-left x y) for sprites bigger than an icon, e.g. a boss's head and chest
    x0, y0 = int(sys.argv[4]), int(sys.argv[5])
    x1, y1 = x0 + 15, y0 + 15
ox = max(0, (16 - (min(x1, max(xs)) - max(x0, min(xs)) + 1)) // 2) if len(sys.argv) <= 5 else 0
oy = (16 - (y1 - y0 + 1)) // 2 if len(sys.argv) <= 5 else 0
grid = [['.'] * 16 for _ in range(16)]
for (x, y), c in cells.items():
    if x0 <= x <= x1 and y0 <= y <= y1:
        grid[y - y0 + oy][x - x0 + ox] = c
used = {c for r in grid for c in r}
pal = [l for l in palette if l.split('=')[0].strip() in used]
text = ['# Source of %s (python tools/gd.py icon <this> <out.png>); cropped from the sprite\'s first IDLE frame' % png]
text += pal + ['---'] + [''.join(r) for r in grid]
open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(text) + '\n')
print('\n'.join(''.join(r) for r in grid))
