"""The Fallen Elder (2026-11-26, level 48, the Bone Colossus's lair; concept in the design doc's Boss lairs): the dragon
graveyard of the old war at a moonless necromantic night. Past every edge of the map the dark fill becomes night sand
(background_tile_set_grave.tres) out to GRAVE_DEPTH cells; then the nodes, rewritten on every run: GraveDressing (giant
ribs, half-sunk skulls and spines of the old war's dragons, broken standards, grave-fires with their green light, the
elder's empty grave behind the spawn ringed by ritual stones, and the grave pit at the gate, the Bone Colossus's spawn
art), the castle buried in a dune (CastleCamouflage with the dune frames) and the night (LairLighting). The set pieces
on the map are level_dressing.py's (area "grave"). Art: tools/sprite/parts/lair_grave_art.py. Rerunnable; reload the
level in the editor after.

    python tools/lair_grave.py [level numbers...] [--dry]     (default: every level in GRAVES)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import level_tiles as lt
from lair_camp import h, dist, ensure_ext, remove_block, pos

# per level: the spawner's row (the pit and the grave lie east of it, past the edge) and the castle's position
GRAVES = {
    48: {"spawn_row": 0, "castle": (-344, -72)},
}
GRAVE_DEPTH = 8
BACKGROUND_SET = "res://assets/tile_sets/background_tile_set_grave.tres"
DRESSING = "GraveDressing"
LIT_GROUP = "lair_lit"
ART = "res://assets/art/tiles/lairs/%s.png"
SCENE = "res://scenes/level/lair/%s.tscn"
DUNE_FRAMES = "res://scenes/level/lair/frames/grave_castle_dune_frames.tres"
LIGHTING_SCRIPT = "res://scenes/level/lair/lair_lighting.gd"
LIGHT_SCRIPT = "res://scenes/level/lair/lair_light.gd"
CAMO_SCENE = "res://scenes/level/lair/castle_camouflage.tscn"
# a moonless night: cold blue ambient, the green grave-fires the only warm-ish light, a black-blue fog
AMBIENT = "Color(0.46, 0.5, 0.66, 1)"
FOG = ("Color(0.05, 0.07, 0.11, 1)", 200.0, 0.1, 0.5)  # colour, depth, grey dim, grey strength
BIG_PIECES = [("grave_ribs", 48, 48, -20), ("grave_skull", 48, 32, -12), ("grave_spine", 48, 24, -8)]
BIG_GAP, FIRE_GAP, STANDARD_GAP = 5, 9, 6
RITUAL_STONES = 9
DUNE_SORT_SHIFT = 26


def build_tiles(level, log):
    field = lt.playfield(level)
    xs, ys = [c[0] for c in field], [c[1] for c in field]
    box = (min(xs), min(ys), max(xs), max(ys))
    background = level.cells("BackgroundTileMapLayer")
    front = level.cells("FrontTileMapLayer")
    spawn_cells = set(c for cells in lt.spawn_squares(level).values() for c in cells)
    sand = 0
    for y in range(box[1] - GRAVE_DEPTH, box[3] + GRAVE_DEPTH + 1):
        for x in range(box[0] - GRAVE_DEPTH, box[2] + GRAVE_DEPTH + 1):
            c = (x, y)
            d = dist(c, box)
            if c in field or c in spawn_cells or d == 0:
                continue
            source, tile, _ = background.get(c, (0, lt.DARK_FILL[0], 0))
            if d == 1 and not (source == 0 and tile in lt.DARK_FILL):
                continue  # the map's stone frame stays
            background[c] = (0, lt.pick(lt.DARK_FILL, c), 0)
            front.pop(c, None)
            sand += 1
    level.set_cells("BackgroundTileMapLayer", background)
    level.set_cells("FrontTileMapLayer", front)
    log.append(("night sand", sand, "cells, box", box))
    return box


def place_dressing(level, box, grave, log):
    (x0, y0, x1, y1) = box
    row = grave["spawn_row"]
    pit = (x1 + 2, row)
    elder = (x1 + 8, row)
    stones = [(round(elder[0] + math.cos(k / RITUAL_STONES * math.tau) * 5.5),
               round(elder[1] + math.sin(k / RITUAL_STONES * math.tau) * 3.5)) for k in range(RITUAL_STONES)]
    keep_clear = set((x, y) for x in range(x1 + 1, x1 + 15) for y in range(row - 5, row + 6))

    def free(c, spots, gap):
        return all(max(abs(c[0] - s[0]), abs(c[1] - s[1])) >= gap for s in spots)

    candidates = [c for c in ((x, y) for y in range(y0 - 6, y1 + 7) for x in range(x0 - 6, x1 + 7))
                  if 2 <= dist(c, box) <= 5 and c not in keep_clear]
    bigs = []
    for c in sorted(candidates, key=lambda c: h(level.number, c, "big")):
        if dist(c, box) >= 3 and free(c, [b for b, _ in bigs], BIG_GAP):
            bigs.append((c, h(c, "kind") % len(BIG_PIECES)))
    taken = [b for b, _ in bigs]
    fires = [(pit[0], row - 2), (pit[0], row + 2)]
    for c in sorted(candidates, key=lambda c: h(level.number, c, "fire")):
        if free(c, taken, 2) and free(c, fires, FIRE_GAP):
            fires.append(c)
    standards = []
    for c in sorted(candidates, key=lambda c: h(level.number, c, "standard")):
        if free(c, taken + fires, 2) and free(c, standards, STANDARD_GAP):
            standards.append(c)
    log.append(("dressing", len(bigs), "bones", len(fires), "fires", len(standards), "standards", len(stones), "stones"))
    return bigs, fires, standards, stones, pit, elder


def write_nodes(level, grave, bigs, fires, standards, stones, pit, elder):
    for name in (DRESSING, "CastleCamouflage", "LairLighting"):
        remove_block(level, name)
    for name, _, _, _ in BIG_PIECES + [("grave_elder_grave", 0, 0, 0)]:
        ensure_ext(level, "Texture2D", ART % name, name)
    for name in ("grave_fire", "grave_stone", "grave_standard", "grave_pit"):
        ensure_ext(level, "PackedScene", SCENE % name, name)
    for kind, path, ext_id in (("PackedScene", CAMO_SCENE, "castle_camouflage"), ("SpriteFrames", DUNE_FRAMES, "grave_dune_frames"),
                               ("Script", LIGHTING_SCRIPT, "lair_lighting"), ("Script", LIGHT_SCRIPT, "lair_light")):
        ensure_ext(level, kind, path, ext_id)
    import re
    m = re.search(r'\[ext_resource type="TileSet"[^\]]*path="res://assets/tile_sets/background_tile_set[^"]*\.tres" id="([^"]+)"\]', level.text)
    level.text = level.text.replace(m.group(0), '[ext_resource type="TileSet" path="%s" id="%s"]' % (BACKGROUND_SET, m.group(1)))

    castle = grave["castle"]
    out = ['[node name="CastleCamouflage" parent="." instance=ExtResource("castle_camouflage")]',
           # sorted at the castle's bottom edge, so the dune covers its south towers too (its picture shifted back up)
           'position = Vector2(%d, %d)' % (castle[0], castle[1] + DUNE_SORT_SHIFT),
           'offset = Vector2(0, %d)' % (-17 - DUNE_SORT_SHIFT), 'sprite_frames = ExtResource("grave_dune_frames")', '',
           '[node name="LairLighting" type="Node" parent="."]', 'script = ExtResource("lair_lighting")',
           'ambient = %s' % AMBIENT, 'overrides_fog = true', 'fog_color = %s' % FOG[0], 'fog_depth = %r' % FOG[1],
           'fog_grey_dim = %r' % FOG[2], 'fog_grey_strength = %r' % FOG[3], '',
           '[node name="HoardGlow" type="Node2D" parent="LairLighting"]', 'position = Vector2(%d, %d)' % (castle[0], castle[1] - 17),
           'script = ExtResource("lair_light")', 'color = Color(1, 0.75, 0.35, 1)', 'radius_tiles = 1.5', 'strength = 0.2', '',
           '[node name="GraveGlow" type="Node2D" parent="LairLighting"]', pos(elder, 8),
           'script = ExtResource("lair_light")', 'color = Color(0.4, 0.95, 0.5, 1)', 'radius_tiles = 6.0', 'strength = 0.35', '',
           '[node name="%s" type="Node2D" parent="." groups=["%s"]]' % (DRESSING, LIT_GROUP), 'y_sort_enabled = true', '']
    for name in ("Bones", "Fires", "Standards", "Stones"):
        out += ['[node name="%s" type="Node2D" parent="%s"]' % (name, DRESSING), 'y_sort_enabled = true',
                'use_parent_material = true', '']
    out += ['[node name="ElderGrave" type="Sprite2D" parent="%s"]' % DRESSING, 'use_parent_material = true', 'z_index = -1',
            pos(elder, 8), 'texture = ExtResource("grave_elder_grave")', '']
    for i, (c, kind) in enumerate(bigs):
        name, _, _, offset = BIG_PIECES[kind]
        out += ['[node name="Bone%d" type="Sprite2D" parent="%s/Bones"]' % (i, DRESSING), 'use_parent_material = true',
                pos(c), 'texture = ExtResource("%s")' % name, 'offset = Vector2(0, %d)' % offset,
                'flip_h = %s' % ('true' if h(c, "fl") % 2 else 'false'), '']
    for i, c in enumerate(fires):
        out += ['[node name="Fire%d" parent="%s/Fires" instance=ExtResource("grave_fire")]' % (i, DRESSING), pos(c, 10), '']
    for i, c in enumerate(standards):
        out += ['[node name="Standard%d" parent="%s/Standards" instance=ExtResource("grave_standard")]' % (i, DRESSING),
                'use_parent_material = true', pos(c), '']
    for i, c in enumerate(stones):
        out += ['[node name="Stone%d" parent="%s/Stones" instance=ExtResource("grave_stone")]' % (i, DRESSING),
                'use_parent_material = true', pos(c), '']
    out += ['[node name="GravePit" parent="%s" instance=ExtResource("grave_pit")]' % DRESSING, 'use_parent_material = true',
            pos(pit, 8), '']
    at = level.text.find('[node name="EndPoint"')
    level.text = level.text[:at] + '\n'.join(out) + '\n' + level.text[at:]


def main(args):
    dry = "--dry" in args
    numbers = [int(a) for a in args if a.isdigit()] or sorted(GRAVES)
    for number in numbers:
        level = lt.Level(number)
        log = []
        box = build_tiles(level, log)
        write_nodes(level, GRAVES[number], *place_dressing(level, box, GRAVES[number], log))
        print("level %d%s" % (number, " (dry run)" if dry else ""))
        for entry in log:
            print("  ", *entry)
        if not dry:
            level.save()


if __name__ == "__main__":
    main(sys.argv[1:])
