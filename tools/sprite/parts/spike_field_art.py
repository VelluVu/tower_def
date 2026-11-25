"""The Spike Field (2026-11-25): a dark wooden frame set in the road with nine spike holes, 20x20 like the Leopard Trap.
IDLE: the tips just show, a glint runs over them; ATTACK: the spikes shoot up and sink back. One sheet per element
(iron, red-hot, ice, venom-dripping). T2 (<prefix>spike_field_t2) bands the frame in the spikes' metal with rivets at the
corners; T3 adds gold corner caps and the spikes shoot one pixel higher. Writes <out>/<prefix>spike_field.txt; then
python tools/sprite/sprite.py build <txt> <aseprite> for each, and the icons (see the README).

usage: spike_field_art.py <parts dir> <art dir>   (writes into <art dir>/units/building/spike_field/)"""
import os
import sys

sys.path.insert(0, sys.argv[1])
from compose import Frame, write_spec  # noqa: E402

OUT = os.path.join(sys.argv[2], "units", "building", "spike_field")
WOOD = {"w": "3e2731", "W": "5d3a2a", "v": "733e39", "V": "9a5a3a", "h": "181425"}
GOLD = {"g": "feae34", "G": "f77622"}
SPIKES = {
    "": ("iron", {"a": "3a4466", "b": "8b9bb4", "c": "c0cbdc", "d": "ffffff"}),
    "fire_": ("red-hot", {"a": "5d1d2c", "b": "e43b44", "c": "f77622", "d": "fee761"}),
    "frost_": ("ice", {"a": "124e89", "b": "0099db", "c": "2ce8f5", "d": "ffffff"}),
    "poison_": ("venom-dripping", {"a": "265c42", "b": "3e8948", "c": "63c74d", "d": "b6d53c"}),
}
HOLES = [(x, y) for y in (8, 11, 14) for x in (5, 9, 13)]


def field(heights, glint=-1, drip=False, tier=1):
    f = Frame(20, 20)
    # the frame: a sunken plank square, lit top-left
    for y in range(5, 18):
        for x in range(2, 18):
            edge = x in (2, 17) or y in (5, 17)
            f.px[(x, y)] = "w" if edge else ("W" if (x + y) % 5 else "v")
    for x in range(3, 17):
        f.px[(x, 6)] = "V"
    # T2: a metal band round the frame, rivets at the corners and the middles
    if tier >= 2:
        for y in range(5, 18):
            for x in range(2, 18):
                if x in (2, 17) or y in (5, 17):
                    f.px[(x, y)] = "a"
        for x, y in ((2, 5), (17, 5), (2, 17), (17, 17), (9, 5), (10, 17), (2, 11), (17, 11)):
            f.px[(x, y)] = "c"
    # T3: gold caps on the four corners
    if tier >= 3:
        for cx, cy, dx, dy in ((2, 5, 1, 1), (17, 5, -1, 1), (2, 17, 1, -1), (17, 17, -1, -1)):
            f.px[(cx, cy)] = "g"
            f.px[(cx + dx, cy)] = "G"
            f.px[(cx, cy + dy)] = "G"
    for i, (hx, hy) in enumerate(HOLES):
        f.px[(hx, hy)] = "h"
        f.px[(hx + 1, hy)] = "h"
        height = heights[i] if isinstance(heights, list) else heights
        # a spike: two pixels wide at its foot, a single tip
        for dy in range(height):
            y = hy - 1 - dy
            tip = dy == height - 1
            if tip:
                f.px[(hx, y)] = "d" if i == glint else "c"
            else:
                f.px[(hx, y)] = "c" if dy % 2 else "b"
                f.px[(hx + 1, y)] = "a"
        if height == 0:
            f.px[(hx, hy)] = "a" if i != glint else "c"
        if drip and height > 1:
            f.px[(hx + 1, hy + 1)] = "b"
    return f


def write(prefix, tier=1):
    look, colours = SPIKES[prefix]
    palette = dict(WOOD)
    palette.update(colours)
    if tier >= 3:
        palette.update(GOLD)
    drip = prefix == "poison_"
    up = [0, 2, 5, 5, 3, 1] if tier >= 3 else [0, 2, 4, 4, 2, 1]
    tags = [
        ("IDLE", 160, [field(1, glint=g, tier=tier) for g in (-1, 0, 4, 8)]),
        ("ATTACK", 70, [field(h, drip=drip, tier=tier) for h in up]),
    ]
    name = prefix + "spike_field" + ("" if tier == 1 else "_t%d" % tier)
    os.makedirs(OUT, exist_ok=True)
    write_spec(os.path.join(OUT, name + ".txt"), """
# Source of %s.aseprite and .png (python tools/sprite/sprite.py build <this> <aseprite>).
# Spike Field%s, %s spikes: a dark wooden frame 3e2731..9a5a3a set in the road with nine spike holes; IDLE a glint runs
# over the tips, ATTACK the spikes shoot up and sink back. Drawn by tools/sprite/parts/spike_field_art.py.""" % (
        name, "" if tier == 1 else " T%d" % tier, look), palette, (20, 20), tags)


if __name__ == "__main__":
    for p in SPIKES:
        for t in (1, 2, 3):
            write(p, t)
