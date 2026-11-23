#!/usr/bin/env python3
"""Draws the title screen's hoard scene: Puffe's castle courtyard at dusk with the treasure pile, the dragon
eggs on top and the hatchlings that come out of them.

    python tools/art/hoard_backdrop.py [--preview <dir>]

Writes into assets/art/ui/title/hoard/ (each piece as a text spec, its .aseprite and packed .png through
tools/sprite/sprite.py build):
    hoard_hall          the 320x180 still background (drawn at 2x, it fills the 640x360 screen)
    hoard_egg_<el>      an egg: IDLE, WOBBLE, CRACK, HATCH (the cap flies off, the head peeks out), EMPTY
    hatchling_<el>      a hatchling facing right: IDLE, WALK, HOP, FLY
    hoard_torch, hoard_flag, hoard_sparkle
and the SpriteFrames for the animated ones into scenes/ui/menu/hoard_backdrop/frames/.
<el> is mint, fire, frost or poison (the tower colours). The scene is laid out around HOARD_X: the menu
sits on the left, so the pile is right of the screen's middle. HoardBackdrop reads the positions it needs
from its own constants; keep EGG_SPOTS, TORCH_SPOTS and FLAG_SPOTS in step with hoard_backdrop.gd.
Edit the shapes, palette or layout here and rerun; the random parts use a fixed seed.
"""
import math
import os
import random
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets" / "art" / "ui" / "title" / "hoard"
FRAMES = ROOT / "scenes" / "ui" / "menu" / "hoard_backdrop" / "frames"
SPRITE_TOOL = ROOT / "tools" / "sprite" / "sprite.py"

W, H = 320, 180
HOARD_X = 206                  # the pile's middle
FLOOR_TOP = 100                # where the back wall meets the floor
PILE_FLOOR_Y = 150             # the pile footprint's middle on the floor
PILE_RX, PILE_RY, PILE_H = 70, 14, 42
WALL_TOP = 50
TOWERS = [(30, 30), (118, 20), (296, 20)]           # (centre x, radius) of the round towers
TORCH_SPOTS = [(146, 72), (266, 72)]                # flame bottoms, for the torch sprites
FLAG_SPOTS = [(119, 4), (297, 4), (31, 16)]         # pole tops, for the flag sprites
BANNERS = [(168, 58), (244, 58)]
GATE = (206, 62, 22)           # centre x, arch top, half width
EGG_SPOTS = [(206, 100), (184, 107), (228, 107), (165, 120), (247, 120)]   # egg bottoms on the pile

# Endesga 32 and the castle's greys
C = {
    "night0": "181425", "night1": "262b44", "night2": "3a4466", "night3": "5a6988", "dusk": "68386c",
    "dusk2": "b55088", "star": "c0cbdc", "white": "ffffff",
    "s0": "262b44", "s1": "3c3b4c", "s2": "454556", "s3": "4e4e5f", "s4": "565869", "s5": "5f6273",
    "s6": "717586", "s7": "9da5b6", "s8": "c0cbdc",
    "g0": "3e2731", "g1": "733e39", "g2": "be4a2f", "g3": "f77622", "g4": "feae34", "g5": "fee761",
    "wood0": "3e2731", "wood1": "733e39", "wood2": "b86f50",
    "m0": "107338", "m1": "0b9b55", "m2": "06c374", "m3": "02eb93", "m4": "68ffd0", "m5": "a2f6db",
    "r0": "5d1d2c", "r1": "a22633", "r2": "e43b44", "r3": "f6757a",
    "b0": "124e89", "b1": "0099db", "b2": "2ce8f5",
    "p0": "45254f", "p1": "68386c", "p2": "b55088",
    "e0": "265c42", "e1": "3e8948", "e2": "63c74d",
}
GOLD = ["g0", "g1", "g2", "g3", "g4", "g5", "white"]
STONE = ["s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7"]


def rgb(key):
    h = C[key]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def put(self, x, y, key):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h and key:
            self.px[y][x] = key

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def rect(self, x0, y0, x1, y1, key):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.put(x, y, key)

    def image(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                k = self.px[y][x]
                if k:
                    im.putpixel((x, y), rgb(k) + (255,))
        return im


def band(value, ramp, x, y, dither=False):
    """A ramp step from a 0-1 value: clean bands, with a checker where two steps meet when asked."""
    v = max(0.0, min(0.999, value)) * len(ramp)
    i, frac = int(v), v - int(v)
    if dither and frac > 0.8 and (x + y) % 2 == 0 and i + 1 < len(ramp):
        i += 1
    return ramp[i]


# ---------------------------------------------------------------- background

def draw_sky(cv):
    stops = [(0, "night0"), (12, "night1"), (26, "night2"), (36, "dusk"), (44, "dusk2")]
    for y in range(0, FLOOR_TOP):
        key = stops[0][1]
        for i, (sy, k) in enumerate(stops):
            if y >= sy:
                key = k
                nxt = stops[i + 1][0] if i + 1 < len(stops) else 999
        for x in range(W):
            k = key
            # a checker row where two bands meet
            for sy, sk in stops[1:]:
                if y == sy - 1 and (x + y) % 2 == 0:
                    k = sk
            cv.put(x, y, k)
    rnd = random.Random(7)
    for _ in range(34):
        x, y = rnd.randrange(W), rnd.randrange(2, 28)
        cv.put(x, y, "star" if rnd.random() < 0.7 else "white")
    # far mountains behind the walls
    for x in range(W):
        h = 6 + 3 * math.sin(x * 0.045 + 1.2) + 2 * math.sin(x * 0.13) + 1 * math.sin(x * 0.37)
        top = int(WALL_TOP - h)
        for y in range(top, WALL_TOP + 4):
            cv.put(x, y, "night2" if y == top and math.sin(x * 0.13) > 0.3 else "night1")


def wall_light(x, y):
    """Torch and hoard light on the back wall, 0-1."""
    light = 0.0
    for tx, ty in TORCH_SPOTS:
        d = math.hypot((x - tx) * 0.9, y - ty + 4)
        light += max(0.0, 1.0 - d / 26.0) * 0.55
    d = math.hypot((x - HOARD_X) * 0.5, (y - 120) * 1.0)
    light += max(0.0, 1.0 - d / 60.0) * 0.35
    return min(1.0, light)


def draw_wall(cv):
    face_top = WALL_TOP + 8
    # walkway lip and merlons
    for x in range(W):
        merlon = (x // 7) % 2 == 0
        top = WALL_TOP if merlon else WALL_TOP + 4
        for y in range(top, face_top):
            edge_l = merlon and x % 7 == 0
            k = "s6" if y == top else ("s5" if edge_l else "s4")
            if y >= face_top - 2:
                k = "s2"
            cv.put(x, y, k)
    # brick face
    for y in range(face_top, FLOOR_TOP):
        row = (y - face_top) // 6
        in_row = (y - face_top) % 6
        for x in range(W):
            off = 6 if row % 2 else 0
            in_brick = (x + off) % 12
            bx = (x + off) // 12 * 12 - off + 5
            by = face_top + row * 6 + 2
            depth = (by - face_top) / (FLOOR_TOP - face_top)
            light = wall_light(bx, by)
            if in_row == 5 or in_brick == 11:
                k = band(0.2 + light * 0.25 - depth * 0.1, STONE, x, y)
            else:
                seed = ((x + off) // 12 * 7 + row * 13) % 5
                value = 0.4 + seed * 0.03 + light * 0.42 - depth * 0.2
                if in_row == 0:
                    value += 0.1
                k = band(value, STONE, x, y)
            cv.put(x, y, k)
    # shadow band where the wall meets the floor
    for x in range(W):
        for y in range(FLOOR_TOP - 3, FLOOR_TOP):
            if (x + y) % 2 == 0 or y == FLOOR_TOP - 1:
                cv.put(x, y, "s1")


def draw_tower(cv, cx, r):
    top = 8 if r < 25 else 22
    base = FLOOR_TOP
    for y in range(top + 7, base):
        for x in range(cx - r, cx + r + 1):
            nx = (x - cx) / r
            if abs(nx) > 1:
                continue
            row = (y - top) // 6
            off = 5 if row % 2 else 0
            u = math.asin(max(-1.0, min(1.0, nx))) * r * 0.9 + off + 60
            brick_nx = math.sin(max(-1.5, min(1.5, ((u // 10) * 10 + 5 - off - 60) / (r * 0.9))))
            light = 0.55 - brick_nx * 0.38 + wall_light(x, y) * 0.3 + ((u // 10 + row) % 3) * 0.03
            seam = (y - top) % 6 == 5 or int(u) % 10 == 0
            if seam:
                light -= 0.18
            if abs(nx) > 0.92:
                light -= 0.15
            cv.put(x, y, band(light, STONE, x, y))
    # crenellated cap, a little wider than the shaft
    cap = r + 2
    for y in range(top, top + 9):
        for x in range(cx - cap, cx + cap + 1):
            nx = (x - cx) / cap
            merlon = ((x - cx + 40) // 5) % 2 == 0
            if y < top + 3 and not merlon:
                continue
            light = 0.62 - nx * 0.4
            if y in (top, top + 3) and (y == top or not merlon):
                light += 0.15
            if y >= top + 7:
                light -= 0.3
            cv.put(x, y, band(light, STONE, x, y))
    # arrow slit with a warm glow
    for y in range(top + 18, top + 26):
        cv.put(cx - 1, y, "s0")
        cv.put(cx, y, "g2" if y > top + 20 else "s0")
    # flag pole
    for y in range(top - 6 if r < 25 else top - 6, top):
        cv.put(cx, y, "wood1")


def draw_gate(cv):
    cx, top, hw = GATE
    for y in range(top - 3, FLOOR_TOP):
        for x in range(cx - hw - 3, cx + hw + 4):
            dx = x - cx
            arch_r = hw + 3
            arch_y = top + arch_r
            inside_outer = y >= arch_y or dx * dx + (y - arch_y) ** 2 <= arch_r * arch_r
            if not inside_outer:
                continue
            inside = y >= arch_y or dx * dx + (y - arch_y) ** 2 <= hw * hw
            if abs(dx) > hw and y >= arch_y:
                inside = False
            if inside:
                # dark passage with a portcullis
                k = "night0"
                if (x - cx) % 5 == 0 or (y - top) % 6 == 0:
                    k = "s1"
                if y > FLOOR_TOP - 8 and (x + y) % 2 == 0:
                    k = "g0"
                cv.put(x, y, k)
            else:
                # arch stones
                ang = math.atan2(y - arch_y, dx)
                seam = int((ang + 4) * 6) % 2 == 0
                cv.put(x, y, "s6" if seam else "s5")


def draw_banner(cv, cx, top):
    hw, length = 7, 26
    for x in range(cx - hw - 1, cx + hw + 2):
        cv.put(x, top - 1, "wood1")
    cv.put(cx - hw - 2, top - 1, "wood2")
    cv.put(cx + hw + 2, top - 1, "wood2")
    for y in range(top, top + length):
        for x in range(cx - hw, cx + hw + 1):
            dx = x - cx
            tail = top + length - 6 + abs(dx) * 6 // hw  # a swallowtail end
            if y > tail and y > top + length - 6:
                if abs(dx) < 3 and y > top + length - 6 + 3 - abs(dx):
                    continue
            if y >= top + length - 1 and abs(dx) < 4:
                continue
            fold = (dx + 9) % 5 == 0
            k = "m1" if fold else ("m2" if dx < 2 else "m1")
            if abs(dx) == hw:
                k = "g4" if dx < 0 else "g3"
            cv.put(x, y, k)
    # a gold egg on the banner
    for y in range(top + 6, top + 16):
        for x in range(cx - 4, cx + 5):
            t = (y - (top + 11)) / (5.0 if y < top + 11 else 4.5)
            hw2 = 3.6 * math.sqrt(max(0.0, 1 - t * t))
            if abs(x - cx + 0.0) <= hw2:
                cv.put(x, y, "g5" if x < cx and y < top + 11 else ("g4" if x <= cx + 1 else "g3"))


def draw_torch_sconce(cv, x, y):
    for yy in range(y, y + 6):
        cv.put(x, yy, "s1")
        cv.put(x - 1, yy, "wood1" if yy < y + 3 else "s1")
    for xx in range(x - 3, x + 3):
        cv.put(xx, y, "s0")
    cv.put(x - 3, y - 1, "s1")
    cv.put(x + 2, y - 1, "s1")


def draw_floor(cv):
    vx, vy = HOARD_X, -60
    rows = [FLOOR_TOP]
    step = 5.0
    while rows[-1] < H:
        rows.append(int(rows[-1] + step))
        step *= 1.22
    for y in range(FLOOR_TOP, H):
        ri = max(i for i, ry in enumerate(rows) if ry <= y)
        in_row = y - rows[ri]
        scale = (y - vy) / (H - vy)
        mid_y = (rows[ri] + (rows[ri + 1] if ri + 1 < len(rows) else H)) / 2.0
        for x in range(W):
            # seams converge on the vanishing point; every other row is offset by half a slab
            u = (x - vx) / scale / 26.0 + (0.5 if ri % 2 else 0.0)
            seam = abs(u - round(u)) * 26.0 * scale < 0.6 or in_row == 0
            sx = vx + (math.floor(u) + 0.5 - (0.5 if ri % 2 else 0.0)) * 26.0 * scale
            x_px, x = x, sx
            y_px, y = y, mid_y
            dist = math.hypot((x - HOARD_X) / 1.9, (y - PILE_FLOOR_Y) * 1.6)
            glow = max(0.0, 1.0 - dist / 95.0)
            for tx, ty in TORCH_SPOTS:
                glow += max(0.0, 1.0 - math.hypot(x - tx, (y - FLOOR_TOP) * 2.2) / 40.0) * 0.4
            depth = (y - FLOOR_TOP) / (H - FLOOR_TOP)
            value = 0.3 + glow * 0.42 - abs(x - HOARD_X) / W * 0.25 + depth * 0.05
            value += ((math.floor(u) * 7 + ri * 3) % 4) * 0.02
            if seam:
                value -= 0.14
            elif in_row == 1:
                value += 0.07
            x, y = x_px, y_px
            cv.put(x, y, band(value, STONE, x, y))


# ---------------------------------------------------------------- the pile

def pile_height(fx, fy):
    """Height of the pile above the floor at a footprint point (fy in floor rows)."""
    dx = (fx - HOARD_X) / PILE_RX
    dy = (fy - PILE_FLOOR_Y) / PILE_RY
    d = math.hypot(dx, dy)
    if d >= 1.0:
        return -1.0
    bumps = 1.0 + 0.06 * math.sin(fx * 0.31 + fy) + 0.05 * math.sin(fx * 0.11 - fy * 0.7)
    return PILE_H * (1.0 - d * d) ** 0.75 * bumps


GEMS = {
    "ruby": ["r0", "r1", "r2", "r3", "white"],
    "sapphire": ["b0", "b0", "b1", "b2", "white"],
    "emerald": ["e0", "e1", "e2", "m4", "white"],
    "amethyst": ["p0", "p1", "p2", "r3", "white"],
}
# 0 dark .. 3 light, 4 a glint
GEM_SHAPES = [
    [".3.", "321", ".1."],
    [".43.", "3221", "2110", ".10."],
    [".343.", "32221", ".211.", "..1.."],
]
# a coin lying flat, seen from the front-top: its lit face (l), face (m) and rim (d)
COIN = [".ll.", "lmmd", ".dd."]
COIN_TONES = [("g5", "g4", "g3"), ("g4", "g3", "g2"), ("g3", "g2", "g1"), ("g2", "g1", "g0")]
LIGHT = (-0.55, 0.45, 0.7)      # towards the light: left, towards the viewer, up


def pile_normal_light(fx, fy):
    gx = (pile_height(fx + 1.5, fy) - pile_height(fx - 1.5, fy)) / 3.0
    gy = (pile_height(fx, fy + 1.0) - pile_height(fx, fy - 1.0)) / 2.0 * 0.5
    n = (-gx, -gy, 1.0)
    length = math.sqrt(sum(c * c for c in n))
    lx, ly, lz = LIGHT
    ll = math.sqrt(lx * lx + ly * ly + lz * lz)
    return sum(a * b for a, b in zip(n, (lx, ly, lz))) / length / ll


def draw_pile(cv, rnd):
    surface = {}   # screen pixel -> coin tone (0 bright .. 3 dark)
    points = []
    for fy2 in range((PILE_FLOOR_Y - PILE_RY) * 2, (PILE_FLOOR_Y + PILE_RY) * 2 + 1):
        fy = fy2 / 2.0
        x = HOARD_X - PILE_RX - 2 + (fy2 % 2) * 2
        while x < HOARD_X + PILE_RX + 2:
            points.append((x + rnd.choice((-1, 0, 0, 1)), fy))
            x += 4
    points.sort(key=lambda p: p[1])
    # the pile's body under the coins, so no floor shows between them
    for fy2 in range((PILE_FLOOR_Y - PILE_RY) * 2, (PILE_FLOOR_Y + PILE_RY) * 2 + 1):
        fy = fy2 / 2.0
        for fx in range(HOARD_X - PILE_RX, HOARD_X + PILE_RX + 1):
            h = pile_height(fx, fy)
            if h >= 0:
                for py in range(int(round(fy - h)), int(round(fy)) + 1):
                    cv.put(fx, py, "g1")
    for fx, fy in points:
        h = pile_height(fx, fy)
        if h < 0:
            continue
        light = pile_normal_light(fx, fy) + h / PILE_H * 0.15 + rnd.uniform(-0.1, 0.1)
        if h < 3:
            light -= 0.15
        tone = 0 if light > 0.7 else (1 if light > 0.46 else (2 if light > 0.2 else 3))
        sx, sy = int(round(fx)), int(round(fy - h))
        lk, mk, dk = COIN_TONES[tone]
        for ry, line in enumerate(COIN):
            for rx, ch in enumerate(line):
                if ch == ".":
                    continue
                px, py = sx + rx - 2, sy + ry - 1
                cv.put(px, py, {"l": lk, "m": mk, "d": dk}[ch])
                surface[(px, py)] = tone
        if tone == 0 and rnd.random() < 0.12:
            cv.put(sx - 1, sy - 1, "white")
    # contact shadow on the floor, in front of the pile only
    for x in range(HOARD_X - PILE_RX - 4, HOARD_X + PILE_RX + 5):
        for y in range(PILE_FLOOR_Y, PILE_FLOOR_Y + PILE_RY + 3):
            dx = (x - HOARD_X) / (PILE_RX + 3)
            dy = (y - PILE_FLOOR_Y) / (PILE_RY + 2)
            d = math.hypot(dx, dy)
            if (x, y) not in surface and d < 1.0 and (cv.get(x, y) or "").startswith("s"):
                cv.put(x, y, "s1" if d < 0.96 or (x + y) % 2 == 0 else cv.get(x, y))
    # gems on the surface
    keys = [k for k, tone in surface.items() if tone < 3]
    placed = []
    for _ in range(400):
        if len(placed) >= 24:
            break
        px, py = rnd.choice(keys)
        if abs(px - HOARD_X) < 46 and py < 116:
            continue    # the eggs sit there
        if any(abs(px - qx) < 9 and abs(py - qy) < 6 for qx, qy in placed):
            continue
        placed.append((px, py))
        gem = rnd.choice(list(GEMS.values()))
        shape = rnd.choice(GEM_SHAPES)
        for ry, line in enumerate(shape):
            for rx, ch in enumerate(line):
                if ch != ".":
                    cv.put(px + rx, py + ry, gem[int(ch)])
    return surface


def draw_spill(cv, rnd):
    """Loose coins and a few stacks on the floor around the pile."""
    for _ in range(30):
        ang = rnd.uniform(0, math.tau)
        r = rnd.uniform(1.02, 1.35)
        x = int(HOARD_X + math.cos(ang) * PILE_RX * r)
        y = int(PILE_FLOOR_Y + math.sin(ang) * PILE_RY * r * 1.4)
        if y < FLOOR_TOP + 2 or y > H - 3:
            continue
        if cv.get(x, y) and cv.get(x, y).startswith("g"):
            continue
        cv.put(x, y, "g5")
        cv.put(x + 1, y, "g4")
        cv.put(x - 1, y + 1, "g4")
        cv.put(x, y + 1, "g3")
        cv.put(x + 1, y + 1, "g3")
        cv.put(x + 2, y + 1, "g2")
        cv.put(x, y + 2, "g1")
        cv.put(x + 1, y + 2, "g1")
    # coin stacks
    for sx, sy, n in [(118, 160, 4), (124, 163, 2), (292, 158, 5), (286, 164, 3), (150, 171, 2)]:
        for i in range(n):
            y = sy - i * 2
            for dx in range(-2, 3):
                cv.put(sx + dx, y, "g2" if dx > 0 else "g3")
                cv.put(sx + dx, y - 1, "g4" if dx < 1 else "g3")
            cv.put(sx - 2, y - 1, "g5")
        for dx in range(-2, 3):
            cv.put(sx + dx, sy + 1, "s1")


def draw_chest(cv, x, y):
    """An open chest left of the pile, spilling coins."""
    for yy in range(y, y + 9):
        for xx in range(x, x + 16):
            k = "wood1" if (yy - y) % 4 else "wood0"
            if xx in (x, x + 15) or yy == y + 8:
                k = "wood0"
            if xx in (x + 3, x + 12):
                k = "s6"
            cv.put(xx, yy, k)
    for xx in range(x + 1, x + 15):     # coins inside
        cv.put(xx, y - 1, "g4" if xx % 3 else "g5")
        cv.put(xx, y, "g3")
    for yy in range(y - 8, y - 1):      # open lid, seen from the front
        for xx in range(x + 1, x + 15):
            cv.put(xx, yy, "wood2" if yy == y - 8 else ("wood0" if xx in (x + 1, x + 14) else "wood1"))
    cv.put(x + 7, y + 3, "g4")
    cv.put(x + 8, y + 3, "g4")
    cv.put(x + 7, y + 4, "g2")
    cv.put(x + 8, y + 4, "g2")


def draw_sword(cv, x, y):
    """A sword stuck in the pile, point down; (x, y) is where the blade goes into the coins."""
    for yy in range(y - 16, y):
        cv.put(x, yy, "s8")
        cv.put(x + 1, yy, "s6")
    for xx in range(x - 3, x + 5):
        cv.put(xx, y - 17, "g4" if xx < x + 1 else "g2")
    for yy in range(y - 22, y - 17):
        cv.put(x, yy, "wood1")
        cv.put(x + 1, yy, "wood0")
    cv.put(x, y - 23, "r2")
    cv.put(x + 1, y - 23, "r1")


def draw_goblet(cv, x, y):
    """A gold goblet tipped on the pile's right foot; (x, y) its foot."""
    for xx in range(x - 2, x + 3):
        cv.put(xx, y, "g2")
    cv.put(x, y - 1, "g3")
    cv.put(x, y - 2, "g3")
    for yy in range(y - 7, y - 2):
        for xx in range(x - 3, x + 4):
            k = "g5" if xx < x - 1 else ("g4" if xx < x + 2 else "g2")
            cv.put(xx, yy, k)
    cv.put(x, y - 5, "r2")
    for xx in range(x - 3, x + 4):
        cv.put(xx, y - 8, "g1")


def draw_crown(cv, x, y):
    rows = ["5.4.4.3", "5545443", "4r4b4r3", "3322221"]
    keys = {"1": "g1", "2": "g2", "3": "g3", "4": "g4", "5": "g5", "r": "r2", "b": "b1"}
    for ry, line in enumerate(rows):
        for rx, ch in enumerate(line):
            if ch != ".":
                cv.put(x + rx, y + ry, keys[ch])


def draw_background():
    rnd = random.Random(1234)
    cv = Canvas(W, H)
    draw_sky(cv)
    draw_wall(cv)
    for cx, r in TOWERS:
        draw_tower(cv, cx, r)
    draw_gate(cv)
    for cx, top in BANNERS:
        draw_banner(cv, cx, top)
    for tx, ty in TORCH_SPOTS:
        draw_torch_sconce(cv, tx, ty)
    draw_floor(cv)
    draw_spill(cv, rnd)
    draw_chest(cv, 124, 128)
    surface = draw_pile(cv, rnd)
    draw_sword(cv, 252, 128)
    draw_crown(cv, 152, 133)
    draw_goblet(cv, 270, 145)
    return cv, surface


# ---------------------------------------------------------------- eggs and hatchlings

# dark .. highlight; the tower colours (mint from Puffe, fire and poison from the Bolter sheets, frost the
# castle egg's blue, so it does not read as a second mint)
ELEMENTS = {
    "mint": ["107338", "0b9b55", "06c374", "02eb93", "2effb8", "68ffd0", "effffa"],
    "fire": ["461a29", "74202e", "a22633", "c3303b", "e43b44", "f6757a", "f1e0e1"],
    "frost": ["162a4f", "124e89", "1f74c4", "0099db", "2ce8f5", "8ff3ff", "e0f1f0"],
    "poison": ["333d23", "476331", "5b893f", "74b355", "85cb34", "a7dc8f", "e7eee3"],
}
EGG_SPOT = {"mint": "g4", "fire": "g4", "frost": "white", "poison": "p2"}
# the little breath a hatchling puffs: (core, glow, fringe)
PUFF = {"mint": ("white", "m5", "m3"), "fire": ("g5", "g4", "g3"), "frost": ("white", "b2", "b1"),
        "poison": ("e2", "e1", "p2")}
for name, ramp in ELEMENTS.items():
    for i, h in enumerate(ramp):
        C["%s%d" % (name, i)] = h
EYE, GLINT = "night0", "white"
SHADE_LIGHT = (-0.55, -0.62, 0.56)     # left, up, towards the viewer


def lit(nx, ny):
    nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
    lx, ly, lz = SHADE_LIGHT
    return (nx * lx + ny * ly + nz * lz) / math.sqrt(lx * lx + ly * ly + lz * lz)


def tone_of(value):
    """Ramp step 1..5 from a light value (0 and 6 are for edges and glints)."""
    for step, edge in ((5, 0.8), (4, 0.55), (3, 0.25), (2, -0.1)):
        if value > edge:
            return step
    return 1


EGG_W, EGG_H = 28, 38
EGG_TOP, EGG_BOTTOM, EGG_CX, EGG_HW = 11, 36, 13.5, 9.6
EGG_LEN = EGG_BOTTOM - EGG_TOP + 1
EGG_SPOTS_AT = [(-4, 6), (2, 4), (5, 11), (-6, 14), (0, 16), (-1, 10), (4, 19), (-5, 20)]
CRACK_ZIG = [1, 2, 1, 0, 1, 2, 3, 2, 1, 0, 1, 2, 1, 0, 1, 2, 1]


def egg_half_width(v):
    """Half width of the egg v rows below its top (0..19)."""
    c = EGG_LEN * 0.55
    a = c if v < c else EGG_LEN - c
    t = (v + 0.5 - c) / a
    return EGG_HW * math.sqrt(max(0.0, 1.0 - t * t))


def crack_row(x):
    """The egg row (from its top) where the crack runs at canvas column x."""
    return 9 + CRACK_ZIG[(int(x) - 3) % len(CRACK_ZIG)]


def egg_pixels(el, tilt=0):
    """{(x, y): key} of a whole egg; tilt shifts the top over by up to that many pixels."""
    out = {}
    ramp = ["%s%d" % (el, i) for i in range(7)]
    for v in range(EGG_BOTTOM - EGG_TOP + 1):
        y = EGG_TOP + v
        hw = egg_half_width(v)
        shift = round(tilt * (EGG_BOTTOM - y) / (EGG_BOTTOM - EGG_TOP))
        for x in range(EGG_W):
            dx = x + 0.5 - EGG_CX
            if abs(dx) > hw:
                continue
            nx = dx / (EGG_HW + 0.6)
            ny = (v + 0.5 - EGG_LEN * 0.5) / (EGG_LEN * 0.6)
            step = tone_of(lit(nx, ny))
            if abs(dx) > hw - 1 and dx > 0 and step <= 2:
                step = 0
            if v >= EGG_LEN - 3:
                step = min(step, 2)
            key = ramp[step]
            for sx, sv in EGG_SPOTS_AT:
                if (round(dx - 0.5) == sx and v == sv) or (round(dx - 0.5) == sx + 1 and v == sv):
                    key = EGG_SPOT[el] if step >= 2 else ramp[max(0, step - 1)]
            out[(x + shift, y)] = key
    # the shine, top left
    for x, y in ((9, EGG_TOP + 4), (9, EGG_TOP + 5), (10, EGG_TOP + 3), (8, EGG_TOP + 6)):
        out[(x + round(tilt * (EGG_BOTTOM - y) / (EGG_BOTTOM - EGG_TOP)), y)] = ramp[6]
    return out


def nest(cv):
    """Coins around the egg's foot, in front of it, so it sits in the pile."""
    rows = [
        (34, "...55.4...........45.44...."),
        (35, "..54434...........343432..."),
        (36, ".4433221..........12233321."),
        (37, "43221.1.............11.2111"),
    ]
    keys = {"1": "g1", "2": "g2", "3": "g3", "4": "g4", "5": "g5"}
    for y, line in rows:
        for x, ch in enumerate(line):
            if ch in keys:
                cv.put(x, y, keys[ch])
    for x in range(8, 20):      # coins over the egg's very bottom
        cv.put(x, 37, "g2" if x % 3 else "g3")
        if x % 4 == 1:
            cv.put(x, 36, "g4")


def stamp(cv, pixels, dx=0, dy=0, only=None):
    for (x, y), key in pixels.items():
        if only is None or only(x, y):
            cv.put(x + dx, y + dy, key)


def egg_frame(el, tilt=0, crack=0, cap_offset=None, head=None, glow=False, empty=False):
    cv = Canvas(EGG_W, EGG_H)
    pixels = egg_pixels(el, tilt)
    is_cap = lambda x, y: y - EGG_TOP < crack_row(x)
    if cap_offset is None and not empty:
        stamp(cv, pixels)
    else:
        # the base shell, its dark inside showing over the jagged rim
        stamp(cv, pixels, only=lambda x, y: not is_cap(x, y))
        for x in range(EGG_W):
            rim = EGG_TOP + crack_row(x)
            if (x, rim) in pixels:
                hw = egg_half_width(rim - EGG_TOP)
                if abs(x + 0.5 - EGG_CX) < hw - 1:
                    cv.put(x, rim, "%s0" % el)
                    cv.put(x, rim + 1, "%s1" % el if (x + 0.5 - EGG_CX) < 0 else "%s0" % el)
        if head is not None:
            draw_hatchling(cv, el, head[0], head[1], Pose(wings="hidden", legs=False, tail=False, body=False))
            # the shell's front lip over the hatchling's chin
            for x in range(EGG_W):
                rim = EGG_TOP + crack_row(x) + 2
                if (x, rim) in pixels:
                    cv.put(x, rim, pixels[(x, rim)])
        if cap_offset is not None:
            stamp(cv, {k: v for k, v in pixels.items() if is_cap(*k)}, cap_offset[0], cap_offset[1])
    if crack:
        # the crack grows from the left side across the egg
        reach = {1: 5, 2: 10, 3: 24}[crack]
        for x in range(5, 5 + reach):
            y = EGG_TOP + crack_row(x)
            if (x, y) in pixels and cap_offset is None:
                cv.put(x, y, "g5" if glow and x % 2 else "%s0" % el)
        if crack >= 2:
            for x, y in ((11, EGG_TOP + 12), (12, EGG_TOP + 13), (17, EGG_TOP + 11), (17, EGG_TOP + 6), (18, EGG_TOP + 5)):
                if (x, y) in pixels and cap_offset is None:
                    cv.put(x, y, "%s0" % el)
    if glow and cap_offset is not None:
        # light bursting out of the opening
        for x, y in ((8, 17), (19, 16), (13, 15), (6, 14), (21, 13), (10, 12), (17, 11)):
            if cv.get(x, y) is None:
                cv.put(x, y, "g5" if (x + y) % 2 else "white")
    nest(cv)
    return cv


def egg_frames(el):
    frames, tags = [], []
    frames.append(egg_frame(el))
    tags.append(("IDLE", 200, 1))
    for tilt in (-1, 0, 1, 0):
        frames.append(egg_frame(el, tilt=tilt))
    tags.append(("WOBBLE", 90, 4))
    for crack in (1, 2, 3):
        frames.append(egg_frame(el, crack=crack))
    tags.append(("CRACK", 160, 3))
    frames += [
        egg_frame(el, crack=3, glow=True),
        egg_frame(el, tilt=1, crack=3, glow=True),
        egg_frame(el, cap_offset=(0, -2), glow=True),
        egg_frame(el, cap_offset=(2, -7), glow=True, head=(13, 22)),
        egg_frame(el, cap_offset=(5, -12), head=(13, 21)),
        egg_frame(el, head=(13, 20), empty=True),
        egg_frame(el, head=(13, 19), empty=True),
        egg_frame(el, head=(13, 20), empty=True),
    ]
    tags.append(("HATCH", 110, 8))
    frames.append(egg_frame(el, empty=True))
    tags.append(("EMPTY", 200, 1))
    return frames, tags


class Pose:
    def __init__(self, head_dy=0, front=(0, 0), back=(0, 0), wings="fold", tail=True, legs=True, body=True,
                 blink=False, tail_dy=0, puff=0, body_dy=0):
        self.head_dy, self.front, self.back, self.wings = head_dy, front, back, wings
        self.tail, self.legs, self.body, self.blink = tail, legs, body, blink
        self.tail_dy, self.puff, self.body_dy = tail_dy, puff, body_dy


HATCH_W, HATCH_H = 26, 22
HEAD_AT = (14, 9)      # head centre in a hatchling frame, facing right
BODY_AT = (10, 15)


def blob(cv, cx, cy, rx, ry, ramp, belly=None):
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            nx = (x + 0.5 - cx) / rx
            ny = (y + 0.5 - cy) / ry
            if nx * nx + ny * ny > 1.0:
                continue
            step = tone_of(lit(nx * 0.9, ny * 0.9))
            if nx * nx + ny * ny > 0.72 and (nx > 0.2 or ny > 0.3):
                step = max(0, min(step, 1) - (1 if ny > 0.55 else 0))
            if belly and belly(nx, ny):
                step = min(5, max(step, 3) + 1)
            cv.put(x, y, ramp[step])


def draw_hatchling(cv, el, hx, hy, pose, bx=None, by=None):
    """A hatchling facing right; (hx, hy) is the head centre, (bx, by) the body's."""
    ramp = ["%s%d" % (el, i) for i in range(7)]
    if bx is None:
        bx, by = hx - 3, hy + 6
    by += pose.body_dy
    hy += pose.head_dy
    if pose.tail:
        t = pose.tail_dy
        for i, (x, y) in enumerate(((bx - 4, by + 1), (bx - 5, by + 1), (bx - 6, by + t), (bx - 7, by - 1 + t),
                                    (bx - 7, by - 2 + t))):
            cv.put(x, y, ramp[3 if i < 2 else 2])
            if i < 3:
                cv.put(x, y + 1, ramp[1])
        # the spade at its tip
        for x, y, step in ((-8, -3, 2), (-7, -3, 3), (-6, -3, 2), (-7, -4, 4), (-8, -4, 1)):
            cv.put(bx + x, by + y + t, ramp[step])
    if pose.legs:
        for (lx, ly), key in (((bx - 2 + pose.back[0], by + 3 + pose.back[1]), ramp[1]),
                              ((bx + 2 + pose.front[0], by + 3 + pose.front[1]), ramp[2])):
            cv.put(lx, ly, key)
            cv.put(lx + 1, ly, key)
            cv.put(lx, ly + 1, ramp[0])
            cv.put(lx + 1, ly + 1, ramp[1])
    if pose.wings in ("up", "mid", "down", "open"):
        draw_wing(cv, ramp, bx - 1, by - 3, pose.wings, far=True)
    if pose.body:
        blob(cv, bx, by, 4.8, 4.2, ramp, belly=lambda nx, ny: nx > 0.3 and ny > -0.2)
    if pose.wings == "fold":
        # a pale membrane folded up on the back, like Puffe's
        wing = ["...2..", "..256.", ".2566.", "25565.", ".2552.", "..22.."]
        for wy, row in enumerate(wing):
            for wx, ch in enumerate(row):
                if ch != ".":
                    cv.put(bx - 7 + wx, by - 6 + wy, ramp[int(ch)])
    elif pose.wings in ("up", "mid", "down", "open"):
        draw_wing(cv, ramp, bx - 1, by - 3, pose.wings, far=False)
    # head: a round skull and a snout to the right
    blob(cv, hx, hy, 4.6, 4.0, ramp)
    blob(cv, hx + 3.0, hy + 1.6, 2.6, 1.8, ramp)
    for x, y, step in ((hx - 3, hy - 4, 3), (hx - 3, hy - 5, 4), (hx - 4, hy - 6, 5),
                       (hx, hy - 4, 3), (hx, hy - 5, 4), (hx - 1, hy - 6, 5)):
        cv.put(x, y, ramp[step])          # horns, swept back
    for x, y in ((hx - 5, hy + 1), (hx - 5, hy - 1)):
        cv.put(x, y, ramp[2])             # frills at the back of the head
    cv.put(hx + 5, hy + 1, ramp[1])       # nostril
    if pose.blink:
        cv.put(hx + 1, hy, ramp[1])
        cv.put(hx + 3, hy, ramp[1])
    else:
        cv.put(hx + 1, hy - 1, EYE)
        cv.put(hx + 1, hy, EYE)
        cv.put(hx + 3, hy - 1, EYE)
        cv.put(hx + 3, hy, EYE)
        cv.put(hx + 1, hy - 1, GLINT)
    cv.put(hx + 4, hy + 3, ramp[1])       # the corner of the mouth
    if pose.puff:
        core, glow, fringe = PUFF[el]
        px, py = hx + 7, hy + 2
        shapes = {
            1: [(0, 0, glow)],
            2: [(0, 0, core), (1, 0, glow), (1, -1, fringe), (2, 1, fringe)],
            3: [(1, 0, core), (2, 0, glow), (0, 0, glow), (2, -1, glow), (3, 0, fringe), (2, 1, fringe), (3, -2, fringe)],
            4: [(3, -1, glow), (4, -2, fringe), (2, 1, fringe), (5, -1, fringe)],
        }
        for dx, dy, key in shapes[pose.puff]:
            cv.put(px + dx, py + dy, key)


def draw_wing(cv, ramp, sx, sy, kind, far):
    """A spread wing from the shoulder (sx, sy); the far one sits behind the body, one step darker."""
    tips = {"up": [(-3, -7), (-6, -6), (-6, -3)], "mid": [(-5, -4), (-7, -2), (-6, 0)],
            "down": [(-4, 1), (-6, 3), (-4, 4)], "open": [(-3, -6), (-6, -5), (-6, -2)]}[kind]
    ox = 2 if far else 0
    oy = -1 if far else 0
    frame = ramp[1 if far else 2]
    fill = ramp[3 if far else 5]
    pts = [(sx + ox, sy + oy)] + [(sx + ox + tx, sy + oy + ty) for tx, ty in tips]
    # fill the fan between the shoulder and the tips, then the bones
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    for y in range(min(ys), max(ys) + 1):
        for x in range(min(xs), max(xs) + 1):
            if point_in_poly(x + 0.5, y + 0.5, pts):
                cv.put(x, y, fill)
    for tx, ty in tips[:2]:
        line(cv, pts[0], (sx + ox + tx, sy + oy + ty), frame)
    line(cv, pts[1], pts[2], frame)


def line(cv, a, b, key):
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        cv.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), key)


def point_in_poly(x, y, pts):
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def hatchling_frames(el):
    hx, hy = HEAD_AT
    poses = []
    tags = []
    idle = [Pose(), Pose(head_dy=1, body_dy=0), Pose(), Pose(blink=True)]
    poses += idle
    tags.append(("IDLE", 220, len(idle)))
    walk = [Pose(front=(1, 0), back=(-1, 0), tail_dy=0),
            Pose(head_dy=-1, body_dy=-1, front=(0, -1), back=(0, 0), tail_dy=-1),
            Pose(front=(-1, 0), back=(1, 0), tail_dy=0),
            Pose(head_dy=-1, body_dy=-1, front=(0, 0), back=(0, -1), tail_dy=1)]
    poses += walk
    tags.append(("WALK", 120, len(walk)))
    hop = [Pose(head_dy=1, body_dy=1, wings="open"), Pose(head_dy=-1, body_dy=-1, wings="up", front=(1, -1), back=(-1, -1))]
    poses += hop
    tags.append(("HOP", 110, len(hop)))
    fly = [Pose(wings="up", front=(0, -1), back=(0, -1)), Pose(wings="mid", head_dy=1, body_dy=1),
           Pose(wings="down", head_dy=1, body_dy=1, front=(0, -1), back=(0, -1)), Pose(wings="mid")]
    poses += fly
    tags.append(("FLY", 80, len(fly)))
    puff = [Pose(head_dy=-1), Pose(head_dy=-1, puff=1), Pose(puff=2), Pose(puff=3), Pose(puff=4), Pose()]
    poses += puff
    tags.append(("PUFF", 110, len(puff)))
    frames = []
    for pose in poses:
        cv = Canvas(HATCH_W, HATCH_H)
        draw_hatchling(cv, el, hx, hy, pose, BODY_AT[0], BODY_AT[1])
        frames.append(cv)
    return frames, tags


# ---------------------------------------------------------------- small props

def torch_frames():
    """A flame on the wall sconce, 7x11, bottom-centre at the sconce's cup."""
    shapes = [
        ["...5...", "...5...", "..545..", "..444..", ".44344.", ".43334.", ".43234.", "..322..", "..222..", "...2...", "......."],
        ["....5..", "...45..", "...44..", "..434..", ".43334.", ".43234.", ".43224.", "..322..", "..222..", "...2...", "......."],
        [".......", "..5....", "..45...", "..444..", ".44344.", "443334.", ".43234.", "..322..", "..222..", "...2...", "......."],
        ["...5...", "..45...", "..44...", "..434..", ".44334.", ".43234.", ".432234", "..322..", "..222..", "...2...", "......."],
    ]
    keys = {"2": "g2", "3": "g3", "4": "g4", "5": "g5"}
    frames = []
    for shape in shapes:
        cv = Canvas(7, 11)
        for y, row in enumerate(shape):
            for x, ch in enumerate(row):
                if ch in keys:
                    cv.put(x, y, keys[ch])
        frames.append(cv)
    return frames, [("IDLE", 120, len(frames))]


def flag_frames():
    """Puffe's mint pennant on a tower pole, 14x8, its left edge at the pole."""
    frames = []
    for phase in range(4):
        cv = Canvas(14, 8)
        for x in range(13):
            wave = round(math.sin(x * 0.7 - phase * math.pi / 2) * 1.2)
            length = 6 - x * 4 // 13
            for y in range(length):
                yy = y + wave + 1 + x * 2 // 13
                key = "m3" if y < 2 else "m2"
                if y == length - 1:
                    key = "m1"
                if wave < 0 and y < 2:
                    key = "m4"
                cv.put(x + 1, yy, key)
        for y in range(8):
            cv.put(0, y, "wood1")
        frames.append(cv)
    return frames, [("IDLE", 150, len(frames))]


def sparkle_frames():
    shapes = [
        [".....", ".....", "..4..", ".....", "....."],
        [".....", "..4..", ".454.", "..4..", "....."],
        ["..4..", "..5..", "45w54", "..5..", "..4.."],
        [".....", "..5..", ".5w5.", "..5..", "....."],
        [".....", ".....", "..5..", ".....", "....."],
    ]
    keys = {"4": "g4", "5": "g5", "w": "white"}
    frames = []
    for shape in shapes:
        cv = Canvas(5, 5)
        for y, row in enumerate(shape):
            for x, ch in enumerate(row):
                if ch in keys:
                    cv.put(x, y, keys[ch])
        frames.append(cv)
    return frames, [("IDLE", 90, len(frames))]


# ---------------------------------------------------------------- output

def write_spec(path, frames, size, tags, comment):
    """frames: list of Canvas; tags: [(name, ms, count)]."""
    used = []
    for f in frames:
        for row in f.px:
            for k in row:
                if k and k not in used:
                    used.append(k)
    chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!$%&*+-=?@^~"
    if len(used) > len(chars):
        sys.exit("too many colours in %s" % path)
    key_of = {k: chars[i] for i, k in enumerate(used)}
    lines = ["# " + line for line in comment.splitlines()]
    lines += ["%s = %s" % (key_of[k], C[k]) for k in used]
    lines += ["size = %dx%d" % size, "---"]
    i = 0
    for name, ms, count in tags:
        lines.append("@%s %d" % (name, ms))
        for _ in range(count):
            f = frames[i]
            i += 1
            lines += ["".join(key_of[k] if k else "." for k in row) for row in f.px]
            lines.append("")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build(name, frames, size, tags, comment):
    spec = ART / (name + ".txt")
    write_spec(spec, frames, size, tags, comment)
    out = ART / (name + ".aseprite")
    code = subprocess.run([sys.executable, str(SPRITE_TOOL), "build", str(spec), str(out)]).returncode
    if code:
        sys.exit("sprite build failed: " + name)
    preview = ART / (name + ".preview.png")
    if preview.exists():
        preview.unlink()


# animations the script plays once and then holds (the rest loop)
ONE_SHOT = {"WOBBLE", "CRACK", "HATCH", "PUFF", "EMPTY"}


def write_sprite_frames(name, fw, fh, count, tags):
    """A SpriteFrames .tres over the packed sheet (ceil(sqrt(n)) columns, as sprite.py exports it)."""
    columns = math.ceil(math.sqrt(count))
    out = ["[gd_resource type=\"SpriteFrames\" load_steps=%d format=3]" % (count + 2), "",
           "[ext_resource type=\"Texture2D\" path=\"res://assets/art/ui/title/hoard/%s.png\" id=\"1_sheet\"]" % name, ""]
    for i in range(count):
        out += ["[sub_resource type=\"AtlasTexture\" id=\"AtlasTexture_%d\"]" % i, "atlas = ExtResource(\"1_sheet\")",
                "region = Rect2(%d, %d, %d, %d)" % (i % columns * fw, i // columns * fh, fw, fh), ""]
    animations = []
    i = 0
    for tag, ms, n in tags:
        frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_%d")\n}' % (i + k)
                           for k in range(n))
        i += n
        animations.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                          % (frames, "false" if tag in ONE_SHOT else "true", tag, repr(round(1000.0 / ms, 3))))
    out += ["[resource]", "animations = [" + ", ".join(animations) + "]", ""]
    (FRAMES / (name + "_frames.tres")).write_text("\n".join(out), encoding="utf-8")


def sprite_sets():
    sets = {}
    for el in ELEMENTS:
        sets["hoard_egg_" + el] = egg_frames(el)
        sets["hatchling_" + el] = hatchling_frames(el)
    sets["hoard_torch"] = torch_frames()
    sets["hoard_flag"] = flag_frames()
    sets["hoard_sparkle"] = sparkle_frames()
    return sets


def main(argv):
    ART.mkdir(parents=True, exist_ok=True)
    preview_dir = argv[argv.index("--preview") + 1] if "--preview" in argv else None
    bg, surface = draw_background()
    if preview_dir:
        im = bg.image()
        im.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(preview_dir, "hoard_hall_x4.png"))
        for name, (frames, _) in sprite_sets().items():
            fw, fh = frames[0].w, frames[0].h
            sheet = Image.new("RGBA", (len(frames) * (fw + 2), fh), rgb("s4") + (255,))
            for i, f in enumerate(frames):
                sheet.alpha_composite(f.image(), (i * (fw + 2), 0))
            scale = 8 if fw < 30 else 4
            sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST).save(
                os.path.join(preview_dir, name + ".png"))
        return 0
    note = "Generated by tools/art/hoard_backdrop.py for the title screen; edit that and rerun."
    build("hoard_hall", [bg], (W, H), [("IDLE", 100, 1)], note)
    FRAMES.mkdir(parents=True, exist_ok=True)
    for name, (frames, tags) in sprite_sets().items():
        build(name, frames, (frames[0].w, frames[0].h), tags, note)
        write_sprite_frames(name, frames[0].w, frames[0].h, len(frames), tags)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
