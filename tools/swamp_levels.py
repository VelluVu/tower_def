"""Build the swamp levels 14, 15 and 24 (and the new ones between) from Serpent Road (level 13): same 48x16 playfield, background frame, waterfalls
and river mouths, a new map painted from the layouts below, the swamp ground tile set, then the usual
level_tiles.py passes (ground, water, edge, surround swamp, rock).

    python tools/swamp_levels.py [level numbers...]     (default: all; rewrites their .tscn files)

Layout cells: . marsh grass, b bog, m wet mud and d dry mud (both slow enemies), ~ water, T tree wall (2 wide),
t small tree (blocks its cell), C castle, S/D/W/K spawn squares (hollow, den, roost, cave), R ruin (a 2x2 pond with
one of the swamp ruins on it, in RUIN order). Grid.crossing() puts stepping stones over deep water for the waders.
A LEVELS entry may add options: tile_set (None keeps level 13's green land, for a cave level) and surround. Reload the levels in the editor afterwards.
"""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import level_tiles as lt

ROOT = lt.ROOT
# the scene every level here is copied from: Serpent Road
SOURCE_LEVEL = 13
W, H, X0, Y0 = 48, 16, -24, -8
# level 13's own origin; scorched_levels.py moves X0 and Y0 for a map of another size
X0_FRAME, Y0_FRAME = X0, Y0
SWAMP_TILE_SET = "res://assets/tile_sets/swamp_land_tile_set.tres"
RUINS_PNG = "res://assets/art/tiles/swamp/swamp_ruins.png"
RUIN_REGIONS = {"head": (0, 0), "column": (32, 0), "wall": (0, 32), "arm": (32, 32)}
SPAWN_SCENES = {"S": "spawn_hollow", "D": "spawn_den", "W": "spawn_roost", "K": "spawn_cave"}
BOG_CROSSING_SCRIPT = "res://scenes/level/bog_crossing/bog_crossing.gd"
# old terrain tiles (green_land.png, source 1) whose neighbours are all their own terrain: they carry decor
OLD_FULL = {".": [(0, 0), (0, 1), (0, 4), (0, 5)], "d": [(2, 6), (2, 7), (5, 6), (6, 6)],
            "m": [(2, 2), (2, 3), (5, 2), (6, 2)]}
BOG_TILE = (lt.GROUND_SOURCE, (lt.BOG_TERRAIN * lt.TERRAIN_BLOCK, 0), 0)
WATER_TILE = (2, (0, 55), 0)
TREE_TOP, TREE_MID, TREE_BOTTOM = {0: (7, 5), 1: (10, 5)}, {0: (7, 6), 1: (10, 6)}, {0: (7, 7), 1: (10, 7)}
SMALL_TREES = [((1, 1), (1, 2)), ((3, 3), (3, 4))]
FIXED_WATER = [(c, r) for c in (24, 25, 26, 39, 40, 41) for r in (0, 1, 2)] + \
              [(c, r) for c in (12, 13, 14, 15, 16, 28, 29) for r in (13, 14, 15)]


class Grid:
    def __init__(self, fill="b"):
        self.g = [[fill] * W for _ in range(H)]
        self.ruins = []
        self.small = []
        self.crossings = []

    def rect(self, c0, r0, c1, r1, ch):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.g[r][c] = ch
        return self

    def tree_wall(self, c, r0, r1):
        return self.rect(c, r0, c + 1, r1, "T")

    def ruin(self, c, r, kind):
        self.rect(c, r, c + 1, r + 1, "R")
        self.ruins.append((c, r, kind))
        return self

    def crossing(self, c0, r0, c1, r1):
        """Stepping stones from the shore cell (c0, r0) over deep water to (c1, r1); waders use them (BogCrossing)."""
        self.crossings.append(((c0, r0), (c1, r1)))
        return self

    def tree(self, c, r):
        self.g[r][c] = "t"
        return self

    def done(self):
        for c, r in FIXED_WATER:
            self.g[r][c] = "~"
        return self


def level_14():
    """Mire Gate: the first real bog. One hollow, four tree walls make a long serpent road, mud slows the bends."""
    g = Grid()
    for r in range(H):
        g.rect(0, r, 12 + r % 3, r, ".")
    g.tree_wall(6, 0, 10).tree_wall(13, 5, 15).tree_wall(20, 0, 10).tree_wall(31, 0, 9).tree_wall(37, 6, 15)
    g.rect(23, 11, 28, 14, "m").rect(41, 1, 44, 4, "d").rect(9, 11, 12, 13, "m").rect(15, 1, 18, 3, "d")
    g.ruin(16, 8, "head").ruin(33, 12, "column").ruin(43, 8, "arm")
    for c, r in ((2, 2), (4, 7), (10, 3), (1, 9), (17, 13)):
        g.tree(c, r)
    g.rect(1, 11, 3, 13, "C").rect(45, 0, 47, 2, "S")
    return g.done()


def level_15():
    """Drowned Chapel: the swamp has swallowed a human chapel. Two spawns, the routes meet at the chapel's
    broken walls and pass a choke by the castle; giant wasps fly straight over the ruins."""
    g = Grid()
    for r in range(H):
        g.rect(0, r, 7 + (r * 7) % 3, r, ".")
    g.rect(17, 3, 30, 12, "d")
    g.ruin(19, 5, "wall").ruin(23, 5, "wall").ruin(27, 5, "head").ruin(19, 10, "column").ruin(25, 10, "wall")
    g.rect(22, 8, 23, 8, "~")
    g.tree_wall(10, 0, 5).tree_wall(10, 10, 15).tree_wall(34, 0, 11).tree_wall(38, 4, 15).tree_wall(42, 0, 7)
    g.rect(12, 6, 15, 9, "m").rect(36, 0, 38, 2, "m")
    for c, r in ((3, 1), (5, 13), (14, 2), (15, 13), (31, 1), (44, 13)):
        g.tree(c, r)
    g.rect(1, 6, 3, 8, "C").rect(45, 0, 47, 2, "S").rect(45, 9, 47, 11, "D")
    return g.done()


def level_24():
    """Hydra's Mire: the Bog Hydra's home, deep bog with sunken statues. The hydra and its brood come from the
    hollow; giant wasps from a roost on the east side."""
    g = Grid()
    for r in range(H):
        g.rect(0, r, 4 + r % 2, r, ".")
    g.tree_wall(8, 0, 11).tree_wall(16, 4, 15).tree_wall(22, 0, 9).tree_wall(27, 6, 15).tree_wall(35, 0, 10).tree_wall(41, 9, 15)
    g.rect(10, 12, 15, 15, "m").rect(18, 11, 21, 15, "m").rect(29, 0, 33, 3, "m").rect(37, 11, 40, 15, "d")
    g.ruin(2, 1, "arm").ruin(12, 5, "head").ruin(24, 12, "column").ruin(31, 7, "head").ruin(44, 11, "wall")
    for c, r in ((5, 6), (14, 2), (19, 6), (39, 3)):
        g.tree(c, r)
    g.rect(1, 12, 3, 14, "C").rect(45, 0, 47, 2, "S").rect(45, 6, 47, 8, "W")
    return g.done()


def level_10():
    """Crystal Deep (Caves, 2026-11-16): a crystal-lit hollow on the way north. Burrowers dig under the maze,
    crystal brutes shrug off plain hits, destroyerlings throw rocks. Forest ground, a cave and a den."""
    g = Grid(".")
    g.tree_wall(38, 4, 15).tree_wall(29, 0, 11).tree_wall(19, 4, 15).tree_wall(9, 0, 10)
    g.rect(32, 5, 35, 7, "~").rect(22, 9, 25, 11, "~")
    g.rect(12, 1, 17, 3, "d").rect(31, 12, 36, 14, "d")
    for c, r in ((5, 2), (15, 8), (26, 4), (43, 8)):
        g.tree(c, r)
    g.rect(1, 6, 3, 8, "C").rect(45, 0, 47, 2, "K").rect(45, 11, 47, 13, "D")
    return g.done()


def level_16():
    """Leech Fen (2026-11-16): three deep channels cut the fen; the road goes round each end, but toads and leeches
    take the stepping stones straight over. The first bog crossings."""
    g = Grid()
    for r in range(H):
        g.rect(0, r, 5, r, ".")
    g.rect(30, 0, 31, 11, "~").rect(18, 4, 19, 15, "~").rect(8, 0, 9, 11, "~")
    g.rect(21, 13, 26, 15, "m").rect(33, 1, 37, 4, "d").rect(11, 1, 16, 3, "m")
    g.crossing(32, 6, 29, 6).crossing(20, 10, 17, 10).crossing(10, 5, 7, 5)
    for c, r in ((2, 2), (4, 13), (13, 9), (25, 6), (42, 13)):
        g.tree(c, r)
    g.rect(1, 6, 3, 8, "C").rect(45, 6, 47, 8, "S")
    return g.done()


def level_17():
    """Frog Pools (2026-11-16): a fen of deep pools between four tree walls. Leaper frogs hop ahead along the road,
    giant wasps come from a roost on the north edge."""
    g = Grid()
    for r in range(H):
        g.rect(0, r, 4 + r % 2, r, ".")
    g.tree_wall(36, 4, 15).tree_wall(26, 0, 11).tree_wall(14, 4, 12).tree_wall(6, 0, 10)
    g.rect(30, 6, 33, 8, "~").rect(20, 9, 23, 11, "~").rect(9, 12, 11, 13, "~").rect(40, 8, 42, 10, "~")
    g.rect(28, 12, 35, 15, "m").rect(16, 0, 23, 3, "d")
    for c, r in ((3, 3), (11, 6), (31, 2), (44, 6)):
        g.tree(c, r)
    g.rect(1, 12, 3, 14, "C").rect(45, 10, 47, 12, "S").rect(45, 3, 47, 5, "W")
    return g.done()


def level_18():
    """Rotting Causeway (2026-11-16): a lake fills the middle and one causeway crosses it; the swamp folk must take it.
    Wall it off and they break through, and bloaters burst on the walls. Islands hold towers."""
    g = Grid()
    for r in range(H):
        g.rect(0, r, 6, r, ".")
    g.rect(8, 3, 40, 12, "~").rect(8, 7, 40, 8, "b")
    g.rect(13, 4, 17, 5, "b").rect(26, 10, 30, 11, "b").rect(33, 4, 37, 5, "b").rect(20, 4, 23, 5, "b").rect(13, 10, 17, 11, "b")
    g.ruin(22, 10, "column").ruin(30, 4, "head")
    for c, r in ((3, 1), (4, 13), (44, 1)):
        g.tree(c, r)
    g.rect(1, 6, 3, 8, "C").rect(45, 4, 47, 6, "S").rect(45, 10, 47, 12, "D")
    return g.done()


def level_19():
    """Wasp Hollow (2026-11-16): a wasp roost on the north-east edge over a winding fen road; the first elites."""
    g = Grid()
    for r in range(H):
        g.rect(0, r, 5, r, ".")
    g.tree_wall(10, 0, 11).tree_wall(20, 4, 15).tree_wall(32, 0, 10).tree_wall(40, 5, 15)
    g.rect(22, 0, 30, 3, "m").rect(12, 12, 19, 12, "d").rect(34, 12, 38, 15, "m")
    g.ruin(26, 7, "arm").ruin(14, 5, "wall")
    for c, r in ((3, 4), (7, 13), (36, 6)):
        g.tree(c, r)
    g.rect(1, 12, 3, 14, "C").rect(45, 11, 47, 13, "S").rect(45, 2, 47, 4, "W")
    return g.done()


def level_20():
    """Sunken Village (2026-11-16): a drowned human village, a long canal splits it in two halves. The hollow sends
    the north half round the canal's west end, the den the south; waders cross the canal on the old stepping stones."""
    g = Grid()
    for r in range(H):
        g.rect(0, r, 5, r, ".")
    g.rect(8, 7, 44, 8, "~")
    g.tree_wall(30, 2, 6).tree_wall(18, 0, 4).tree_wall(36, 9, 13).tree_wall(22, 11, 15)
    g.crossing(20, 6, 20, 9).crossing(34, 6, 34, 9)
    g.ruin(12, 2, "head").ruin(26, 4, "wall").ruin(10, 11, "wall").ruin(30, 11, "column")
    g.rect(38, 3, 43, 5, "d").rect(14, 10, 19, 12, "m")
    g.rect(1, 12, 3, 14, "C").rect(45, 0, 47, 2, "S").rect(45, 12, 47, 14, "D")
    return g.done()


def level_21():
    """Plague Marsh (2026-11-16): dry mud flats where the plague boars and bloaters root; poison barely bites here.
    A hollow and a den, the road zigzags round four tree walls."""
    g = Grid()
    for r in range(H):
        g.rect(0, r, 4, r, ".")
    g.tree_wall(9, 3, 15).tree_wall(17, 0, 10).tree_wall(28, 3, 12).tree_wall(37, 5, 15)
    g.rect(19, 3, 27, 9, "d").rect(30, 6, 36, 14, "m").rect(11, 9, 16, 15, "d")
    g.ruin(22, 11, "head")
    for c, r in ((2, 3), (6, 9), (33, 2)):
        g.tree(c, r)
    g.rect(1, 12, 3, 14, "C").rect(44, 9, 46, 11, "S").rect(44, 1, 46, 3, "D")
    return g.done()


def level_22():
    """Mirewood (2026-11-16): a drowned wood, seven turns of road between tree walls and two deep channels.
    The waders cut both channels on stepping stones; everyone else walks the whole maze."""
    g = Grid()
    g.tree_wall(6, 0, 9).rect(11, 5, 12, 15, "~").tree_wall(17, 0, 9).rect(23, 5, 24, 15, "~").tree_wall(30, 0, 10)
    g.tree_wall(36, 5, 15).tree_wall(42, 0, 9)
    g.crossing(25, 8, 22, 8).crossing(13, 9, 10, 9)
    g.rect(32, 12, 35, 15, "m").rect(19, 11, 22, 14, "d")
    for c, r in ((3, 3), (14, 2), (27, 3), (39, 9)):
        g.tree(c, r)
    g.rect(1, 11, 3, 13, "C").rect(45, 6, 47, 8, "S")
    return g.done()


def level_23():
    """The Drowning Deep (2026-11-16): the last mire before the Hydra. Two long canals, a hollow, a den and a roost;
    every swamp creature comes, elites among them."""
    g = Grid()
    for r in range(H):
        g.rect(0, r, 4, r, ".")
    g.rect(6, 4, 30, 5, "~").rect(18, 10, 44, 11, "~")
    g.tree_wall(14, 6, 9).tree_wall(30, 6, 9).tree_wall(36, 13, 15)
    g.crossing(20, 3, 20, 6).crossing(38, 12, 38, 9)
    g.rect(32, 0, 37, 3, "m").rect(6, 12, 11, 15, "d")
    g.ruin(9, 1, "arm").ruin(24, 13, "head")
    g.rect(1, 6, 3, 8, "C").rect(45, 0, 47, 2, "S").rect(45, 6, 47, 8, "D").rect(45, 12, 47, 14, "W")
    return g.done()


GREEN_LAND = {"tile_set": None, "surround": "crossroads"}
LEVELS = {
    8: (level_10, [], GREEN_LAND),  # Crystal Deep: 10 until the Broodmother moved to 12 (2026-11-24), 9 until 2026-11-25
    16: (level_16, [(360, 8), (136, 24), (136, 72), (-56, 72), (-56, -72), (-216, -72), (-216, 72), (-344, 8)]),
    17: (level_17, [(360, -56), (264, -56), (200, 72), (104, 72), (104, -88), (-24, -88), (-56, 72), (-344, 104)]),
    18: (level_18, []),
    19: (level_19, [(360, -88), (200, -56), (200, 72), (-24, 72), (-24, -88), (-184, -88), (-184, 88), (-344, 104)]),
    20: (level_20, [(360, -88), (200, -72), (-56, -72), (-56, -40), (-216, -40), (-264, 40), (-344, 104)]),
    21: (level_21, [(344, 72), (248, 72), (248, -56), (104, -56), (104, -88), (-72, -88), (-72, 56), (-200, 56), (-200, -88), (-248, -88), (-248, 40), (-344, 104)]),
    22: (level_22, [(360, 8), (232, 40), (232, -56), (136, -56), (136, 56), (24, 56), (24, -56), (-72, -56), (-72, 40), (-168, 40), (-168, -56), (-248, -56), (-248, 40), (-344, 88)]),
    23: (level_23, [(360, 88), (264, 24), (104, 24), (-56, -24), (-200, -24), (-344, 8)]),
    14: (level_14, [(360, -88), (232, -40), (40, 56), (-152, -72), (-344, 72)]),
    15: (level_15, [(360, -72), (200, -56), (200, 72), (-184, 72), (-184, 24), (-344, 8)]),
    24: (level_24, [(360, -88), (216, -24), (40, 40), (-120, -56), (-344, 104)]),
}


def cell(c, r):
    return (X0 + c, Y0 + r)


def find(g, ch):
    cells = [(c, r) for r in range(H) for c in range(W) if g.g[r][c] == ch]
    return cells


def paint(level, g):
    ground, water, front = {}, {}, {}
    old_front = level.cells("FrontTileMapLayer")
    field = set(cell(c, r) for r in range(H) for c in range(W))
    # keep everything past the playfield; `surround` redoes it
    for k, v in old_front.items():
        if k not in field:
            front[k] = v
    trees = set()
    for r in range(H):
        for c in range(W):
            ch, p = g.g[r][c], cell(c, r)
            if ch in OLD_FULL or ch in "CtT":
                kind = ch if ch in OLD_FULL else "."
                ground[p] = (lt.OLD_GROUND_SOURCE, lt.pick(OLD_FULL[kind], level.number, p), 0)
            else:
                ground[p] = BOG_TILE
            if ch in "~R":
                water[p] = WATER_TILE
            if ch == "T":
                trees.add((c, r))
    for (c, r) in trees:
        # a wall is two trees wide: the left one uses the column's left tiles
        side = 0 if (c + 1, r) in trees and (c - 1, r) not in trees else 1
        top, bottom = (c, r - 1) not in trees, (c, r + 1) not in trees
        front[cell(c, r)] = (2, (TREE_TOP if top else TREE_BOTTOM if bottom else TREE_MID)[side], 0)
    for i, (c, r) in enumerate(find(g, "t")):
        top, bottom = SMALL_TREES[lt.pick([0, 1], level.number, c, r)]
        front[cell(c, r)] = (2, bottom, 0)
        if r > 0 and g.g[r - 1][c] not in "TtR~CSDWK":
            front[cell(c, r - 1)] = (2, top, 0)
    castle = find(g, "C")
    c0, r0 = min(castle)
    for dc in range(3):
        for dr in range(3):
            front[cell(c0 + dc, r0 + dr)] = (0, (dc, dr), 0)
    level.set_cells("GroundTileMapLayer", ground)
    level.set_cells("WaterTileMapLayer", water)
    level.set_cells("FrontTileMapLayer", front)
    level.set_cells("DecorTileMapLayer", {})
    return (c0 + 1, r0 + 2)


def center(c, r):
    x, y = cell(c, r)
    return (x * 16 + 8, y * 16 + 8)


def nodes(level, g, end_cell, route, tile_set=SWAMP_TILE_SET):
    text = level.text
    text = text.replace('[node name="Level%03d"' % SOURCE_LEVEL + '', '[node name="Level%03d"' % level.number)
    # level 13's reference may carry a uid or not (references into level_data drop them); without this every level
    # built from it played Serpent Road's waves
    text = re.sub(r'\[ext_resource type="Resource"(?: uid="[^"]+")? path="res://scenes/level/level_data/level_%03d_data.tres' % SOURCE_LEVEL + '"',
                  '[ext_resource type="Resource" path="res://scenes/level/level_data/level_%03d_data.tres"' % level.number, text)
    if tile_set:
        text = re.sub(r'\[ext_resource type="TileSet" uid="[^"]+" path="res://assets/tile_sets/green_land_tile_set.tres"',
                      '[ext_resource type="TileSet" path="%s"' % tile_set, text)
    ex, ey = center(*end_cell)
    text = re.sub(r'(\[node name="EndPoint"[^\n]*\]\nposition = )Vector2\([^)]*\)', r'\g<1>Vector2(%d, %d)' % (ex, ey), text)
    # spawners: drop level 12's and add one per spawn square, ids in S, D, W order
    text = re.sub(r'\[node name="Spawner\d*"[^\n]*\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    ext = ''
    add = ''
    sid = 0
    for ch, scene in SPAWN_SCENES.items():
        square = find(g, ch)
        if not square:
            continue
        c0, r0 = min(square)
        x, y = center(c0 + 1, r0 + 2)
        ext_id = "spawn_point_" + scene[6:]
        if 'id="%s"' % ext_id not in text and ext_id not in ext:
            ext += '[ext_resource type="PackedScene" path="res://scenes/unit/spawner/spawn_points/%s.tscn" id="%s"]\n' % (scene, ext_id)
        name = "Spawner" if sid == 0 else "Spawner%d" % (sid + 1)
        add += ('[node name="%s" parent="." node_paths=PackedStringArray("end_point", "flight_route") groups=["Spawner"] '
                'instance=ExtResource("%s")]\nposition = Vector2(%d, %d)\n%send_point = NodePath("../EndPoint")\n'
                'flight_route = NodePath("../FlightRoute")\n\n') % (name, ext_id, x, y, "id = %d\n" % sid if sid else "")
        sid += 1
    # bog crossings: stepping stones from the entry shore to the exit shore
    if g.crossings:
        ext += '[ext_resource type="Script" path="%s" id="bog_crossing"]\n' % BOG_CROSSING_SCRIPT
        for i, (entry, exit_cell) in enumerate(g.crossings):
            ex0, ey0 = center(*entry)
            ex1, ey1 = center(*exit_cell)
            add += ('[node name="BogCrossing%d" type="Node2D" parent="."]\nposition = Vector2(%d, %d)\n'
                    'script = ExtResource("bog_crossing")\nexit_offset = Vector2(%d, %d)\n\n') % (i, ex0, ey0, ex1 - ex0, ey1 - ey0)
    # ruins: one Sprite2D per ruin, standing on the bottom of its 2x2 pond
    ruin_subs = ''
    if g.ruins:
        if 'id="swamp_ruins"' not in text:
            ext += '[ext_resource type="Texture2D" path="%s" id="swamp_ruins"]\n' % RUINS_PNG
        add += '[node name="Ruins" type="Node2D" parent="."]\ny_sort_enabled = true\n\n'
        for i, (c, r, kind) in enumerate(g.ruins):
            x, y = cell(c, r)
            rx, ry = RUIN_REGIONS[kind]
            ruin_subs += ('[sub_resource type="AtlasTexture" id="AtlasTexture_ruin%d"]\natlas = ExtResource("swamp_ruins")\n'
                          'region = Rect2(%d, %d, 32, 32)\n\n') % (i, rx, ry)
            add += ('[node name="Ruin%d" type="Sprite2D" parent="Ruins"]\nposition = Vector2(%d, %d)\n'
                    'texture = SubResource("AtlasTexture_ruin%d")\noffset = Vector2(0, -14)\n\n') % (i, x * 16 + 16, y * 16 + 30, i)
    last_ext = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
    text = text[:last_ext] + ext + text[last_ext:]
    first_sub = text.index('[sub_resource')
    text = text[:first_sub] + ruin_subs + text[first_sub:]
    pts = ", ".join("0, 0, 0, 0, %d, %d" % p for p in route)
    text = re.sub(r'("points": PackedVector2Array\()[^)]*\)', r'\g<1>%s)' % pts, text)
    text = re.sub(r'point_count = \d+', 'point_count = %d' % len(route), text)
    m = re.search(r'\[node name="FlightRoute"[^\n]*\]\n(?:[^\[\n][^\n]*\n)*\n?', text)
    text = text[:m.end()] + add + text[m.end():]
    level.text = text


def build(number):
    design, route, *rest = LEVELS[number]
    # options: tile_set (None keeps level 13's green land), surround (level_tiles.py surround kind)
    opts = rest[0] if rest else {}
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
    nodes(level, g, end_cell, route, opts.get("tile_set", SWAMP_TILE_SET))
    level.save()
    tool = os.path.join(ROOT, "tools", "level_tiles.py")
    for args in (["ground"], ["water"], ["edge"], ["surround", opts.get("surround", "swamp")], ["rock"]):
        subprocess.run([sys.executable, tool] + args + [str(number)], check=True, capture_output=True)
    print("level %d built" % number)


if __name__ == "__main__":
    for n in [int(a) for a in sys.argv[1:]] or sorted(LEVELS):
        build(n)
