"""Keeps a sprite spec's frames off the canvas edge: optional shift of every frame, then clears edge pixels.
usage: margin.py <spec.txt> [dx] [dy]"""
import sys

path = sys.argv[1]
dx = int(sys.argv[2]) if len(sys.argv) > 2 else 0
dy = int(sys.argv[3]) if len(sys.argv) > 3 else 0
lines = open(path, encoding='utf-8').read().split('\n')
w, h = [int(v) for v in next(l for l in lines if l.startswith('size')).split('=')[1].strip().split('x')]
body_start = lines.index('---') + 1
out = lines[:body_start]
frame = []
cleared = 0


def flush():
    global frame, cleared
    if not frame:
        return
    grid = [list(r.ljust(w, '.')) for r in frame]
    moved = [['.'] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            X, Y = x + dx, y + dy
            if grid[y][x] != '.' and 0 <= X < w and 0 <= Y < h:
                moved[Y][X] = grid[y][x]
    for y in range(h):
        for x in range(w):
            if (x in (0, w - 1) or y in (0, h - 1)) and moved[y][x] != '.':
                moved[y][x] = '.'
                cleared += 1
    out.extend(''.join(r) for r in moved)
    frame = []


for line in lines[body_start:]:
    if line.startswith('@') or line.startswith('#') or line.strip() == '':
        flush()
        out.append(line)
    else:
        frame.append(line)
        if len(frame) == h:
            flush()
flush()
open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print(path, 'cleared', cleared, 'edge pixels')
