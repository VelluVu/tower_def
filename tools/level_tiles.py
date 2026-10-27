"""Generate the tile layers around a level's playfield, and render a level to a PNG to look at it.

    python tools/level_tiles.py edge <level numbers...> [--dry] [--variants]
        frame around the playfield (BackgroundTileMapLayer); --variants re-picks the variant of every straight piece
    python tools/level_tiles.py water <level numbers...> [--dry]   retile the water (WaterTileMapLayer)
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


def playfield(level):
    return set(level.cells("GroundTileMapLayer")) | set(level.cells("WaterTileMapLayer"))


def build_edge(level, log, variants=False):
    field = playfield(level)
    background = level.cells("BackgroundTileMapLayer")
    water = set(c for c, (_, t, _) in background.items() if t in BACKGROUND_WATER)
    ring = set(add(c, d) for c in field for d in (N, E, S, W, NE, NW, SE, SW)) - field
    for c in sorted(ring):
        tile = background.get(c, (0, pick(DARK_FILL, c), 0))[1]
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
    background = level.cells("BackgroundTileMapLayer")
    open_water = set(c for c, (_, t, _) in background.items() if t in BACKGROUND_WATER)
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
    if len(args) < 2 or args[0] not in ("edge", "water", "render"):
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
        else:
            build_water(level, log)
        print("level %d%s" % (number, " (dry run)" if dry else ""))
        for entry in log:
            print("  ", *entry)
        if not dry:
            level.save()


if __name__ == "__main__":
    main(sys.argv[1:])
