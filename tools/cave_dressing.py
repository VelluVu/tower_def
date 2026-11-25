"""Dresses the cave levels so their maps show what their stories say (2026-11-25, the user: every level's surroundings
painted to match its description). Only dressing: 2x2 set pieces on open spots off every road (found in Godot by
tools/reports/landmark_spots.gd, every route kept open) and props on the decor layer, which blocks nothing, so the
levels play as before.

    python tools/cave_dressing.py [level numbers...]     (default: every level in LEVELS)

  4 Forest Fork        groves of pines and round trees (green land props, object set source 2)
  5 Crossroads         the miners' tunnel mouths: mine scaffolds with ore carts, stalagmites, rubble
  6 Echo Crossing      the smashed bridge in the north river mouth (EXTRA); tunnels on every side: mine
                       scaffolds, rubble, stalagmites
  7 Bat Roost          skull piles and stalagmites under the ridges where the batlings nest
  8 Crystal Deep       crystal clusters, crystal-grown ribs, pink crystals and glowing mushrooms
  9 Collapsed Tunnels  mine scaffolds, rubble, stalagmites
 11 Barricade Bridge   the humans' fences, banner and supplies at the bridge's east end (EXTRA)

Rerunning replaces the set pieces and cave props it placed (brood landmark source 16, the groves it recorded in
GROVE_MARK on the level, caves props decor source 4). Reload the levels in the editor afterwards.
"""
import os
import re
import subprocess
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import level_tiles as lt

ROOT = lt.ROOT
FRONT = "FrontTileMapLayer"
DECOR = "DecorTileMapLayer"
WATER = "WaterTileMapLayer"
BROOD = 16      # object_tile_set_01: the Brood Cavern's set pieces, five on a 3x2 grid of 2x2 pieces
TREES = 2       # object_tile_set_01: green land props (trees)
HUMANS = 7      # object_tile_set_01: human props (hay, fence, barrel / crate, banner, flowers)
CAVE_PROPS = 4  # decor_tile_set: caves_props, 3x2 single cells
# brood set pieces
EGGS, MINE, RIBS, BOULDER, CRYSTALS = range(5)
# caves props
STALAGMITE, SPIKES, PINK_CRYSTAL, SKULLS, MUSHROOMS, RUBBLE = (0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)
# a grove: two trees side by side, each two cells tall (green land props columns 0-4, rows 3-4: round trees and pines)
GROVE_TREES = [0, 1, 2, 3, 4]

LEVELS = {
    4: dict(spots=24, spacing=3, pieces=["grove"], props=[], one_in=0),
    5: dict(spots=3, spacing=8, pieces=[MINE, BOULDER, MINE], props=[STALAGMITE, SPIKES, RUBBLE], one_in=11),
    6: dict(spots=3, spacing=8, pieces=[MINE, MINE, BOULDER], props=[RUBBLE, STALAGMITE, SPIKES], one_in=10),
    7: dict(spots=2, spacing=10, pieces=[BOULDER, RIBS], props=[SKULLS, STALAGMITE, SPIKES], one_in=12),
    8: dict(spots=4, spacing=6, pieces=[CRYSTALS, RIBS, CRYSTALS, CRYSTALS], props=[PINK_CRYSTAL, MUSHROOMS, PINK_CRYSTAL],
            one_in=8),
    9: dict(spots=3, spacing=8, pieces=[MINE, MINE, BOULDER], props=[RUBBLE, RUBBLE, STALAGMITE], one_in=9),
}
GROVE_MARK = "cave_dressing_groves"
# single front tiles by hand, per level: cell -> (source, atlas). Echo Crossing's smashed bridge: a plank stub out
# from the bank into the north river mouth (its posts on the shore) and a broken-off plank further out
EXTRA = {
    6: {(0, -6): (TREES, (3, 8)), (0, -5): (TREES, (3, 9)), (2, -7): (TREES, (6, 8))},
    # Barricade Bridge: the humans' fences, banner and supplies on the east bank either side of the bridge's end
    # (the bridge is rows -1..0 over the river at x 15-17; the road keeps both rows)
    11: {(18, -2): (HUMANS, (1, 0)), (19, -2): (HUMANS, (1, 1)), (20, -2): (HUMANS, (1, 0)),
         (18, 1): (HUMANS, (1, 0)), (19, 1): (HUMANS, (1, 0)), (20, 1): (HUMANS, (0, 1)), (21, 1): (HUMANS, (2, 0))},
}


def find_spots(number, count, spacing):
    out = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "gd.py"), "--timeout", "600", "run",
                          "tools/reports/landmark_spots.gd", str(number), "count=%d" % count, "spacing=%d" % spacing, "--raw"],
                         capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    return [(int(m.group(2)), int(m.group(3))) for m in re.finditer(r"^SPOT (\d+) (-?\d+) (-?\d+)$", out, re.M)]


def rnd(*key):
    return zlib.crc32(repr(key).encode())


def groves_path(number):
    return os.path.join(ROOT, "tools", "reports", "%s_%03d.txt" % (GROVE_MARK, number))


def dress(number):
    spec = LEVELS.get(number, dict(spots=0, spacing=8, pieces=[], props=[], one_in=0))
    level = lt.Level(number)
    front = level.cells(FRONT)
    # what an earlier run placed
    for k in [k for k, v in front.items() if v[0] == BROOD]:
        del front[k]
    if os.path.exists(groves_path(number)):
        for line in open(groves_path(number)).read().split():
            x, y = map(int, line.split(","))
            front.pop((x, y), None)
    level.set_cells(FRONT, front)
    level.save()
    spots = find_spots(number, spec["spots"], spec["spacing"]) if spec["spots"] else []
    level = lt.Level(number)
    front = level.cells(FRONT)
    groves = []
    for i, (x, y) in enumerate(spots):
        piece = spec["pieces"][i % len(spec["pieces"])]
        if piece == "grove":
            for dc in (0, 1):
                tree = GROVE_TREES[rnd(number, i, dc) % len(GROVE_TREES)]
                for dr in (0, 1):
                    front[(x + dc, y + dr)] = (TREES, (tree, 3 + dr), 0)
                    groves.append("%d,%d" % (x + dc, y + dr))
        else:
            for dc in (0, 1):
                for dr in (0, 1):
                    front[(x + dc, y + dr)] = (BROOD, (piece % 3 * 2 + dc, piece // 3 * 2 + dr), 0)
    for cell, (source, atlas) in EXTRA.get(number, {}).items():
        front[cell] = (source, atlas, 0)
    level.set_cells(FRONT, front)
    if groves:
        open(groves_path(number), "w").write("\n".join(groves))
    decor = {k: v for k, v in level.cells(DECOR).items() if v[0] != CAVE_PROPS}
    if spec["one_in"]:
        water = level.cells(WATER)
        for cell in level.cells("GroundTileMapLayer"):
            if cell in water or cell in front:
                continue
            if rnd(number, cell, "prop") % spec["one_in"] == 0:
                decor[cell] = (CAVE_PROPS, spec["props"][rnd(number, cell, "kind") % len(spec["props"])], 0)
        level.set_cells(DECOR, decor)
    level.save()
    print("level %d: %d pieces, props one in %s" % (number, len(spots), spec["one_in"] or "-"))


if __name__ == "__main__":
    for n in [int(a) for a in sys.argv[1:]] or sorted(set(LEVELS) | set(EXTRA)):
        dress(n)
