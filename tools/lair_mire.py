"""Hydra's Mire (2026-11-24, level 24, the Bog Hydra's lair): what lies past the map's edge. Every cell outside the
playfield becomes the mire's deep black water (the dark fill of background_tile_set_mire.tres) except the muddy bank
round the map; a boardwalk causeway runs out behind the castle and open channels lead away behind the spawns
(MIRES); lily pads, reeds and bubbles float on the water (background source 2, mire_water_tiles.png). Then the
dressing nodes (MireDressing, rewritten on every run): drowned giant trees and root arches standing in the water,
will-o'-wisps over it and braziers on the bank. The rock on the Hydra's pool spawn's square goes (the pool is its own
art). Art: tools/sprite/parts/lair_mire_art.py. Rerunnable; reload the level in the editor after.

    python tools/lair_mire.py [level numbers...] [--dry]     (default: every level in MIRES)
"""
import os
import re
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import level_tiles as lt

# per level: the causeway (start cell, end cell; one row of planks), channels (start, end, half width at the start,
# at the end) and the pool spawn's mouth cell
MIRES = {
    24: {"causeway": ((-25, 5), (-40, 5)),
         "channels": [((24, -6), (38, -9), 1.6, 2.2), ((24, 0), (38, 2), 1.3, 2.0)],
         "pool": (22, -6)},
}
MARGIN = 16
WATER_SOURCE = 2
PLANKS = [(0, 0), (1, 0), (2, 0)]
POSTS = (3, 0)
LILIES = [(0, 1), (1, 1), (2, 1)]
LOG = (3, 1)
REEDS = [(0, 2), (1, 2), (2, 2)]
BUBBLES = (3, 2)
TREES_TEXTURE = "res://assets/art/tiles/lairs/mire_trees.png"
ARCH_TEXTURE = "res://assets/art/tiles/lairs/mire_root_arch.png"
WISP_SCENE = "res://scenes/level/lair/mire_wisp.tscn"
BRAZIER_SCENE = "res://scenes/level/lair/mire_brazier.tscn"
# mire_trees.png is packed two columns of 48x64; a tree's waterline is its row 57, a root arch's (64x32) row 27
TREE_REGIONS = [(0, 0), (48, 0), (0, 64)]
TREE_OFFSET = (0, -25)
ARCH_OFFSET = (0, -11)
DRESSING = "MireDressing"
# wisps also hover over the map's own ponds
POND_WISPS = 6
POND_SIZE = 3
ROW_WISPS = 10
LIT_GROUP = "lair_lit"


def h(*key):
    return zlib.crc32(repr(key).encode())


def dist(c, box):
    (x0, y0, x1, y1) = box
    return max(x0 - c[0], c[0] - x1, y0 - c[1], c[1] - y1, 0)


def build_tiles(level, mire, log):
    field = lt.playfield(level)
    xs, ys = [c[0] for c in field], [c[1] for c in field]
    box = (min(xs), min(ys), max(xs), max(ys))
    background = level.cells("BackgroundTileMapLayer")
    front = level.cells("FrontTileMapLayer")
    (cx0, cy), (cx1, _) = mire["causeway"]
    causeway = set((x, cy) for x in range(min(cx0, cx1), max(cx0, cx1) + 1))
    channels = set()
    for i, (start, end, half0, half1) in enumerate(mire["channels"]):
        channels |= lt._tunnel_cells(start, end, half0, half1, (level.number, i))
    channels -= field
    near_open = set((x + dx, y + dy) for x, y in causeway | channels for dx in (-1, 0, 1) for dy in (-1, 0, 1))
    for y in range(box[1] - MARGIN, box[3] + MARGIN + 1):
        for x in range(box[0] - MARGIN, box[2] + MARGIN + 1):
            c = (x, y)
            if c in field:
                continue
            front.pop(c, None)
            source, tile, _ = background.get(c, (0, lt.DARK_FILL[0], 0))
            bank = dist(c, box) == 1 and source == 0 and tile not in lt.DARK_FILL and c not in channels
            if bank:
                continue
            background[c] = (0, lt.pick(lt.DARK_FILL, c), 0)
            d = dist(c, box)
            if c in near_open or d < 2 or d > 6:
                continue
            roll = h(level.number, c, "float") % 60
            if roll < 3:
                background[c] = (WATER_SOURCE, lt.pick(LILIES, c), 0)
            elif roll < 5:
                background[c] = (WATER_SOURCE, lt.pick(REEDS, c), 0)
            elif roll < 6:
                background[c] = (WATER_SOURCE, BUBBLES, 0)
            elif roll < 7:
                background[c] = (WATER_SOURCE, LOG, 0)
    for c in channels:  # lily pads line the channels
        for n in (lt.add(c, lt.N), lt.add(c, lt.S)):
            if n not in channels and n not in field and n not in causeway and dist(n, box) > 1 and h(n, "lily") % 3 == 0:
                background[n] = (WATER_SOURCE, lt.pick(LILIES, n), 0)
    for i, c in enumerate(sorted(causeway, key=lambda c: -c[0])):
        background[c] = (WATER_SOURCE, POSTS if i == len(causeway) - 1 else lt.pick(PLANKS, c), 0)
    pool = mire.get("pool")
    if pool:
        square = lt.spawn_squares(level).get(pool, [])
        for c in square + [pool]:
            front.pop(c, None)
    level.set_cells("BackgroundTileMapLayer", background)
    level.set_cells("FrontTileMapLayer", front)
    log.append(("mire", "box", box, "causeway", len(causeway), "channel cells", len(channels)))
    return box, causeway, channels


def place_dressing(level, box, causeway, channels, log):
    """tree, arch, wisp and brazier spots: trees a few cells into the water (further south, where their tops would
    cover the map), spaced apart, off the causeway and channels"""
    (x0, y0, x1, y1) = box
    keep_clear = set((x + dx, y + dy) for x, y in causeway | channels for dx in range(-2, 3) for dy in range(-2, 3))
    trees, arches = [], []

    def free(c, spots, gap):
        return all(max(abs(c[0] - s[0]), abs(c[1] - s[1])) >= gap for s, _ in spots)

    candidates = []
    for y in range(y0 - 6, y1 + 8):
        for x in range(x0 - 8, x1 + 9):
            c = (x, y)
            d = dist(c, box)
            south = y > y1
            if c in keep_clear or d < (4 if south else 2) or d > (6 if south else 5):
                continue
            candidates.append(c)
    candidates.sort(key=lambda c: h(level.number, c, "tree"))
    for c in candidates:
        if free(c, trees, 4):
            trees.append((c, h(c, "kind") % len(TREE_REGIONS)))
    for c in candidates:
        if len(arches) < 8 and free(c, trees, 3) and free(c, arches, 6) and dist(c, box) <= 4:
            arches.append((c, h(c, "flip") % 2))
    wisps = []
    for c in sorted(candidates, key=lambda c: h(level.number, c, "wisp")):
        if len(wisps) < 6 and dist(c, box) <= 3 and free(c, trees, 2) and free(c, wisps, 8):
            wisps.append((c, 0))
    ponds = _ponds(level)
    wisps += [(c, 0) for c in ponds[:POND_WISPS]]
    # and over the map's tree rows (blocking forest tiles nobody builds on), one every few cells, light for the middle
    forest = sorted(c for c, v in level.cells("FrontTileMapLayer").items()
                    if v[0] == lt.FOREST_SOURCE and x0 <= c[0] <= x1 and y0 <= c[1] <= y1)
    row_wisps = []
    for c in sorted(forest, key=lambda c: h(level.number, c, "row wisp")):
        if len(row_wisps) < ROW_WISPS and free(c, wisps + row_wisps, 5):
            row_wisps.append((c, 0))
    wisps += row_wisps
    braziers = []
    for x in range(x0 + 3, x1 - 2, 9):  # on the bank above and below the map
        for y in (y0 - 1, y1 + 1):
            c = (x + (h(x, y, "b") % 3) - 1, y)
            if c not in keep_clear:
                braziers.append((c, 0))
    cx = max(c[0] for c in causeway)
    braziers += [((cx, causeway_row(causeway) - 1), 0), ((cx, causeway_row(causeway) + 1), 0)]
    log.append(("dressing", len(trees), "trees", len(arches), "arches", len(wisps), "wisps", len(braziers), "braziers"))
    return trees, arches, wisps, braziers


def _ponds(level):
    """the middle cell of each pond on the map (water layer groups of POND_SIZE cells or more), biggest first"""
    water = set(level.cells("WaterTileMapLayer"))
    ponds = []
    while water:
        todo, group = [water.pop()], []
        while todo:
            c = todo.pop()
            group.append(c)
            for d in (lt.N, lt.E, lt.S, lt.W):
                n = lt.add(c, d)
                if n in water:
                    water.remove(n)
                    todo.append(n)
        if len(group) >= POND_SIZE:
            mx = sum(c[0] for c in group) / len(group)
            my = sum(c[1] for c in group) / len(group)
            ponds.append((len(group), min(group, key=lambda c: (c[0] - mx) ** 2 + (c[1] - my) ** 2)))
    return [c for _, c in sorted(ponds, reverse=True)]


def causeway_row(causeway):
    return next(iter(causeway))[1]


def ensure_ext(level, kind, path, ext_id):
    if 'id="%s"' % ext_id in level.text:
        return
    line = '[ext_resource type="%s" path="%s" id="%s"]\n' % (kind, path, ext_id)
    last = list(re.finditer(r'^\[ext_resource [^\n]*\n', level.text, re.M))[-1]
    level.text = level.text[:last.end()] + line + level.text[last.end():]


def write_dressing(level, trees, arches, wisps, braziers):
    text = level.text
    start = text.find('[node name="%s"' % DRESSING)
    if start >= 0:  # the old block: the node and every node under it
        m = re.compile(r'^\[node (?![^\n]*parent="%s)' % DRESSING, re.M).search(text, start + 1)
        end = m.start() if m else len(text)
        text = text[:start] + text[end:]
    level.text = text
    ensure_ext(level, "Texture2D", TREES_TEXTURE, "mire_trees")
    ensure_ext(level, "Texture2D", ARCH_TEXTURE, "mire_root_arch")
    ensure_ext(level, "PackedScene", WISP_SCENE, "mire_wisp")
    ensure_ext(level, "PackedScene", BRAZIER_SCENE, "mire_brazier")
    out = ['[node name="%s" type="Node2D" parent="." groups=["%s"]]' % (DRESSING, LIT_GROUP), 'y_sort_enabled = true', '']
    for name in ("Trees", "Arches", "Wisps", "Braziers"):
        out += ['[node name="%s" type="Node2D" parent="%s"]' % (name, DRESSING), 'y_sort_enabled = true',
                'use_parent_material = true', '']
    for i, ((x, y), kind) in enumerate(trees):
        rx, ry = TREE_REGIONS[kind]
        out += ['[node name="Tree%d" type="Sprite2D" parent="%s/Trees"]' % (i, DRESSING), 'use_parent_material = true',
                'position = Vector2(%d, %d)' % (x * 16 + 8, y * 16 + 12), 'texture = ExtResource("mire_trees")',
                'offset = Vector2(%d, %d)' % TREE_OFFSET, 'flip_h = %s' % ('true' if h(x, y, "fl") % 2 else 'false'),
                'region_enabled = true', 'region_rect = Rect2(%d, %d, 48, 64)' % (rx, ry), '']
    for i, ((x, y), flip) in enumerate(arches):
        out += ['[node name="Arch%d" type="Sprite2D" parent="%s/Arches"]' % (i, DRESSING), 'use_parent_material = true',
                'position = Vector2(%d, %d)' % (x * 16 + 8, y * 16 + 12), 'texture = ExtResource("mire_root_arch")',
                'offset = Vector2(%d, %d)' % ARCH_OFFSET, 'flip_h = %s' % ('true' if flip else 'false'), '']
    # wisps and braziers keep their own bright light, outside the lit material
    for i, ((x, y), _) in enumerate(wisps):
        out += ['[node name="Wisp%d" parent="%s/Wisps" instance=ExtResource("mire_wisp")]' % (i, DRESSING),
                'position = Vector2(%d, %d)' % (x * 16 + 8, y * 16 + 10), '']
    for i, ((x, y), _) in enumerate(braziers):
        out += ['[node name="Brazier%d" parent="%s/Braziers" instance=ExtResource("mire_brazier")]' % (i, DRESSING),
                'position = Vector2(%d, %d)' % (x * 16 + 8, y * 16 + 12), '']
    at = level.text.find('[node name="EndPoint"')
    level.text = level.text[:at] + '\n'.join(out) + '\n' + level.text[at:]


def main(args):
    dry = "--dry" in args
    numbers = [int(a) for a in args if a.isdigit()] or sorted(MIRES)
    for number in numbers:
        level = lt.Level(number)
        log = []
        box, causeway, channels = build_tiles(level, MIRES[number], log)
        write_dressing(level, *place_dressing(level, box, causeway, channels, log))
        print("level %d%s" % (number, " (dry run)" if dry else ""))
        for entry in log:
            print("  ", *entry)
        if not dry:
            level.save()


if __name__ == "__main__":
    main(sys.argv[1:])
