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
LANDMARK_SOURCES = {"swamp": [12], "fields": [14, 13, 14]}
AREAS = {"swamp": range(13, 25), "fields": range(25, 37)}
# ground decor (decor_tile_set source 3, twelve pieces four by three: stumps, chips, ruts, gravel...), on about one open
# cell in DECOR_ONE_IN of the Wasted Lands; a rerun replaces it
DECOR_SOURCE = {"fields": 3}
DECOR_PIECES = 12
DECOR_ONE_IN = 7
WATER_LAYER = "WaterTileMapLayer"


def area_of(number):
    for area, numbers in AREAS.items():
        if number in numbers:
            return area
    return None


def find_spots(numbers):
    out = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "gd.py"), "--timeout", "900", "run",
                          "tools/reports/landmark_spots.gd"] + [str(n) for n in numbers] + ["--raw"],
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
    for k in [k for k, v in front.items() if v[0] in sources]:
        del front[k]
    # a level's landmarks are different kinds, starting from a kind picked per level
    first = zlib.crc32(repr(number).encode()) % 4
    for i, (x, y) in enumerate(cells):
        kind = (first + i) % 4
        source = sources[i % len(sources)]
        for dc in (0, 1):
            for dr in (0, 1):
                front[(x + dc, y + dr)] = (source, (kind % 2 * 2 + dc, kind // 2 * 2 + dr), 0)
    level.set_cells("FrontTileMapLayer", front)
    if area in DECOR_SOURCE:
        scatter_decor(level, front, DECOR_SOURCE[area])
    level.save()
    print("level %d: %d landmarks (%s)" % (number, len(cells), area))


def scatter_decor(level, front, source):
    """the area's ground pieces on open ground: on the playfield, not under water or a front tile; a piece may take
    the place of an old meadow tuft (almost every meadow cell has one)"""
    decor = {k: v for k, v in level.cells("DecorTileMapLayer").items() if v[0] != source}
    water = level.cells(WATER_LAYER)
    for cell in level.cells("GroundTileMapLayer"):
        if cell in water or cell in front:
            continue
        if zlib.crc32(repr((level.number, cell, "decor")).encode()) % DECOR_ONE_IN == 0:
            i = zlib.crc32(repr((level.number, cell, "piece")).encode()) % DECOR_PIECES
            decor[cell] = (source, (i % 4, i // 4), 0)
    level.set_cells("DecorTileMapLayer", decor)


if __name__ == "__main__":
    numbers = [int(a) for a in sys.argv[1:]] or [n for numbers in AREAS.values() for n in numbers]
    numbers = [n for n in numbers if area_of(n)]
    spots = find_spots(numbers)
    for n in numbers:
        dress(n, spots.get(n, []))
