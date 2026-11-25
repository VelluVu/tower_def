"""The Elder Drake's art (2026-11-25): the grown drakeling (the Bolter's T3 sheet of each element: the same frames and
tags, IDLE, START_ATTACK, STOP_ATTACK; its crown) as an old drake with a gold scale on its chest. The START_ATTACK frames are copied once more as BREATH (the once-a-wave breath; ElderDrake plays it).
Drawn over the sheets like tools/sprite/parts/scorched_enemies.py draws enemies over their parents.

usage: elder_drake_art.py <parts dir> assets/art/units/building/puffe
(writes puffe_elder/<colour>_puffe_elder.txt, .aseprite and .png)"""
import os
import sys

sys.path.insert(0, sys.argv[1])
import scorched_enemies as se  # noqa: E402  (its ROOT is the art folder given here)

GOLD = ['733e39', 'f77622', 'feae34', 'fee761']
SHEETS = {'': 'puffe_bolter_t3', 'red_': 'puffe_bolter_red_t3', 'blue_': 'puffe_bolter_blue_t3', 'green_': 'puffe_bolter_green_t3'}


def chest_scale(base, px, i):
    if not base:
        return
    ys = [y for _, y in base]
    y0, y1 = min(ys), max(ys)
    row = y0 + (y1 - y0) * 3 // 5
    xs = sorted(x for x, y in base if y == row and 1 <= x <= 16)
    if len(xs) < 5:
        return
    mid = xs[len(xs) // 2]
    for x, y, c in ((mid, row, GOLD[3]), (mid - 1, row, GOLD[2]), (mid + 1, row, GOLD[2]), (mid, row + 1, GOLD[1])):
        if (x, y) in base:
            px[(x, y)] = c


def clear_edge(size):
    w, h = size

    def apply(base, px, i):
        for p in [p for p in px if p[0] in (0, w - 1) or p[1] in (0, h - 1)]:
            del px[p]
    return apply


def main():
    src_dir = 'puffe_bolter'
    for prefix, sheet in SHEETS.items():
        name = prefix + 'puffe_elder'
        path = os.path.join(se.ROOT, src_dir, sheet + '.aseprite')
        w, h, durs, tags = se.info(path)
        frames = se.frames_of(path, len(durs), w, h)
        # the T3 sheet's crown already says elder: no horns over it (they floated above the crown's tips)
        over = [chest_scale, clear_edge((w, h))]
        out = []
        for tag, a, b in tags + [('BREATH', a2, b2) for t2, a2, b2 in tags if t2 == 'START_ATTACK']:
            fs = []
            for i in range(a, b + 1):
                px = dict(frames[i])
                for o in over:
                    o(frames[i], px, i)
                fs.append(px)
            out.append((tag, durs[a] if tag != 'BREATH' else 140, fs))
        se.save(name, '''
# Source of %s.aseprite and .png: the Elder Drake (the Bolter's T3 drakeling of this element as an old drake: its
# crown, a gold chest scale; BREATH repeats START_ATTACK slower), drawn by tools/sprite/parts/elder_drake_art.py
# over %s.aseprite.''' % (name, sheet), (w, h), out)
        src = os.path.join(se.ROOT, name)
        dst = os.path.join(se.ROOT, 'puffe_elder')
        if src == dst:
            continue
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(src):
            os.replace(os.path.join(src, f), os.path.join(dst, f))
        os.rmdir(src)


if __name__ == '__main__':
    main()
