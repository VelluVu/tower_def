"""The Shredder's art (2026-11-25): the Nova drakeling of each element (its own frames and tags: IDLE, START_ATTACK,
STOP_ATTACK) in iron: steel horns and a spiked iron collar, the look of a drakeling that tears armour apart. Drawn over
the Nova's sheets like tools/sprite/parts/scorched_enemies.py draws enemies over their parents.

usage: shredder_art.py <parts dir> assets/art/units/building/puffe
(writes puffe_shredder/<colour>_puffe_shredder.txt, .aseprite and .png)"""
import os
import sys

sys.path.insert(0, sys.argv[1])
import scorched_enemies as se  # noqa: E402  (its ROOT is the art folder given here)

STEEL = ['3a4466', '5a6988', '8b9bb4', 'c0cbdc']
NOVA = {'': 'puffe_nova', 'red_': 'red_puffe_nova', 'blue_': 'blue_puffe_nova', 'green_': 'green_puffe_nova'}


def collar(base, px, i):
    """an iron collar with spikes across the neck: the row a little past halfway down the body"""
    if not base:
        return
    ys = [y for _, y in base]
    y0, y1 = min(ys), max(ys)
    row = y0 + (y1 - y0) * 11 // 20
    # the drakeling sheets are 18 wide: keep 1 px clear for the outline shader
    xs = sorted(x for x, y in base if y == row and 1 <= x <= 16)
    for x in xs:
        px[(x, row)] = STEEL[1] if x % 2 else STEEL[3]
    for x in xs[1:-1:3]:
        if (x, row - 1) not in base and row - 1 >= 1:
            px[(x, row - 1)] = STEEL[2]


def horns(base, px, i):
    if not base:
        return
    y0 = min(y for _, y in base)
    xs = sorted(x for x, y in base if y == y0)
    for x in (xs[0], xs[-1]):
        for dy in (1, 2):
            if y0 - dy >= 1:
                px[(x, y0 - dy)] = STEEL[3] if dy == 2 else STEEL[2]


def clear_edge(size):
    """the Nova's own art touches the canvas edge in a frame; the outline shader needs 1 px clear all round"""
    w, h = size

    def apply(base, px, i):
        for p in [p for p in px if p[0] in (0, w - 1) or p[1] in (0, h - 1)]:
            del px[p]
    return apply


def main():
    for prefix, nova in NOVA.items():
        name = prefix + 'puffe_shredder'
        w, h, _, _ = se.info(os.path.join(se.ROOT, 'puffe_nova', nova + '.aseprite'))
        se.derive(name, ('puffe_nova', nova), {}, [collar, horns, clear_edge((w, h))], '''
# Source of %s.aseprite and .png: the Shredder drakeling (the Nova's of this element in iron: steel horns, a spiked
# collar), drawn by tools/sprite/parts/shredder_art.py over %s.aseprite (same frames and tags).''' % (name, nova))
        # derive writes <root>/<name>/<name>.*: move it into the Shredder's folder
        src = os.path.join(se.ROOT, name)
        dst = os.path.join(se.ROOT, 'puffe_shredder')
        if src == dst:
            continue
        os.makedirs(dst, exist_ok=True)
        for f in os.listdir(src):
            os.replace(os.path.join(src, f), os.path.join(dst, f))
        os.rmdir(src)


if __name__ == '__main__':
    main()
