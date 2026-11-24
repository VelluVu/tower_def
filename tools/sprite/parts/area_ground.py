"""Ground sheets for the Caves, Swamp and Human areas, recoloured from green_land/ground_tiles.png.

The layout is ground_tiles.png's exactly (6 terrain blocks of 8x8 tiles, one per neighbour mask), so a tile set
that points its ground source (source 2 of green_land_tile_set) at one of these keeps every tile's TileType data,
and tools/level_tiles.py ground places them the same way. Each area maps the green-land colours by role:
grass base/rim/dark, block 1, pale sand, sand, red, bog.
usage: area_ground.py <parts dir> <tiles dir>   (tiles dir = assets/art/tiles)"""
import os
import sys
sys.path.insert(0, sys.argv[1])
from PIL import Image

TILES = sys.argv[2]
KEYS = 'abcdefghijklmnopqrstuvwxyz'
SRC = Image.open(TILES + '/green_land/ground_tiles.png').convert('RGBA')

AREAS = {
    'caves': ('''cave floor: slate 3a4466 with a 5a6988 rim, block 1 slate 3a4466, pale sand = gravel 5a6988/8b9bb4,
# sand = cave dust 733e39/b86f50, red = amethyst veins 68386c, bog = dark pools 181425/262b44 (2026-11-24: a cool
# mid-tone slate for the Brood Cavern, the first level to use it, so the warm torchlight stands out; its LairLighting
# does the darkening)''', {
        '439148': '3a4466', '63c74d': '5a6988', '2f6b3d': '262b44', '568239': '3a4466',
        'cdb99a': '5a6988', 'dacab7': '8b9bb4', 'e4a672': '733e39', 'e8b796': 'b86f50', 'bc6e48': '68386c',
        '45472a': '181425', '56602f': '262b44', '323a26': '181425', '3a3b24': '1e2033'}),
    'swamp': ('''swamp: dull marsh grass 4b6a35 with a 6b8a3a rim, block 1 rotting moss 3a4d2a, pale sand = dry mud
# a08a5a/b09a6a, sand = wet mud 6b5638/7a6442, red = toxic patches 68386c, bog as green_land's''', {
        '439148': '4b6a35', '63c74d': '6b8a3a', '2f6b3d': '2a3a22', '568239': '3a4d2a',
        'cdb99a': 'a08a5a', 'dacab7': 'b09a6a', 'e4a672': '6b5638', 'e8b796': '7a6442', 'bc6e48': '68386c',
        '45472a': '45472a', '56602f': '56602f', '323a26': '323a26', '3a3b24': '3a3b24'}),
    'humans': ('''human lands: meadow 5aa04a with a 8fd060 rim, block 1 = wheat b6a23c, pale sand = cobble road
# 8b9bb4/c0cbdc, sand = dirt road d8b07a/e4c08a, red = ploughed earth 8a4a2a, bog = muddy puddles''', {
        '439148': '5aa04a', '63c74d': '8fd060', '2f6b3d': '3e8948', '568239': 'b6a23c',
        'cdb99a': '8b9bb4', 'dacab7': 'c0cbdc', 'e4a672': 'd8b07a', 'e8b796': 'e4c08a', 'bc6e48': '8a4a2a',
        '45472a': '4a3a2e', '56602f': '6a5a44', '323a26': '3e2731', '3a3b24': '554535'}),
    'desert': ('''ash desert (levels 37-42): dune sand e0c08a with a f0dcaa rim, block 1 = packed dunes c4a06c, pale
# sand = bone-white salt flats d8d0c0/ece6d8, sand = red dust road b8784e/c88a5c, red = cracked hardpan 9a5a3a,
# bog = oasis reeds and mud''', {
        '439148': 'e0c08a', '63c74d': 'f0dcaa', '2f6b3d': 'b8955f', '568239': 'c4a06c',
        'cdb99a': 'd8d0c0', 'dacab7': 'ece6d8', 'e4a672': 'b8784e', 'e8b796': 'c88a5c', 'bc6e48': '9a5a3a',
        '45472a': '4a5a32', '56602f': '5e6e3a', '323a26': '35452a', '3a3b24': '42502e'}),
    'volcano': ('''volcano (levels 43-48): ash ground 4e3e42 with a 6a5458 rim, block 1 = scorched red earth 6e3a32,
# pale sand = ash drifts 8a8088/a69ca2, sand = hot cinders 9e3a2a/b84a30, red = dark ember earth 5a2a26 (not as
# bright as lava, which is the water layer),
# bog = cooled black glass''', {
        '439148': '4e3e42', '63c74d': '6a5458', '2f6b3d': '2e2428', '568239': '6e3a32',
        'cdb99a': '8a8088', 'dacab7': 'a69ca2', 'e4a672': '9e3a2a', 'e8b796': 'b84a30', 'bc6e48': '5a2a26',
        '45472a': '181425', '56602f': '262b44', '323a26': '120f1a', '3a3b24': '1e1a26'}),
}

for area, (note, colours) in AREAS.items():
    keys = {c: KEYS[i] for i, c in enumerate(sorted(set(colours.values())))}
    rows = []
    for y in range(SRC.height):
        row = []
        for x in range(SRC.width):
            p = SRC.getpixel((x, y))
            row.append(keys[colours['%02x%02x%02x' % p[:3]]] if p[3] else '.')
        rows.append(''.join(row))
    os.makedirs('%s/%s' % (TILES, area), exist_ok=True)
    out = ['# Source of %s_ground_tiles.aseprite and .png (python tools/sprite/sprite.py build <this> <out.aseprite>).' % area,
           '# Recoloured from green_land/ground_tiles.png by tools/sprite/parts/area_ground.py, same layout (point a copy of',
           '# green_land_tile_set\'s ground source at it). The ' + note,
           'size = %dx%d' % SRC.size]
    out += ['%s = %s' % (k, c) for c, k in sorted(keys.items(), key=lambda kv: kv[1])]
    out += ['---', '@IDLE 100'] + rows + ['']
    open('%s/%s/%s_ground_tiles.txt' % (TILES, area, area), 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
    print(area)
