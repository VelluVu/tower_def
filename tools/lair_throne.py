"""Throne of Embers (2026-11-26, level 60, the Ashen Wyrm's lair and the game's end; concept in the design doc's Boss
lairs): the volcano's heart in an inferno glow. Past every edge the dark fill becomes the caldera
(background_tile_set_throne.tres): basalt ledges LEDGE_DEPTH cells deep round the map, the lava lake beyond (the lava
falls and the spawns' rock stay). Then the nodes, rewritten on every run: ThroneDressing (obsidian spires and basalt
columns, the old exile chains, cultist braziers on the ledges, lava bubbles, the Wyrm's throne with its stolen hoard on
the lava behind the spawns and the magma vent at the gate, its spawn art), the castles bound by the cultists' chains
(one CastleCamouflage per castle) and the inferno (LairLighting with the lava lake's glow round the edge). The set
pieces on the map are level_dressing.py's (area "throne"). Art: tools/sprite/parts/lair_throne_art.py. Rerunnable;
reload the level in the editor after.

    python tools/lair_throne.py [level numbers...] [--dry]     (default: every level in THRONES)
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import level_tiles as lt
from lair_camp import h, dist, ensure_ext, remove_block, pos

# per level: the middle spawner's row (the vent and the throne lie east of it) and every castle's position
THRONES = {
    60: {"spawn_row": 0, "castles": [(-72, -72), (-344, 8)]},
}
LEDGE_DEPTH = 3
CALDERA_DEPTH = 9
LAVA_TILES = [(0, 0), (1, 0)]
LEDGE_TILES = [(0, 1), (1, 1)]
BACKGROUND_SET = "res://assets/tile_sets/background_tile_set_throne.tres"
DRESSING = "ThroneDressing"
LIT_GROUP = "lair_lit"
ART = "res://assets/art/tiles/lairs/%s.png"
SCENE = "res://scenes/level/lair/%s.tscn"
CHAIN_FRAMES = "res://scenes/level/lair/frames/throne_castle_chains_frames.tres"
LIGHTING_SCRIPT = "res://scenes/level/lair/lair_lighting.gd"
LIGHT_SCRIPT = "res://scenes/level/lair/lair_light.gd"
CAMO_SCENE = "res://scenes/level/lair/castle_camouflage.tscn"
# the inferno: a dim red ambient, the lava lake glowing all round the edge, a red-black smoke
AMBIENT = "Color(0.82, 0.64, 0.6, 1)"
FOG = ("Color(0.22, 0.05, 0.03, 1)", 200.0, 0.05, 0.35)  # colour, depth, grey dim, grey strength
LAVA_GLOW = ("Color(1, 0.42, 0.15, 1)", 7.0, 0.45)
BIG_PIECES = [("throne_spire", -20), ("throne_columns", -12), ("throne_hanging_chain", -8)]
BIG_GAP, BRAZIER_GAP, BUBBLE_GAP, GLOW_STEP = 5, 7, 4, 8


def build_tiles(level, log):
    field = lt.playfield(level)
    xs, ys = [c[0] for c in field], [c[1] for c in field]
    box = (min(xs), min(ys), max(xs), max(ys))
    background = level.cells("BackgroundTileMapLayer")
    count = {"ledge": 0, "lava": 0}
    for y in range(box[1] - CALDERA_DEPTH, box[3] + CALDERA_DEPTH + 1):
        for x in range(box[0] - CALDERA_DEPTH, box[2] + CALDERA_DEPTH + 1):
            c = (x, y)
            d = dist(c, box)
            if d < 2:
                continue
            source, tile, _ = background.get(c, (0, lt.DARK_FILL[0], 0))
            if source != 0 or tile not in lt.DARK_FILL + LAVA_TILES + LEDGE_TILES:
                continue  # the lava falls and the spawns' rock stay
            kind = "ledge" if d <= LEDGE_DEPTH else "lava"
            background[c] = (0, lt.pick(LEDGE_TILES if kind == "ledge" else LAVA_TILES, c), 0)
            count[kind] += 1
    level.set_cells("BackgroundTileMapLayer", background)
    log.append(("caldera", count["ledge"], "ledge cells", count["lava"], "lava cells, box", box))
    return box


def place_dressing(level, box, throne, log):
    (x0, y0, x1, y1) = box
    row = throne["spawn_row"]
    vent = (x1 + 2, row)
    seat = (x1 + 10, row)
    keep_clear = set((x, y) for x in range(x1 + 1, x1 + 17) for y in range(row - 6, row + 7))

    def free(c, spots, gap):
        return all(max(abs(c[0] - s[0]), abs(c[1] - s[1])) >= gap for s in spots)

    lava = [c for c in ((x, y) for y in range(y0 - 8, y1 + 9) for x in range(x0 - 8, x1 + 9))
            if LEDGE_DEPTH + 1 <= dist(c, box) <= 7 and c not in keep_clear]
    bigs = []
    for c in sorted(lava, key=lambda c: h(level.number, c, "big")):
        if free(c, [b for b, _ in bigs], BIG_GAP):
            bigs.append((c, h(c, "kind") % len(BIG_PIECES)))
    bubbles = []
    for c in sorted(lava, key=lambda c: h(level.number, c, "bubble")):
        if free(c, [b for b, _ in bigs], 2) and free(c, bubbles, BUBBLE_GAP):
            bubbles.append(c)
    ledge = [c for c in ((x, y) for y in range(y0 - 3, y1 + 4) for x in range(x0 - 3, x1 + 4))
             if dist(c, box) == 2 and c not in keep_clear]
    braziers = [(vent[0], row - 3), (vent[0], row + 3)]
    for c in sorted(ledge, key=lambda c: h(level.number, c, "brazier")):
        if free(c, braziers, BRAZIER_GAP):
            braziers.append(c)
    glows = []
    for x in range(x0 - 4, x1 + 5, GLOW_STEP):
        glows += [(x, y0 - 3), (x, y1 + 3)]
    for y in range(y0, y1 + 1, GLOW_STEP):
        glows += [(x0 - 3, y), (x1 + 3, y)]
    log.append(("dressing", len(bigs), "spires/columns/chains", len(bubbles), "bubbles", len(braziers), "braziers",
                len(glows), "lava glows"))
    return bigs, bubbles, braziers, glows, vent, seat


def write_nodes(level, throne, bigs, bubbles, braziers, glows, vent, seat):
    for name in (DRESSING, "LairLighting"):
        remove_block(level, name)
    for i in range(8):
        remove_block(level, "CastleCamouflage" if i == 0 else "CastleCamouflage%d" % (i + 1))
    for name, _ in BIG_PIECES + [("throne_throne", 0)]:
        ensure_ext(level, "Texture2D", ART % name, name)
    for name in ("throne_brazier", "throne_bubble", "throne_vent"):
        ensure_ext(level, "PackedScene", SCENE % name, name)
    for kind, path, ext_id in (("PackedScene", CAMO_SCENE, "castle_camouflage"), ("SpriteFrames", CHAIN_FRAMES, "throne_chain_frames"),
                               ("Script", LIGHTING_SCRIPT, "lair_lighting"), ("Script", LIGHT_SCRIPT, "lair_light")):
        ensure_ext(level, kind, path, ext_id)
    m = re.search(r'\[ext_resource type="TileSet"[^\]]*path="res://assets/tile_sets/background_tile_set[^"]*\.tres" id="([^"]+)"\]', level.text)
    level.text = level.text.replace(m.group(0), '[ext_resource type="TileSet" path="%s" id="%s"]' % (BACKGROUND_SET, m.group(1)))

    out = []
    for i, castle in enumerate(throne["castles"]):
        out += ['[node name="%s" parent="." instance=ExtResource("castle_camouflage")]' % ("CastleCamouflage" if i == 0 else "CastleCamouflage%d" % (i + 1)),
                'position = Vector2(%d, %d)' % castle, 'sprite_frames = ExtResource("throne_chain_frames")', '']
    out += ['[node name="LairLighting" type="Node" parent="."]', 'script = ExtResource("lair_lighting")',
            'ambient = %s' % AMBIENT, 'overrides_fog = true', 'fog_color = %s' % FOG[0], 'fog_depth = %r' % FOG[1],
            'fog_grey_dim = %r' % FOG[2], 'fog_grey_strength = %r' % FOG[3], '']
    for i, castle in enumerate(throne["castles"]):
        out += ['[node name="HoardGlow%d" type="Node2D" parent="LairLighting"]' % i, 'position = Vector2(%d, %d)' % (castle[0], castle[1] - 17),
                'script = ExtResource("lair_light")', 'color = Color(1, 0.75, 0.35, 1)', 'radius_tiles = 2.5', 'strength = 0.5', '']
    for i, c in enumerate(glows):
        out += ['[node name="LavaGlow%d" type="Node2D" parent="LairLighting"]' % i, pos(c, 8), 'script = ExtResource("lair_light")',
                'color = %s' % LAVA_GLOW[0], 'radius_tiles = %r' % LAVA_GLOW[1], 'strength = %r' % LAVA_GLOW[2], 'flicker = 0.1', '']
    out += ['[node name="ThroneGlow" type="Node2D" parent="LairLighting"]', pos(seat, 0), 'script = ExtResource("lair_light")',
            'color = Color(1, 0.6, 0.25, 1)', 'radius_tiles = 6.0', 'strength = 0.5', '',
            '[node name="%s" type="Node2D" parent="." groups=["%s"]]' % (DRESSING, LIT_GROUP), 'y_sort_enabled = true', '']
    for name in ("Rocks", "Bubbles", "Braziers"):
        out += ['[node name="%s" type="Node2D" parent="%s"]' % (name, DRESSING), 'y_sort_enabled = true',
                'use_parent_material = true', '']
    out += ['[node name="Throne" type="Sprite2D" parent="%s"]' % DRESSING, 'use_parent_material = true',
            pos(seat, 20), 'texture = ExtResource("throne_throne")', 'offset = Vector2(0, -32)', '']
    for i, (c, kind) in enumerate(bigs):
        name, offset = BIG_PIECES[kind]
        out += ['[node name="Rock%d" type="Sprite2D" parent="%s/Rocks"]' % (i, DRESSING), 'use_parent_material = true',
                pos(c), 'texture = ExtResource("%s")' % name, 'offset = Vector2(0, %d)' % offset,
                'flip_h = %s' % ('true' if h(c, "fl") % 2 else 'false'), '']
    # the lava and the fires glow by themselves, outside the lit material
    for i, c in enumerate(bubbles):
        out += ['[node name="Bubble%d" parent="%s/Bubbles" instance=ExtResource("throne_bubble")]' % (i, DRESSING), pos(c, 8),
                'frame = %d' % (h(c, "frame") % 6), '']
    for i, c in enumerate(braziers):
        out += ['[node name="Brazier%d" parent="%s/Braziers" instance=ExtResource("throne_brazier")]' % (i, DRESSING), pos(c, 10), '']
    out += ['[node name="Vent" parent="%s" instance=ExtResource("throne_vent")]' % DRESSING, pos(vent, 8), '']
    at = level.text.find('[node name="EndPoint"')
    level.text = level.text[:at] + '\n'.join(out) + '\n' + level.text[at:]


def main(args):
    dry = "--dry" in args
    numbers = [int(a) for a in args if a.isdigit()] or sorted(THRONES)
    for number in numbers:
        level = lt.Level(number)
        log = []
        box = build_tiles(level, log)
        write_nodes(level, THRONES[number], *place_dressing(level, box, THRONES[number], log))
        print("level %d%s" % (number, " (dry run)" if dry else ""))
        for entry in log:
            print("  ", *entry)
        if not dry:
            level.save()


if __name__ == "__main__":
    main(sys.argv[1:])
