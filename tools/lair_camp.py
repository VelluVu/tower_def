"""Dragonslayer's Camp (2026-11-26, level 36, the Dragonslayer's lair; concept in the design doc's Boss lairs): the
humans' war camp at a blood-red dusk round the drakelings' last keep. Past the map's north, south and east edges the
forest gives way to the camp's trampled earth (background_tile_set_camp.tres: the dark fill recoloured) out to
CAMP_DEPTH cells; west of the map the forest stays, the drakelings' way home. Then the nodes, rewritten on every run:
CampDressing (a palisade with its gate behind the spawners, tents, watchtowers, trebuchets aimed at the castle,
campfires with their light, banners, the Dragonslayer's command tent past the gate), the castle under siege
(CastleCamouflage with the siege frames: ladders shoved off when he spawns) and the dusk (LairLighting). The set pieces
on the map are level_dressing.py's (area "camp"). Art: tools/sprite/parts/lair_camp_art.py. Rerunnable; reload the
level in the editor after.

    python tools/lair_camp.py [level numbers...] [--dry]     (default: every level in CAMPS)
"""
import os
import re
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import level_tiles as lt

# per level: the gate's rows on the east side (kept clear behind the spawners) and the castle's position
CAMPS = {
    36: {"gate_rows": (-6, 5), "castle": (-344, 104)},
}
CAMP_DEPTH = 7
PALISADE_DISTANCE = 5
BACKGROUND_SET = "res://assets/tile_sets/background_tile_set_camp.tres"
DRESSING = "CampDressing"
LIT_GROUP = "lair_lit"
TENTS_TEXTURE = "res://assets/art/tiles/lairs/camp_tents.png"
PALISADE_TEXTURE = "res://assets/art/tiles/lairs/camp_palisade.png"
TOWER_TEXTURE = "res://assets/art/tiles/lairs/camp_watchtower.png"
TREBUCHET_TEXTURE = "res://assets/art/tiles/lairs/camp_trebuchet.png"
FIRE_SCENE = "res://scenes/level/lair/camp_fire.tscn"
BANNER_SCENE = "res://scenes/level/lair/camp_banner.tscn"
TENT_SCENE = "res://scenes/level/lair/camp_command_tent.tscn"
CAMO_SCENE = "res://scenes/level/lair/castle_camouflage.tscn"
SIEGE_FRAMES = "res://scenes/level/lair/frames/camp_castle_siege_frames.tres"
LIGHTING_SCRIPT = "res://scenes/level/lair/lair_lighting.gd"
LIGHT_SCRIPT = "res://scenes/level/lair/lair_light.gd"
# the dusk: a red-gold ambient, the low sun from the west behind the castle, a smoky red fog past the edge
AMBIENT = "Color(0.88, 0.6, 0.52, 1)"
FOG = ("Color(0.32, 0.14, 0.11, 1)", 220.0, 0.05, 0.3)  # colour, depth, grey dim, grey strength (the camp keeps its colours)
SUN = ((-560, -40), "Color(1, 0.55, 0.3, 1)", 18.0, 0.35)
TENT_GAP, FIRE_GAP = 3, 4


def h(*key):
    return zlib.crc32(repr(key).encode())


def dist(c, box):
    (x0, y0, x1, y1) = box
    return max(x0 - c[0], c[0] - x1, y0 - c[1], c[1] - y1, 0)


def build_tiles(level, camp, log):
    field = lt.playfield(level)
    xs, ys = [c[0] for c in field], [c[1] for c in field]
    box = (min(xs), min(ys), max(xs), max(ys))
    background = level.cells("BackgroundTileMapLayer")
    front = level.cells("FrontTileMapLayer")
    spawn_cells = set(c for cells in lt.spawn_squares(level).values() for c in cells)
    ground = set()
    for y in range(box[1] - CAMP_DEPTH, box[3] + CAMP_DEPTH + 1):
        for x in range(box[0], box[2] + CAMP_DEPTH + 1):  # west of the map stays forest
            c = (x, y)
            d = dist(c, box)
            if c in field or c in spawn_cells or d == 0 or d > CAMP_DEPTH:
                continue
            source, tile, _ = background.get(c, (0, lt.DARK_FILL[0], 0))
            if d == 1 and not (source == 0 and tile in lt.DARK_FILL):
                continue  # the map's stone frame and the river mouths stay
            ground.add(c)
            background[c] = (0, lt.pick(lt.DARK_FILL, c), 0)
            if c in front and front[c][0] == lt.FOREST_SOURCE:
                del front[c]
    # the forest left round the camp gets its edge pieces again
    forest = set(c for c, v in front.items() if v[0] == lt.FOREST_SOURCE and c not in field)
    for c in forest:
        if any(lt.add(c, d) in ground for d in (lt.N, lt.E, lt.S, lt.W)):
            front[c] = lt._forest_piece(c, forest)
    level.set_cells("BackgroundTileMapLayer", background)
    level.set_cells("FrontTileMapLayer", front)
    log.append(("camp ground", len(ground), "cells, box", box))
    return box


def place_dressing(level, box, camp, log):
    (x0, y0, x1, y1) = box
    g0, g1 = camp["gate_rows"]
    gate = lambda c: c[0] > x1 and g0 <= c[1] <= g1

    palisade = []
    for x in range(x0, x1 + PALISADE_DISTANCE + 1):
        palisade += [(x, y0 - PALISADE_DISTANCE), (x, y1 + PALISADE_DISTANCE)]
    for y in range(y0 - PALISADE_DISTANCE + 1, y1 + PALISADE_DISTANCE):
        if not g0 - 1 <= y <= g1 + 1:
            palisade.append((x1 + PALISADE_DISTANCE, y))

    towers = [(x1 + 3, y0 - 3), (x1 + 3, y1 + 3), (x0 + 14, y0 - 3), (x0 + 30, y1 + 3)]
    trebuchets = [(x0 + 8, y0 - 3), (x0 + 22, y1 + 4)]
    taken = towers + trebuchets

    def free(c, spots, gap):
        return all(max(abs(c[0] - s[0]), abs(c[1] - s[1])) >= gap for s in spots)

    candidates = [c for c in ((x, y) for y in range(y0 - 4, y1 + 5) for x in range(x0, x1 + 5))
                  if 2 <= dist(c, box) <= 4 and not gate(c)]
    tents = []
    for c in sorted(candidates, key=lambda c: h(level.number, c, "tent")):
        if free(c, taken + tents, TENT_GAP):
            tents.append(c)
    fires = []
    for c in sorted(candidates, key=lambda c: h(level.number, c, "fire")):
        if free(c, taken + tents, 2) and free(c, fires, FIRE_GAP):
            fires.append(c)
    banners = [(x1 + 2, g0 - 1), (x1 + 2, g1 + 1)]
    for x in range(x0 + 4, x1, 10):
        banners += [(x, y0 - 2), (x + 5, y1 + 2)]
    banners = [c for c in banners if free(c, tents + towers + trebuchets, 2) or c[0] > x1]
    command_tent = (x1 + 3, (g0 + g1) // 2)
    log.append(("dressing", len(palisade), "stakes", len(tents), "tents", len(fires), "fires", len(banners), "banners"))
    return palisade, tents, towers, trebuchets, fires, banners, command_tent


def ensure_ext(level, kind, path, ext_id):
    if 'id="%s"' % ext_id in level.text:
        return
    line = '[ext_resource type="%s" path="%s" id="%s"]\n' % (kind, path, ext_id)
    last = list(re.finditer(r'^\[ext_resource [^\n]*\n', level.text, re.M))[-1]
    level.text = level.text[:last.end()] + line + level.text[last.end():]


def remove_block(level, name):
    """a node at the level's root and every node under it"""
    text = level.text
    start = text.find('[node name="%s" ' % name)
    if start < 0:
        return
    m = re.compile(r'^\[node (?![^\n]*parent="%s[/"])' % name, re.M).search(text, start + 1)
    end = m.start() if m else len(text)
    level.text = text[:start] + text[end:]


def pos(c, dy=12):
    return 'position = Vector2(%d, %d)' % (c[0] * 16 + 8, c[1] * 16 + dy)


def write_nodes(level, camp, palisade, tents, towers, trebuchets, fires, banners, command_tent):
    for name in (DRESSING, "CastleCamouflage", "LairLighting"):
        remove_block(level, name)
    for kind, path, ext_id in (("Texture2D", TENTS_TEXTURE, "camp_tents"), ("Texture2D", PALISADE_TEXTURE, "camp_palisade"),
                               ("Texture2D", TOWER_TEXTURE, "camp_watchtower"), ("Texture2D", TREBUCHET_TEXTURE, "camp_trebuchet"),
                               ("PackedScene", FIRE_SCENE, "camp_fire"), ("PackedScene", BANNER_SCENE, "camp_banner"),
                               ("PackedScene", TENT_SCENE, "camp_command_tent"), ("PackedScene", CAMO_SCENE, "castle_camouflage"),
                               ("SpriteFrames", SIEGE_FRAMES, "camp_siege_frames"), ("Script", LIGHTING_SCRIPT, "lair_lighting"),
                               ("Script", LIGHT_SCRIPT, "lair_light")):
        ensure_ext(level, kind, path, ext_id)
    # the background layer takes the camp's ground
    m = re.search(r'\[ext_resource type="TileSet"[^\]]*path="res://assets/tile_sets/background_tile_set[^"]*\.tres" id="([^"]+)"\]', level.text)
    level.text = level.text.replace(m.group(0), '[ext_resource type="TileSet" path="%s" id="%s"]' % (BACKGROUND_SET, m.group(1)))

    castle = camp["castle"]
    out = ['[node name="CastleCamouflage" parent="." instance=ExtResource("castle_camouflage")]',
           'position = Vector2(%d, %d)' % castle, 'sprite_frames = ExtResource("camp_siege_frames")', '',
           '[node name="LairLighting" type="Node" parent="."]', 'script = ExtResource("lair_lighting")',
           'ambient = %s' % AMBIENT, 'overrides_fog = true', 'fog_color = %s' % FOG[0], 'fog_depth = %r' % FOG[1],
           'fog_grey_dim = %r' % FOG[2], 'fog_grey_strength = %r' % FOG[3], '',
           '[node name="HoardGlow" type="Node2D" parent="LairLighting"]', 'position = Vector2(%d, %d)' % (castle[0], castle[1] - 17),
           'script = ExtResource("lair_light")', 'color = Color(1, 0.75, 0.35, 1)', 'radius_tiles = 2.5', 'strength = 0.5', '',
           '[node name="Sunset" type="Node2D" parent="LairLighting"]', 'position = Vector2(%d, %d)' % SUN[0],
           'script = ExtResource("lair_light")', 'color = %s' % SUN[1], 'radius_tiles = %r' % SUN[2], 'strength = %r' % SUN[3], '',
           '[node name="%s" type="Node2D" parent="." groups=["%s"]]' % (DRESSING, LIT_GROUP), 'y_sort_enabled = true', '']
    for name in ("Palisade", "Tents", "Towers", "Trebuchets", "Fires", "Banners"):
        out += ['[node name="%s" type="Node2D" parent="%s"]' % (name, DRESSING), 'y_sort_enabled = true',
                'use_parent_material = true', '']
    for i, c in enumerate(palisade):
        out += ['[node name="Stakes%d" type="Sprite2D" parent="%s/Palisade"]' % (i, DRESSING), 'use_parent_material = true',
                pos(c), 'texture = ExtResource("camp_palisade")', 'offset = Vector2(0, -12)', 'region_enabled = true',
                'region_rect = Rect2(%d, %d, 16, 32)' % ((h(c, "st") % 3) % 2 * 16, (h(c, "st") % 3) // 2 * 32), '']
    for i, c in enumerate(tents):
        kind = h(level.number, c, "kind") % 2
        out += ['[node name="Tent%d" type="Sprite2D" parent="%s/Tents"]' % (i, DRESSING), 'use_parent_material = true',
                pos(c), 'texture = ExtResource("camp_tents")', 'offset = Vector2(0, -12)',
                'flip_h = %s' % ('true' if h(c, "fl") % 2 else 'false'), 'region_enabled = true',
                'region_rect = Rect2(%d, 0, 32, 32)' % (kind * 32), '']
    for i, c in enumerate(towers):
        out += ['[node name="Watchtower%d" type="Sprite2D" parent="%s/Towers"]' % (i, DRESSING), 'use_parent_material = true',
                pos(c), 'texture = ExtResource("camp_watchtower")', 'offset = Vector2(0, -20)', '']
    for i, c in enumerate(trebuchets):
        out += ['[node name="Trebuchet%d" type="Sprite2D" parent="%s/Trebuchets"]' % (i, DRESSING), 'use_parent_material = true',
                pos(c), 'texture = ExtResource("camp_trebuchet")', 'offset = Vector2(0, -20)', 'flip_h = true', '']
    # fires keep their own bright flame, outside the lit material
    for i, c in enumerate(fires):
        out += ['[node name="Fire%d" parent="%s/Fires" instance=ExtResource("camp_fire")]' % (i, DRESSING), pos(c, 10), '']
    for i, c in enumerate(banners):
        out += ['[node name="Banner%d" parent="%s/Banners" instance=ExtResource("camp_banner")]' % (i, DRESSING),
                'use_parent_material = true', pos(c), '']
    out += ['[node name="CommandTent" parent="%s" instance=ExtResource("camp_command_tent")]' % DRESSING,
            'use_parent_material = true', pos(command_tent, 14), '']
    at = level.text.find('[node name="EndPoint"')
    level.text = level.text[:at] + '\n'.join(out) + '\n' + level.text[at:]


def main(args):
    dry = "--dry" in args
    numbers = [int(a) for a in args if a.isdigit()] or sorted(CAMPS)
    for number in numbers:
        level = lt.Level(number)
        log = []
        box = build_tiles(level, CAMPS[number], log)
        write_nodes(level, CAMPS[number], *place_dressing(level, box, CAMPS[number], log))
        print("level %d%s" % (number, " (dry run)" if dry else ""))
        for entry in log:
            print("  ", *entry)
        if not dry:
            level.save()


if __name__ == "__main__":
    main(sys.argv[1:])
