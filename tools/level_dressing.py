"""Adds 32x32 landmarks to existing levels without rebuilding them (so hand edits and older generator output stay as
they are): tools/reports/landmark_spots.gd finds open 2x2 spots off every road in Godot, with every route kept open,
and this writes the landmark's four tiles into the level's FrontTileMapLayer. Rerunning replaces the landmarks it
placed before (only tiles of the area's landmark source are touched).

    python tools/level_dressing.py [level numbers...]     (default: the swamp 13-24 and the Wasted Lands 25-36)

Landmark art: tools/sprite/parts/area_landmarks.py (swamp, fields) and scorched_decor.py (desert, volcano; those
levels place theirs in tools/scorched_levels.py). Run tools/area_tiles.py first, so the area tile sets carry the
landmark sources. Reload the levels in the editor afterwards.
"""
import os
import re
import subprocess
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import level_tiles as lt

ROOT = lt.ROOT
# object_tile_set_01 sources (and their area copies): four landmarks, two by two on a 64x64 sheet. The human lands
# (the Wasted Lands since 2026-11-18) take their landmarks in turn from the timber-and-quarry sheet (14) and the farm
# sheet (13): two of the first to one of the second.
# Hydra's Mire (24) mixes its own landmarks (object_tile_set_swamp source 16, lair_mire_art.py) with the swamp's
# Dragonslayer's Camp (36) mixes its own (object_tile_set_humans source 16, lair_camp_art.py) with the timber-and-quarry
# sheet, two to one; it clears the farm sheet (13) it had before
LANDMARK_SOURCES = {"swamp": [12], "fields": [14, 13, 14], "brood": [16], "mire": [16, 12, 16], "camp": [16, 14, 16], "grave": [16, 10, 16], "throne": [16, 11, 16]}
AREAS = {"swamp": range(13, 24), "fields": range(25, 36), "brood": [12], "mire": [24], "camp": [36], "grave": [48], "throne": [60]}
# sources a rerun clears besides the area's own
CLEARED_SOURCES = {"camp": [13]}  # the Fallen Elder (48) mixes object_tile_set_desert source 16 (lair_grave_art.py) with the desert's own (10), Throne of Embers (60)
# object_tile_set_volcano source 16 (lair_throne_art.py) with the volcano's own (11)
# a sheet's landmark count and columns when it is not four, two by two (the boss lairs, tools/sprite/parts/lair_art.py;
# the Brood Cavern is level 12)
LANDMARK_LAYOUT = {("brood", 16): (5, 3), ("camp", 16): (6, 3), ("grave", 16): (6, 3), ("throne", 16): (6, 3)}  # by area: source 16 of the swamp set is the mire's sheet, four two by two
LANDMARK_COUNT = {"brood": 5, "mire": 5, "camp": 5, "grave": 5, "throne": 5}
# ground decor (decor_tile_set source 3, twelve pieces four by three: stumps, chips, ruts, gravel...), on about one open
# cell in DECOR_ONE_IN of the Wasted Lands; a rerun replaces it
DECOR_SOURCE = {"fields": 3, "brood": 4, "camp": 3}
DECOR_PIECES = {3: (12, 4), 4: (6, 3)}  # pieces and columns per decor source
DECOR_ONE_IN = {"fields": 7, "brood": 9, "camp": 7}
# areas whose level loses the meadow decor (decor_tile_set source 0) under its own: the cave lair has no grass
DECOR_REPLACES_MEADOW = {"brood"}
WATER_LAYER = "WaterTileMapLayer"


def area_of(number):
    for area, numbers in AREAS.items():
        if number in numbers:
            return area
    return None


def find_spots(numbers, count=3):
    out = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "gd.py"), "--timeout", "900", "run",
                          "tools/reports/landmark_spots.gd"] + [str(n) for n in numbers] + ["count=%d" % count, "--raw"],
                         capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    spots = {}
    for m in re.finditer(r"^SPOT (\d+) (-?\d+) (-?\d+)$", out, re.M):
        spots.setdefault(int(m.group(1)), []).append((int(m.group(2)), int(m.group(3))))
    return spots


def dress(number, cells):
    area = area_of(number)
    sources = LANDMARK_SOURCES[area]
    level = lt.Level(number)
    front = level.cells("FrontTileMapLayer")
    for k in [k for k, v in front.items() if v[0] in sources + CLEARED_SOURCES.get(area, [])]:
        del front[k]
    # a level's landmarks are different kinds, starting from a kind picked per level
    for i, (x, y) in enumerate(cells):
        source = sources[i % len(sources)]
        kinds, columns = LANDMARK_LAYOUT.get((area, source), (4, 2))
        kind = (zlib.crc32(repr(number).encode()) + i) % kinds
        for dc in (0, 1):
            for dr in (0, 1):
                front[(x + dc, y + dr)] = (source, (kind % columns * 2 + dc, kind // columns * 2 + dr), 0)
    level.set_cells("FrontTileMapLayer", front)
    if area in DECOR_SOURCE:
        scatter_decor(level, front, DECOR_SOURCE[area], area)
    level.save()
    print("level %d: %d landmarks (%s)" % (number, len(cells), area))


def scatter_decor(level, front, source, area):
    """the area's ground pieces on open ground: on the playfield, not under water or a front tile; a piece may take
    the place of an old meadow tuft (almost every meadow cell has one)"""
    cleared = (source, 0) if area in DECOR_REPLACES_MEADOW else (source,)
    decor = {k: v for k, v in level.cells("DecorTileMapLayer").items() if v[0] not in cleared}
    pieces, columns = DECOR_PIECES[source]
    water = level.cells(WATER_LAYER)
    for cell in level.cells("GroundTileMapLayer"):
        if cell in water or cell in front:
            continue
        if zlib.crc32(repr((level.number, cell, "decor")).encode()) % DECOR_ONE_IN[area] == 0:
            i = zlib.crc32(repr((level.number, cell, "piece")).encode()) % pieces
            decor[cell] = (source, (i % columns, i // columns), 0)
    level.set_cells("DecorTileMapLayer", decor)


if __name__ == "__main__":
    numbers = [int(a) for a in sys.argv[1:]] or [n for numbers in AREAS.values() for n in numbers]
    numbers = [n for n in numbers if area_of(n)]
    spots = {}
    for count in sorted(set(LANDMARK_COUNT.get(area_of(n), 3) for n in numbers)):
        spots.update(find_spots([n for n in numbers if LANDMARK_COUNT.get(area_of(n), 3) == count], count))
    for n in numbers:
        dress(n, spots.get(n, []))
