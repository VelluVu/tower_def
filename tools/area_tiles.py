"""Area versions of the rock and water tiles: the Swamp gets mossy dark stone and murky water, the human Fields warm
sandstone, the ash desert pale sandstone, the volcano black basalt and lava for water (the Caves keep the grey
stone and the forest's blue water). Recolours the rock sheets and the water sheet
by colour role, writes area copies of the object and water tile sets that point at them (every tile keeps its
TileType data), and points each level at its area's sets.

    python tools/area_tiles.py

Rerun after swamp_levels.py or field_levels.py rebuilt a level (they copy Serpent Road, which is a swamp level now,
so a field level would come out with swamp rock until this runs).
"""
import os
import re
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILES = os.path.join(ROOT, "assets", "art", "tiles")
SETS = os.path.join(ROOT, "assets", "tile_sets")
LEVELS = os.path.join(ROOT, "scenes", "level", "levels")
ROCK_SHEETS = ("rock_tiles", "rock_tiles_high", "rock_tiles_peak")
OBJECT_SET = "object_tile_set_01.tres"
WATER_SET = "basic_water_tile_set.tres"
WATER_SHEET = "water/water_animated_tile_set.png"
BACKGROUND_SET = "background_tile_set.tres"
BACKGROUND_SHEET = "green_land/background_tiles.png"
WATERFALL_SHEET = "water/waterfall_tiles.png"

# grey stone ramp of rock_tiles*.png -> the area's stone
ROCK = {
    "swamp": {"262b44": "1b2a26", "31353b": "243530", "3a3e45": "2d3f36", "4a5058": "3e5244", "515661": "4a5e4c",
              "5e656e": "5a6e56", "6a717a": "6b7d62", "8b9bb4": "8fa47a"},
    "humans": {"262b44": "3e2731", "31353b": "4f3a35", "3a3e45": "5e463c", "4a5058": "7a5c48", "515661": "8a6a52",
               "5e656e": "9c7a5c", "6a717a": "b08c68", "8b9bb4": "d2b48c"},
    # wind-scoured pale sandstone
    "desert": {"262b44": "6a4630", "31353b": "7e5638", "3a3e45": "93683f", "4a5058": "a87a4a", "515661": "b88a56",
               "5e656e": "c89c64", "6a717a": "d8b07a", "8b9bb4": "f0d8a8"},
    # black basalt
    "volcano": {"262b44": "0f0b14", "31353b": "181420", "3a3e45": "201a28", "4a5058": "2c2432", "515661": "352c3a",
                "5e656e": "443a48", "6a717a": "54485a", "8b9bb4": "7a6a7e"},
}
WATER = {
    "swamp": {"124e89": "2a4a35", "0b6eac": "3a5e3f", "0878b7": "46704a", "0683c3": "557f55", "038ecf": "628c5c",
              "5a6988": "4f5e48", "8b9bb4": "7c8f6a", "c0cbdc": "a8b88e",
              # the deep pools of the background sheet
              "0b3257": "223a2c", "07466e": "2e4a36"},
    # the volcano's water is lava: glowing in the middle, dark crust at the shore (the desert keeps blue oases)
    "volcano": {"124e89": "8b2330", "0b6eac": "b8302c", "0878b7": "d8462e", "0683c3": "f06a2a", "038ecf": "fea040",
                "5a6988": "3e2731", "8b9bb4": "733e39", "c0cbdc": "fee761", "0b3257": "5d1d2c", "07466e": "7a2230"},
}
# level number ranges per area (the rest keep the shared sets)
AREA_LEVELS = {"swamp": range(13, 25), "humans": range(25, 37), "desert": range(37, 49), "volcano": range(49, 61)}


def recolour(src, dst, mapping):
    image = Image.open(src).convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            new = mapping.get("%02x%02x%02x" % (r, g, b))
            if new:
                pixels[x, y] = (int(new[0:2], 16), int(new[2:4], 16), int(new[4:6], 16), a)
    image.save(dst)


def copy_set(source_name, target_name, swaps):
    text = open(os.path.join(SETS, source_name), encoding="utf8").read()
    first = text.index("\n")
    # a copy must not keep the source's uid
    text = re.sub(r' uid="[^"]+"', "", text[:first]) + text[first:]
    for old, new in swaps.items():
        text, n = re.subn(r'\[ext_resource type="Texture2D"(?: uid="[^"]+")? path="%s"' % re.escape(old),
                          '[ext_resource type="Texture2D" path="%s"' % new, text)
        assert n == 1, (source_name, old)
    open(os.path.join(SETS, target_name), "w", encoding="utf8", newline="\n").write(text)


def set_name(kind, area):
    """the area's own tile set of a kind, or None when it shares the base one"""
    if kind == "object":
        return "object_tile_set_%s.tres" % area if area in ROCK else None
    if kind == "water":
        return "%s_water_tile_set.tres" % area if area in WATER else None
    return "background_tile_set_%s.tres" % area if area in WATER else None


BASE_SETS = {"object": OBJECT_SET, "water": WATER_SET, "background": BACKGROUND_SET}


def point_levels():
    """Every area level gets its area's set of each kind, or the base set when the area has none; whatever set it
    had before (the base one, or another area's from the level it was copied from) is replaced."""
    areas = sorted(set(ROCK) | set(WATER))
    for area, numbers in AREA_LEVELS.items():
        for number in numbers:
            path = os.path.join(LEVELS, "level_%03d.tscn" % number)
            if not os.path.exists(path):
                continue
            text = open(path, encoding="utf8").read()
            for kind, base in BASE_SETS.items():
                names = [base] + [n for n in (set_name(kind, a) for a in areas) if n]
                pattern = r'\[ext_resource type="TileSet"(?: uid="[^"]+")? path="res://assets/tile_sets/(%s)"' % "|".join(re.escape(n) for n in names)
                new = set_name(kind, area) or base
                text = re.sub(pattern, '[ext_resource type="TileSet" path="res://assets/tile_sets/%s"' % new, text)
            open(path, "w", encoding="utf8", newline="\n").write(text)


def main():
    for area, mapping in ROCK.items():
        os.makedirs(os.path.join(TILES, area), exist_ok=True)
        swaps = {}
        for sheet in ROCK_SHEETS:
            recolour(os.path.join(TILES, "props", sheet + ".png"), os.path.join(TILES, area, "%s_%s.png" % (area, sheet)), mapping)
            swaps["res://assets/art/tiles/props/%s.png" % sheet] = "res://assets/art/tiles/%s/%s_%s.png" % (area, area, sheet)
        object_set = "object_tile_set_%s.tres" % area
        copy_set(OBJECT_SET, object_set, swaps)
        print("%s: rock sheets, %s" % (area, object_set))
    for area, mapping in WATER.items():
        dst = os.path.join(TILES, area, "%s_water_animated_tile_set.png" % area)
        recolour(os.path.join(TILES, WATER_SHEET), dst, mapping)
        water_set = "%s_water_tile_set.tres" % area
        copy_set(WATER_SET, water_set, {"res://assets/art/tiles/%s" % WATER_SHEET: "res://assets/art/tiles/%s/%s_water_animated_tile_set.png" % (area, area)})
        print("%s: water sheet, %s" % (area, water_set))
        # the surroundings' pools and the waterfalls take the same murky water
        swaps = {}
        for sheet, name in ((BACKGROUND_SHEET, "background_tiles"), (WATERFALL_SHEET, "waterfall_tiles")):
            dst = os.path.join(TILES, area, "%s_%s.png" % (area, name))
            recolour(os.path.join(TILES, sheet), dst, mapping)
            swaps["res://assets/art/tiles/%s" % sheet] = "res://assets/art/tiles/%s/%s_%s.png" % (area, area, name)
        background_set = "background_tile_set_%s.tres" % area
        copy_set(BACKGROUND_SET, background_set, swaps)
        print("%s: background and waterfall sheets, %s" % (area, background_set))
    point_levels()
    print("levels pointed at their area sets")


if __name__ == "__main__":
    main()
