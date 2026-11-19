"""Build the Scorched Lands levels 37-48 from Serpent Road (level 13), like field_levels.py does for the Fields:
the ash desert 37-42 (the old war's battlefield) and the volcano 43-48. Same 48x16 playfield and frame, a map
painted from the layouts below, the area's ground tile set and props, then the usual level_tiles.py passes
(ground, water, edge, surround barren, rock). Run tools/area_tiles.py afterwards (rock, lava and background sets).

    python tools/scorched_levels.py [level numbers...]     (default: all; rewrites their .tscn files)

Layout cells: . the base ground (dune sand, ash), u block 1 (packed dunes, scorched earth), s salt flats / ash
drifts, r red dust road / hot cinders, h hardpan / dark ember earth (s, r and h slow enemies, like mud), ~ water
(an oasis in the desert, lava at the volcano), X rock ridge (rounded by the rock pass), C castle (3x3; several
blocks = several castles, see SPAWN_CASTLES), S plain
spawner (ids top to bottom), props (one blocking cell each, per area, see PROPS). The frame keeps level 13's
ponds (swamp_levels.FIXED_WATER: columns 24-26 and 39-41 on rows 0-2, 12-16 and 28-29 on rows 13-15).
Reload the levels in the editor afterwards.
"""
import os
import re
import subprocess
import zlib
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import level_tiles as lt
import swamp_levels as sw

ROOT = lt.ROOT
SOURCE_LEVEL = 13
H, W = sw.H, sw.W
TILE_SETS = {"desert": "res://assets/tile_sets/desert_land_tile_set.tres",
             "volcano": "res://assets/tile_sets/volcano_land_tile_set.tres"}
# object_tile_set_01 sources 8 and 9: desert_props.png and volcano_props.png (3 x 2 props of 16 px)
PROPS_SOURCE = {"desert": 8, "volcano": 9}
PROPS = {
    "desert": {"o": (0, 0), "R": (1, 0), "K": (2, 0), "P": (0, 1), "E": (1, 1), "Y": (2, 1)},
    "volcano": {"B": (0, 0), "V": (1, 0), "O": (2, 0), "Y": (0, 1), "K": (1, 1), "Z": (2, 1)},
}
TERRAIN = {"u": 1, "s": 2, "r": 3, "h": 4}
BASE = [(0, 0), (0, 1), (0, 4), (0, 5)]
ROCK_TILE = (lt.ROCK_SOURCE, (0, 0), 0)


def find(g, ch):
    return [(c, r) for r in range(g.h) for c in range(g.w) if g.g[r][c] == ch]


def area_of(number):
    return "desert" if number <= 48 else "volcano"


class Grid(sw.Grid):
    def __init__(self, rows=H, cols=W):
        super().__init__(".")
        # any size (the user, 2026-11-18: levels may vary in width and height). A 48-wide map keeps level 13's frame
        # (its waterfalls and ponds; a taller one adds new rows below); any other width gets a fresh frame of its own
        self.h = rows
        self.w = cols
        self.g = [["."] * cols for _ in range(rows)]

    @property
    def fresh(self):
        return self.w != W

    def origin(self):
        """the map's top-left cell in the level: level 13's for its frame, else the map centred on (0, 0)"""
        return (sw.X0_FRAME, sw.Y0_FRAME) if not self.fresh else (-(self.w // 2), -(self.h // 2))

    def done(self):
        """level 13's frame ponds; on a taller map only the top ones (the bottom ones were river mouths at row 15);
        none on a fresh frame"""
        if self.fresh:
            return self
        for c, r in sw.FIXED_WATER:
            if self.h == H or r < 3:
                self.g[r][c] = "~"
        return self

    def ridge(self, c, r0, r1):
        """a rock ridge one cell wide, top to bottom"""
        return self.rect(c, r0, c, r1, "X")

    def ledge(self, c0, c1, r):
        """a rock ridge one cell high, left to right"""
        return self.rect(c0, r, c1, r, "X")

    def shape(self, r0, spans, ch):
        """an irregular patch: one (first column, last column) span per row from r0 down"""
        for i, (c0, c1) in enumerate(spans):
            self.rect(c0, r0 + i, c1, r0 + i, ch)
        return self

    def props(self, *cells):
        for c, r, ch in cells:
            self.rect(c, r, c, r, ch)
        return self


# ======================= ash desert =======================
def level_37():
    """Ashfall Road: the desert's edge past the Dragonslayer's camp. The humans' rearguard, and the first dead rise."""
    g = Grid()
    g.ridge(10, 0, 9).ridge(20, 6, 15).ridge(33, 0, 10).ridge(43, 7, 15)
    g.rect(22, 3, 30, 4, "r").rect(12, 11, 18, 12, "u").rect(35, 12, 41, 14, "s").rect(6, 12, 7, 13, "~")
    g.props((5, 2, "o"), (15, 2, "R"), (27, 8, "K"), (38, 3, "P"), (45, 2, "o"), (14, 8, "Y"), (30, 13, "E"), (4, 11, "o"))
    g.rect(1, 6, 3, 8, "C").rect(47, 4, 47, 4, "S").rect(47, 11, 47, 11, "S")
    return g.done()


def level_38():
    """Bleached Dunes: white salt flats between dune ridges. Scarabs swarm over the salt; the first sandstorm."""
    g = Grid()
    g.ridge(8, 4, 15).ridge(17, 0, 11).ridge(27, 4, 15).ridge(36, 0, 11).ridge(44, 5, 15)
    g.rect(10, 0, 15, 3, "s").rect(19, 12, 26, 15, "s").rect(29, 5, 34, 9, "u").rect(38, 12, 43, 15, "s")
    g.rect(4, 8, 5, 9, "~")
    g.props((12, 7, "o"), (22, 6, "R"), (31, 13, "K"), (40, 6, "Y"), (46, 2, "o"), (3, 13, "P"))
    g.rect(1, 2, 3, 4, "C").rect(47, 2, 47, 2, "S").rect(47, 8, 47, 8, "S").rect(47, 13, 47, 13, "S")
    return g.done()


def level_39():
    """Rusted Siege Lines: the old war's siege works, three lanes behind two long barricades of rock and wreckage."""
    g = Grid()
    g.ledge(4, 47, 5).ledge(0, 43, 10)
    g.rect(8, 1, 20, 2, "r").rect(28, 7, 40, 8, "r").rect(6, 12, 10, 14, "h")
    g.props((15, 4, "E"), (30, 3, "P"), (36, 1, "E"), (10, 7, "P"), (22, 8, "E"), (18, 12, "P"), (33, 14, "E"), (44, 13, "o"))
    g.rect(1, 12, 3, 14, "C").rect(47, 1, 47, 1, "S").rect(47, 3, 47, 3, "S")
    return g.done()


def level_40():
    """Drakebone Graveyard: where the dragons of the old war fell. Their bones lie in rows, and some of them fly."""
    g = Grid()
    g.ridge(9, 0, 10).ridge(18, 5, 15).ridge(30, 0, 10).ridge(38, 5, 15)
    g.rect(20, 7, 27, 8, "s").rect(2, 12, 6, 14, "u")
    g.props((4, 2, "R"), (13, 3, "K"), (14, 7, "R"), (22, 4, "R"), (25, 11, "K"), (34, 3, "R"), (34, 12, "R"),
            (43, 9, "K"), (44, 13, "R"), (6, 10, "Y"))
    g.rect(1, 6, 3, 8, "C").rect(47, 3, 47, 3, "S").rect(47, 12, 47, 12, "S")
    return g.done()


def level_41():
    """The Last Oasis: the only water for days splits the road in two. The grave callers wait by it."""
    g = Grid()
    g.rect(18, 5, 29, 10, "~").ridge(9, 3, 12).ridge(38, 4, 11)
    g.rect(16, 4, 31, 4, "u").rect(16, 11, 31, 11, "u").rect(40, 0, 46, 2, "s")
    g.props((13, 2, "Y"), (13, 13, "Y"), (34, 7, "o"), (44, 9, "R"), (5, 12, "P"), (5, 3, "K"))
    g.rect(1, 6, 3, 8, "C").rect(47, 2, 47, 2, "S").rect(47, 13, 47, 13, "S")
    return g.done()


# the desert's second half (2026-11-18, the user: twelve levels per area and levels of any size): between the Last
# Oasis and the Fallen Elder. Sizes vary: Grid(rows, columns).
def level_42():
    """Scarab Warrens (32x18, fits the screen): a small dug-out hollow where the scarabs breed; a tight serpent road."""
    g = Grid(18, 32)
    g.ridge(7, 0, 11).ridge(14, 6, 17).ridge(21, 0, 11).ledge(24, 28, 14)
    g.rect(9, 13, 12, 15, "s").rect(16, 1, 19, 3, "s").rect(24, 4, 29, 6, "u")
    g.props((4, 2, "Y"), (11, 4, "o"), (18, 9, "K"), (26, 9, "o"), (4, 14, "R"))
    g.rect(1, 7, 3, 9, "C").rect(31, 2, 31, 2, "S").rect(31, 15, 31, 15, "S")
    return g.done()


def level_43():
    """Windscour Flats (64x14): a long run over open salt flats where the storms are worst. Few ridges; the maze is
    yours to build, and the sand eats your towers' sight."""
    g = Grid(14, 64)
    g.rect(10, 4, 20, 9, "s").rect(30, 0, 38, 5, "s").rect(44, 8, 54, 13, "s")
    g.ridge(16, 0, 3).ridge(26, 10, 13).ridge(36, 7, 10).ridge(48, 0, 4).ledge(56, 60, 7)
    g.props((6, 2, "o"), (23, 6, "R"), (33, 11, "E"), (42, 3, "P"), (52, 6, "K"), (5, 11, "Y"))
    g.rect(1, 5, 3, 7, "C").rect(63, 1, 63, 1, "S").rect(63, 7, 63, 7, "S").rect(63, 12, 63, 12, "S")
    return g.done()


def level_44():
    """The Ossuary Stair (30x28, tall): terraces cut into a cliff of bones, down to a castle at the foot. The dead
    come down from the top, step by step."""
    g = Grid(28, 30)
    g.ledge(0, 22, 5).ledge(7, 29, 10).ledge(0, 22, 15).ledge(7, 29, 20)
    g.rect(24, 6, 28, 9, "u").rect(1, 11, 5, 14, "h").rect(24, 16, 28, 19, "u")
    g.props((10, 2, "R"), (18, 7, "K"), (12, 12, "R"), (4, 18, "K"), (20, 17, "o"), (24, 24, "R"), (5, 24, "Y"))
    g.rect(13, 23, 15, 25, "C").rect(3, 0, 3, 0, "S").rect(26, 0, 26, 0, "S")
    return g.done()


def level_45():
    """Old War Camp (40x22, two castles): the dragons' old camp, two keeps behind a wall of rock that splits the camp
    in two. Each keep has its own road winding through the old trench lines; towers between the keeps reach both.
    (Redrawn 2026-11-18: the first layout's roads were 33-50 cells to keeps far apart, and nothing could win it.)"""
    g = Grid(22, 40)
    g.ledge(0, 35, 10)
    g.ridge(30, 0, 7).ridge(22, 2, 9).ridge(14, 0, 7).ridge(8, 2, 9)
    g.ridge(31, 13, 21).ridge(23, 11, 19).ridge(15, 13, 21).ridge(8, 11, 19)
    g.rect(24, 4, 28, 6, "s").rect(16, 15, 20, 17, "s").rect(32, 13, 36, 15, "u").rect(10, 3, 12, 5, "r")
    g.props((5, 1, "P"), (11, 7, "E"), (18, 4, "P"), (35, 2, "Y"), (27, 17, "E"), (11, 14, "o"), (36, 20, "P"))
    g.rect(1, 5, 3, 7, "C").rect(1, 14, 3, 16, "C")
    g.rect(20, 0, 20, 0, "S").rect(39, 4, 39, 4, "S").rect(39, 17, 39, 17, "S")
    return g.done()


def level_46():
    """Mirage Wells (44x24): five wells in a ring, some real, all of them full of reeds. Roads wind between them; ash
    drakes fly straight over."""
    g = Grid(24, 44)
    g.rect(8, 3, 13, 8, "~").rect(8, 15, 13, 20, "~").rect(19, 9, 25, 14, "~").rect(30, 2, 35, 7, "~").rect(30, 16, 35, 21, "~")
    g.ridge(16, 0, 5).ridge(16, 18, 23).ridge(27, 8, 15).ridge(39, 6, 17)
    g.rect(18, 2, 26, 4, "s").rect(18, 19, 26, 21, "s")
    g.props((4, 3, "Y"), (4, 20, "o"), (22, 7, "R"), (22, 16, "K"), (36, 11, "P"), (41, 2, "o"))
    g.rect(1, 10, 3, 12, "C").rect(43, 2, 43, 2, "S").rect(43, 21, 43, 21, "S")
    return g.done()


def level_47():
    """Gate of Bones (56x20): the last march to the elder's resting place, through four bone walls with a gap in each.
    Everything the desert has comes at once."""
    g = Grid(20, 56)
    g.ridge(12, 0, 13).ridge(22, 6, 19).ridge(32, 0, 13).ridge(42, 6, 19)
    g.rect(14, 15, 20, 18, "s").rect(24, 1, 30, 4, "u").rect(34, 15, 40, 18, "s").rect(44, 1, 50, 4, "r")
    g.props((5, 3, "R"), (6, 15, "K"), (17, 8, "R"), (27, 12, "E"), (37, 8, "K"), (47, 12, "R"), (52, 16, "o"))
    g.rect(1, 8, 3, 10, "C").rect(55, 2, 55, 2, "S").rect(55, 10, 55, 10, "S").rect(55, 17, 55, 17, "S")
    return g.done()


def level_48():
    """The Fallen Elder: a long road between bone-white ridges to where the elder dragon's skeleton lies."""
    g = Grid()
    g.ridge(7, 4, 15).ridge(14, 0, 10).ridge(21, 4, 15).ridge(31, 0, 11).ridge(38, 5, 15).ridge(43, 0, 11)
    g.rect(16, 12, 20, 15, "s").rect(33, 1, 37, 3, "s").rect(9, 0, 12, 2, "u")
    g.props((3, 8, "R"), (4, 12, "K"), (11, 6, "R"), (17, 4, "o"), (26, 9, "R"), (35, 9, "K"), (45, 14, "o"))
    g.rect(1, 1, 3, 3, "C").rect(47, 8, 47, 8, "S")
    return g.done()


# ======================= volcano =======================
def level_49():
    """Cinder Gate: the way up the volcano. A lava river cuts the land with one ford at its south end; salamanders
    swim the lava further up."""
    g = Grid()
    # the ford is at the river's south end; the stones further up are the salamanders' shortcut
    g.rect(22, 0, 23, 12, "~").ridge(10, 4, 15).ridge(34, 4, 15)
    g.rect(24, 13, 33, 14, "r").rect(12, 4, 20, 5, "u").rect(36, 0, 45, 2, "s")
    g.props((5, 3, "B"), (16, 9, "V"), (28, 12, "O"), (40, 8, "Y"), (44, 12, "B"), (6, 13, "K"))
    # stones over the lava: the salamanders swim past the ford
    g.crossing(24, 3, 21, 3).crossing(24, 9, 21, 9)
    g.rect(1, 6, 3, 8, "C").rect(47, 3, 47, 3, "S").rect(47, 12, 47, 12, "S")
    return g.done()


def level_50():
    """Obsidian Pass: three narrow basalt lanes up the mountain, the castle at the top of the pass."""
    g = Grid()
    g.ledge(6, 47, 5).ledge(0, 41, 10)
    g.rect(14, 7, 15, 8, "~").rect(32, 7, 33, 8, "~").rect(20, 12, 24, 12, "h")
    g.props((10, 2, "O"), (30, 3, "B"), (8, 7, "B"), (24, 7, "V"), (38, 13, "O"), (6, 13, "B"))
    g.rect(44, 1, 46, 3, "C").rect(0, 13, 0, 13, "S")
    return g.done()


def level_51():
    """Ember Monastery: the cultists' monastery stands in the middle; their braziers burn day and night."""
    g = Grid()
    g.rect(20, 5, 27, 10, "X").ridge(10, 3, 12).ridge(36, 0, 5).ridge(36, 10, 15)
    g.rect(12, 6, 18, 9, "u").rect(29, 6, 34, 9, "u")
    g.props((19, 4, "Z"), (28, 4, "Z"), (19, 11, "Z"), (28, 11, "Z"), (5, 3, "Y"), (42, 8, "B"), (15, 13, "K"))
    g.rect(1, 6, 3, 8, "C").rect(47, 2, 47, 2, "S").rect(47, 7, 47, 7, "S").rect(47, 13, 47, 13, "S")
    return g.done()


def level_52():
    """Lava Falls: lava pours down the cliffs in two rivers, and the fissures here erupt."""
    g = Grid()
    g.rect(15, 0, 16, 10, "~").rect(31, 5, 32, 15, "~").ridge(40, 0, 10)
    g.rect(18, 6, 29, 8, "h").rect(4, 2, 12, 4, "u")
    g.props((8, 8, "V"), (22, 12, "O"), (26, 2, "B"), (36, 3, "V"), (44, 12, "Y"), (5, 13, "K"))
    g.crossing(33, 13, 30, 13).crossing(17, 2, 14, 2)
    g.rect(1, 11, 3, 13, "C").rect(47, 3, 47, 3, "S").rect(47, 13, 47, 13, "S")
    return g.done()


def level_53():
    """Caldera Rim: the castle stands on an island in the old crater, a ring of lava around it and a bridge on each
    side. Everything the Wyrm commands converges on it from all four edges: cultists from the north, the raised dead
    from the west (the desert side), fire creatures from the east, golems and phoenixes from the south. A taller map
    (24 rows), the convergence level asked for on 2026-11-17."""
    g = Grid(24)
    # the lava ring and its island, a bridge on every side
    g.rect(16, 6, 31, 17, "~").rect(19, 9, 28, 14, ".")
    g.rect(23, 6, 24, 8, ".").rect(23, 15, 24, 17, ".").rect(16, 11, 18, 12, ".").rect(29, 11, 31, 12, ".")
    g.rect(14, 4, 33, 4, "h").rect(14, 19, 33, 19, "h").rect(20, 10, 27, 13, "u")
    # basalt outcrops in the four quadrants leave lanes to maze
    g.ridge(8, 2, 9).ridge(8, 14, 21).ridge(39, 2, 9).ridge(39, 14, 21)
    g.ledge(12, 20, 21).ledge(27, 35, 2)
    g.props((4, 4, "B"), (4, 19, "O"), (13, 9, "V"), (34, 14, "Z"), (44, 4, "Y"), (44, 19, "B"), (20, 2, "K"),
            (28, 21, "V"), (12, 16, "Z"), (35, 7, "O"))
    g.rect(22, 10, 24, 12, "C")
    g.rect(12, 0, 12, 0, "S").rect(0, 12, 0, 12, "S").rect(47, 12, 47, 12, "S").rect(35, 23, 35, 23, "S")
    return g.done()


# the volcano's second half (2026-11-18): between Caldera Rim and the Throne of Embers, sizes vary
def level_54():
    """Smoldering Steps (36x24): terraces up the mountain, lava trickling over their edges; the fissures here erupt."""
    g = Grid(24, 36)
    g.ledge(0, 27, 6).ledge(8, 35, 12).ledge(0, 27, 18)
    g.rect(14, 0, 15, 3, "~").rect(6, 7, 7, 9, "~").rect(20, 15, 21, 17, "~")
    g.rect(22, 1, 27, 3, "h").rect(10, 13, 16, 14, "u")
    g.props((8, 3, "B"), (24, 9, "V"), (14, 9, "O"), (30, 15, "B"), (4, 21, "Y"), (28, 21, "K"))
    g.rect(16, 20, 18, 22, "C").rect(3, 0, 3, 0, "S").rect(33, 0, 33, 0, "S")
    return g.done()


def level_55():
    """Glassfield (60x16): a long field of black glass cut by three lava rivers, each with a ford at one end. The
    salamanders swim straight across."""
    g = Grid(16, 60)
    g.rect(14, 0, 15, 11, "~").rect(30, 4, 31, 15, "~").rect(46, 0, 47, 11, "~")
    g.ledge(18, 26, 8).ledge(34, 42, 7).ledge(50, 56, 4)
    g.rect(4, 2, 10, 4, "u").rect(20, 11, 27, 13, "h").rect(36, 1, 43, 3, "u")
    g.props((7, 12, "O"), (22, 3, "B"), (38, 12, "O"), (53, 10, "V"), (11, 8, "Y"))
    g.crossing(16, 6, 13, 6).crossing(32, 10, 29, 10).crossing(48, 5, 45, 5)
    g.rect(1, 6, 3, 8, "C").rect(59, 3, 59, 3, "S").rect(59, 12, 59, 12, "S")
    return g.done()


def level_56():
    """The Cinder Forge (40x20): the forge where the old war's weapons were made, cold for an age, now lit again by
    the cultists. Braziers around the anvil hall; the ground in front of it cracks."""
    g = Grid(20, 40)
    g.rect(16, 6, 23, 13, "X").ridge(8, 0, 7).ridge(8, 12, 19).ridge(31, 4, 15)
    g.rect(10, 8, 14, 11, "h").rect(25, 8, 29, 11, "h")
    g.props((15, 5, "Z"), (24, 5, "Z"), (15, 14, "Z"), (24, 14, "Z"), (4, 3, "B"), (35, 2, "Y"), (4, 16, "K"))
    g.rect(1, 8, 3, 10, "C").rect(39, 1, 39, 1, "S").rect(39, 10, 39, 10, "S").rect(39, 18, 39, 18, "S")
    return g.done()


def level_57():
    """Magma Heart (34x30, tall): two lakes of magma under the summit, a strip of rock between them. The walkers go
    round; the salamanders swim through."""
    g = Grid(30, 34)
    # the lakes have rounded, uneven shores (2026-11-19, the user's OK: rectangles looked man-made); column 16 stays
    # lava from row 8 to 13 and 16 to 21 for the crossings
    g.shape(8, [(13, 20), (11, 22), (10, 23), (9, 24), (9, 23), (10, 22)], "~")
    g.shape(16, [(10, 23), (9, 24), (9, 24), (10, 23), (11, 22), (13, 20)], "~").ridge(4, 10, 24).ridge(29, 10, 24).ledge(0, 13, 6).ledge(20, 33, 6)
    g.shape(14, [(11, 22), (10, 23)], "h").shape(2, [(13, 20), (12, 21), (13, 21)], "u").shape(26, [(2, 5), (1, 6), (1, 5)], "h")
    g.props((2, 4, "B"), (31, 4, "O"), (6, 16, "V"), (27, 16, "V"), (26, 27, "Y"), (16, 6, "K"))
    g.crossing(16, 7, 16, 14).crossing(16, 15, 16, 22)
    g.rect(15, 25, 17, 27, "C").rect(5, 0, 5, 0, "S").rect(28, 0, 28, 0, "S")
    return g.done()


def level_58():
    """Phoenix Roost (44x26): cliffs stacked above each other where the phoenixes nest. The road zig-zags down; the
    birds take the short way."""
    g = Grid(26, 44)
    g.ledge(6, 43, 6).ledge(0, 37, 13).ledge(6, 43, 20)
    g.rect(18, 2, 20, 3, "~").rect(28, 9, 30, 10, "~").rect(12, 16, 14, 17, "~").rect(30, 23, 32, 24, "~")
    g.rect(2, 8, 8, 11, "u").rect(36, 15, 42, 18, "h")
    g.props((10, 2, "V"), (34, 3, "Z"), (20, 10, "B"), (24, 16, "O"), (8, 23, "B"), (22, 23, "Y"))
    g.rect(39, 21, 41, 23, "C").rect(43, 2, 43, 2, "S").rect(43, 9, 43, 9, "S")
    return g.done()


def level_59():
    """The Black Gate (64x22): the Wyrm's own wall of basalt, two gate lines before the throne. Three roads converge
    on the gaps; the gaps crack and burn."""
    g = Grid(22, 64)
    g.ridge(20, 0, 7).ridge(20, 10, 13).ridge(20, 16, 21).ridge(40, 3, 18)
    g.rect(48, 8, 52, 12, "X").rect(28, 0, 31, 4, "~").rect(28, 17, 31, 21, "~").rect(8, 14, 11, 17, "~")
    g.rect(24, 8, 36, 13, "h").rect(44, 0, 56, 2, "u").rect(44, 19, 56, 21, "u")
    g.props((6, 3, "Z"), (14, 19, "Z"), (34, 2, "V"), (34, 19, "O"), (46, 10, "B"), (58, 6, "Y"), (58, 15, "K"))
    g.rect(2, 9, 4, 11, "C").rect(63, 2, 63, 2, "S").rect(63, 10, 63, 10, "S").rect(63, 19, 63, 19, "S")
    return g.done()


def level_60():
    """Throne of Embers: the Wyrm's seat in the heart of the volcano. Lava pools between black ridges."""
    g = Grid()
    g.ridge(8, 3, 12).ridge(16, 0, 10).ridge(24, 5, 15).ridge(33, 0, 10).ridge(41, 5, 15)
    g.rect(19, 12, 21, 13, "~").rect(28, 2, 30, 3, "~").rect(36, 12, 38, 13, "~")
    g.rect(10, 1, 14, 2, "h").rect(26, 11, 31, 12, "r")
    g.props((12, 13, "Z"), (20, 4, "K"), (29, 8, "V"), (37, 4, "Z"), (45, 9, "O"), (4, 2, "B"), (4, 13, "B"))
    # two castles: the throne-side keep between the ridges takes the north spawner's march
    g.rect(1, 6, 3, 8, "C").rect(18, 1, 20, 3, "C")
    g.rect(47, 2, 47, 2, "S").rect(47, 8, 47, 8, "S").rect(47, 14, 47, 14, "S")
    return g.done()


# number: (layout, flight route points from the map centre; [] = flyers fly straight)
LEVELS = {n: (globals()["level_%d" % n], []) for n in range(37, 61)}
# fissures (Fissure nodes): (layout cells (column, row), the waves they erupt at). They narrow a lane, never close
# it: LavaField.erupt keeps a cell dry when its lava would leave a spawner without a road.
FISSURES = {
    54: [([(30, 8), (31, 8), (30, 9), (31, 9)], [3, 5]), ([(4, 14), (5, 14), (4, 15), (5, 15)], [4, 6])],
    # the forge's yard
    56: [([(26, 2), (27, 2), (26, 3), (27, 3)], [2, 4, 6]), ([(26, 16), (27, 16), (26, 17), (27, 17)], [3, 5])],
    # just behind the first gate's gaps
    59: [([(21, 8), (22, 8), (21, 9), (22, 9)], [3, 5]), ([(21, 14), (22, 14), (21, 15), (22, 15)], [4, 6])],
    52: [([(19, 11), (20, 11), (21, 11), (19, 12), (20, 12), (21, 12)], [3, 5]),
         ([(36, 12), (37, 12), (38, 12), (36, 13), (37, 13), (38, 13)], [3, 5])],
    # the west and east approaches to the caldera
    53: [([(11, 11), (12, 11), (11, 12), (12, 12), (11, 13), (12, 13)], [2, 6]),
         ([(35, 10), (36, 10), (35, 11), (36, 11), (35, 12), (36, 12)], [4, 6])],
    60: [([(13, 12), (14, 12), (15, 12), (13, 13), (14, 13), (15, 13)], [2, 4, 6]),
         ([(37, 2), (38, 2), (39, 3), (37, 3), (38, 3)], [2, 4, 6]),
         ([(28, 7), (29, 7), (30, 7), (28, 8), (29, 8), (30, 8)], [4, 6])],
}
FISSURE_SCRIPT = "res://scenes/level/scorched/fissure.gd"
# several castles: the castle (0 = the top-left C block, then on in reading order) each spawner's enemies march on,
# by spawner id; a level not listed sends every spawner to the first
SPAWN_CASTLES = {45: [0, 0, 1], 60: [0, 1, 1]}


def paint(level, g, area):
    ground, water, front = {}, {}, {}
    field = set(sw.cell(c, r) for r in range(g.h) for c in range(g.w))
    for k, v in level.cells("FrontTileMapLayer").items():
        # level 13's forest past the edge does not grow in the wastes; a fresh frame keeps nothing of level 13's
        if k not in field and v[0] != lt.FOREST_SOURCE and not g.fresh:
            front[k] = v
    props = PROPS[area]
    for r in range(g.h):
        for c in range(g.w):
            ch, p = g.g[r][c], sw.cell(c, r)
            if ch in TERRAIN:
                ground[p] = (lt.GROUND_SOURCE, (TERRAIN[ch] * lt.TERRAIN_BLOCK, 0), 0)
            else:
                ground[p] = (lt.OLD_GROUND_SOURCE, lt.pick(BASE, level.number, p), 0)
            if ch == "~":
                water[p] = sw.WATER_TILE
            if ch == "X":
                front[p] = ROCK_TILE
            if ch in props:
                front[p] = (PROPS_SOURCE[area], props[ch], 0)
    ends = []
    for c0, r0 in castles(g):
        for dc in range(3):
            for dr in range(3):
                front[sw.cell(c0 + dc, r0 + dr)] = (0, (dc, dr), 0)
        ends.append((c0 + 1, r0 + 2))
    # level 13's swamp surroundings left bog pools past the edge; dark fill again, `surround barren` redoes it
    pools = set(t for pool in lt.BOG_POOLS for t in pool)
    background = level.cells("BackgroundTileMapLayer")
    if g.fresh:
        # a ring of dark fill SURROUND_DEPTH deep: `edge` draws the frame on it, `surround` and `rock` the rest
        background = {}
        for y in range(sw.Y0 - lt.SURROUND_DEPTH, sw.Y0 + g.h + lt.SURROUND_DEPTH):
            for x in range(sw.X0 - lt.SURROUND_DEPTH, sw.X0 + g.w + lt.SURROUND_DEPTH):
                if (x, y) not in field:
                    background[(x, y)] = (0, lt.pick(lt.DARK_FILL, (x, y)), 0)
    for k, (source, tile, _) in list(background.items()):
        if k not in field and source == 0 and tile in pools:
            background[k] = (0, lt.pick(lt.DARK_FILL, k), 0)
        # a taller map covers level 13's bottom frame: under the new ground the old background goes (its rock and
        # river mouths would block those cells); `edge` draws the frame again
        elif k in field and k[1] >= sw.Y0 + H and not g.fresh:
            del background[k]
    level.set_cells("BackgroundTileMapLayer", background)
    level.set_cells("GroundTileMapLayer", ground)
    level.set_cells("WaterTileMapLayer", water)
    level.set_cells("FrontTileMapLayer", front)
    level.set_cells("DecorTileMapLayer", {})
    return ends


def castles(g):
    """the top-left cells of the 3x3 castle blocks, top-left first"""
    left = set(find(g, "C"))
    corners = []
    while left:
        c0, r0 = min(left, key=lambda p: (p[1], p[0]))
        corners.append((c0, r0))
        left -= set((c0 + dc, r0 + dr) for dc in range(3) for dr in range(3))
    return corners


def end_point_name(index):
    return "EndPoint" if index == 0 else "EndPoint%d" % (index + 1)


def nodes(level, g, ends, route, area):
    text = level.text
    text = text.replace('[node name="Level%03d"' % SOURCE_LEVEL, '[node name="Level%03d"' % level.number)
    # level 13's reference may carry a uid or not (references into level_data drop them)
    text = re.sub(r'\[ext_resource type="Resource"(?: uid="[^"]+")? path="res://scenes/level/level_data/level_%03d_data.tres"' % SOURCE_LEVEL,
                  '[ext_resource type="Resource" path="res://scenes/level/level_data/level_%03d_data.tres"' % level.number, text)
    text = re.sub(r'\[ext_resource type="TileSet" uid="[^"]+" path="res://assets/tile_sets/green_land_tile_set.tres"',
                  '[ext_resource type="TileSet" path="%s"' % TILE_SETS[area], text)
    ex, ey = sw.center(*ends[0])
    text = re.sub(r'(\[node name="EndPoint"[^\n]*\]\nposition = )Vector2\([^)]*\)', r'\g<1>Vector2(%d, %d)' % (ex, ey), text)
    # the other castles' end points (several castles share the level's lives)
    text = re.sub(r'\[node name="EndPoint\d+"[^\n]*\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    more = ''.join('[node name="%s" type="Marker2D" parent="."]\nposition = Vector2(%d, %d)\n\n' % ((end_point_name(i),) + sw.center(*end))
                   for i, end in enumerate(ends) if i > 0)
    if more:
        m = re.search(r'\[node name="EndPoint"[^\n]*\]\n(?:[^\[\n][^\n]*\n)*\n?', text)
        text = text[:m.end()] + more + text[m.end():]
    castle_of = SPAWN_CASTLES.get(level.number, [])
    # level 13's bog crossings and spawners go; one plain spawner per S, ids top to bottom
    text = re.sub(r'\[node name="BogCrossing\d*"[^\n]*\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    text = re.sub(r'\[node name="Spawner\d*"[^\n]*\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    ext = '[ext_resource type="PackedScene" path="res://scenes/unit/spawner/spawner.tscn" id="spawner_plain"]\n'
    add = ''
    for sid, (c, r) in enumerate(sorted(find(g, "S"), key=lambda p: (p[1], p[0]))):
        x, y = sw.center(c, r)
        name = "Spawner" if sid == 0 else "Spawner%d" % (sid + 1)
        add += ('[node name="%s" parent="." node_paths=PackedStringArray("end_point", "flight_route") groups=["Spawner"] '
                'instance=ExtResource("spawner_plain")]\nposition = Vector2(%d, %d)\n%send_point = NodePath("../%s")\n'
                'flight_route = NodePath("../FlightRoute")\n\n') % (name, x, y, "id = %d\n" % sid if sid else "",
                                                                   end_point_name(castle_of[sid] if sid < len(castle_of) else 0))
    if ext not in text:
        last_ext = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
        text = text[:last_ext] + ext + text[last_ext:]
    pts = ", ".join("0, 0, 0, 0, %d, %d" % p for p in route)
    text = re.sub(r'("points": PackedVector2Array\()[^)]*\)', r'\g<1>%s)' % pts, text)
    text = re.sub(r'point_count = \d+', 'point_count = %d' % len(route), text)
    text = re.sub(r'\[node name="Fissure\d*"[^\n]*\]\n(?:[^\[\n][^\n]*\n)*\n?', '', text)
    # lava crossings: BogCrossing stepping stones over the lava, for the waders (the magma salamander)
    for i, (entry, exit_cell) in enumerate(g.crossings):
        ex0, ey0 = sw.center(*entry)
        ex1, ey1 = sw.center(*exit_cell)
        add += ('[node name="BogCrossing%d" type="Node2D" parent="."]\nposition = Vector2(%d, %d)\n'
                'script = ExtResource("bog_crossing")\nexit_offset = Vector2(%d, %d)\n\n') % (i, ex0, ey0, ex1 - ex0, ey1 - ey0)
    if g.crossings and 'id="bog_crossing"' not in text:
        last_ext = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
        text = text[:last_ext] + '[ext_resource type="Script" path="%s" id="bog_crossing"]\n' % sw.BOG_CROSSING_SCRIPT + text[last_ext:]
    for i, (cells, waves) in enumerate(FISSURES.get(level.number, []), 1):
        grid_cells = ", ".join("Vector2i(%d, %d)" % sw.cell(c, r) for c, r in cells)
        add += ('[node name="Fissure%d" type="Node2D" parent="."]\nscript = ExtResource("fissure_script")\n'
                'cells = Array[Vector2i]([%s])\nerupt_waves = Array[int]([%s])\n\n') % (i, grid_cells, ", ".join(map(str, waves)))
    if level.number in FISSURES and 'id="fissure_script"' not in text:
        last_ext = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
        text = text[:last_ext] + '[ext_resource type="Script" path="%s" id="fissure_script"]\n' % FISSURE_SCRIPT + text[last_ext:]
    m = re.search(r'\[node name="FlightRoute"[^\n]*\]\n(?:[^\[\n][^\n]*\n)*\n?', text)
    text = text[:m.end()] + add + text[m.end():]
    level.text = text


# levels with flyers: their flight route follows the road from this spawner (id) to its castle, corner to corner, so
# ash drakes and phoenixes fly over the towers that guard the road instead of straight across
# (47 is left out: its flyers come from four sides straight at the island castle)
FLIGHT_FROM = {37: 0, 38: 0, 39: 0, 40: 0, 41: 0, 42: 0, 43: 1, 44: 0, 45: 1, 46: 0, 47: 1, 48: 0, 49: 0, 50: 0, 52: 0,
               54: 0, 55: 0, 56: 1, 57: 0, 58: 0, 59: 1, 60: 1}
WALKABLE = set(".usrhS")


def road_path(g, spawner_id, castle_of):
    """the cells of the shortest road (breadth first over the layout) from the spawner to its castle's gate; empty
    when there is none"""
    spawners = sorted(find(g, "S"), key=lambda p: (p[1], p[0]))
    start = spawners[spawner_id]
    c0, r0 = castles(g)[castle_of[spawner_id] if spawner_id < len(castle_of) else 0]
    goal = (c0 + 1, r0 + 2)
    came = {start: None}
    queue = [start]
    for cell in queue:
        if cell == goal:
            break
        c, r = cell
        for n in ((c - 1, r), (c + 1, r), (c, r - 1), (c, r + 1)):
            if n not in came and 0 <= n[0] < g.w and 0 <= n[1] < g.h and (g.g[n[1]][n[0]] in WALKABLE or n == goal):
                came[n] = cell
                queue.append(n)
    if goal not in came:
        return []
    path = []
    cell = goal
    while cell is not None:
        path.append(cell)
        cell = came.get(cell)
    path.reverse()
    return path


def road_route(g, spawner_id, castle_of):
    """corners of the shortest road from the spawner to its castle's gate, in level coordinates, the spawner's own
    cell left out"""
    path = road_path(g, spawner_id, castle_of)
    corners = [p for i, p in enumerate(path[1:-1], 1)
               if (path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1]) != (path[i + 1][0] - path[i][0], path[i + 1][1] - path[i][1])]
    return [sw.center(*p) for p in corners + [path[-1]]]


# landmarks (32x32, object_tile_set_01 sources 10 and 11: four kinds each, two by two on their 64x64 sheets) and decor
# (decor_tile_set sources 1 and 2: twelve pieces, four by three)
LANDMARK_SOURCE = {"desert": 10, "volcano": 11}
DECOR_SOURCE = {"desert": 1, "volcano": 2}
LANDMARKS_PER_LEVEL = 3
LANDMARK_SPACING = 8
DECOR_PIECES = 12
DECOR_ONE_IN = 9
OPEN = set(".u")


def seeded(*key):
    return zlib.crc32(repr(key).encode())


def place_landmarks(g, number):
    """up to LANDMARKS_PER_LEVEL 2x2 landmarks on open ground: never on or next to a spawner's shortest road, apart
    from each other, and only where every spawner still reaches its castle (marked 'M' in the layout)"""
    castle_of = SPAWN_CASTLES.get(number, [])
    spawner_count = len(find(g, "S"))
    roads = set()
    for sid in range(spawner_count):
        for c, r in road_path(g, sid, castle_of):
            roads |= {(c + dc, r + dr) for dc in (-1, 0, 1) for dr in (-1, 0, 1)}
    spots = []
    for r in range(1, g.h - 2):
        for c in range(1, g.w - 2):
            ring = [(c + dc, r + dr) for dc in range(-1, 3) for dr in range(-1, 3)]
            if all(g.g[y][x] in OPEN for x, y in ring) and not any((c + dc, r + dr) in roads for dc in (0, 1) for dr in (0, 1)):
                spots.append((c, r))
    spots.sort(key=lambda p: seeded(number, p, "landmark"))
    placed = []
    for c, r in spots:
        if len(placed) >= LANDMARKS_PER_LEVEL:
            break
        if any(abs(c - pc) + abs(r - pr) < LANDMARK_SPACING for pc, pr, _ in placed):
            continue
        saved = [g.g[r + dr][c:c + 2] for dr in (0, 1)]
        g.rect(c, r, c + 1, r + 1, "M")
        if all(road_path(g, sid, castle_of) for sid in range(spawner_count)):
            # different kinds within a level, starting from one picked per level
            placed.append((c, r, (seeded(number, "kind") + len(placed)) % 4))
        else:
            for dr in (0, 1):
                g.g[r + dr][c:c + 2] = saved[dr]
    return placed


def decor_cells(g, number, area):
    """about one open ground cell in DECOR_ONE_IN gets a decor piece, picked per cell (stable between rebuilds)"""
    cells = {}
    for r in range(g.h):
        for c in range(g.w):
            if g.g[r][c] in OPEN and seeded(number, c, r, "decor") % DECOR_ONE_IN == 0:
                i = seeded(number, c, r, "piece") % DECOR_PIECES
                cells[sw.cell(c, r)] = (DECOR_SOURCE[area], (i % 4, i // 4), 0)
    return cells


def build(number):
    design, route = LEVELS[number]
    area = area_of(number)
    src = os.path.join(ROOT, lt.LEVEL_PATH % SOURCE_LEVEL)
    dst = os.path.join(ROOT, lt.LEVEL_PATH % number)
    with open(src, encoding="utf8") as f:
        text = f.read()
    # the copy gets its own uid from Godot; keeping level 13's would make references by uid ambiguous
    first = text.index("\n")
    text = re.sub(r' (uid="[^"]+"|load_steps=\d+)', "", text[:first]) + text[first:]
    with open(dst, "w", encoding="utf8", newline="\n") as f:
        f.write(text)
    level = lt.Level(number)
    g = design()
    # every cell conversion below (sw.cell, sw.center) uses this map's origin
    sw.X0, sw.Y0 = g.origin()
    if number in FLIGHT_FROM:
        route = road_route(g, FLIGHT_FROM[number], SPAWN_CASTLES.get(number, []))
    landmarks = place_landmarks(g, number)
    ends = paint(level, g, area)
    front = level.cells("FrontTileMapLayer")
    for c, r, kind in landmarks:
        for dc in (0, 1):
            for dr in (0, 1):
                front[sw.cell(c + dc, r + dr)] = (LANDMARK_SOURCE[area], (kind % 2 * 2 + dc, kind // 2 * 2 + dr), 0)
    level.set_cells("FrontTileMapLayer", front)
    nodes(level, g, ends, route, area)
    level.save()
    tool = os.path.join(ROOT, "tools", "level_tiles.py")
    for args in (["ground"], ["water"], ["edge"], ["surround", "barren"], ["rock"]):
        subprocess.run([sys.executable, tool] + args + [str(number)], check=True, capture_output=True)
    # the ground pass moved the old tiles' grass tufts and flowers to the decor layer: the wastes get their own
    level = lt.Level(number)
    level.set_cells("DecorTileMapLayer", decor_cells(g, number, area))
    level.save()
    print("level %d built (%s)" % (number, area))


if __name__ == "__main__":
    for n in [int(a) for a in sys.argv[1:]] or sorted(LEVELS):
        build(n)
