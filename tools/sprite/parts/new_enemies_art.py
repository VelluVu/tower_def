"""The 2026-11-16 enemies' own art (they were recolours of a parent until then): leaper frog, bloater, sapper, burrower
and crystal brute, each with IDLE, WALK, ATTACK and DEATH plus its ability's tags (LEAP/LAND, BURROW/EMERGE).
usage: new_enemies_art.py <parts dir> <enemy art dir>   (writes <name>/<name>.txt for each)"""
import math
import os
import sys

sys.path.insert(0, sys.argv[1])
from compose import Frame, part, write_spec  # noqa: E402

OUT = sys.argv[2]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[1] + "/x")))))
sys.path.insert(0, os.path.join(ROOT, "tools", "sprite"))
import recolor  # noqa: E402


def blob(f, cx, cy, rx, ry, ramp, light=(-0.5, -0.7)):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x - cx) / rx, (y - cy) / ry
            d = nx * nx + ny * ny
            if d <= 1.0:
                lit = -(nx * light[0] + ny * light[1])
                v = 0.5 + lit * 0.55 - (0.25 if d > 0.75 else 0)
                f.px[(x, y)] = ramp[max(0, min(len(ramp) - 1, int(v * len(ramp))))]


def thick(f, pts_, ramp, width=2):
    for i in range(len(pts_) - 1):
        (x0, y0), (x1, y1) = pts_[i], pts_[i + 1]
        steps = max(abs(x1 - x0), abs(y1 - y0), 1) * 2
        for s in range(steps + 1):
            t = s / steps
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for o in range(width):
                f.px[(round(x), round(y + o))] = ramp[min(len(ramp) - 1, 1 + (width - 1 - o))]


def dot(f, pts, ch):
    for p in pts:
        f.px[p] = ch


def shifted(f, dx=0, dy=0):
    g = Frame(f.w, f.h)
    for (x, y), c in f.px.items():
        if 1 <= x + dx < f.w - 1 and 1 <= y + dy < f.h - 1:
            g.px[(x + dx, y + dy)] = c
    return g


def clip_below(f, line_y):
    g = Frame(f.w, f.h)
    g.px = {k: v for k, v in f.px.items() if k[1] < line_y}
    return g


# ======================= leaper frog (18x18) =======================
FROG = {"1": "193c3e", "2": "265c42", "3": "3e8948", "4": "63c74d", "q": "ead4aa", "r": "e43b44", "K": "181425",
        "o": "f77622", "n": "f6757a"}
GREEN = ["1", "2", "3", "4"]


def frog(dy=0, crouch=0, pose="sit", tongue=0, blink=False, throat=False):
    """sit: hind leg folded under; leap: stretched out, arms reaching; crouch lowers the body before a jump."""
    f = Frame(18, 18)
    y = dy + crouch
    if pose == "sit":
        thick(f, [(6, 11 + y), (3, 13 + y), (4, 15), (8, 15)], GREEN)
        blob(f, 8.5, 11 + y, 5, 3.4 - crouch * 0.4, GREEN)
        blob(f, 12.5, 8.5 + y, 3.2, 2.6, GREEN)
        dot(f, [(9, 13 + y), (10, 13 + y), (11, 13 + y), (12, 12 + y)], "q")
        dot(f, [(12, 13 + y), (12, 14), (13, 15), (14, 15)], "3")
        if throat:
            dot(f, [(13, 11 + y), (14, 11 + y), (14, 10 + y)], "q")
        dot(f, [(13, 6 + y), (14, 6 + y)], "r" if not blink else "2")
        dot(f, [(14, 7 + y)], "K" if not blink else "1")
        dot(f, [(7, 9 + y), (9, 10 + y), (5, 11 + y)], "o")
        if tongue:
            dot(f, [(15 + i, 9 + y) for i in range(min(tongue, 2))], "n")
    else:
        thick(f, [(5, 9 + y), (2, 12 + y), (1, 15)], GREEN)
        thick(f, [(6, 10 + y), (4, 14 + y), (3, 16)], GREEN, 1)
        blob(f, 9, 8 + y, 5.5, 2.6, GREEN)
        blob(f, 13.5, 6 + y, 3.0, 2.3, GREEN)
        dot(f, [(10, 10 + y), (11, 10 + y), (12, 9 + y)], "q")
        thick(f, [(13, 9 + y), (15, 11 + y), (16, 12 + y)], GREEN, 1)
        dot(f, [(14, 4 + y), (15, 4 + y)], "r")
        dot(f, [(15, 5 + y)], "K")
        dot(f, [(8, 6 + y), (10, 7 + y), (6, 8 + y)], "o")
    return f


def frog_dead(n):
    f = Frame(18, 18)
    flat = min(n, 2)
    blob(f, 9, 13 + flat * 0.5, 5.5 + flat * 0.5, 2.6 - flat * 0.5, ["1", "q", "q", "3"])
    for lx in (5, 12):
        thick(f, [(lx, 12), (lx - 1, 9 + flat)], GREEN, 1)
    dot(f, [(14, 12)], "K")
    return f


def write_frog():
    write_spec(OUT + "/leaper_frog/leaper_frog.txt", """
# Source of leaper_frog.aseprite and leaper_frog.png (python tools/sprite/sprite.py build <this> leaper_frog.aseprite).
# Leaper frog: a red-eyed tree frog, deep greens 193c3e..63c74d, pale belly ead4aa, orange spots f77622. Sits on long
# folded hind legs, hops, licks with its tongue, flips belly up; LEAP crouches and launches, LAND comes down from the air.
# Drawn by tools/sprite/parts/new_enemies_art.py.""", FROG, (18, 18), [
        ("IDLE", 180, [frog(), frog(throat=True), frog(), frog(blink=True)]),
        ("WALK", 110, [frog(crouch=1), shifted(frog(pose="leap"), 0, 1), frog(pose="leap"), frog()]),
        ("ATTACK", 100, [frog(crouch=1), frog(tongue=1), frog(tongue=2), frog()]),
        ("DEATH", 140, [frog(crouch=1), frog_dead(0), frog_dead(1), frog_dead(2)]),
        ("LEAP", 90, [frog(crouch=1), frog(pose="leap"), shifted(frog(pose="leap"), 0, -2)]),
        ("LAND", 90, [shifted(frog(pose="leap"), 0, -2), frog(pose="leap"), frog(crouch=1), frog()]),
    ])


# ======================= bloater (26x26) =======================
BLOAT = {"1": "3e2731", "2": "68386c", "3": "b55088", "4": "f6757a", "y": "fee761", "g": "63c74d", "K": "181425",
         "w": "ffffff", "p": "3e8948"}
BRUISE = ["1", "2", "3", "4"]


def bloater(bob=0, sway=0, mouth=0, swell=0.0, cracked=False, dx=0):
    f = Frame(26, 26)
    cy = 11 + bob
    for i, x0 in enumerate((8, 12, 16)):
        s = round(math.sin(sway + i * 1.7))
        thick(f, [(x0 + dx, cy + 7), (x0 + dx - 1 + s, cy + 10), (x0 + dx + s, min(cy + 13, 24))], ["1", "2"], 1)
    blob(f, 13 + dx, cy, 9 + swell, 7.5 + swell, BRUISE)
    for (px, py, c) in ((8, -3, "y"), (9, -3, "y"), (17, 2, "y"), (11, 4, "y"), (18, -4, "y"), (9, -2, "g"), (17, 3, "g"), (18, -3, "g")):
        f.px[(px + dx, cy + py)] = c
    dot(f, [(14 + dx, cy - 2), (16 + dx, cy - 2)], "K")
    dot(f, [(14 + dx, cy - 3)], "w")
    mouth_row = [(13 + dx + i, cy + 1) for i in range(4)]
    dot(f, mouth_row, "1")
    if mouth:
        dot(f, [(13 + dx + i, cy + 2) for i in range(4)], "K")
    if cracked:
        for (x, y) in list(f.px):
            if (x + y) % 6 == 0 and f.px[(x, y)] in ("3", "4"):
                f.px[(x, y)] = "1"
    return f


def bloater_burst(n):
    f = Frame(26, 26)
    if n == 0:
        f = bloater(swell=1.0, cracked=True)
    # gobs of pus flying out: 2x2 clusters, fewer and further each frame
    for a in range(15 + n * 20, 375 + n * 20, 45 + n * 15):
        r = 5 + n * 3
        x, y = round(13 + r * math.cos(math.radians(a))), round(12 + r * 0.7 * math.sin(math.radians(a)))
        for (ox, oy) in ((0, 0), (1, 0), (0, 1), (1, 1)) if n < 3 else ((0, 0), (1, 0)):
            if 1 <= x + ox <= 24 and 1 <= y + oy <= 24:
                f.px[(x + ox, y + oy)] = "y" if (ox + oy) == 0 else "g"
    if n >= 1:
        blob(f, 13, 21, 7 - n, 2, ["1", "2", "2", "3"])
        dot(f, [(10, 20), (15, 21), (12, 22)], "p")
    return f


def write_bloater():
    write_spec(OUT + "/bloater/bloater.txt", """
# Source of bloater.aseprite and bloater.png (python tools/sprite/sprite.py build <this> bloater.aseprite).
# Bloater: a swollen bruise-purple sack 3e2731..f6757a floating on dangling tendrils, glowing pustules fee761/63c74d,
# small black eyes. Bobs as it drifts, lunges with its mouth open, swells, cracks and bursts in a spray of pus.
# Drawn by tools/sprite/parts/new_enemies_art.py.""", BLOAT, (26, 26), [
        ("IDLE", 160, [bloater(0, 0.0), bloater(-1, 0.8), bloater(-1, 1.6), bloater(0, 2.4)]),
        ("WALK", 140, [bloater(0, 0.0), bloater(-1, 1.0), bloater(-1, 2.0), bloater(0, 3.0)]),
        ("ATTACK", 110, [bloater(0, 0.0, dx=-1), bloater(0, 0.5, mouth=1, dx=1), bloater(0, 1.0, mouth=1, dx=2), bloater(0, 1.5)]),
        ("DEATH", 120, [bloater(swell=0.6), bloater_burst(0), bloater_burst(1), bloater_burst(2), bloater_burst(3)]),
    ])


# ======================= sapper (18x18): the soldier's body with a satchel and a lit bomb =======================
SOLDIER_SPEC = os.path.join(ROOT, "assets", "art", "units", "enemy", "soldier", "soldier.txt")
SAP_PAL = {"A": "c0cbdc", "B": "8b9bb4", "C": "5a6988", "D": "3a4466", "s": "e8b796", "t": "c28569", "K": "181425",
           "b": "b86f50", "n": "733e39", "g": "f77622", "l": "b86f50", "m": "733e39", "o": "3e2731", "r": "a22633",
           "f": "fee761", "x": "262b44", "w": "ffffff", "e": "e4a672"}


def soldier_frames():
    lines = open(SOLDIER_SPEC, encoding="utf8").read().split("\n")
    body = lines[lines.index("---") + 1:]
    tags, current = {}, None
    rows = []
    for l in body:
        if l.startswith("@"):
            current = l[1:].split()[0]
            tags[current] = []
            continue
        if current is None:
            continue
        if l.strip() == "":
            if rows:
                tags[current].append(rows)
                rows = []
            continue
        rows.append(l)
    if rows and current:
        tags[current].append(rows)
    return tags


def sapper_from(rows, bomb_at=None, satchel=True):
    """A soldier frame without its spear, a satchel on the hip and a bomb where the hand is."""
    f = Frame(18, 18)
    f.stamp(part("\n".join(rows)))
    for (x, y), c in list(f.px.items()):
        if c == "l" and x >= 11:
            del f.px[(x, y)]
    if satchel:
        body = [x for (x, y), c in f.px.items() if c in "nb" and 7 <= y <= 10]
        if body:
            sx = min(body) - 1
            dot(f, [(sx, 9), (sx - 1, 9), (sx, 10), (sx - 1, 10)], "n")
            dot(f, [(sx, 8)], "e")
    if bomb_at:
        bx, by = bomb_at
        dot(f, [(bx, by), (bx + 1, by), (bx, by + 1), (bx + 1, by + 1)], "x")
        dot(f, [(bx + 1, by - 1)], "g")
        dot(f, [(bx + 2, by - 2)], "f")
    return f


def write_sapper():
    tags = soldier_frames()
    idle = [sapper_from(r, (12, 10)) for r in tags["IDLE"]]
    walk = [sapper_from(r, (12, 10)) for r in tags["WALK"]]
    base = tags["IDLE"][0]
    attack = [sapper_from(base, (8, 3)), sapper_from(base, (11, 3)), sapper_from(base, (14, 5)), sapper_from(base, None)]
    death = [sapper_from(r, None) for r in tags["DEATH"]]
    write_spec(OUT + "/sapper/sapper.txt", """
# Source of sapper.aseprite and sapper.png (python tools/sprite/sprite.py build <this> sapper.aseprite).
# Sapper: the soldier's kettle helm and leather tabard b86f50/733e39 without the spear, a satchel of charges on the
# hip and a lit bomb 262b44 with a spark f77622/fee761 in hand; ATTACK swings it over the head and throws it.
# Drawn by tools/sprite/parts/new_enemies_art.py from soldier.txt's frames.""", SAP_PAL, (18, 18), [
        ("IDLE", 200, idle), ("WALK", 120, walk), ("ATTACK", 110, attack), ("DEATH", 130, death)])


# ======================= burrower (18x18): a hunched mole-runt =======================
MOLE = {"1": "3e2731", "2": "733e39", "3": "b86f50", "4": "c28569", "n": "f6757a", "w": "c0cbdc", "K": "181425",
        "d": "8a4b32", "e": "e4a672"}
FUR = ["1", "2", "3", "4"]


def burrower(dy=0, breathe=0.0, claws=0, snout=0, step=0):
    f = Frame(18, 18)
    blob(f, 8, 10.5 + dy, 5, 4.5 + breathe, FUR)
    blob(f, 12, 9 + dy, 3, 2.6, FUR)
    dot(f, [(15 + snout, 9 + dy), (15 + snout, 10 + dy)], "n")
    dot(f, [(12, 8 + dy)], "K")
    cx = 11 + claws
    dot(f, [(cx, 14 + dy - claws), (cx + 1, 15 - claws), (cx + 2, 15 - claws), (cx + 3, 15 - claws)], "w")
    feet = [(5, 15), (6, 15), (8, 15), (9, 15)] if step == 0 else [(4, 15), (5, 15), (9, 15), (10, 15)]
    dot(f, feet, "1")
    return f


def mound(f, depth, t=0):
    for x in range(3, 15):
        for y in range(14, 17):
            if (x * 3 + y + t) % 4:
                f.px[(x, y)] = "d" if y > 14 else "e"
    for i, (x, y) in enumerate(((4, 9), (6, 7), (14, 8), (15, 6), (11, 9))):
        if (i + t) % 2 == 0:
            f.px[(x, y + depth)] = "d"
    return f


def burrower_dig(depth, t):
    f = clip_below(shifted(burrower(), 0, depth), 14)
    return mound(f, min(depth, 3), t)


def burrower_dead(n):
    f = Frame(18, 18)
    blob(f, 9, 13 + n * 0.5, 6, 3 - n * 0.6, FUR)
    dot(f, [(13, 12)], "K")
    dot(f, [(15, 13)], "n")
    dot(f, [(6, 10 + n), (7, 10 + n), (11, 10 + n)], "w")
    return f


def write_burrower():
    write_spec(OUT + "/burrower/burrower.txt", """
# Source of burrower.aseprite and burrower.png (python tools/sprite/sprite.py build <this> burrower.aseprite).
# Burrower: a hunched mole-runt in browns 3e2731..c28569 with a pink snout f6757a and big pale digging claws c0cbdc.
# Sniffs, scurries, claws; BURROW sinks it into a dirt mound with flying clods, EMERGE brings it back out.
# Drawn by tools/sprite/parts/new_enemies_art.py.""", MOLE, (18, 18), [
        ("IDLE", 180, [burrower(), burrower(breathe=0.3), burrower(snout=1), burrower(breathe=0.3)]),
        ("WALK", 100, [burrower(step=0), burrower(dy=-1, step=1), burrower(step=1), burrower(dy=-1, step=0)]),
        ("ATTACK", 100, [burrower(claws=1), burrower(claws=2, snout=1), burrower(claws=1), burrower()]),
        ("DEATH", 130, [burrower(dy=1), burrower_dead(0), burrower_dead(1), burrower_dead(2)]),
        ("BURROW", 100, [burrower_dig(1, 0), burrower_dig(3, 1), burrower_dig(5, 0), burrower_dig(8, 1)]),
        ("EMERGE", 100, [burrower_dig(8, 0), burrower_dig(5, 1), burrower_dig(2, 0), burrower()]),
    ])


# ======================= crystal brute (26x26): the beefling, crystal-blue, with violet crystal spikes =======================
BEEFLING = os.path.join(ROOT, "assets", "art", "units", "enemy", "beefling", "beefling.aseprite")
CRYSTAL_SWAPS = {"b59e85": "262b44", "cab494": "3a4466", "d5bf9b": "124e89", "e0caa3": "0099db", "ead4aa": "0099db",
                 "ecd8b1": "2ce8f5", "efdebd": "c0cbdc", "87202b": "45254f", "902a35": "68386c", "a22633": "b55088"}


def write_crystal_brute():
    text = recolor.spec_from_aseprite(BEEFLING)
    head, body = text.split("---", 1)
    pal = {}
    for line in head.splitlines():
        if " = " in line:
            k, v = line.split(" = ")
            pal[k.strip()] = CRYSTAL_SWAPS.get(v.strip().lower(), v.strip())
    pal.update({"Q": "b55088", "P": "f6757a", "W": "ffffff", "V": "45254f"})
    tags = []
    current, rows, frames = None, [], []
    for line in body.split("\n") + [""]:
        if line.startswith("@"):
            if current:
                tags.append((current[0], current[1], frames))
            current, frames, rows = (line[1:].split()[0], int(line.split()[1])), [], []
            continue
        if line.strip() == "":
            if rows:
                f = Frame(26, 26)
                f.stamp(part("\n".join(rows)))
                frames.append(spikes(f, current[0]))
                rows = []
            continue
        rows.append(line)
    if current:
        tags.append((current[0], current[1], frames))
    write_spec(OUT + "/crystal_brute/crystal_brute.txt", """
# Source of crystal_brute.aseprite and crystal_brute.png (python tools/sprite/sprite.py build <this> crystal_brute.aseprite).
# Crystal brute: the beefling's frames recoloured crystal blue 262b44..c0cbdc with violet loincloth, and amethyst
# crystals b55088/f6757a with white tips growing from its back and shoulders (placed on each frame's body outline).
# Drawn by tools/sprite/parts/new_enemies_art.py from beefling.aseprite.""", pal, (26, 26), tags)


def spikes(f, tag):
    """Crystals growing up and back out of the brute's back (it faces right): from the back edge of three shoulder
    rows, each a 2-wide shard leaning left, violet at the root, pink lit side, a white tip."""
    if tag == "DEATH":
        return f
    if not f.px:
        return f
    head_top = min(y for (x, y) in f.px)
    for (drop, h) in ((5, 3), (8, 4), (11, 3)):
        row = head_top + drop
        xs = [x for (x, y) in f.px if y == row]
        if not xs:
            continue
        x0 = min(xs)
        for i in range(h):
            x, y = x0 - i // 2, row - i - 1
            if x - 1 < 1 or y < 1:
                break
            f.px[(x, y)] = "V" if i == 0 else "Q"
            f.px[(x - 1, y)] = "V" if i == 0 else "P"
        tip = (x0 - (h - 1) // 2 - 1, row - h - 1)
        if tip[0] >= 1 and tip[1] >= 1:
            f.px[tip] = "W"
    return f


write_frog()
write_bloater()
write_sapper()
write_burrower()
write_crystal_brute()
print("ok")
