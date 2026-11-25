"""The sixteen enemies of 2026-11-25, four per area: Caves (cave shaman, wall crawler, spore carrier, glow moth), Swamp
(bog witch, snapping turtle, mosquito, leech mother), Humans (shieldbearer, battering ram, war drummer, crossbow sniper)
and the Scorched Lands (sand wurm, bone vulture, mummy priest, ash harpy).

Most are drawn over an existing enemy's frames like tools/sprite/parts/scorched_enemies.py (same canvas, frames and
tags, a new palette by colour role plus overlays); the leech mother, the sand wurm and the battering ram are drawn from
parts. Writes <name>/<name>.txt, .aseprite and .png under the enemy art folder.

usage: units_2026_11_25_art.py <parts dir> <enemy art dir> [name...]"""
import math
import os
import sys

sys.path.insert(0, sys.argv[1])
import scorched_enemies as se  # noqa: E402  (same arguments: parts dir, enemy art dir)
from scorched_enemies import BONE, EMBER, GLOW, blob, thick, derive, save  # noqa: E402

# cave folk: the weakling's pale tan skin
CAVE_SKIN = ['b59e85', 'cab494', 'd5bf9b', 'e0caa3', 'ecd8b1']
HIDE = ['3e2731', '5d3a2a', '7a4e34', '9a6a44']
SWAMP_TEAL = ['17323a', '1f5048', '2d7356', '4a9a5c', '8fc46a']
WITCH = ['2a1a33', '45254f', '68386c', '8e4f7a', 'b55088']
STEEL = ['262b44', '3a4466', '5a6988', '8b9bb4', 'c0cbdc']
WOOD = ['3e2731', '5d3a2a', '733e39', '9a5a3a', 'b86f50']
SAND = ['8a6a44', 'b08a5a', 'd0a870', 'e4c08a', 'f0d8a8']
WRAPS = ['5e5040', '8a7a60', 'b8a888', 'ddd0b0', 'f0e8d0']
ASH = ['2a2028', '3e3038', '5e5458', '847a80', 'a89ea4']


def clamp_put(px, size, p, c):
    x, y = p
    if 1 <= x <= size[0] - 2 and 1 <= y <= size[1] - 2:
        px[p] = c


def bbox(base, colours):
    pts = [p for p, c in base.items() if c in colours]
    if not pts:
        return None
    xs, ys = [x for x, _ in pts], [y for _, y in pts]
    return min(xs), min(ys), max(xs), max(ys)


# ----------------------------------------------------------------------------------------- overlays
def cap(skin, ramp, spots, size=(18, 18)):
    """a mushroom cap over the head: the top two rows of skin become the cap, the lower one a pixel wider each side"""
    def apply(base, px, i):
        box = bbox(base, skin)
        if box is None:
            return
        y0 = box[1]
        for (x, y), c in base.items():
            if c in skin and y0 <= y <= y0 + 1:
                px[(x, y)] = ramp[2] if y == y0 else ramp[1]
        row = sorted(x for (x, y), c in base.items() if c in skin and y == y0 + 1)
        if row:
            clamp_put(px, size, (row[0] - 1, y0 + 1), ramp[0])
            clamp_put(px, size, (row[-1] + 1, y0 + 1), ramp[0])
            clamp_put(px, size, ((row[0] + row[-1]) // 2, y0), spots)
    return apply


def spots(colours, colour, every=7):
    """fixed spots (mould, toxic dots) through the given base colours, so they hold between frames"""
    def apply(base, px, i):
        for (x, y), c in base.items():
            if c in colours and (x * 5 + y * 3) % every == 0 and se.near(base, (x, y), colours, 8) >= 6:
                px[(x, y)] = colour
    return apply


def glow_all(colours, colour):
    def apply(base, px, i):
        for p, c in base.items():
            if c in colours:
                px[p] = colour
    return apply


def tower_shield(body, size=(26, 26)):
    """a tall iron-rimmed tower shield in front of the body (the right side; the game flips the sprite)"""
    def apply(base, px, i):
        box = bbox(base, body)
        if box is None:
            return
        x1, y0, _, y1 = box[2], box[1], box[2], box[3]
        if y1 - y0 < 10:  # lying down (DEATH): the shield lies flat by the body
            for x in range(box[0], box[2] + 1):
                clamp_put(px, size, (x, y1 + 1), STEEL[2] if x % 3 else STEEL[0])
            return
        sx = min(x1 - 1, size[0] - 6)
        for y in range(y0 + 4, y0 + 15):
            for dx in range(4):
                edge = dx in (0, 3) or y in (y0 + 4, y0 + 14)
                colour = STEEL[1] if edge else ('3f6ea8' if (y + dx) % 5 else 'feae34')
                clamp_put(px, size, (sx + dx, y), colour)
        clamp_put(px, size, (sx + 1, y0 + 9), 'feae34')
        clamp_put(px, size, (sx + 2, y0 + 9), 'feae34')
    return apply


def drum(body, size=(18, 18)):
    """a red war drum hung on the belly, its pale head up; the sticks are the spear's place"""
    def apply(base, px, i):
        box = bbox(base, body)
        if box is None:
            return
        cx, cy = (box[0] + box[2]) // 2 + 1, (box[1] + box[3]) // 2 + 1
        if box[3] - box[1] < 4:  # lying down
            cy = box[3]
        for dy in range(-1, 3):
            for dx in range(-2, 3):
                colour = 'f0e8d0' if dy == -1 else ('a22633' if dx not in (-2, 2) else '5d1d2c')
                if dy == 2 and abs(dx) == 2:
                    continue
                clamp_put(px, size, (cx + dx, cy + dy), colour)
        clamp_put(px, size, (cx - 1, cy + 1), 'feae34')
        clamp_put(px, size, (cx + 1, cy + 1), 'feae34')
    return apply


def shell(body, ramp, size=(26, 26)):
    """the upper half of the body becomes a domed shell with plates"""
    def apply(base, px, i):
        box = bbox(base, body)
        if box is None:
            return
        mid = (box[1] + box[3]) // 2
        for (x, y), c in base.items():
            if c in body and y <= mid:
                plate = (x // 3 + y // 2) % 2
                edge = y == mid or se.near(base, (x, y), body, 4) < 4
                px[(x, y)] = ramp[0] if edge else ramp[2 + plate]
    return apply


# ----------------------------------------------------------------------------------------- Caves
def cave_shaman():
    derive('cave_shaman', ('wizard', 'wizard'), {
        'e8b796': CAVE_SKIN[4], 'b86f50': CAVE_SKIN[2], '68386c': HIDE[1], 'b55088': HIDE[3], '3e2731': HIDE[0],
        '2ce8f5': '9a9a9a', '0099db': '5e5e66', 'feae34': BONE[4], 'fee761': BONE[3], 'a22633': 'ff0044'},
        [se.eyes('181425', ['e8b796', 'b86f50'], 'ff0044')], '''
# Cave shaman: the cave folk's elder, pale tan skin, a hide robe 3e2731..9a6a44 with a bone headdress, a staff with a
# grey stone 9a9a9a; gives nearby enemies a stone skin that soaks one hit. Drawn by
# tools/sprite/parts/units_2026_11_25_art.py over wizard.aseprite (same frames and tags).''')


def wall_crawler():
    body = ['2a1a33', '45254f', '68386c', '8e4f7a', 'b55088']
    derive('wall_crawler', ('fastswampling', 'fastswampling'), {
        '2a1a33': '3e2731', '45254f': '5d3a2a', '68386c': '8a5a34', '8e4f7a': 'b07a44', 'b55088': 'c89a5a',
        'b6d53c': 'e4c08a', 'e6f07a': 'f0d8a8', 'f6757a': 'ff0044', 'fee761': 'ff0044'},
        [se.stripes_x(body, '3e2731', 2)], '''
# Wall crawler: a cave centipede-crawler with a segmented rust-brown back 3e2731..c89a5a, pale legs and red eyes; climbs
# over walls instead of walking the maze. Drawn by tools/sprite/parts/units_2026_11_25_art.py over
# fastswampling.aseprite (same frames and tags).''')


def spore_carrier():
    skin = ['b59e85', 'bfa98c', 'cab494', 'd5bf9b', 'e0caa3', 'ead4aa', 'ecd8b1', 'eddbb7', 'efdebd']
    pale = ['8a8070', '9a9080', 'aaa090', 'b8b0a0', 'c4bca8', 'd0c8b4', 'dcd4c0', 'e4dcc8', 'ece4d0']
    mapping = dict(zip(skin, pale))
    mapping.update({'a22633': '68386c', 'f6757a': '8e4f7a'})
    derive('spore_carrier', ('weakling', 'weakling_aseprite'), mapping,
           [cap(skin, ['45254f', '68386c', 'b55088'], 'f0e8d0'), spots(skin, '8fc46a', 9)], '''
# Spore carrier: a cave weakling overgrown by a purple mushroom 45254f/68386c/b55088 with pale spots, mouldy grey skin
# and green mould 8fc46a; killed, it bursts into a cloud of healing spores. Drawn by
# tools/sprite/parts/units_2026_11_25_art.py over the weakling's frames.''')


def glow_moth():
    derive('glow_moth', ('batling', 'batling'), {
        'ecd8b1': 'f0f0c0', 'd5bf9b': 'd8d890', 'b59e85': 'a8a868', '68386c': '3e4a5a', 'b55088': '6a8a8a',
        'f6757a': 'b6d53c', 'a22633': '2a3a40', 'ff0044': 'e6f07a', 'fee761': 'e6f07a', '3e2731': '1e2a30'}, [], '''
# Glow moth: the caves' second flyer, a pale moth f0f0c0/d8d890 with dusky blue-grey wings 3e4a5a/6a8a8a and glowing
# green-yellow spots b6d53c/e6f07a; comes in flocks. Drawn by tools/sprite/parts/units_2026_11_25_art.py over
# batling.aseprite.''')


# ----------------------------------------------------------------------------------------- Swamp
def bog_witch():
    derive('bog_witch', ('wizard', 'wizard'), {
        'e8b796': '8fc46a', 'b86f50': '4a9a5c', '68386c': SWAMP_TEAL[1], 'b55088': SWAMP_TEAL[2], '3e2731': SWAMP_TEAL[0],
        '2ce8f5': 'b55088', '0099db': '68386c', 'feae34': '7a9a1e', 'fee761': 'b6d53c', 'a22633': '45254f'},
        [se.eyes('181425', ['e8b796', 'b86f50'], 'fee761')], '''
# Bog witch: a green-skinned swamp hag 4a9a5c/8fc46a in moss-teal rags 17323a..2d7356, yellow eyes, a crooked staff
# with a purple hex light b55088; curses towers to attack slower. Drawn by tools/sprite/parts/units_2026_11_25_art.py
# over wizard.aseprite.''')


def snapping_turtle():
    body = ['e8b796', 'c28569', 'f6757a', 'b55088', '68386c', '3e2731']
    mapping = {'e8b796': '7a9a4a', 'c28569': '4a7a3a', 'f6757a': '8fc46a', 'b55088': '3e5a2a', '68386c': '2a3a22',
               '3e2731': '1e2a1a', '7a9a1e': '2f6b3d', 'b6d53c': '4a8a45', 'e6f07a': '7cbf4a', 'c0cbdc': 'e0e0c0'}
    shell_ramp = ['1e2a1a', '3e3a22', '5d5a2a', '7a6e34']
    name, src = 'snapping_turtle', ('plaguepig', 'plaguepig')
    path = os.path.join(se.ROOT, src[0], src[1] + '.aseprite')
    w, h, durs, tags = se.info(path)
    frames = se.frames_of(path, len(durs), w, h)
    over = [shell(body, shell_ramp), spots(['e8b796', 'c28569'], '2f6b3d', 8)]
    out = []
    for tag, a, b in tags:
        fs = []
        for i in range(a, b + 1):
            px = {p: mapping.get(c, c) for p, c in frames[i].items()}
            for o in over:
                o(frames[i], px, i)
            fs.append(px)
        out.append((tag, durs[a], fs))
    # SHELL: only the dome shows, head and legs pulled in (it crawls on, slowly, in it)
    box = bbox(frames[0], body)
    cx, cy = (box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0 + 1

    def dome(dy, squash):
        px = {}
        blob(px, cx, cy + dy, (box[2] - box[0]) / 2.0 - 1, (box[3] - box[1]) / 2.0 - squash, shell_ramp)
        for (x, y) in list(px):
            if (x // 3 + y // 2) % 2 and px[(x, y)] != shell_ramp[0]:
                px[(x, y)] = shell_ramp[2]
        for x in range(int(cx - 3), int(cx + 4)):
            px[(x, int(cy + dy + (box[3] - box[1]) / 2.0 - squash))] = '1e2a1a'
        return px
    out.append(('SHELL', 160, [dome(0, 1), dome(1, 1.5), dome(1, 1.5), dome(0, 1)]))
    save(name, '''
# Snapping turtle: the swamp's new tank, a mossy olive turtle 4a7a3a/7a9a4a under a plated dome shell 1e2a1a..7a6e34;
# after a big hit it pulls into the shell (SHELL) and takes far less for a moment. Drawn by
# tools/sprite/parts/units_2026_11_25_art.py over plaguepig.aseprite plus the SHELL tag from parts.''', (w, h), out)


def mosquito():
    derive('mosquito', ('giant_wasp', 'giant_wasp'), {
        'feae34': '5e5458', 'fee761': '847a80', 'f77622': 'a22633', '17323a': '2a2028', '1f5048': '3e3038',
        '181425': '1e1a22', '8b9bb4': '8b9bb4', 'c0cbdc': 'c0cbdc', 'ffffff': 'dfe6f0'}, [], '''
# Mosquito: the swamp's group flyer, a grey-brown bloodsucker 5e5458/847a80 with a red belly full of blood a22633 and
# pale wings; comes in clouds. Drawn by tools/sprite/parts/units_2026_11_25_art.py over giant_wasp.aseprite.''')


LEECH = ['2a1a22', '45253a', '68384a', '8e4f5a', 'b06a6a']


def leech(stretch=0.0, bob=0, mouth=0, swell=0.0, flat=0.0, drop=None):
    """a fat striped leech mother (26x26), head to the right; stretch lengthens and thins her as she inches"""
    px = {}
    rx, ry = 9 + stretch * 2, 5.5 - stretch - flat
    cy = 16 + bob + flat * 0.8
    blob(px, 12, cy, rx, ry, LEECH)
    if swell:
        blob(px, 6, cy - 1, 4 + swell, 4 + swell * 0.7, LEECH)
    for (x, y), c in list(px.items()):
        if c != LEECH[0] and x % 4 == 1:
            px[(x, y)] = LEECH[1]
        if c != LEECH[0] and abs(y - (cy - ry * 0.4)) < 0.6 and x % 2:
            px[(x, y)] = 'c89a3a'
    head = 12 + rx
    blob(px, head - 1, cy - 1, 2.6, 2.4, LEECH)
    px[(int(head), int(cy - 2))] = 'fee761'
    if mouth:
        for dy in range(-1, 2):
            px[(int(head) + 1 + mouth, int(cy - 1 + dy))] = 'a22633' if dy else '2a1a22'
    if drop is not None:
        dx, dy = drop
        for x in range(dx, dx + 4):
            px[(x, dy)] = LEECH[2]
            px[(x, dy + 1)] = LEECH[1]
        px[(dx + 3, dy)] = 'fee761'
    return {p: c for p, c in px.items() if 1 <= p[0] <= 24 and 1 <= p[1] <= 24}


def leech_mother():
    tags = [
        ('IDLE', 180, [leech(), leech(bob=-1, swell=0.3), leech(), leech(swell=0.3)]),
        ('WALK', 140, [leech(0.0), leech(0.4), leech(0.8), leech(0.4)]),
        ('ATTACK', 110, [leech(-0.2), leech(0.3, mouth=1), leech(0.6, mouth=2), leech()]),
        ('DEATH', 150, [leech(swell=0.5), leech(flat=1.0), leech(flat=2.0), leech(flat=3.0), leech(flat=3.5)]),
        ('LAY_EGG', 140, [leech(swell=1.0), leech(swell=2.0), leech(swell=1.0, drop=(3, 20)), leech(drop=(2, 21))]),
    ]
    save('leech_mother', '''
# Leech mother: a bloated swamp leech 2a1a22..b06a6a with gold side stripes c89a3a and a yellow eye; inches along and
# swells at the back to drop a leechling (LAY_EGG). Drawn from parts by tools/sprite/parts/units_2026_11_25_art.py.''',
         (26, 26), tags)


# ----------------------------------------------------------------------------------------- Humans
def shieldbearer():
    body = ['181425', '3a4466', '5a6988', '8b9bb4', 'c0cbdc', 'a22633', 'e43b44', 'feae34', 'f77622', '733e39']
    derive('shieldbearer', ('armored_knight', 'armored_knight'), {
        'a22633': '124e89', 'e43b44': '0099db', 'f77622': 'feae34'},
        [tower_shield(body)], '''
# Shieldbearer: a knight in steel with a blue tabard 124e89/0099db and a tall blue-and-gold tower shield in front;
# enemies near him take less from bolts. Drawn by tools/sprite/parts/units_2026_11_25_art.py over
# armored_knight.aseprite.''')


def war_drummer():
    derive('war_drummer', ('soldier', 'soldier'), {
        '0099db': 'a22633', '124e89': '5d1d2c', 'c0cbdc': 'feae34', '8b9bb4': 'c28a3a', '5a6988': '8a5a2a',
        '3a4466': '5d3a2a'},
        [drum(['0099db', '124e89'])], '''
# War drummer: a human soldier in a red tabard a22633/5d1d2c and a brass helm feae34..5d3a2a with a war drum on his
# belly; his beat speeds up the troops round him. Drawn by tools/sprite/parts/units_2026_11_25_art.py over
# soldier.aseprite.''')


def crossbow_sniper():
    derive('crossbow_sniper', ('archer', 'archer'), {
        '265c42': '3a4466', '3e8948': '5a6988', 'b86f50': '5d3a2a', '733e39': '3e2731', 'ffffff': 'feae34',
        'a22633': '181425'}, [], '''
# Crossbow sniper: a human marksman in a slate hood 3a4466/5a6988 with a dark heavy crossbow and a gold-fletched bolt;
# shoots the tower that reaches farthest and stuns it. Drawn by tools/sprite/parts/units_2026_11_25_art.py over
# archer.aseprite.''')


RAM_WOOD = WOOD


def ram(roll=0, swing=0, bob=0, tilt=0, broken=0):
    """a wheeled ram (26x26): a roofed frame on two wheels, a log hung in it with an iron head to the right, and the
    men's legs pushing under it; swing pulls the log back (negative) and drives it forward"""
    px = {}
    top = 7 + bob
    if broken < 2:
        # the roof
        for x in range(4, 21):
            for y in range(top, top + 2):
                px[(x, y + (tilt if x > 12 else 0))] = '6e6250' if y == top else '4a4238'
        for x in range(4, 21, 3):
            px[(x, top)] = '847a80'
        # the posts
        for y in range(top + 2, top + 11):
            px[(5, y)] = WOOD[2]
            px[(19, y + tilt)] = WOOD[2]
        # the log on its chains
        ly = top + 6
        for x in range(6 + swing, 20 + swing):
            px[(x, ly)] = WOOD[4] if x % 4 else WOOD[3]
            px[(x, ly + 1)] = WOOD[2]
        for y in range(top + 2, ly):
            px[(9, y)] = '847a80'
            px[(16, y)] = '847a80'
        for dy in (-1, 0, 1, 2):
            px[(20 + swing, ly + dy)] = '3a4466' if dy in (-1, 2) else '8b9bb4'
            px[(21 + swing, ly + dy)] = '5a6988' if dy in (0, 1) else '3a4466'
        px[(22 + swing, ly)] = '3a4466'
        px[(22 + swing, ly + 1)] = '3a4466'
        # the base beam
        for x in range(4, 21):
            px[(x, top + 11 + (tilt if x > 12 else 0))] = WOOD[1]
    else:
        for x in range(3, 22):
            px[(x, 21)] = WOOD[2] if x % 3 else WOOD[1]
            px[(x, 20)] = WOOD[4] if x % 5 else WOOD[3]
        px[(22, 20)] = '8b9bb4'
        px[(22, 21)] = '3a4466'
    # wheels
    for wx in (7, 17):
        wy = top + 13 + (tilt if wx > 12 else 0)
        if broken >= 2:
            wx, wy = wx + 1, 21
        for dx, dy in ((-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)):
            px[(wx + dx, wy + dy)] = WOOD[0] if (dx + dy + roll) % 2 else WOOD[2]
        px[(wx, wy)] = '847a80'
    # the men under the roof: two pairs of blue legs stepping
    if broken == 0:
        for i, lx in enumerate((10, 14)):
            step = (roll + i) % 2
            for y in range(top + 12, top + 15):
                px[(lx + (step if y == top + 14 else 0), y)] = '124e89'
            px[(lx + step, top + 15)] = '3e2731'
    return {p: c for p, c in px.items() if 1 <= p[0] <= 24 and 1 <= p[1] <= 24}


def battering_ram():
    tags = [
        ('IDLE', 200, [ram(), ram(swing=-1)]),
        ('WALK', 140, [ram(roll=r, bob=r % 2) for r in range(4)]),
        ('ATTACK', 110, [ram(swing=-2), ram(swing=-3), ram(swing=2), ram(swing=1), ram()]),
        ('DEATH', 150, [ram(tilt=1), ram(tilt=2), ram(broken=2), ram(broken=3)]),
    ]
    save('battering_ram', '''
# Battering ram: a human siege ram, a roofed wooden frame 3e2731..b86f50 on two wheels with an iron-headed log on
# chains, the soldiers' blue legs pushing it from under the roof; goes for walls and smashes them. Drawn from parts by
# tools/sprite/parts/units_2026_11_25_art.py.''', (26, 26), tags)


# ----------------------------------------------------------------------------------------- Scorched Lands
def wurm(rise=1.0, open_=0, sway=0.0, sink=0.0, dead=0):
    """a sand wurm (26x26) rearing out of a sand mound: rise 0..1 how much body shows, open_ the jaws"""
    px = {}
    # the mound
    blob(px, 12, 21, 9, 2.6, SAND)
    if dead:
        blob(px, 13, 19 + dead, 8, 3 - dead * 0.5, ['5a4a3a', '7a6a50', '9a8a6a', 'b0a080'])
        return {p: c for p, c in px.items() if 1 <= p[0] <= 24 and 1 <= p[1] <= 24}
    height = int(14 * rise * (1 - sink))
    pts = []
    for s in range(height + 1):
        t = s / max(1, height)
        pts.append((round(12 + math.sin(t * 2.2 + sway) * 3 * t), 20 - s))
    for i, (x, y) in enumerate(pts):
        r = 3 if i < len(pts) - 3 else 2
        for dx in range(-r, r + 1):
            shade = 0 if dx == -r else (3 if dx > 0 else 2)
            if i % 3 == 0:
                shade = max(0, shade - 1)
            px[(x + dx, y)] = ['5a4a3a', '7a6a50', '9a8a6a', 'b0a080'][shade]
    if height >= 4:
        hx, hy = pts[-1]
        for dx in range(-2, 4):
            px[(hx + dx, hy - 1)] = '7a6a50'
        if open_:
            for dx in range(0, 3 + open_):
                px[(hx + 1 + dx, hy - 2 - open_)] = 'b0a080'
                px[(hx + 1 + dx, hy)] = 'b0a080'
                px[(hx + 1 + dx, hy - 1)] = 'a22633'
            for dx in range(1, 3 + open_, 2):
                px[(hx + 1 + dx, hy - 1 - open_ + 1)] = 'f0e8d0'
        px[(hx, hy - 2)] = EMBER
    return {p: c for p, c in px.items() if 1 <= p[0] <= 24 and 1 <= p[1] <= 24}


def sand_wurm():
    tags = [
        ('IDLE', 170, [wurm(sway=0.0), wurm(sway=0.4), wurm(sway=0.8), wurm(sway=0.4)]),
        ('WALK', 130, [wurm(0.8, sway=0.0), wurm(0.9, sway=0.6), wurm(0.8, sway=1.2), wurm(0.7, sway=0.6)]),
        ('ATTACK', 100, [wurm(sway=-0.4), wurm(open_=1, sway=0.2), wurm(open_=2, sway=0.6), wurm()]),
        ('DEATH', 150, [wurm(open_=2), wurm(sink=0.4), wurm(sink=0.8), wurm(dead=1), wurm(dead=2)]),
        ('BURROW', 110, [wurm(sink=0.2), wurm(sink=0.5), wurm(sink=0.8), wurm(sink=1.0)]),
        ('EMERGE', 110, [wurm(sink=1.0), wurm(sink=0.6, open_=1), wurm(sink=0.2, open_=2), wurm()]),
    ]
    save('sand_wurm', '''
# Sand wurm: a ringed desert worm 5a4a3a..b0a080 rearing from a sand mound e4c08a with an ember eye and a red maw; dives
# under the sand (BURROW) and comes up far along the road (EMERGE). Drawn from parts by
# tools/sprite/parts/units_2026_11_25_art.py.''', (26, 26), tags)


def bone_vulture():
    derive('bone_vulture', ('giant_eagle', 'giant_eagle'), {
        'ffffff': BONE[4], 'c0cbdc': BONE[3], 'b86f50': BONE[2], '733e39': BONE[1], '3e2731': BONE[0],
        'feae34': '6e3424', 'f77622': '4a2a22', 'a22633': EMBER, '181425': EMBER}, [], '''
# Bone vulture: the ash desert's group flyer, a raised vulture's skeleton ece6d8..3a3430 with a rust beak and ember eyes;
# shot down, it falls and the bones walk on. Drawn by tools/sprite/parts/units_2026_11_25_art.py over
# giant_eagle.aseprite.''')


def mummy_priest():
    wraps = ['ffffff', 'c0cbdc', '8b9bb4']
    derive('mummy_priest', ('priest', 'priest'), {
        'ffffff': WRAPS[4], 'c0cbdc': WRAPS[3], '8b9bb4': WRAPS[2], 'e8b796': WRAPS[3], 'c28569': WRAPS[1],
        'feae34': '2ce8f5', 'fee761': '9cf0f8', 'f77622': '0099db', 'a22633': '124e89', '181425': '2ce8f5'},
        [se.ribs(wraps, WRAPS[3], WRAPS[1])], '''
# Mummy priest: an old-war priest wound in grave wrappings f0e8d0..5e5040, turquoise sigils 2ce8f5/0099db and glowing
# eyes; killed, its curse silences the towers round it. Drawn by tools/sprite/parts/units_2026_11_25_art.py over
# priest.aseprite.''')


def ash_harpy():
    derive('ash_harpy', ('giant_eagle', 'giant_eagle'), {
        'ffffff': 'e0caa3', 'c0cbdc': ASH[4], 'b86f50': ASH[2], '733e39': ASH[1], '3e2731': ASH[0],
        'feae34': EMBER, 'f77622': 'e43b44', 'a22633': GLOW}, [], '''
# Ash harpy: the volcano's flyer, a harpy with a pale face e0caa3, ash-grey wings 2a2028..a89ea4 and ember talons
# f77622/e43b44; dives at a tower and sets it burning. Drawn by tools/sprite/parts/units_2026_11_25_art.py over
# giant_eagle.aseprite.''')


# ----------------------------------------------------------------------------------------- the second round
def banner(body, size=(18, 18)):
    """a standard on a pole behind the body (its left side), a red flag with a gold drake at the top"""
    def apply(base, px, i):
        box = bbox(base, body)
        if box is None:
            return
        if box[3] - box[1] < 6:  # lying down: the pole lies along the ground
            for x in range(1, size[0] - 1):
                clamp_put(px, size, (x, box[3] + 1 if box[3] + 1 < size[1] - 1 else box[3]), '733e39' if x % 4 else 'feae34')
            return
        pole = max(5, box[0] - 1)
        for y in range(1, box[3] + 1):
            clamp_put(px, size, (pole, y), '733e39' if y > 1 else 'feae34')
        for y in range(2, 6):
            for x in range(pole - 4, pole):
                colour = 'a22633' if (x + y) % 5 else 'e43b44'
                if y == 3 and x == pole - 2:
                    colour = 'feae34'
                if y == 5 and (x - pole) % 2:
                    continue
                clamp_put(px, size, (x, y), colour)
    return apply


def tunnel_rat():
    derive('tunnel_rat', ('swarmling', 'swarmling'), {
        'ecd8b1': '9a8e80', 'd5bf9b': '7a6e64', 'b59e85': '5a4e48', 'b86f50': 'c28569', '733e39': '8a5a50',
        '3e2731': '2a2228', 'a22633': '3e3038'}, [], '''
# Tunnel rat: a grey-brown cave rat 2a2228..9a8e80 with a pink tail c28569 and red eyes; comes in swarms and runs under
# traps. Drawn by tools/sprite/parts/units_2026_11_25_art.py over swarmling.aseprite.''')


def bog_lurker():
    derive('bog_lurker', ('fastswampling', 'fastswampling'), {
        '2a1a33': '122218', '45254f': '1b3424', '68386c': '264a30', '8e4f7a': '33603a', 'b55088': '4a7a44',
        'b6d53c': '7a8a3a', 'e6f07a': 'a0a860', 'f6757a': 'c8b070', 'fee761': 'fee761'}, [], '''
# Bog lurker: a long murky-green swamp reptile 122218..4a7a44 with a mossy back 7a8a3a and yellow eyes; swims
# submerged (the game draws it see-through) until it nears the castle. Drawn by
# tools/sprite/parts/units_2026_11_25_art.py over fastswampling.aseprite.''')


def standard_bearer():
    body = ['0099db', '124e89', 'e8b796', 'c28569', 'c0cbdc', '8b9bb4', '5a6988', '3a4466']
    derive('standard_bearer', ('soldier', 'soldier'), {'0099db': 'a22633', '124e89': '5d1d2c'}, [banner(body)], '''
# Standard bearer: a human soldier in a red tabard a22633/5d1d2c carrying the invaders' standard, a red flag with a gold
# drake on a tall pole; troops near it shrug off slows and freezes. Drawn by tools/sprite/parts/units_2026_11_25_art.py
# over soldier.aseprite.''')


def ash_wraith():
    derive('ash_wraith', ('wizard', 'wizard'), {
        '68386c': ASH[1], 'b55088': ASH[2], '3e2731': ASH[0], 'e8b796': '3e3038', 'b86f50': '2a2028',
        '2ce8f5': EMBER, '0099db': 'a22633', 'feae34': ASH[3], 'fee761': ASH[4], 'a22633': ASH[0], 'ffffff': ASH[4]},
        [se.eyes('181425', ['e8b796', 'b86f50'], GLOW)], '''
# Ash wraith: a hooded shade of ash 2a2028..a89ea4 with a dark face, glowing eyes fee761 and an ember lantern on its
# staff; fades out of the world for a moment now and then. Drawn by tools/sprite/parts/units_2026_11_25_art.py over
# wizard.aseprite.''')


ALL = {
    'tunnel_rat': tunnel_rat, 'bog_lurker': bog_lurker, 'standard_bearer': standard_bearer, 'ash_wraith': ash_wraith,
    'cave_shaman': cave_shaman, 'wall_crawler': wall_crawler, 'spore_carrier': spore_carrier, 'glow_moth': glow_moth,
    'bog_witch': bog_witch, 'snapping_turtle': snapping_turtle, 'mosquito': mosquito, 'leech_mother': leech_mother,
    'shieldbearer': shieldbearer, 'battering_ram': battering_ram, 'war_drummer': war_drummer,
    'crossbow_sniper': crossbow_sniper,
    'sand_wurm': sand_wurm, 'bone_vulture': bone_vulture, 'mummy_priest': mummy_priest, 'ash_harpy': ash_harpy,
}

if __name__ == '__main__':
    for unit in (sys.argv[3:] or ALL):
        ALL[unit]()
