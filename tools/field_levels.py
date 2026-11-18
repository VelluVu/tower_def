"""Build the Fields levels 25-36 (the human lands past the northern bridge) from Serpent Road (level 13), like
swamp_levels.py does for the swamp: same 48x16 playfield and frame, a map painted from the layouts below, the
fields ground tile set (humans_ground_tiles.png), the farm props as blocking front tiles, then the usual
level_tiles.py passes (ground, water, edge, surround forest, rock).

    python tools/field_levels.py [level numbers...]     (default: all; rewrites their .tscn files)

Layout cells: . meadow, w wheat, r dirt road, o cobble and p ploughed earth (the last three slow enemies, like
mud), ~ water, T hedgerow (2 wide), t small tree, C castle, S plain spawner (the humans march in from the map's
edge, ids top to bottom), props (one blocking cell each): h haystack, F fence, b barrel, x crate, B banner,
y berry bush. Reload the levels in the editor afterwards. Level 12's frame keeps its ponds (swamp_levels.FIXED_WATER:
columns 24-26 and 39-41 on rows 0-2, 12-16 and 28-29 on rows 13-15), so leave the roads clear of them.
"""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import level_tiles as lt
import swamp_levels as sw

ROOT = lt.ROOT
# the scene every level here is copied from: Serpent Road
SOURCE_LEVEL = 13
H = sw.H
W = sw.W
FIELDS_TILE_SET = "res://assets/tile_sets/fields_land_tile_set.tres"
PROPS_SOURCE = 7  # object_tile_set_01: humans_props.png
PROPS = {"h": (0, 0), "F": (1, 0), "b": (2, 0), "x": (0, 1), "B": (1, 1), "y": (2, 1)}
# terrain blocks of the ground sheet painted straight as rounded pieces (`ground` picks the shapes)
TERRAIN = {"w": 1, "o": 2, "r": 3, "p": 4}
MEADOW = [(0, 0), (0, 1), (0, 4), (0, 5)]


def level_25():
    """Wheatfield Road: the first farm past the northern bridge. Soldiers, scouts and dogs, and the first archers.
    Hedgerows and fences fold the road; ploughed strips slow the bends."""
    g = sw.Grid(".")
    g.rect(9, 0, 20, 3, "w").rect(27, 6, 35, 9, "w").rect(4, 13, 10, 15, "w").rect(42, 11, 46, 15, "w")
    g.tree_wall(12, 6, 15).tree_wall(22, 0, 9).tree_wall(31, 11, 15).tree_wall(38, 0, 8)
    g.rect(3, 5, 11, 5, "F").rect(26, 10, 33, 10, "F").rect(42, 9, 47, 9, "F")
    g.rect(15, 10, 19, 12, "p").rect(34, 1, 37, 3, "p").rect(6, 1, 8, 3, "p")
    g.rect(35, 13, 39, 13, "r").rect(41, 3, 47, 3, "r")
    for c, r, ch in ((5, 2, "h"), (17, 7, "h"), (27, 2, "h"), (2, 8, "b"), (5, 8, "b"), (6, 9, "x"), (44, 1, "B"),
                     (44, 5, "B"), (30, 4, "y"), (9, 9, "y"), (19, 14, "h"), (25, 13, "y")):
        g.rect(c, r, c, r, ch)
    for c, r in ((1, 2), (18, 5), (36, 6)):
        g.tree(c, r)
    g.rect(1, 11, 3, 13, "C").rect(47, 2, 47, 2, "S").rect(47, 7, 47, 7, "S")
    return g.done()


def level_26():
    """Haystack Farm: a big farmstead, two lanes of fields split by a long hedge, the farm yard in the middle.
    Wizards and priests join the soldiers; giant eagles fly over the barns."""
    g = sw.Grid(".")
    g.tree_wall(6, 4, 11).rect(8, 7, 30, 8, "T").tree_wall(36, 0, 6).tree_wall(36, 10, 15)
    g.rect(10, 0, 20, 5, "w").rect(10, 10, 18, 15, "w").rect(24, 1, 33, 5, "p").rect(22, 10, 30, 13, "p")
    g.rect(38, 7, 47, 8, "r").rect(32, 7, 37, 8, "o")
    g.rect(41, 3, 45, 3, "F").rect(41, 12, 45, 12, "F").rect(14, 6, 19, 6, "F").rect(14, 9, 19, 9, "F")
    for c, r, ch in ((22, 3, "h"), (23, 4, "h"), (20, 12, "h"), (33, 9, "b"), (34, 9, "b"), (32, 6, "x"),
                     (46, 5, "B"), (46, 10, "B"), (3, 2, "y"), (4, 14, "y"), (43, 0, "h"), (43, 15, "h")):
        g.rect(c, r, c, r, ch)
    for c, r in ((2, 5), (9, 2), (27, 15)):
        g.tree(c, r)
    g.rect(1, 6, 3, 8, "C").rect(47, 1, 47, 1, "S").rect(47, 14, 47, 14, "S").rect(47, 7, 47, 7, "S")
    return g.done()


def level_27():
    """Millstream Ford: a mill stream runs across the fields and the humans must take one of its two fords. Their
    cavalry rides for the first time; hedges turn the road back and forth on both banks."""
    g = sw.Grid(".")
    g.rect(20, 0, 21, 15, "~").rect(20, 4, 21, 5, "o").rect(20, 10, 21, 11, "o")
    g.tree_wall(38, 6, 15).tree_wall(30, 0, 10).tree_wall(10, 3, 15)
    g.rect(24, 6, 28, 9, "w").rect(42, 8, 46, 14, "w").rect(2, 11, 8, 14, "w")
    g.rect(22, 9, 25, 12, "p").rect(13, 2, 18, 4, "p")
    g.rect(40, 3, 47, 4, "r").rect(32, 11, 37, 12, "r")
    for c, r, ch in ((16, 6, "h"), (17, 7, "h"), (23, 3, "x"), (24, 4, "b"), (33, 14, "b"), (34, 14, "x"),
                     (44, 6, "B"), (44, 11, "B"), (6, 9, "y"), (26, 14, "y"), (35, 2, "h")):
        g.rect(c, r, c, r, ch)
    for c, r in ((4, 2), (15, 10), (35, 8)):
        g.tree(c, r)
    g.rect(1, 6, 3, 8, "C").rect(47, 2, 47, 2, "S").rect(47, 13, 47, 13, "S")
    return g.done()


def level_28():
    """Ashen Village: a burned village the humans hold as their last line before the camp. Fenced yards and
    hedges make a long street; every kind of human comes, the giant eagles over the roofs."""
    g = sw.Grid(".")
    g.tree_wall(36, 6, 15).tree_wall(27, 0, 9).tree_wall(18, 4, 15).tree_wall(9, 0, 9)
    g.rect(30, 2, 33, 2, "F").rect(21, 8, 24, 8, "F").rect(12, 4, 15, 4, "F").rect(40, 10, 44, 10, "F")
    g.rect(29, 10, 35, 12, "o").rect(20, 1, 26, 3, "o").rect(11, 11, 17, 12, "p").rect(38, 4, 47, 5, "r")
    g.rect(30, 5, 34, 8, "w").rect(2, 1, 7, 4, "w")
    for c, r, ch in ((31, 3, "x"), (32, 3, "b"), (22, 9, "x"), (23, 9, "b"), (13, 5, "h"), (14, 5, "x"),
                     (42, 11, "b"), (45, 2, "B"), (45, 13, "B"), (24, 13, "y"), (5, 7, "y"), (39, 14, "h")):
        g.rect(c, r, c, r, ch)
    for c, r in ((3, 9), (24, 6), (42, 7)):
        g.tree(c, r)
    g.rect(1, 11, 3, 13, "C").rect(47, 3, 47, 3, "S").rect(47, 8, 47, 8, "S").rect(47, 12, 47, 12, "S")
    return g.done()


def level_36():
    """Dragonslayer's Camp: the humans' war camp on the fields. Every human comes, cavalry from the camp road,
    and the Dragonslayer himself in the last wave."""
    g = sw.Grid(".")
    g.tree_wall(7, 0, 9).tree_wall(14, 6, 15).tree_wall(21, 0, 9).tree_wall(28, 6, 15).tree_wall(35, 0, 9)
    g.rect(9, 11, 13, 15, "w").rect(23, 0, 34, 2, "w").rect(37, 11, 41, 15, "p").rect(16, 0, 20, 3, "p")
    g.rect(42, 4, 47, 5, "r").rect(42, 10, 47, 11, "r")
    g.rect(40, 7, 46, 7, "F").rect(40, 8, 46, 8, "F")
    for c, r, ch in ((44, 2, "B"), (44, 13, "B"), (38, 3, "x"), (39, 3, "b"), (24, 12, "h"), (10, 4, "h"),
                     (17, 13, "y"), (31, 4, "y"), (3, 3, "b"), (4, 3, "x")):
        g.rect(c, r, c, r, ch)
    for c, r in ((2, 9), (18, 7), (32, 13)):
        g.tree(c, r)
    g.rect(1, 12, 3, 14, "C").rect(47, 4, 47, 4, "S").rect(47, 11, 47, 11, "S")
    return g.done()


def level_29():
    """Sapper's Trench (2026-11-16): the humans dig in. Ploughed trenches slow the road between four hedgerows, and
    sappers come for the towers and walls with their charges."""
    g = sw.Grid(".")
    g.tree_wall(38, 0, 10).tree_wall(28, 5, 12).tree_wall(18, 0, 10).tree_wall(8, 5, 15)
    g.rect(30, 6, 36, 9, "p").rect(20, 5, 26, 8, "p").rect(10, 1, 16, 3, "p").rect(42, 12, 47, 13, "r")
    g.rect(41, 5, 45, 5, "F")
    for c, r, ch in ((43, 4, "x"), (44, 4, "b"), (33, 2, "h"), (22, 12, "x"), (12, 8, "b"), (4, 2, "y"), (44, 9, "B")):
        g.rect(c, r, c, r, ch)
    for c, r in ((3, 7), (23, 2), (34, 13)):
        g.tree(c, r)
    g.rect(1, 11, 3, 13, "C").rect(47, 3, 47, 3, "S").rect(47, 12, 47, 12, "S")
    return g.done()


def level_30():
    """Old Mill Hill (2026-11-16): a mill race runs across the hill with two fords; the humans bring their first
    champions (elites)."""
    g = sw.Grid(".")
    g.rect(4, 7, 47, 8, "~").rect(10, 7, 11, 8, "o").rect(36, 7, 37, 8, "o")
    g.tree_wall(20, 0, 4).tree_wall(30, 11, 15)
    g.rect(13, 1, 18, 4, "w").rect(32, 1, 37, 4, "w").rect(18, 10, 26, 12, "p").rect(40, 10, 46, 11, "r")
    for c, r, ch in ((23, 5, "h"), (24, 5, "h"), (8, 2, "b"), (9, 2, "x"), (44, 4, "B"), (44, 13, "B"), (34, 12, "y")):
        g.rect(c, r, c, r, ch)
    for c, r in ((3, 3), (27, 3), (15, 13)):
        g.tree(c, r)
    g.rect(1, 11, 3, 13, "C").rect(47, 2, 47, 2, "S").rect(47, 13, 47, 13, "S")
    return g.done()


def level_31():
    """Orchard Wall (2026-11-16): an apple orchard behind three dry-stone walls (fences); the road weaves between
    the rows of trees. Giant eagles over the orchard."""
    g = sw.Grid(".")
    g.rect(20, 0, 20, 11, "F").rect(34, 4, 34, 15, "F").rect(8, 0, 8, 10, "F")
    for c in range(23, 33, 3):
        for r in range(1, 15, 3):
            g.tree(c, r)
    for c in range(11, 19, 3):
        for r in range(2, 12, 3):
            g.tree(c, r)
    g.rect(36, 8, 46, 9, "r").rect(2, 10, 6, 14, "w")
    for c, r, ch in ((44, 2, "h"), (45, 2, "h"), (38, 13, "x"), (39, 13, "b"), (5, 1, "y")):
        g.rect(c, r, c, r, ch)
    g.rect(1, 3, 3, 5, "C").rect(47, 6, 47, 6, "S").rect(47, 11, 47, 11, "S")
    return g.done()


def level_32():
    """Bridgehead Camp (2026-11-16): the humans hold the one bridge over a river; past it two hedgerows turn the
    road back and forth to the castle."""
    g = sw.Grid(".")
    g.rect(32, 0, 33, 15, "~").rect(32, 7, 33, 8, "o")
    g.tree_wall(20, 0, 10).tree_wall(10, 5, 15)
    g.rect(22, 2, 29, 5, "w").rect(12, 11, 18, 12, "p").rect(34, 7, 47, 8, "r")
    for c, r, ch in ((37, 3, "B"), (37, 12, "B"), (40, 4, "x"), (41, 4, "b"), (42, 11, "x"), (43, 11, "h"), (6, 8, "y")):
        g.rect(c, r, c, r, ch)
    for c, r in ((4, 11), (16, 2), (26, 13), (45, 1)):
        g.tree(c, r)
    g.rect(1, 1, 3, 3, "C").rect(47, 4, 47, 4, "S").rect(47, 12, 47, 12, "S")
    return g.done()


def level_33():
    """Watchtower Fields (2026-11-16): wide fields under the humans' watchtowers; archers shoot from the road and giant
    eagles fly over the three hedgerows."""
    g = sw.Grid(".")
    g.tree_wall(36, 6, 15).tree_wall(24, 3, 12).tree_wall(12, 0, 8)
    g.rect(27, 6, 33, 10, "w").rect(14, 1, 21, 4, "w").rect(3, 11, 9, 14, "p").rect(38, 3, 47, 4, "r")
    for c, r, ch in ((30, 2, "B"), (18, 12, "B"), (7, 3, "B"), (44, 8, "x"), (44, 12, "h")):
        g.rect(c, r, c, r, ch)
    for c, r in ((4, 2), (20, 9), (42, 12)):
        g.tree(c, r)
    g.rect(1, 6, 3, 8, "C").rect(47, 2, 47, 2, "S").rect(47, 9, 47, 9, "S").rect(47, 14, 47, 14, "S")
    return g.done()


def level_34():
    """Siege Lines (2026-11-16): three barricade lines (fences) across the field make a long switchback road; the
    humans bring sappers and their heavy knights."""
    g = sw.Grid(".")
    g.rect(6, 4, 47, 4, "F").rect(0, 8, 41, 8, "F").rect(6, 11, 47, 11, "F")
    g.rect(10, 1, 20, 2, "p").rect(30, 5, 38, 7, "p").rect(10, 9, 20, 10, "p").rect(30, 13, 36, 14, "p")
    for c, r, ch in ((45, 2, "B"), (45, 9, "B"), (22, 6, "x"), (23, 6, "b"), (40, 14, "h")):
        g.rect(c, r, c, r, ch)
    for c, r in ((3, 2), (26, 13)):
        g.tree(c, r)
    g.rect(1, 12, 3, 14, "C").rect(47, 1, 47, 1, "S").rect(47, 6, 47, 6, "S")
    return g.done()


def level_35():
    """Banner Road (2026-11-16): the humans' road to their war camp, banners on every bend; every kind of human, their
    champions among them."""
    g = sw.Grid(".")
    g.tree_wall(36, 0, 9).tree_wall(26, 6, 15).tree_wall(16, 0, 9).tree_wall(6, 5, 15)
    g.rect(42, 7, 47, 8, "r").rect(28, 1, 34, 4, "w").rect(18, 11, 24, 12, "o").rect(8, 1, 14, 3, "p")
    for c, r, ch in ((38, 12, "B"), (28, 5, "B"), (18, 10, "B"), (8, 4, "B"), (44, 2, "x"), (44, 13, "h")):
        g.rect(c, r, c, r, ch)
    for c, r in ((2, 2), (31, 12), (21, 6)):
        g.tree(c, r)
    g.rect(1, 10, 3, 12, "C").rect(47, 2, 47, 2, "S").rect(47, 8, 47, 8, "S").rect(47, 14, 47, 14, "S")
    return g.done()


LEVELS = {
    29: (level_29, []),
    30: (level_30, []),
    31: (level_31, [(376, -24), (232, -88), (88, 72), (-56, -88), (-200, 72), (-344, -8)]),
    32: (level_32, []),
    33: (level_33, [(376, 8), (232, -56), (104, -56), (104, 104), (-104, 104), (-152, 24), (-344, 8)]),
    34: (level_34, []),
    35: (level_35, [(376, 8), (232, 72), (72, -56), (-88, 72), (-248, -88), (-344, 72)]),
    25: (level_25, []),
    26: (level_26, [(376, -104), (232, -24), (40, 24), (-200, -24), (-344, -8)]),
    27: (level_27, []),
    # over the street's corners, where the towers stand
    28: (level_28, [(376, -8), (88, -72), (88, 40), (-56, 40), (-56, -72), (-200, -72), (-200, 40), (-344, 88)]),
    # over the switchback road's bends, where the towers stand (the diagonal route let the eagles past, 2026-11-16)
    36: (level_36, [(376, -56), (216, -56), (216, 40), (104, 40), (104, -40), (-8, -40), (-8, 40), (-120, 40), (-120, -40), (-232, -40), (-232, 40), (-344, 104)]),
}


def paint(level, g):
    ground, water, front = {}, {}, {}
    field = set(sw.cell(c, r) for r in range(H) for c in range(W))
    for k, v in level.cells("FrontTileMapLayer").items():
        if k not in field:
            front[k] = v
    trees = set()
    for r in range(H):
        for c in range(W):
            ch, p = g.g[r][c], sw.cell(c, r)
            if ch in TERRAIN:
                ground[p] = (lt.GROUND_SOURCE, (TERRAIN[ch] * lt.TERRAIN_BLOCK, 0), 0)
            else:
                ground[p] = (lt.OLD_GROUND_SOURCE, lt.pick(MEADOW, level.number, p), 0)
            if ch in "~":
                water[p] = sw.WATER_TILE
            if ch == "T":
                trees.add((c, r))
            if ch in PROPS:
                front[p] = (PROPS_SOURCE, PROPS[ch], 0)
    for (c, r) in trees:
        side = 0 if (c + 1, r) in trees and (c - 1, r) not in trees else 1
        top, bottom = (c, r - 1) not in trees, (c, r + 1) not in trees
        front[sw.cell(c, r)] = (2, (sw.TREE_TOP if top else sw.TREE_BOTTOM if bottom else sw.TREE_MID)[side], 0)
    for c, r in sw.find(g, "t"):
        top, bottom = sw.SMALL_TREES[lt.pick([0, 1], level.number, c, r)]
        front[sw.cell(c, r)] = (2, bottom, 0)
        if r > 0 and g.g[r - 1][c] not in "TtR~CS" + "".join(PROPS):
            front[sw.cell(c, r - 1)] = (2, top, 0)
    c0, r0 = min(sw.find(g, "C"))
    for dc in range(3):
        for dr in range(3):
            front[sw.cell(c0 + dc, r0 + dr)] = (0, (dc, dr), 0)
    # level 12's swamp surroundings left bog pools past the edge; dark fill again, `surround forest` redoes it
    pools = set(t for pool in lt.BOG_POOLS for t in pool)
    background = level.cells("BackgroundTileMapLayer")
    for k, (source, tile, _) in list(background.items()):
        if k not in field and source == 0 and tile in pools:
            background[k] = (0, lt.pick(lt.DARK_FILL, k), 0)
    level.set_cells("BackgroundTileMapLayer", background)
    level.set_cells("GroundTileMapLayer", ground)
    level.set_cells("WaterTileMapLayer", water)
    level.set_cells("FrontTileMapLayer", front)
    level.set_cells("DecorTileMapLayer", {})
    return (c0 + 1, r0 + 2)


def nodes(level, g, end_cell, route):
    text = level.text
    text = text.replace('[node name="Level%03d"' % SOURCE_LEVEL + '', '[node name="Level%03d"' % level.number)
    # level 13's reference may carry a uid or not (references into level_data drop them); without this every level
    # built from it played Serpent Road's waves
    text = re.sub(r'\[ext_resource type="Resource"(?: uid="[^"]+")? path="res://scenes/level/level_data/level_%03d_data.tres' % SOURCE_LEVEL + '"',
                  '[ext_resource type="Resource" path="res://scenes/level/level_data/level_%03d_data.tres"' % level.number, text)
    text = re.sub(r'\[ext_resource type="TileSet" uid="[^"]+" path="res://assets/tile_sets/green_land_tile_set.tres"',
                  '[ext_resource type="TileSet" path="%s"' % FIELDS_TILE_SET, text)
    ex, ey = sw.center(*end_cell)
    text = re.sub(r'(\[node name="EndPoint"[^\n]*\]\nposition = )Vector2\([^)]*\)', r'\g<1>Vector2(%d, %d)' % (ex, ey), text)
    text = re.sub(r'\[node name="Spawner\d*"[^\n]*\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    ext = '[ext_resource type="PackedScene" path="res://scenes/unit/spawner/spawner.tscn" id="spawner_plain"]\n'
    add = ''
    for sid, (c, r) in enumerate(sorted(sw.find(g, "S"), key=lambda p: (p[1], p[0]))):
        x, y = sw.center(c, r)
        name = "Spawner" if sid == 0 else "Spawner%d" % (sid + 1)
        add += ('[node name="%s" parent="." node_paths=PackedStringArray("end_point", "flight_route") groups=["Spawner"] '
                'instance=ExtResource("spawner_plain")]\nposition = Vector2(%d, %d)\n%send_point = NodePath("../EndPoint")\n'
                'flight_route = NodePath("../FlightRoute")\n\n') % (name, x, y, "id = %d\n" % sid if sid else "")
    last_ext = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
    text = text[:last_ext] + ext + text[last_ext:]
    pts = ", ".join("0, 0, 0, 0, %d, %d" % p for p in route)
    text = re.sub(r'("points": PackedVector2Array\()[^)]*\)', r'\g<1>%s)' % pts, text)
    text = re.sub(r'point_count = \d+', 'point_count = %d' % len(route), text)
    m = re.search(r'\[node name="FlightRoute"[^\n]*\]\n(?:[^\[\n][^\n]*\n)*\n?', text)
    text = text[:m.end()] + add + text[m.end():]
    level.text = text


def build(number):
    design, route = LEVELS[number]
    src = os.path.join(ROOT, lt.LEVEL_PATH % SOURCE_LEVEL)
    dst = os.path.join(ROOT, lt.LEVEL_PATH % number)
    with open(src, encoding="utf8") as f:
        text = f.read()
    # the copy gets its own uid from Godot; keeping level 12's would make references by uid ambiguous
    first = text.index("\n")
    text = re.sub(r' (uid="[^"]+"|load_steps=\d+)', "", text[:first]) + text[first:]
    with open(dst, "w", encoding="utf8", newline="\n") as f:
        f.write(text)
    level = lt.Level(number)
    g = design()
    end_cell = paint(level, g)
    nodes(level, g, end_cell, route)
    level.save()
    tool = os.path.join(ROOT, "tools", "level_tiles.py")
    for args in (["ground"], ["water"], ["edge"], ["surround", "forest"], ["rock"]):
        subprocess.run([sys.executable, tool] + args + [str(number)], check=True, capture_output=True)
    print("level %d built" % number)


if __name__ == "__main__":
    for n in [int(a) for a in sys.argv[1:]] or sorted(LEVELS):
        build(n)
