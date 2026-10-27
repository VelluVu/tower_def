"""Generate the tile layers around a level's playfield, and render a level to a PNG to look at it.

    python tools/level_tiles.py edge <level numbers...> [--dry] [--variants]
        frame around the playfield (BackgroundTileMapLayer); --variants re-picks the variant of every straight piece
    python tools/level_tiles.py water <level numbers...> [--dry]   retile the water (WaterTileMapLayer)
    python tools/level_tiles.py rock <level numbers...> [--dry]    rounded rock (FrontTileMapLayer): every rock
        cell gets the rock_tiles piece for its rock neighbours; cells outside the playfield count as rock
    python tools/level_tiles.py ground <level numbers...> [--dry]  rounded ground (GroundTileMapLayer): old
        terrain tiles become ground_tiles pieces by same-terrain neighbours (water and the map edge count as the
        same), their decor goes to DecorTileMapLayer (added after the ground layer when missing); rerunning
        only re-picks the pieces. Paint new patches with the old terrain tiles, then run it
    python tools/level_tiles.py surround <forest|crossroads|swamp> <level numbers...> [--dry]   what lies past
        the map's edge (forest; forest with bog below; bog pools and dark trees), over the dark fill and the rock band;
        run it after `edge` and before `rock`
    python tools/level_tiles.py falls <level numbers...> [--dry]   the still waterfall pieces become the animated
        waterfall_tiles (BackgroundTileMapLayer source 1)
    python tools/level_tiles.py render <level number> <out.png> [--scale 3]

The playfield is every cell of the ground and water layers. Both generators keep the cells they do not own:
`edge` replaces only dark fill and grass frame tiles next to the playfield (waterfalls, river mouths and the
rock band stay; rock next to the playfield gets its brown rim), `water` keeps the footprint of the water layer
except one-cell tips, and fills a concave corner with a diagonal piece on the land cell (an inner corner tile
when a front layer prop stands there). Waterfalls and river mouths are found from the background layer's water.
Variants are picked from a hash of the cell; a piece that already has a variant of the right kind keeps it
(hand-picked ones too) unless --variants is given, so a rerun gives the same tiles. Reload the level in the editor after.
"""
import base64
import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEVEL_PATH = "scenes/level/levels/level_%03d.tscn"
EMPTY_SOURCE = 0xFFFF
FLIP_H = 1 << 12  # TileSetAtlasSource.TRANSFORM_FLIP_H on the alternative id

N, E, S, W = (0, -1), (1, 0), (0, 1), (-1, 0)
NE, NW, SE, SW = (1, -1), (-1, -1), (1, 1), (-1, 1)

# background_tiles.png (source 0 of background_tile_set.tres), atlas coords
DARK_FILL = [(0, 0), (1, 0), (0, 1), (1, 1)]
NORTH_LIP = [(4, 0), (5, 0), (6, 0), (7, 0)]       # above the playfield
SOUTH_FACE = [(4, 1), (5, 1), (6, 1), (7, 1)]      # cliff face below the playfield
WEST_SIDE = [(2, 0), (2, 1), (2, 2), (2, 3)]       # left of the playfield
EAST_SIDE = [(3, 0), (3, 1), (3, 2), (3, 3)]       # right of the playfield
# rarer variants with stones, roots and a crack (row 13), about one straight piece in five
DETAIL = {
    "face": [(0, 13), (1, 13)], "lip": [(2, 13), (3, 13)], "west": [(4, 13), (5, 13)], "east": [(6, 13), (7, 13)],
}
NORTH_LIP_PICK = NORTH_LIP * 2 + DETAIL["lip"]
SOUTH_FACE_PICK = SOUTH_FACE * 2 + DETAIL["face"]
WEST_SIDE_PICK = WEST_SIDE * 2 + DETAIL["west"]
EAST_SIDE_PICK = EAST_SIDE * 2 + DETAIL["east"]
OUTER = {SE: (1, 2), SW: (6, 12), NE: (0, 3), NW: (9, 10)}  # by the one diagonal that is playfield
INNER = {(N, E): ((0, 2), 0), (N, W): ((4, 12), 0), (S, W): ((5, 12), 0), (S, E): ((5, 12), FLIP_H)}
FACE_END = {E: (9, 10), W: (0, 3)}                 # a cliff face that ends at water on that side
GRASS_FRAME = set(DARK_FILL + NORTH_LIP_PICK + SOUTH_FACE_PICK + WEST_SIDE_PICK + EAST_SIDE_PICK + list(OUTER.values())
                  + [t for t, _ in INNER.values()] + [(1, 3)])
ROCK_EDGE = {W: [(3, 8), (3, 9)], E: [(2, 8), (2, 9)], S: [(4, 7), (5, 7), (6, 7), (7, 7)]}
ROCK_CORNER = {(S, W): (2, 5), (S, E): (3, 5)}
ROCK = set([(x, y) for x in (0, 1) for y in (6, 7, 8, 9)] + [(x, y) for x in range(4, 8) for y in (4, 5, 8, 9)]
           + [t for ts in ROCK_EDGE.values() for t in ts] + list(ROCK_CORNER.values()))
BACKGROUND_WATER = set([(8, 0), (9, 0), (8, 1), (9, 1), (0, 4), (1, 4), (0, 5), (1, 5), (7, 12), (8, 12)]
                       + [(x, y) for x in range(4, 10) for y in (2, 3)])
# waterfall_tiles.png (source 1 of background_tile_set.tres): the animated left (0, 0) and right (0, 1) pieces that
# replace the still waterfall (7, 12) and (8, 12)
FALLS_SOURCE = 1
FALLS = {(7, 12): (0, 0), (8, 12): (0, 1)}

# water_animated_tile_set.png (source 2 of basic_water_tile_set.tres), tiles in column 0, y = index
WATER_SOURCE = 2
CENTERS = [37, 38, 39, 40, 37, 38, 39, 40, 33, 34, 35, 36]
RIPPLE = {"/": [0, 2], "\\": [1, 3]}
EDGE = {N: 11, S: 12, W: 9, E: 10}
FOAM = {frozenset(): 55, frozenset([W]): 56, frozenset([E]): 57}
INNER_WATER = {NW: 45, NE: 46, SW: 47, SE: 48}
# land sides -> (square, round, rough corner), (straight, rough, round diagonal), diagonal slope
CORNER = {
    frozenset([N, W]): ((16, 19, 23), (27, 31, 43), "/"),
    frozenset([N, E]): ((14, 20, 24), (28, 32, 44), "\\"),
    frozenset([S, W]): ((15, 17, 21), (25, 29, 41), "\\"),
    frozenset([S, E]): ((13, 18, 22), (26, 30, 42), "/"),
}

# rock_tiles.png (source 4 of object_tile_set_01.tres): tile (col, row) = 16 neighbour masks x the 2x2 positions
# of its stone pattern (see rock_tiles.txt); the square rocks of green_land_props (source 2) are replaced by it
ROCK_SOURCE = 4
OLD_ROCK_SOURCE = 2
OLD_ROCK = set([(8, 0), (9, 0), (10, 0), (8, 1), (9, 1), (10, 1), (8, 2), (9, 2), (10, 2)])
ROCK_MASK_BITS = ((N, 1), (E, 2), (S, 4), (W, 8))
SPAWN_POINTS = "scenes/unit/spawner/spawn_points/"
# terraces outside the map: rock_tiles at height 1 (source 4), _high at 2 (5), _peak at 3 (6)
ROCK_SOURCES = (ROCK_SOURCE, 5, 6)
TERRACE_GROWTH = 3
# surroundings past the map's edge (`surround`): props of object tile set source 2, background pools for bog
FOREST_SOURCE = 2
SURROUND_DEPTH = 4
BOG_POOLS = [[(8, 0), (9, 0), (8, 1), (9, 1)], [(6, 2), (7, 2), (6, 3), (7, 3)], [(8, 2), (9, 2), (8, 3), (9, 3)],
             [(0, 4), (1, 4), (0, 5), (1, 5)]]
ROCK_FILL = [(0, 6), (0, 7), (0, 8), (0, 9), (1, 7), (1, 8), (1, 9)]  # background_tiles stone without rims
# the rim and ends of the rock band under the map (river-mouth gaps), shaped with the rest of the outside rock
ROCK_BAND_RIM = set([(x, 6) for x in range(4, 8)] + [(2, 7), (3, 7), (4, 10), (5, 10)])

# green_land_tile_set.tres: source 1 is the old terrain sheet (green_land.png, painted with Godot terrains),
# source 2 the rounded pieces (ground_tiles.png): block = terrain (0 grass, 1 less green, 2 pale sand, 3 sand,
# 4 red), 8x8 tiles, picked like the rock; the old tiles' decor moves to DecorTileMapLayer (decor_tile_set.tres,
# decor_tiles.png: old tile (ox, oy) shuffled, variant v at (ox*4 + v, oy))
GROUND_TILE_SET = "assets/tile_sets/green_land_tile_set.tres"
OLD_GROUND_SOURCE = 1
GROUND_SOURCE = 2
TERRAIN_BLOCK = 8
DECOR_LAYER = "DecorTileMapLayer"
DECOR_TILE_SET = "res://assets/tile_sets/decor_tile_set.tres"
DECOR_VARIANTS = 4


def add(c, d):
    return (c[0] + d[0], c[1] + d[1])


def pick(options, *key):
    return options[zlib.crc32(repr(key).encode()) % len(options)]


class Level:
    def __init__(self, number):
        self.number = number
        self.path = os.path.join(ROOT, LEVEL_PATH % number)
        with open(self.path, encoding="utf8") as f:
            self.text = f.read()

    def _match(self, layer):
        m = re.search(r'name="%s".*?tile_map_data = PackedByteArray\("([^"]*)"\)' % layer, self.text, re.S)
        if m is None:
            sys.exit("%s has no %s with tiles" % (self.path, layer))
        return m

    def cells(self, layer):
        data = base64.b64decode(self._match(layer).group(1))
        out = {}
        for i in range(2, len(data) - 11, 12):
            x, y, source, ax, ay, alt = struct.unpack("<hhHHHH", data[i:i + 12])
            if source != EMPTY_SOURCE:
                out[(x, y)] = (source, (ax, ay), alt)
        return out

    def set_cells(self, layer, cells):
        m = self._match(layer)
        data = bytearray(base64.b64decode(m.group(1))[:2])
        for (x, y), (source, (ax, ay), alt) in sorted(cells.items(), key=lambda kv: (kv[0][1], kv[0][0])):
            data += struct.pack("<hhHHHH", x, y, source, ax, ay, alt)
        self.text = self.text[:m.start(1)] + base64.b64encode(bytes(data)).decode() + self.text[m.end(1):]

    def save(self):
        with open(self.path, "w", encoding="utf8", newline="\n") as f:
            f.write(self.text)

    def tile_sets(self):
        ext = dict((m.group(2), m.group(1)) for m in re.finditer(
            r'\[ext_resource type="TileSet"[^\]]*path="([^"]+)" id="([^"]+)"', self.text))
        out = {}
        for m in re.finditer(r'\[node name="(\w+)" type="TileMapLayer"[^\n]*\n(.*?)(?=\n\[|\Z)', self.text, re.S):
            ts = re.search(r'tile_set = ExtResource\("([^"]+)"\)', m.group(2))
            if ts:
                out[m.group(1)] = ext[ts.group(1)]
        return out


def background_water(background):
    return set(c for c, (s, t, _) in background.items() if s == FALLS_SOURCE or (s == 0 and t in BACKGROUND_WATER))


def build_falls(level, log):
    background = level.cells("BackgroundTileMapLayer")
    for c, (source, tile, alt) in background.items():
        if source == 0 and tile in FALLS:
            background[c] = (FALLS_SOURCE, FALLS[tile], 0)
            log.append(("waterfall", c))
    level.set_cells("BackgroundTileMapLayer", background)


def playfield(level):
    return set(level.cells("GroundTileMapLayer")) | set(level.cells("WaterTileMapLayer"))


def build_edge(level, log, variants=False):
    field = playfield(level)
    background = level.cells("BackgroundTileMapLayer")
    water = background_water(background)
    ring = set(add(c, d) for c in field for d in (N, E, S, W, NE, NW, SE, SW)) - field
    for c in sorted(ring):
        source, tile, _ = background.get(c, (0, pick(DARK_FILL, c), 0))
        if source != 0:
            continue  # the animated waterfall
        sides = [d for d in (N, E, S, W) if add(c, d) in field]
        if tile in ROCK:
            new = _rock_edge(c, sides)
        elif tile in GRASS_FRAME:
            new = _grass_edge(c, sides, field, water, log)
        else:
            continue
        if new is not None and (variants or not _same_piece(background.get(c), new)):
            background[c] = (0, new[0], new[1])
    level.set_cells("BackgroundTileMapLayer", background)


def _same_piece(current, new):
    """A hand-picked variant of the right piece stays."""
    if current is None or current[2] != new[1]:
        return False
    variants = [DARK_FILL, NORTH_LIP_PICK, SOUTH_FACE_PICK, WEST_SIDE_PICK, EAST_SIDE_PICK] + list(ROCK_EDGE.values())
    return any(current[1] in group and new[0] in group for group in variants)


def _rock_edge(c, sides):
    for pair, tile in ROCK_CORNER.items():
        if set(pair) == set(sides):
            return tile, 0
    if len(sides) == 1 and sides[0] in ROCK_EDGE:
        return pick(ROCK_EDGE[sides[0]], c), 0
    return None


def _grass_edge(c, sides, field, water, log):
    if (N in sides and S in sides) or (E in sides and W in sides) or len(sides) > 2:
        log.append(("no frame piece for playfield on %s sides" % len(sides), c))
        return None
    if len(sides) == 2:
        key = (sides[0], sides[1]) if (sides[0], sides[1]) in INNER else (sides[1], sides[0])
        return INNER[key]
    if sides == [N]:
        for d, tile in FACE_END.items():
            if add(c, d) in water:
                return tile, 0
        return pick(SOUTH_FACE_PICK, c), 0
    if sides:
        return pick({S: NORTH_LIP_PICK, E: WEST_SIDE_PICK, W: EAST_SIDE_PICK}[sides[0]], c), 0
    corners = [d for d in OUTER if add(c, d) in field]
    if len(corners) == 1:
        return OUTER[corners[0]], 0
    return pick(DARK_FILL, c), 0


def build_water(level, log):
    cells = level.cells("WaterTileMapLayer")
    mask = set(cells)
    ground = set(level.cells("GroundTileMapLayer"))
    open_water = background_water(level.cells("BackgroundTileMapLayer"))
    front = set(level.cells("FrontTileMapLayer"))
    changed = True
    while changed:
        changed = False
        wet = mask | open_water
        for c in sorted(mask):
            land = [d for d in (N, E, S, W) if add(c, d) not in wet]
            if len(land) >= 3 or (N in land and S in land) or (E in land and W in land):
                mask.discard(c)
                log.append(("removed a one-cell tip", c))
                changed = True
        for c in sorted(ground - mask):
            if sum(add(c, d) in wet for d in (N, E, S, W)) >= 3:
                mask.add(c)
                log.append(("filled a notch", c))
                changed = True
    wet = mask | open_water
    diagonal = {}
    for c in sorted(ground - wet):
        water_sides = [d for d in (N, E, S, W) if add(c, d) in wet]
        if len(water_sides) != 2:
            continue
        a, b = water_sides
        if a[0] + b[0] == 0 and a[1] + b[1] == 0 or add(add(c, a), b) not in wet:
            continue
        if c in front:
            continue  # the water cells get inner corners instead
        diagonal[c] = frozenset(d for d in (N, E, S, W) if d not in water_sides)
        log.append(("diagonal on land", c))

    def is_wet(c, d):
        n = add(c, d)
        return n in wet or (n in diagonal and (-d[0], -d[1]) not in diagonal[n])

    out, slopes = {}, {}
    for c, land in diagonal.items():
        _, diagonals, slope = CORNER[land]
        out[c], slopes[c] = pick(diagonals, level.number, c), slope
    for c in mask:
        land = frozenset(d for d in (N, E, S, W) if not is_wet(c, d))
        if add(c, N) in open_water and land in FOAM:
            out[c] = FOAM[land]
        elif len(land) == 1:
            out[c] = EDGE[next(iter(land))]
        elif len(land) == 2:
            corners, diagonals, slope = CORNER[land]
            if pick([True, True, False, False, False], level.number, c, "diagonal"):
                out[c], slopes[c] = pick(diagonals, level.number, c), slope
            else:
                out[c] = pick(corners, level.number, c, "corner")
    for c in mask:
        if c in out:
            continue
        inner = [d for d in INNER_WATER if add(c, d) not in wet and add(c, d) not in diagonal]
        near = [slopes[add(c, d)] for d in (N, E, S, W) if add(c, d) in slopes]
        if inner:
            out[c] = INNER_WATER[inner[0]]
        elif near and pick([True, False], level.number, c, "ripple"):
            out[c] = pick(RIPPLE[near[0]], level.number, c)
        else:
            out[c] = pick(CENTERS, level.number, c, "center")
    level.set_cells("WaterTileMapLayer", dict((c, (WATER_SOURCE, (0, i), 0)) for c, i in out.items()))


def spawn_squares(level):
    """mouth cell -> the other cells of its 3x3 square, for every spawn point scene (spawn_points/*.tscn) placed"""
    ext = dict((m.group(2), m.group(1)) for m in re.finditer(
        r'\[ext_resource type="PackedScene"[^\]]*path="([^"]+)" id="([^"]+)"', level.text))
    squares = {}
    for m in re.finditer(r'\[node [^\n]*instance=ExtResource\("([^"]+)"\)\]\n(.*?)(?=\n\[|\Z)', level.text, re.S):
        pos = re.search(r"^position = Vector2\(([-\d.]+), ([-\d.]+)\)", m.group(2), re.M)
        if SPAWN_POINTS not in ext.get(m.group(1), "") or pos is None:
            continue
        mouth = (int(float(pos.group(1)) // 16), int(float(pos.group(2)) // 16))
        squares[mouth] = [(mouth[0] + dx, mouth[1] + dy) for dy in (-2, -1, 0) for dx in (-1, 0, 1) if (dx, dy) != (0, 0)]
    return squares


def _shape_outside_rock(level, field, spawn_cells, log):
    """The rock fill around the map (background ROCK pieces) gets rounded rock on the front layer, with a few spurs
    into the dark so it reads as a mountain edge, not a rectangle. The dark fill goes under every piece that does
    not touch the playfield, so the rounded corners show the dark; run `edge` before this, not after."""
    background = level.cells("BackgroundTileMapLayer")
    shaped = set(c for c, (s, _, _) in level.cells("FrontTileMapLayer").items() if s in ROCK_SOURCES and c not in field and c not in spawn_cells)
    if shaped:
        return shaped  # shaped on an earlier run: keep it, so a rerun does not grow more spurs
    outside = set(c for c, (s, t, _) in background.items() if s == 0 and (t in ROCK or t in ROCK_BAND_RIM) and c not in field)
    spurs = set()
    for c in sorted(outside):
        for d in (N, E, S, W):
            n = add(c, d)
            if n in field or n in outside or (n in background and background[n][1] not in DARK_FILL):
                continue
            if pick([True, False, False], level.number, c, d, "spur"):
                spurs.add(n)
                far = add(n, d)
                if far not in field and far not in background and pick([True, False, False, False], level.number, n, "peak"):
                    spurs.add(far)
    for c in outside | spurs:
        touches_field = any(add(c, d) in field for d in (N, E, S, W))
        # plain stone under the edge toward the map (no gap opens there), the dark under the outer edges
        background[c] = (0, pick(ROCK_FILL, c) if touches_field else pick(DARK_FILL, c), 0)
    level.set_cells("BackgroundTileMapLayer", background)
    log.append(("outside rock", len(outside), "spurs", len(spurs)))
    return outside | spurs


def _grow_terraces(level, field, outside, log):
    """The outside rock climbs away from the map: it grows up to TERRACE_GROWTH cells into the dark (once), and each
    cell's height is its distance from the map (1-3). Stone goes under the pieces inside the mass and the dark under
    its outer edge, so the rounded corners show the step below or the dark."""
    background = level.cells("BackgroundTileMapLayer")
    grown = set(outside)
    if not any(s in ROCK_SOURCES[1:] for s, _, _ in level.cells("FrontTileMapLayer").values()):
        frontier = set(outside)
        for _ in range(TERRACE_GROWTH):
            new = set()
            for c in frontier:
                for d in (N, E, S, W):
                    n = add(c, d)
                    if n in field or n in grown or (n in background and (background[n][0] != 0 or background[n][1] not in DARK_FILL)):
                        continue
                    new.add(n)
            grown |= new
            frontier = new
        log.append(("terraces grown", len(grown) - len(outside)))
    height = {}
    for c in grown:
        distance = min(max(abs(c[0] - f[0]), abs(c[1] - f[1])) for f in field if abs(c[0] - f[0]) <= 4 and abs(c[1] - f[1]) <= 4)             if any(abs(c[0] - f[0]) <= 4 and abs(c[1] - f[1]) <= 4 for f in field) else 4
        height[c] = max(1, min(len(ROCK_SOURCES), distance))
    for c in grown:
        edge = any(add(c, d) not in grown and add(c, d) not in field for d in (N, E, S, W))
        touches_field = any(add(c, d) in field for d in (N, E, S, W))
        background[c] = (0, pick(ROCK_FILL, c) if touches_field or not edge else pick(DARK_FILL, c), 0)
    level.set_cells("BackgroundTileMapLayer", background)
    return height


def build_rock(level, log):
    front = level.cells("FrontTileMapLayer")
    rock = set(c for c, (source, t, _) in front.items()
               if source in ROCK_SOURCES or (source == OLD_ROCK_SOURCE and t in OLD_ROCK))
    field = playfield(level)
    # a spawn's cave is a mouth in the rock: rock on its square, and the mouth counts as rock for the neighbours
    squares = spawn_squares(level)
    mouths = set(squares)
    for cells in squares.values():
        rock |= set(cells)
    rock -= mouths
    for c in mouths:
        if c in front and front[c][0] in ROCK_SOURCES:
            del front[c]
    spawn_cells = set(c for cells in squares.values() for c in cells)
    outside = _shape_outside_rock(level, field, spawn_cells, log)
    height = _grow_terraces(level, field, outside - spawn_cells, log)
    rock |= set(height)
    background = level.cells("BackgroundTileMapLayer")

    def level_of(c):
        return height.get(c, 1)

    def is_rock(c, n):
        if n in mouths:
            return True
        if n in rock:
            return level_of(n) >= level_of(c)  # a higher step shows its rim and face over a lower one
        # outside the map: the border cliff continues the rock, the dark fill, the grass frame and nothing do not
        return n not in field and n in background and background[n][0] == 0 and background[n][1] in ROCK

    for c in sorted(rock, key=lambda c: (c[1], c[0])):
        mask = sum(bit for d, bit in ROCK_MASK_BITS if is_rock(c, add(c, d)))
        tile = ((mask % 4) * 2 + c[0] % 2, (mask // 4) * 2 + c[1] % 2)
        source = ROCK_SOURCES[level_of(c) - 1]
        if front.get(c) != (source, tile, 0):
            log.append(("rock", c, "mask", mask))
        front[c] = (source, tile, 0)
    level.set_cells("FrontTileMapLayer", front)


def _outside_distance(c, field, limit):
    near = [max(abs(c[0] - f[0]), abs(c[1] - f[1])) for f in field if abs(c[0] - f[0]) <= limit and abs(c[1] - f[1]) <= limit]
    return min(near) if near else limit + 1


def _forest_piece(c, forest):
    """a piece of the big forest block (props sheet 7-10, 5-7): canopy tops, middles and trunks, edge columns"""
    top = add(c, N) not in forest
    bottom = add(c, S) not in forest
    row = 5 if top else (7 if bottom else 6)
    if add(c, W) not in forest:
        col = 7
    elif add(c, E) not in forest:
        col = 10
    else:
        col = 8 + c[0] % 2
    return (FOREST_SOURCE, (col, row), 0)


def build_surroundings(level, theme, log):
    """What lies past the map's edge, from the level's story: forest, forest with bog toward the bottom
    (crossroads), or swamp (bog pools and dark trees). It fills SURROUND_DEPTH cells outside the playfield where the
    background is dark fill or the grey rock band, and leaves the grass frame, waterfalls and spawn rock alone."""
    field = playfield(level)
    background = level.cells("BackgroundTileMapLayer")
    front = level.cells("FrontTileMapLayer")
    spawn_cells = set(c for cells in spawn_squares(level).values() for c in cells)
    xs, ys = [c[0] for c in field], [c[1] for c in field]
    free = set()
    for y in range(min(ys) - SURROUND_DEPTH, max(ys) + SURROUND_DEPTH + 1):
        for x in range(min(xs) - SURROUND_DEPTH, max(xs) + SURROUND_DEPTH + 1):
            c = (x, y)
            if c in field or c in spawn_cells or _outside_distance(c, field, SURROUND_DEPTH) > SURROUND_DEPTH:
                continue
            source, tile, _ = background.get(c, (0, DARK_FILL[0], 0))
            if source == 0 and (tile in DARK_FILL or tile in ROCK or tile in ROCK_BAND_RIM):
                free.add(c)
    bottom_row = max(ys)
    bog = set()
    if theme in ("crossroads", "swamp"):
        # 2x2 pools scattered in a shuffled order, some left out, never touching another pool
        for c in sorted(free, key=lambda c: zlib.crc32(repr((level.number, c, "bog")).encode())):
            if theme == "crossroads" and c[1] <= bottom_row:
                continue
            square = [c, add(c, E), add(c, S), add(c, SE)]
            near = set((x + dx, y + dy) for x, y in square for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            if not all(s in free for s in square) or near & bog or not pick([True, False], level.number, c, "pool"):
                continue
            pool = pick(BOG_POOLS, level.number, c)
            for s, tile in zip(square, pool):
                bog.add(s)
                background[s] = (0, tile, 0)
    for c in free - bog:
        background[c] = (0, pick(DARK_FILL, c), 0)
    for c in free:
        if c in front:
            del front[c]
    if theme == "swamp" or theme == "crossroads":
        trees = free - bog
        if theme == "crossroads":
            forest = set(c for c in trees if c[1] <= bottom_row)
            trees -= forest
        else:
            forest = set()
        for c in sorted(trees):
            if pick([True, False, False], level.number, c, "tree") and add(c, S) in trees and add(c, N) not in bog:
                front[c] = (FOREST_SOURCE, (0, 3), 0)
                front[add(c, S)] = (FOREST_SOURCE, (0, 4), 0)
    else:
        forest = free
    for c in forest:
        front[c] = _forest_piece(c, forest)
    level.set_cells("BackgroundTileMapLayer", background)
    level.set_cells("FrontTileMapLayer", front)
    log.append((theme, len(free), "cells", len(bog), "bog"))


def _old_ground_tiles():
    """terrain per old atlas tile, and the old tiles whose eight peering bits are all their own terrain"""
    with open(os.path.join(ROOT, GROUND_TILE_SET), encoding="utf8") as f:
        text = f.read()
    block = text[text.index('[sub_resource type="TileSetAtlasSource"'):]
    block = block[:block.index("\n[", 1)]
    props = {}
    for m in re.finditer(r"^(\d+):(\d+)/0/([\w/]+) = (\w+)$", block, re.M):
        props.setdefault((int(m.group(1)), int(m.group(2))), {})[m.group(3)] = m.group(4)
    terrain = dict((t, int(p["terrain"])) for t, p in props.items() if "terrain" in p)
    full = set(t for t, p in props.items() if t in terrain and
               [v for k, v in p.items() if k.startswith("terrains_peering_bit")] == [p["terrain"]] * 8)
    return terrain, full


def _decor_tiles():
    with open(os.path.join(ROOT, DECOR_TILE_SET.replace("res://", "")), encoding="utf8") as f:
        return set((int(m.group(1)), int(m.group(2))) for m in re.finditer(r"^(\d+):(\d+)/0 = 0$", f.read(), re.M))


def _ensure_layer(level, name, tile_set, after):
    if 'name="%s"' % name in level.text:
        return
    ext_id = "decor_tile_set"
    if 'id="%s"' % ext_id not in level.text:
        last = [m.end() for m in re.finditer(r"\[ext_resource [^\n]*\]\n", level.text)][-1]
        level.text = level.text[:last] + '[ext_resource type="TileSet" path="%s" id="%s"]\n' % (tile_set, ext_id) + level.text[last:]
    m = re.search(r'\[node name="%s" type="TileMapLayer" parent="([^"]+)"[^\n]*\]\n.*?(?=\n\[)' % after, level.text, re.S)
    node = ('\n\n[node name="%s" type="TileMapLayer" parent="%s"]\nz_index = -1\ntile_map_data = PackedByteArray("AAA=")\n'
            'tile_set = ExtResource("%s")\n' % (name, m.group(1), ext_id))
    level.text = level.text[:m.end()] + node + level.text[m.end():]


def build_ground(level, log):
    old_terrain, old_full = _old_ground_tiles()
    decor_tiles = _decor_tiles()
    ground = level.cells("GroundTileMapLayer")
    water = set(level.cells("WaterTileMapLayer"))
    front = set(level.cells("FrontTileMapLayer"))
    _ensure_layer(level, DECOR_LAYER, DECOR_TILE_SET, "GroundTileMapLayer")
    decor = level.cells(DECOR_LAYER)

    terrain = {}
    for c, (source, t, _) in ground.items():
        if source == GROUND_SOURCE:
            terrain[c] = t[0] // TERRAIN_BLOCK
        elif source == OLD_GROUND_SOURCE:
            terrain[c] = old_terrain.get(t, 0)
            variant = (ord(pick("abcd", level.number, c, "decor")) - ord("a")) % DECOR_VARIANTS
            tile = (t[0] * DECOR_VARIANTS + variant, t[1])
            if t in old_full and tile in decor_tiles and c not in water and c not in front:
                decor[c] = (0, tile, 0)

    def same(c, d):
        n = add(c, d)
        return n not in terrain or n in water or terrain[n] == terrain[c]

    for c in sorted(terrain, key=lambda c: (c[1], c[0])):
        if terrain[c] == 0:
            tile = (0, 0)
        else:
            mask = sum(bit for d, bit in ROCK_MASK_BITS if same(c, d))
            tile = (terrain[c] * TERRAIN_BLOCK + (mask % 4) * 2 + c[0] % 2, (mask // 4) * 2 + c[1] % 2)
        if ground[c] != (GROUND_SOURCE, tile, 0):
            log.append(("ground", c, "terrain", terrain[c]))
        ground[c] = (GROUND_SOURCE, tile, 0)
    level.set_cells("GroundTileMapLayer", ground)
    level.set_cells(DECOR_LAYER, decor)


def render(level, out_path, scale):
    from PIL import Image
    textures = {}
    for layer, tile_set in level.tile_sets().items():
        with open(os.path.join(ROOT, tile_set.replace("res://", "")), encoding="utf8") as f:
            text = f.read()
        ext = dict((m.group(2), m.group(1)) for m in re.finditer(
            r'\[ext_resource type="Texture2D"[^\]]*path="([^"]+)" id="([^"]+)"', text))
        subs = dict((m.group(1), m.group(2)) for m in re.finditer(
            r'\[sub_resource type="TileSetAtlasSource" id="([^"]+)"\]\ntexture = ExtResource\("([^"]+)"\)', text))
        textures[layer] = dict((int(m.group(1)), Image.open(os.path.join(ROOT, ext[subs[m.group(2)]].replace(
            "res://", ""))).convert("RGBA")) for m in re.finditer(r'sources/(\d+) = SubResource\("([^"]+)"\)', text))
    layers = [(name, level.cells(name)) for name in textures]
    every = [c for _, cells in layers for c in cells]
    x0, y0 = min(c[0] for c in every), min(c[1] for c in every)
    x1, y1 = max(c[0] for c in every), max(c[1] for c in every)
    img = Image.new("RGBA", ((x1 - x0 + 1) * 16, (y1 - y0 + 1) * 16), (31, 20, 25, 255))
    for name, cells in layers:
        for (x, y), (source, (ax, ay), alt) in cells.items():
            if source not in textures[name]:
                continue
            tile = textures[name][source].crop((ax * 16, ay * 16, ax * 16 + 16, ay * 16 + 16))
            if alt & FLIP_H:
                tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
            img.alpha_composite(tile, ((x - x0) * 16, (y - y0) * 16))
    img.resize((img.width * scale, img.height * scale), Image.NEAREST).save(out_path)
    print("%s: cells %d,%d to %d,%d" % (out_path, x0, y0, x1, y1))


def main(args):
    if len(args) < 2 or args[0] not in ("edge", "water", "rock", "ground", "falls", "surround", "render"):
        sys.exit(__doc__)
    if args[0] == "render":
        scale = int(args[args.index("--scale") + 1]) if "--scale" in args else 3
        render(Level(int(args[1])), args[2], scale)
        return
    dry = "--dry" in args
    for number in [int(a) for a in args[1:] if a.isdigit()]:
        level = Level(number)
        log = []
        if args[0] == "edge":
            build_edge(level, log, "--variants" in args)
        elif args[0] == "rock":
            build_rock(level, log)
        elif args[0] == "ground":
            build_ground(level, log)
        elif args[0] == "falls":
            build_falls(level, log)
        elif args[0] == "surround":
            build_surroundings(level, args[1], log)
        else:
            build_water(level, log)
        print("level %d%s" % (number, " (dry run)" if dry else ""))
        for entry in log:
            print("  ", *entry)
        if not dry:
            level.save()


if __name__ == "__main__":
    main(sys.argv[1:])
