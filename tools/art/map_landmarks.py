#!/usr/bin/env python3
"""Story landmarks on the world map (2026-11-25, the user: "more meaningful looking landmarks to world map"): one
small animated sprite per place a level's story names, drawn in the map's style (seen from above at a slant, lit from
the top left, Endesga 32, no outlines) and set over the map art beside its level, under the fog, trails and nodes,
like the Ashen Wyrm's throne (wyrm_throne.py).

    python tools/art/map_landmarks.py [names...] [--preview <out.png>] [--no-place]

Writes assets/art/ui/map_landmarks/<name>.txt/.aseprite/.png (IDLE) and scenes/ui/game_world_map/frames/
<name>_frames.tres. PLACES gives each one's spot on the map (map units, the sprite's top-left; the map draws the art
at 2x); place_landmarks() writes the AnimatedSprite2D nodes into game_world_map.tscn (rerunnable).
"""
import math
import os
import re
import sys
import zlib
from pathlib import Path

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hoard_backdrop as hb  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
hb.ART = ROOT / "assets" / "art" / "ui" / "map_landmarks"
hb.FRAMES = ROOT / "scenes" / "ui" / "game_world_map" / "frames"
MAP_SCENE = ROOT / "scenes" / "ui" / "game_world_map" / "game_world_map.tscn"

hb.C.update({
    # stone, wood, roofs
    "st0": "262b44", "st1": "3a4466", "st2": "5a6988", "st3": "8b9bb4", "st4": "c0cbdc",
    "wd0": "3e2731", "wd1": "733e39", "wd2": "b86f50", "wd3": "e4a672", "wd4": "ead4aa",
    "rf0": "3e2731", "rf1": "5d1d2c", "rf2": "a22633", "rf3": "be4a2f",
    # bog water and swamp creatures
    "bg0": "17323a", "bg1": "1f5048", "bg2": "2d7356", "bg3": "4a9a5c", "bg4": "8fc46a", "bglow": "e6f07a",
    "eye": "fee761", "ink": "181425", "gold": "feae34", "ember": "f77622",
    # the humans' banners, the raised elder's spell glow
    "water": "0099db", "pink": "b55088", "purple": "68386c", "glint": "2ce8f5",
})


def rnd(*key):
    return (zlib.crc32(repr(key).encode()) % 10007) / 10007.0


def ellipse(cv, cx, cy, rx, ry, colour_at):
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d <= 1.0:
                c = colour_at(x, y, d)
                if c:
                    cv.put(x, y, c)


def line(cv, x0, y0, x1, y1, colour):
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for s in range(n + 1):
        cv.put(round(x0 + (x1 - x0) * s / n), round(y0 + (y1 - y0) * s / n), colour)


def bog_pool(cv, cx, cy, rx, ry, frame, frames, key):
    """a dark bog pool: a darker rim, a lighter sheen to the upper left, a ripple ring that widens and fades"""
    def at(x, y, d):
        if d > 0.78:
            return "bg0"
        if d < 0.35 and x < cx and y < cy:
            return "bg2"
        return "bg1"
    ellipse(cv, cx, cy, rx, ry, at)
    grow = (frame % frames) / frames
    rr = 0.35 + grow * 0.5
    for a in range(0, 360, 12):
        x = round(cx + math.cos(math.radians(a)) * rx * rr)
        y = round(cy + math.sin(math.radians(a)) * ry * rr)
        if rnd(key, a) < 0.75 - grow * 0.5 and cv.get(x, y) in ("bg1", "bg2"):
            cv.put(x, y, "bg3")


# --- the Swamp ------------------------------------------------------------------------------------------------------

def drowned_chapel(cv, f, frames):
    """a stone chapel half sunk in a bog pool: a broken gable, a bell tower stub, moss, a wisp by the door"""
    bog_pool(cv, 15, 22, 14, 6, f, frames, "chapel")
    # the side wall (shade) and the front gable wall (lit), their feet under the water
    for y in range(10, 21):
        for x in range(19, 23):
            cv.put(x, y - (x - 19) // 2, "st1" if x > 20 else "st2")
    for y in range(9, 21):
        for x in range(8, 20):
            cv.put(x, y, "st3" if x < 11 else "st2" if (x + y) % 7 else "st1")
    for x in range(8, 20):  # the gable's broken top edge
        top = 9 - (6 - abs(x - 14)) // 2 if x < 16 else 8 + (x - 15)
        for y in range(top, 9):
            cv.put(x, y, "st3" if x < 11 else "st2")
    for x in range(9, 15):  # what is left of the roof, on the lit side
        cv.put(x, 9 - (x - 8) // 2, "rf1")
        cv.put(x, 10 - (x - 8) // 2, "rf0")
    for y in range(2, 12):  # the bell tower stub with an arched window
        for x in range(4, 9):
            cv.put(x, y, "st3" if x < 6 else "st2")
    cv.put(5, 1, "st3"); cv.put(7, 2, "st2")
    for y in range(4, 7):
        cv.put(6, y, "ink")
    cv.put(6, 3, "st1")
    for y in range(14, 21):  # the arched door, water inside
        for x in range(12, 16):
            if y > 14 or 12 < x < 15:
                cv.put(x, y, "bg0" if y > 18 else "ink")
    for x, y in ((9, 12), (10, 13), (17, 11), (18, 12), (19, 15), (8, 17), (16, 19), (5, 9)):  # moss
        cv.put(x, y, "bg3" if (x + y) % 2 else "bg2")
    for x in range(8, 23):  # the waterline on the walls
        cv.put(x, 20, "bg1")
    bob = (0, -1, -1, 0)[f % 4]  # the wisp bobs and flickers by the door
    wx, wy = 18, 15 + bob
    cv.put(wx, wy, "bglow" if f % 2 == 0 else "bg4")
    cv.put(wx + 1, wy, "bg4")
    cv.put(wx, wy + 1, "bg3")


def wasp_hive(cv, f, frames):
    """a giant papery hive hanging from a dead tree, wasps circling it"""
    line(cv, 9, 29, 10, 6, "wd0")  # the dead trunk, lit on its left
    line(cv, 8, 29, 9, 8, "wd1")
    line(cv, 10, 7, 21, 5, "wd0")  # the branch the hive hangs from
    line(cv, 9, 12, 4, 8, "wd0")
    line(cv, 4, 8, 3, 5, "wd0")
    cv.put(7, 29, "wd0"); cv.put(11, 29, "wd0")

    def at(x, y, d):
        band = (y // 2) % 2
        if x > 21 or d > 0.8:
            return "wd1"
        return "wd3" if band else "wd2"
    ellipse(cv, 19, 15, 6, 9, at)
    line(cv, 19, 5, 19, 7, "wd1")
    for y in range(17, 21):  # the entrance
        cv.put(18, y, "ink")
        cv.put(19, y, "ink" if y > 17 else "wd1")
    for k in range(3):  # wasps circling
        a = (f / frames + k / 3) * math.tau
        x, y = round(19 + math.cos(a) * 9), round(15 + math.sin(a) * 6)
        cv.put(x, y, "gold")
        cv.put(x + 1, y, "ink")
        if (f + k) % 2:
            cv.put(x, y - 1, "st4")


def sunken_village(cv, f, frames):
    """roofs of a drowned village poking out of a bog: three gables, a chimney, a rotten beam"""
    bog_pool(cv, 18, 13, 17, 8, f, frames, "village")

    def roof(x0, y0, w, h, broken=False):
        for r in range(h):
            for c in range(w):
                x, y = x0 + c, y0 + r
                ridge = x0 + w // 2
                if abs(x - ridge) > r + 1:
                    continue
                if broken and c > w - 3 and r < 2:
                    continue
                cv.put(x, y, "rf2" if x < ridge else "rf1")
        for c in range(w):  # the wall top just above the water
            cv.put(x0 + c, y0 + h, "wd3" if c < w // 2 else "wd2")
            cv.put(x0 + c, y0 + h + 1, "bg0")
    roof(4, 7, 8, 4)
    roof(15, 3, 9, 5)
    roof(25, 10, 7, 3, broken=True)
    for y in range(1, 5):  # a chimney
        cv.put(21, y, "st2")
        cv.put(22, y, "st1")
    if f % 2 == 0:  # a thin smoke wisp: someone still lives here?
        cv.put(21, 0, "st3")
    line(cv, 27, 9, 31, 7, "wd1")  # a rotten beam
    for x, y in ((2, 13), (3, 12), (33, 14), (34, 13)):  # reeds
        cv.put(x, y, "bg3")
        cv.put(x, y - 1, "bg4")


def hydra_heads(cv, f, frames):
    """the Bog Hydra's three heads rising out of its mire on thick necks, swaying, jaws open, yellow eyes"""
    bog_pool(cv, 18, 30, 17, 5, f, frames, "hydra")
    necks = [(8, 29, -3, 0.0, 12), (18, 30, 0, 1.6, 6), (28, 29, 3, 3.1, 12)]  # foot x, y, lean, phase, top y
    for fx, fy, lean, phase, top in necks:
        sway = math.sin(f / frames * math.tau + phase) * 1.5
        points = []
        for k in range(fy - top + 1):
            t = k / (fy - top)
            x = fx + lean * t + sway * t * t + math.sin(t * 2.6 + phase) * 1.6
            points.append((x, fy - k, 5 - round(t * 1.5)))  # x, y, width: thick at the water, thinner up top
        for i, (x, y, w) in enumerate(points):
            left = round(x - w / 2)
            for o in range(w):
                c = "bg3" if o == 0 else "bg0" if o == w - 1 else "bg1" if o == w - 2 else "bg2"
                cv.put(left + o, y, c)
            if i % 2 == 0:
                cv.put(left + 1, y, "bg4")  # belly scales catching the light
        hx, hy, _ = points[-1]
        hx = round(hx)
        head = ["..h...h..",
                ".bbbbbbb.",
                "bBBeBeBBb",
                "bBBBBBBBd",
                ".bmmmmmd.",
                "..tttt...",
                "..bbbb..."]
        colours = {"h": "bg0", "b": "bg2", "B": "bg3", "e": "eye", "d": "bg0", "m": "rf2", "t": "st4"}
        snap = f % 2 == 0 and phase == 1.6  # the middle head snaps now and then
        for r, row in enumerate(head):
            for c, ch in enumerate(row):
                if ch == ".":
                    continue
                if snap and ch in "mt":
                    ch = "b"
                cv.put(hx - 4 + c, hy - 6 + r, colours[ch])


# --- the Wasted Lands -----------------------------------------------------------------------------------------------

def smoke_column(cv, x, y, f, frames, height=10, puffs=3, key="smoke"):
    """grey puffs rising and drifting east, growing and thinning"""
    for p in range(puffs):
        age = ((f / frames) + p / puffs) % 1.0
        cx, cy = x + age * 4, y - age * height
        r = 1.2 + age * 2.2
        for py in range(int(cy - r), int(cy + r) + 1):
            for px in range(int(cx - r), int(cx + r) + 1):
                d = math.hypot(px - cx, py - cy)
                if d <= r and not (age > 0.6 and (px + py) % 2) and cv.get(px, py) is None:
                    cv.put(px, py, "st3" if d < r * 0.5 and py < cy else "st2")


def house(cv, x0, y0, w, h, roof=True, burned=False):
    """a small house from above at a slant: a lit front wall, a gable roof, a dark door"""
    wall_lit, wall_shade = ("wd1", "wd0") if burned else ("wd4", "wd3")
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            cv.put(x, y, wall_lit if x < x0 + w - 2 else wall_shade)
    cv.put(x0 + w // 2, y0 + h - 1, "ink")
    cv.put(x0 + w // 2, y0 + h - 2, "ink")
    for r in range(w // 2 + 1):
        for x in range(x0 + r - 1, x0 + w - r + 1):
            if burned and (x + r) % 3 == 0:
                continue  # only charred rafters left
            cv.put(x, y0 - 1 - r, ("ink" if burned else "rf2") if x < x0 + w // 2 else ("wd0" if burned else "rf1"))


def burned_village(cv, f, frames):
    """charred house shells, collapsed roofs, smoke rising, embers glowing in the ruins"""
    house(cv, 3, 14, 9, 6, burned=True)
    house(cv, 17, 9, 10, 7, burned=True)
    house(cv, 22, 20, 7, 5, burned=True)
    for x, y in ((6, 19), (20, 15), (24, 24), (9, 18)):  # embers
        cv.put(x, y, "ember" if (x + f) % 3 else "gold")
    for x, y in ((13, 22), (14, 23), (2, 22), (30, 17)):  # scattered ash
        cv.put(x, y, "st1")
    smoke_column(cv, 21, 7, f, frames, height=8, key="a")
    smoke_column(cv, 7, 11, (f + 2) % frames, frames, height=7, key="b")


def windmill(cv, f, frames):
    """a stone windmill on its hill, four sails turning"""
    for y in range(12, 30):  # the tapering stone tower
        half = 3 + (y - 12) // 5
        for x in range(16 - half, 16 + half + 1):
            cv.put(x, y, "st3" if x < 16 else "st2" if x < 16 + half else "st1")
    for r in range(5):  # the cap
        for x in range(12 + r, 21 - r):
            cv.put(x, 11 - r, "rf2" if x < 16 else "rf1")
    cv.put(16, 27, "ink"); cv.put(16, 28, "ink"); cv.put(15, 20, "ink")
    hub = (16, 12)
    turn = f / frames * (math.pi / 2)
    for k in range(4):  # the sails: a spar and a lattice sail beside it
        a = turn + k * math.pi / 2
        for t in range(1, 12):
            x, y = hub[0] + math.cos(a) * t, hub[1] + math.sin(a) * t
            cv.put(round(x), round(y), "wd1")
            if t > 3:
                sx, sy = x + math.cos(a + math.pi / 2) * 2, y + math.sin(a + math.pi / 2) * 2
                cv.put(round(sx), round(sy), "wd4" if t % 2 else "wd3")
                mx, my = x + math.cos(a + math.pi / 2), y + math.sin(a + math.pi / 2)
                cv.put(round(mx), round(my), "wd3")
    cv.put(hub[0], hub[1], "ink")


def watchtower(cv, x0, y0, f, phase):
    """a wooden watchtower: four legs, a cross brace, a roofed platform, a fluttering blue pennant"""
    for y in range(y0 + 6, y0 + 20):
        cv.put(x0, y, "wd1"); cv.put(x0 + 6, y, "wd0")
        cv.put(x0 + 2, y, "wd1") if y > y0 + 12 else None
    for k in range(6):  # the cross brace
        cv.put(x0 + k, y0 + 8 + k, "wd2")
        cv.put(x0 + 6 - k, y0 + 8 + k, "wd1")
    for x in range(x0 - 1, x0 + 8):  # the platform
        cv.put(x, y0 + 6, "wd2"); cv.put(x, y0 + 5, "wd3")
    for x in range(x0, x0 + 7):  # the railing and roof
        cv.put(x, y0 + 3, "wd1")
    for r in range(4):
        for x in range(x0 - 1 + r, x0 + 8 - r):
            cv.put(x, y0 + 2 - r, "rf2" if x < x0 + 3 else "rf1")
    cv.put(x0 + 3, y0 - 3, "wd0"); cv.put(x0 + 3, y0 - 4, "wd0")
    wave = (f + phase) % 2
    for k in range(3):  # the pennant
        cv.put(x0 + 4 + k, y0 - 4 + (wave if k == 2 else 0), "water" if k < 2 else "gold")


def watchtowers(cv, f, frames):
    watchtower(cv, 4, 6, f, 0)
    watchtower(cv, 20, 10, f, 1)


def siege_lines(cv, f, frames):
    """three rows of sharpened stake barricades across the field, a banner on the middle one"""
    for row, (y, x0, x1) in enumerate(((6, 2, 26), (14, 6, 30), (22, 2, 26))):
        for x in range(x0, x1, 3):
            for k in range(5):  # a stake leaning out, pale tip
                cv.put(x + k // 2, y + 3 - k, "wd4" if k == 4 else "wd1" if (x // 3) % 2 else "wd0")
        for x in range(x0, x1):
            cv.put(x, y + 2, "wd0")
    for y in range(6, 14):  # the banner pole on the middle line
        cv.put(17, y, "wd1")
    wave = f % 2
    for y in range(6, 9):
        for x in range(18, 22):
            cv.put(x, y + (wave if x == 21 else 0), "water" if y < 8 else "gold" if x == 19 else "water")


def war_camp(cv, f, frames):
    """the Dragonslayer's war camp: rows of canvas tents, the big command tent, banners, a campfire"""
    def tent(x0, y0, w, h, stripe):
        for r in range(h):
            for x in range(x0 + r // 2, x0 + w - r // 2):
                y = y0 + h - r
                lit = x < x0 + w // 2
                c = "wd4" if lit else "st3"
                if stripe and (x - x0) % 4 == 0:
                    c = "rf2" if lit else "rf1"
                cv.put(x, y, c)
        cv.put(x0 + w // 2, y0 + h, "ink")
        cv.put(x0 + w // 2, y0 + h - 1, "ink")
    tent(2, 14, 9, 6, False)
    tent(12, 18, 9, 6, False)
    tent(30, 15, 9, 6, False)
    tent(16, 4, 15, 10, True)  # the command tent
    for y in range(-1, 6):  # its banner: the humans' blue and gold
        cv.put(23, y + 1, "wd1")
    wave = f % 2
    for y in range(1, 5):
        for x in range(24, 28):
            cv.put(x, y + (wave if x == 27 else 0), "gold" if (x == 25 and y == 2) else "water")
    for x0 in (6, 35):  # pennants on the side tents
        cv.put(x0, 11, "wd1"); cv.put(x0, 12, "wd1"); cv.put(x0, 13, "wd1")
        cv.put(x0 + 1, 11 + wave, "rf2")
    cx, cy = 26, 24  # the campfire and its smoke
    cv.put(cx - 1, cy, "wd0"); cv.put(cx + 1, cy, "wd0")
    cv.put(cx, cy, "ember" if f % 2 else "gold")
    cv.put(cx, cy - 1, "gold" if f % 2 else "ember")
    smoke_column(cv, cx, cy - 3, f, frames, height=6, puffs=2)


# --- the Ash Desert -------------------------------------------------------------------------------------------------

BONE, BONE_SHADE, BONE_SHADOW = "st4", "st3", "wd2"


def rib(cv, x, y, h, lean):
    """one bleached rib arching up out of the sand: two pixels thick, its shadow on the sand"""
    for k in range(h):
        bx = x + round(math.sin(k / h * math.pi * 0.8) * lean)
        cv.put(bx, y - k, BONE)
        cv.put(bx + 1, y - k, BONE_SHADE)
        if cv.get(bx + 2, y - k + 1) is None:
            cv.put(bx + 2, y - k + 1, BONE_SHADOW)


def skull_at(cv, x, y, rows, eye):
    colours = {"s": BONE, "d": BONE_SHADE, "k": eye, "t": BONE, "o": BONE_SHADOW}
    for r, line_text in enumerate(rows):
        for c, ch in enumerate(line_text):
            if ch != ".":
                cv.put(x + c, y + r, colours[ch])


def drake_ribs(cv, f, frames):
    """the old war's fallen dragons: rows of ribs out of the sand, a skull, a wisp of dust"""
    for row, y in enumerate((10, 18, 26)):
        for x in range(3 + row * 2, 31 + row * 2):  # the spine half buried, its shadow below
            cv.put(x, y, BONE_SHADE)
            cv.put(x, y + 1, BONE_SHADOW)
        for k in range(5):
            x = 4 + row * 2 + k * 6
            rib(cv, x, y, 6 + (k % 2) * 2, -2)
            rib(cv, x + 3, y, 6 + (k % 2) * 2, 2)
    skull_at(cv, 29, 20, [".ssss.", "skkdsd", "ssssdd", ".t.t..", "oooooo"], "ink")
    drift = f % frames  # a wisp of blown sand
    for k in range(3):
        cv.put((drift * 5 + k * 11) % 36, 3 + k * 2, "wd3")


def palm(cv, x, y, h, f, phase):
    """a palm: a curved ringed trunk, fronds that sway"""
    sway = (0, 1, 1, 0)[(f + phase) % 4]
    top = None
    for k in range(h):
        tx = x + round(math.sin(k / h * 1.4) * 3)
        cv.put(tx, y - k, "wd2" if k % 2 else "wd1")
        top = (tx, y - h)
    tx, ty = top
    for a in (-2.6, -1.9, -1.1, -0.4, 0.3, 1.0):
        for t in range(1, 6):
            fx = tx + math.cos(a) * t + sway * (t / 5)
            fy = ty + math.sin(a) * t * 0.6 + (t * t) / 9
            cv.put(round(fx), round(fy), "bg4" if a < -1 else "bg3" if t < 4 else "bg2")
    cv.put(tx, ty + 1, "wd0"); cv.put(tx + 1, ty + 1, "wd0")  # dates


def oasis_palms(cv, f, frames):
    """palms leaning over the oasis, swaying in the hot wind"""
    palm(cv, 7, 26, 15, f, 0)
    palm(cv, 18, 28, 19, f, 2)
    palm(cv, 27, 25, 13, f, 1)
    for x in (3, 4, 12, 23, 24, 31):  # tufts at their feet
        cv.put(x, 27, "bg3"); cv.put(x, 26, "bg4")


def bone_gate(cv, f, frames):
    """a gate of bone across the road: two great tusks meeting overhead, a dragon skull on the keystone, walls of
    stacked bone either side"""
    for side, x0 in ((-1, 9), (1, 27)):  # the tusks curving in, thick at the root
        for k in range(19):
            x = x0 - side * round((k / 19) ** 2 * 7)
            width = 4 if k < 8 else 3
            for w in range(width):
                cv.put(x + w - 1, 28 - k, BONE if w < width - 1 else BONE_SHADE)
            cv.put(x + width - 1, 29 - k, BONE_SHADOW)
    for x0, x1 in ((0, 7), (30, 36)):  # walls of stacked bones in rows
        for y in range(18, 29):
            for x in range(x0, x1):
                cv.put(x, y, BONE if (x + (y // 2) * 2) % 4 else BONE_SHADE)
            cv.put(x1, y, BONE_SHADOW)
        for x in range(x0, x1 + 1):
            cv.put(x, 29, BONE_SHADOW)
    glow = "gold" if f % 2 else "ember"
    skull_at(cv, 12, 6, ["..ssssss..", ".ssssssssd", "sskksskksd", "ssssssssdd", ".t.t.t.t..", "..ssssdd.."], glow)


def fallen_elder(cv, f, frames):
    """the elder dragon's skeleton sprawled across the sand: a great skull, spine, ribs, a wing's bones, the tail; its
    eye sockets glow with the cold purple of the spell that raised it"""
    spine = [(12 + k * 1.5, 22 - math.sin(k / 26 * math.pi) * 6) for k in range(27)]
    for x, y in spine:
        cv.put(round(x), round(y), BONE)
        cv.put(round(x), round(y) + 1, BONE_SHADE)
        cv.put(round(x), round(y) + 2, BONE_SHADOW)
    for k in range(3, 20, 2):  # ribs arching up off the spine
        x, y = spine[k]
        rib(cv, round(x), round(y), 7, -2 if k % 4 else 2)
    for t in range(14):  # a wing: arm bone and fingers spread over the sand
        cv.put(26 + t, 9 - t // 3, BONE)
        cv.put(26 + t, 10 - t // 3, BONE_SHADE)
    for fx in (30, 34, 38):
        for t in range(8):
            cv.put(fx + t // 2, 6 + t, BONE)
            cv.put(fx + t // 2 + 1, 6 + t, BONE_SHADOW)
    for t in range(12):  # the tail tapering off
        cv.put(50 + t // 2, 22 + t // 2, BONE if t % 2 else BONE_SHADE)
    glow = ("pink", "purple", "pink", "rf3")[f % 4]
    skull_at(cv, 0, 13, ["..ssssss....", ".sssssssssd.", "sskkssssssdd", "ssssssssssd.", ".t.t.t.tdd..",
                         "..ssssssd...", "..oooooo...."], glow)
    for x, y in ((3, 12), (6, 11)):  # horns
        cv.put(x, y, BONE)
        cv.put(x + 1, y - 1, BONE_SHADE)
        cv.put(x + 2, y - 2, BONE)


# --- the Volcano ----------------------------------------------------------------------------------------------------

def brazier(cv, x, y, f, phase):
    cv.put(x - 1, y, "st1"); cv.put(x, y, "st1"); cv.put(x + 1, y, "st1"); cv.put(x, y + 1, "st0")
    flicker = (f + phase) % 3
    cv.put(x, y - 1, "gold"); cv.put(x - 1 + flicker % 2, y - 2, "ember")
    if flicker:
        cv.put(x, y - 3, "rf2")


def monastery(cv, f, frames):
    """the cult's monastery on the slope: a dark stone hall with a stepped roof, a bell tower, braziers burning"""
    for y in range(12, 26):  # the hall
        for x in range(6, 28):
            cv.put(x, y, "st2" if x < 10 else "st1" if x < 25 else "st0")
    for r in range(3):  # stepped roofs, red tiles: each layer a solid band with a dark eave below
        for yy in range(3):
            for x in range(4 + r * 3 - (1 if yy == 2 else 0), 30 - r * 3 + (1 if yy == 2 else 0)):
                lit = ("rf3" if yy == 0 else "rf2") if x < 17 else "rf1"
                cv.put(x, 9 - r * 3 + yy, "rf0" if yy == 2 else lit)
    for y in range(2, 14):  # the tower
        for x in range(25, 30):
            cv.put(x, y, "st2" if x < 27 else "st1")
    cv.put(27, 1, "rf2"); cv.put(26, 2, "rf2"); cv.put(28, 2, "rf1")
    cv.put(27, 5, "gold" if f % 2 else "ember")  # a lit window
    for y in range(19, 26):  # the gate, a glow inside
        for x in range(14, 19):
            cv.put(x, y, "ember" if y > 22 and f % 2 else "rf1" if y > 21 else "ink")
    for x in range(8, 24, 4):  # windows
        if x not in (12, 16):
            cv.put(x, 16, "gold")
    brazier(cv, 3, 25, f, 0)
    brazier(cv, 31, 25, f, 1)


def cinder_forge(cv, f, frames):
    """the old war's forge, lit again: a squat stone forge, its chimney belching sparks, the furnace mouth glowing"""
    for y in range(14, 28):
        for x in range(4, 26):
            cv.put(x, y, "st2" if x < 8 else "st1" if x < 23 else "st0")
    for x in range(3, 27):  # the roof edge
        cv.put(x, 13, "st3" if x < 15 else "st2")
    for y in range(0, 14):  # the chimney
        for x in range(18, 23):
            cv.put(x, y, "st2" if x < 20 else "st1")
    heat = ("ember", "gold", "ember", "rf2")[f % 4]
    for y in range(20, 27):  # the furnace mouth
        for x in range(9, 16):
            if y > 20 or 10 < x < 15:
                cv.put(x, y, heat if y > 22 else "rf2")
    for k in range(4):  # sparks rising from the chimney's mouth, drifting east and dimming
        age = ((f / frames) + k / 4) % 1.0
        sx = round(20 + math.sin(k * 2.1) * 1.5 + age * 4)
        sy = round(4 - age * 5)
        if cv.get(sx, sy) is None or cv.get(sx, sy) in ("st1", "st2"):
            cv.put(sx, max(0, sy), "gold" if age < 0.5 else "ember")
    for x in range(26, 32):  # an anvil outside
        cv.put(x, 25, "st0")
    cv.put(28, 26, "st0"); cv.put(29, 26, "st0"); cv.put(27, 24, "st1"); cv.put(30, 24, "st1")


def phoenix_roost(cv, f, frames):
    """a cliff of stacked ledges with burning nests, a phoenix rising off the top nest, flames trailing"""
    for y, x0, x1 in ((11, 6, 26), (19, 3, 30), (27, 0, 34)):  # three ledges, wider downward
        for x in range(x0, x1):
            cv.put(x, y, "st3" if x < x0 + 4 else "st2")
            for d in range(1, 6):
                cv.put(x, y + d, "st1" if d < 4 else "st0")
    for nx, ny in ((12, 10), (22, 18), (8, 26), (27, 26)):  # nests: twigs and glowing embers
        for x in range(nx - 3, nx + 4):
            cv.put(x, ny, "wd0" if x % 2 else "wd1")
        for x in range(nx - 2, nx + 3):
            cv.put(x, ny - 1, ("ember", "gold", "rf2")[(x + f) % 3])
    rise = (0, -2, -4, -5, -4, -2)[f % 6]  # the phoenix over the top nest
    flap = f % 2
    px, py = 13, 5 + rise
    body = {(0, 0): "gold", (0, 1): "ember", (-1, 1): "ember", (1, 1): "ember", (0, 2): "rf2", (0, -1): "gold",
            (0, -2): "eye", (1, -2): "ember"}
    for (dx, dy), c in body.items():
        cv.put(px + dx, py + dy, c)
    for side in (-1, 1):  # wings: up on one frame, down on the next
        for t in range(1, 6):
            cv.put(px + side * t, py - (t // 2 if flap else -(t // 3)), "gold" if t < 3 else "ember" if t < 5 else "rf2")
    for t in range(3):  # a trail of flame
        cv.put(px, py + 3 + t, ("ember", "rf2", "rf1")[t])


def black_gate(cv, f, frames):
    """the Wyrm's basalt wall with its gate: dark blocks, glowing cracks that pulse, a spiked arch"""
    for y in range(8, 30):
        for x in range(0, 40):
            if 15 <= x <= 24 and y > 14:
                continue  # the gate's opening
            block = ((x // 5) + (y // 4)) % 2
            cv.put(x, y, "st1" if block else "st0")
            if y % 4 == 0 or (x + (y // 4) * 2) % 5 == 0:
                cv.put(x, y, "ink")
    for x in range(14, 26):  # the arch over the gate
        cv.put(x, 13, "st1"); cv.put(x, 14, "st0")
    for x in range(0, 40, 4):  # spikes on top
        cv.put(x + 1, 7, "st1"); cv.put(x + 1, 6, "st2")
    pulse = ("rf2", "ember", "gold", "ember")[f % 4]
    for x, y in ((5, 20), (6, 21), (7, 21), (8, 22), (31, 12), (32, 13), (32, 14), (33, 15), (28, 24), (29, 25)):
        cv.put(x, y, pulse)
    for y in range(15, 30):  # heat inside the gate
        for x in range(15, 25):
            cv.put(x, y, "rf1" if y < 24 else pulse if (x + y + f) % 4 == 0 else "rf0")


# --- the second round (2026-11-25, "go on") --------------------------------------------------------------------------

def mire_gate(cv, f, frames):
    """two mossy standing stones and a lintel across the bog road, a lantern of marsh light hanging from it"""
    bog_pool(cv, 15, 25, 15, 4, f, frames, "gate")
    for x0 in (5, 20):  # the pillars, lit on the left, moss creeping up
        for y in range(6, 25):
            for x in range(x0, x0 + 5):
                cv.put(x, y, "st3" if x < x0 + 2 else "st2" if x < x0 + 4 else "st1")
        for y in (18, 21, 23, 12):
            cv.put(x0 + (y % 3), y, "bg3")
            cv.put(x0 + (y % 3) + 1, y + 1, "bg2")
    for x in range(3, 28):  # the lintel
        cv.put(x, 4, "st3" if x < 14 else "st2")
        cv.put(x, 5, "st2" if x < 14 else "st1")
        cv.put(x, 6, "st0")
    cv.put(15, 7, "wd1"); cv.put(15, 8, "wd1")  # the marsh light
    cv.put(15, 9, "bglow" if f % 2 else "bg4"); cv.put(14, 10, "bg4"); cv.put(16, 10, "bg4")


def giant_frog(cv, f, frames):
    """a lily pool with pads and a pink flower, a huge frog squatting on the biggest pad, its throat puffing"""
    bog_pool(cv, 17, 18, 16, 9, f, frames, "frog")
    for px, py in ((6, 16), (26, 20), (12, 24)):  # pads
        for x in range(px - 2, px + 3):
            cv.put(x, py, "bg3"); cv.put(x, py + 1, "bg2")
    cv.put(26, 19, "pink"); cv.put(27, 19, "rf3")
    for x in range(10, 26):  # the frog's pad
        cv.put(x, 19, "bg3"); cv.put(x, 20, "bg2")
    frog = ["...ee.ee...", "..bEbbbEb..", ".bbbbbbbbb.", "bbBBBBBBBbb", "bBBBBBBBBBb", ".lttttttl..", "ll......ll."]
    puff = f % 2 == 0
    colours = {"e": "bg4", "E": "ink", "b": "bg3", "B": "bg2", "l": "bg1", "t": "wd4" if puff else "bg4"}
    for r, row in enumerate(frog):
        for c, ch in enumerate(row):
            if ch != ".":
                cv.put(12 + c, 12 + r, colours[ch])


def causeway(cv, f, frames):
    """a stone causeway on piers across a dark lake, a gap where the stones have sunk, bloaters bobbing"""
    bog_pool(cv, 20, 14, 20, 8, f, frames, "causeway")
    for x in range(1, 40):
        if 21 <= x <= 23:
            continue  # the sunken gap
        cv.put(x, 12, "st3" if x % 4 else "st2")
        cv.put(x, 13, "st2")
        cv.put(x, 14, "st1")
        if x % 6 == 2:  # piers
            cv.put(x, 15, "st0"); cv.put(x, 16, "st0")
    bob = f % 2
    for bx, by in ((10, 7), (30, 19)):  # bloaters
        for dx, dy, c in ((0, 0, "bg4"), (1, 0, "bg3"), (0, 1, "bg3"), (1, 1, "bg2"), (0, -1, "pink")):
            cv.put(bx + dx, by + dy + bob, c)


def drowned_trees(cv, f, frames):
    """dead trees standing in black water, roots and branches bare, a mist curl drifting between them"""
    bog_pool(cv, 18, 24, 17, 6, f, frames, "mirewood")
    for tx, h, lean in ((7, 18, -1), (17, 22, 1), (27, 16, 2)):
        for k in range(h):
            x = tx + round(lean * k / h)
            cv.put(x, 25 - k, "wd0"); cv.put(x + 1, 25 - k, "wd1" if k % 3 else "wd0")
        top = (tx + lean, 25 - h)
        for side in (-1, 1):  # bare branches
            for t in range(5):
                cv.put(top[0] + side * t, top[1] + 2 + t // 2 - (t > 2), "wd0")
            cv.put(top[0] + side * 3, top[1] - 1, "wd0")
        for dx in (-2, -1, 2, 3):  # roots
            cv.put(tx + dx, 25, "wd0")
    drift = (f / frames) * 30
    for k in range(9):  # mist
        x = int((drift + k * 4) % 36)
        cv.put(x, 14 + (k % 3), "st4" if k % 2 else "st3")


def scarecrow(cv, f, frames):
    """a scarecrow in a wheat field, its coat flapping, a crow circling"""
    for y in range(14, 30):  # wheat rows
        for x in range(0, 34):
            if (x + y * 2) % 5 < 3 and (y % 3) != 2:
                cv.put(x, y, "gold" if (x + y) % 4 else "wd3")
    for y in range(6, 28):  # the post
        cv.put(17, y, "wd1")
    for x in range(10, 25):  # the arms
        cv.put(x, 11, "wd1")
    flap = f % 2
    for y in range(10, 18):  # the coat
        for x in range(13, 22):
            if abs(x - 17) <= 2 + (y - 10) // 3:
                cv.put(x, y, "rf2" if x < 17 else "rf1")
    cv.put(12, 12 + flap, "rf1"); cv.put(22, 12 + flap, "rf1")
    for dx, dy, c in ((0, 0, "wd3"), (1, 0, "wd3"), (-1, 1, "wd3"), (0, 1, "wd3"), (1, 1, "wd2"), (0, 2, "wd2")):
        cv.put(17 + dx, 6 + dy, c)  # the sack head
    for x in range(14, 21):  # the hat
        cv.put(x, 5, "wd0")
    cv.put(16, 4, "wd0"); cv.put(17, 4, "wd0"); cv.put(18, 4, "wd0")
    a = f / frames * math.tau  # the crow
    cx, cy = round(26 + math.cos(a) * 5), round(5 + math.sin(a) * 2)
    cv.put(cx, cy, "ink"); cv.put(cx - 1, cy - 1 + flap, "ink"); cv.put(cx + 1, cy - 1 + flap, "ink")


def haystack(cv, x, y, w, h):
    for r in range(h):
        half = round(w / 2 * math.sqrt(1 - ((h - r) / h) ** 2)) if r < h else w // 2
        for c in range(-half, half + 1):
            cv.put(x + c, y + r, "gold" if c < 0 else "wd3" if c < half - 1 else "wd2")
    for c in range(-w // 2, w // 2 + 1):
        cv.put(x + c, y + h, "wd2")


def haystack_farm(cv, f, frames):
    """a red barn with a white-trimmed door and haystacks round it"""
    for y in range(8, 22):
        for x in range(14, 32):
            cv.put(x, y, "rf2" if x < 29 else "rf1")
    for r in range(6):  # the roof
        for x in range(13 + r, 33 - r):
            cv.put(x, 7 - r, "wd1" if x < 23 else "wd0")
    for y in range(13, 22):  # the door with its white cross
        for x in range(19, 26):
            cv.put(x, y, "rf1")
    for k in range(7):
        cv.put(19 + k, 13 + round(k * 8 / 6), "wd4")
        cv.put(25 - k, 13 + round(k * 8 / 6), "wd4")
    cv.put(23, 3, "wd4")  # the loft window
    haystack(cv, 6, 14, 8, 7)
    haystack(cv, 5, 23, 6, 5)
    haystack(cv, 36, 18, 6, 5)
    if f % 2 == 0:  # a bird on the roof's peak
        cv.put(22, 1, "ink")


def water_mill(cv, f, frames):
    """a timber mill on the stream, its water wheel turning, the stream running past"""
    for y in range(20, 27):  # the stream
        for x in range(0, 38):
            cv.put(x, y, "glint" if (x + y * 3 + f * 2) % 9 == 0 else "water")
    for y in range(6, 21):  # the mill house
        for x in range(4, 20):
            cv.put(x, y, "wd3" if x < 7 else "wd2" if x < 18 else "wd1")
            if (y - 6) % 4 == 3:
                cv.put(x, y, "wd1")
    for r in range(6):
        for x in range(3 + r, 21 - r):
            cv.put(x, 5 - r, "rf2" if x < 12 else "rf1")
    cv.put(10, 12, "ink"); cv.put(10, 13, "ink"); cv.put(14, 10, "gold")
    hub = (26, 17)
    turn = f / frames * (math.pi / 3)
    for a in range(0, 360, 6):  # the rim
        x = hub[0] + math.cos(math.radians(a)) * 7
        y = hub[1] + math.sin(math.radians(a)) * 7
        cv.put(round(x), round(y), "wd1")
    for k in range(6):  # spokes and paddles
        a = turn + k * math.pi / 3
        for t in range(8):
            cv.put(round(hub[0] + math.cos(a) * t), round(hub[1] + math.sin(a) * t), "wd0" if t < 7 else "wd2")
    cv.put(hub[0], hub[1], "ink")
    for x in range(20, 33):  # splash
        if (x + f) % 3 == 0:
            cv.put(x, 24, "st4")


def orchard(cv, f, frames):
    """apple trees in rows behind a dry-stone wall, red apples, one falling"""
    for x in range(0, 38):  # the wall
        cv.put(x, 26, "st3" if (x // 2) % 2 else "st2")
        cv.put(x, 27, "st1")
    for row, y in enumerate((9, 18)):
        for k in range(4):
            tx = 5 + k * 9 + (row * 4)
            if tx > 34:
                continue
            for dy in range(-4, 3):  # the crown
                for dx in range(-4, 5):
                    if dx * dx + dy * dy * 1.6 <= 16:
                        cv.put(tx + dx, y + dy, "bg3" if dx < 0 and dy < 0 else "bg2" if dx < 2 else "bg1")
            for dy in range(3, 6):
                cv.put(tx, y + dy, "wd1")
            for ax, ay in ((-2, -1), (1, 1), (2, -2), (-1, 2)):
                cv.put(tx + ax, y + ay, "rf2")
    fall = f % frames
    cv.put(14, 10 + fall * 3, "rf2")


def banner_road(cv, f, frames):
    """tall poles with the humans' banners along a bend of road, every one fluttering"""
    for k in range(4):
        x, y = 4 + k * 9, 6 + (k % 2) * 6
        for yy in range(y, y + 18):
            cv.put(x, yy, "wd1")
        wave = (f + k) % 2
        for yy in range(y + 1, y + 7):
            for xx in range(x + 1, x + 5):
                cv.put(xx, yy + (wave if xx == x + 4 else 0), "water" if yy < y + 5 else "gold")
        cv.put(x + 2, y + 3, "gold")
        cv.put(x, y - 1, "gold")


def ballista_wreck(cv, f, frames):
    """a rusted siege ballista half sunk in the sand: a heavy tilted stock, one bow arm whole and one snapped, a
    half-buried wheel, a spent bolt"""
    for x in range(3, 29):  # the stock, three pixels thick, tilted
        y = 19 - (x - 3) // 4
        cv.put(x, y, "wd2"); cv.put(x, y + 1, "wd1"); cv.put(x, y + 2, "wd0")
    for k in range(13):  # the whole bow arm, rusty iron, two thick
        x, y = 25 - k // 3, 15 - k
        cv.put(x, y, "rf3"); cv.put(x + 1, y, "rf1")
    for k in range(6):  # the snapped arm
        x, y = 26 + k // 2, 16 + k // 2
        cv.put(x, y, "rf3"); cv.put(x + 1, y, "rf1")
    cv.put(23, 3, "st3"); cv.put(23, 2, "st4")  # the bowstring's broken end
    for a in range(0, 181, 15):  # the wheel, half buried
        x = round(11 + math.cos(math.radians(a)) * 5)
        y = round(23 - math.sin(math.radians(a)) * 5)
        cv.put(x, y, "wd1"); cv.put(x, y + 1, "wd0")
    for x in range(2, 21):  # a spent bolt in the sand
        cv.put(x, 27, "wd1")
    cv.put(1, 27, "st3"); cv.put(0, 27, "st4"); cv.put(21, 26, "rf3"); cv.put(21, 28, "rf3")
    for x in range(0, 34):  # sand drifted over it
        cv.put(x, 24, "wd3")
        if x % 4 == 0:
            cv.put(x, 23, "wd3")
    drift = f % frames
    cv.put((drift * 7) % 34, 4, "wd3")


def scarab_mound(cv, f, frames):
    """a sand mound riddled with holes, scarabs pouring in and out"""
    for y in range(10, 26):
        half = round(16 * math.sqrt(max(0, 1 - ((y - 26) / 16) ** 2)))
        for x in range(18 - half, 18 + half):
            cv.put(x, y, "wd3" if x < 18 else "wd2")
    for hx, hy in ((12, 18), (18, 14), (24, 19), (16, 22), (22, 23)):
        cv.put(hx, hy, "ink"); cv.put(hx + 1, hy, "ink"); cv.put(hx, hy - 1, "wd1")
    for k in range(7):  # scarabs scurrying
        a = (f / frames) * math.tau + k * 0.9
        x, y = round(18 + math.cos(a) * (8 + k % 3 * 3)), round(19 + math.sin(a) * (4 + k % 2))
        cv.put(x, y, "bg0"); cv.put(x + 1, y, "water" if k % 3 == 0 else "bg1")


def twin_keeps(cv, f, frames):
    """two ruined keeps of the dragons' old camp behind a broken rock wall, a tattered dragon pennant"""
    for x0, top in ((3, 4), (24, 8)):
        for y in range(top, 26):
            for x in range(x0, x0 + 12):
                broken = y == top and x % 3 == 0
                cv.put(x, y, "ink" if broken else "wd3" if x < x0 + 3 else "wd2" if x < x0 + 10 else "wd1")
        for y in range(top + 6, top + 9):
            cv.put(x0 + 5, y, "ink"); cv.put(x0 + 6, y, "ink")
    for x in range(0, 40):  # the wall between, broken in places
        if x % 9 in (4, 5):
            continue
        for y in (22, 23, 24):
            cv.put(x, y, "wd2" if y < 24 else "wd1")
    wave = f % 2
    for y in range(-2, 4):  # a pole and a tattered mint dragon pennant
        cv.put(8, y + 2, "wd1")
    for x in range(9, 13):
        cv.put(x, 1 + (wave if x == 12 else 0), "bg4")
        cv.put(x, 2, "bg3" if x < 12 else None)


def obsidian_spires(cv, f, frames):
    """black glass spires out of the ash, the light glinting along their edges"""
    for sx, h, w in ((6, 22, 3), (14, 28, 4), (22, 18, 3), (29, 24, 3)):
        for k in range(h):
            half = max(0, round(w * (1 - k / h)))
            for dx in range(-half, half + 1):
                cv.put(sx + dx, 29 - k, "st2" if dx < 0 else "ink" if dx > 0 else "st1")
    g = f % 4  # a glint running up one edge
    for sx, h in ((14, 28), (29, 24)):
        y = 29 - (g * h // 4)
        cv.put(sx - 1, y, "st4"); cv.put(sx - 1, y - 1, "st3")


def lava_falls(cv, f, frames):
    """two falls of lava pouring off a black cliff into a glowing pool"""
    for y in range(4, 22):  # the cliff
        for x in range(0, 36):
            cv.put(x, y, "st1" if (x + y) % 6 else "st0")
    for x in range(0, 36):
        cv.put(x, 3, "st2")
    for fx in (9, 24):
        for y in range(3, 24):  # the fall, its bands sliding down
            for dx in range(-2, 3):
                band = (y - f * 2) % 4
                cv.put(fx + dx, y, "gold" if band == 0 and abs(dx) < 2 else "ember" if abs(dx) < 2 else "rf2")
    for y in range(22, 28):  # the pool
        for x in range(2, 34):
            if (x - 18) ** 2 / 300 + (y - 25) ** 2 / 9 <= 1:
                cv.put(x, y, "ember" if (x + y + f) % 5 else "gold")


def glass_shards(cv, f, frames):
    """a field of black glass shards: tall wedges with a lit left edge, a few catching the lava's glow"""
    shards = [(4, 22, 8, 2), (11, 25, 11, 3), (19, 20, 7, 2), (25, 26, 13, 3), (32, 21, 9, 2), (8, 14, 6, 2),
              (28, 13, 7, 2), (17, 27, 5, 2)]
    for k, (x, y, h, w) in enumerate(shards):
        for t in range(h):
            half = max(0, round(w * (1 - t / h)))
            lean = t // 4
            for dx in range(-half, half + 1):
                cv.put(x + dx + lean, y - t, "st2" if dx < 0 else "ink" if dx > 0 else "st1")
        cv.put(x - w, y + 1, "st0")
        if (k + f) % 4 == 0:  # a glint of the lava's glow
            cv.put(x + h // 4, y - h + 1, "ember")
            cv.put(x + h // 4 - 1, y - h + 2, "rf2")


def titan_hand(cv, f, frames):
    """a stone hand bigger than a castle rising out of a lake of magma, cracks glowing, magma dripping off it"""
    hand = ["..f.f.f....",
            ".fffffff...",
            ".ffffffft..",
            "fffffffftt.",
            "ffffffffft.",
            ".fffffffff.",
            "..ffffffff.",
            "..ffffffff.",
            "..ffffffff.",
            "...ffffff..",
            "...ffffff..",
            "...ffffff.."]
    top = 9
    for y in range(3, top + 1):  # fingers reaching up
        for fx in (13, 15, 17, 19):
            if y > 3 + (fx % 4):
                cv.put(fx, y, "st1")
                cv.put(fx + 1, y, "st0")
    for r, row in enumerate(hand):
        for c, ch in enumerate(row):
            if ch != ".":
                cv.put(12 + c, top + r, "st1" if c < 5 else "st0")
    pulse = ("rf2", "ember", "gold", "ember")[f % 4]
    for x, y in ((14, 11), (15, 12), (16, 14), (17, 15), (18, 17), (14, 18), (16, 20)):
        cv.put(x, y, pulse)
    for y in range(18, 31):  # the magma lake, its surface over the wrist
        for x in range(0, 38):
            if (x - 19) ** 2 / 400 + (y - 25) ** 2 / 30 <= 1 and not (y < 21 and 14 <= x <= 22):
                cv.put(x, y, "ember" if (x + y + f) % 4 else "gold")
    for x in range(13, 24):  # the ring where the hand breaks the surface
        cv.put(x, 21, "gold" if (x + f) % 2 else "rf2")
    drip = 10 + (f % 4) * 3
    cv.put(22, drip, "ember")


LANDMARKS = {
    # name: (width, height, frames, frame ms, draw)
    "drowned_chapel": (28, 28, 4, 220, drowned_chapel),
    "wasp_hive": (28, 31, 6, 120, wasp_hive),
    "sunken_village": (36, 22, 4, 240, sunken_village),
    "hydra_heads": (38, 38, 6, 180, hydra_heads),
    "burned_village": (32, 27, 6, 200, burned_village),
    "windmill": (32, 31, 4, 160, windmill),
    "watchtowers": (30, 30, 4, 260, watchtowers),
    "siege_lines": (34, 27, 4, 300, siege_lines),
    "war_camp": (42, 27, 6, 220, war_camp),
    "drake_ribs": (38, 27, 4, 260, drake_ribs),
    "oasis_palms": (34, 30, 4, 240, oasis_palms),
    "bone_gate": (36, 30, 4, 300, bone_gate),
    "fallen_elder": (58, 30, 4, 260, fallen_elder),
    "monastery": (35, 28, 6, 160, monastery),
    "cinder_forge": (33, 29, 6, 150, cinder_forge),
    "phoenix_roost": (34, 30, 6, 150, phoenix_roost),
    "black_gate": (40, 31, 4, 220, black_gate),
    "mire_gate": (31, 30, 4, 260, mire_gate),
    "giant_frog": (34, 28, 4, 280, giant_frog),
    "causeway": (40, 24, 4, 300, causeway),
    "drowned_trees": (36, 31, 6, 220, drowned_trees),
    "scarecrow": (34, 30, 4, 240, scarecrow),
    "haystack_farm": (42, 29, 4, 300, haystack_farm),
    "water_mill": (38, 28, 6, 150, water_mill),
    "orchard": (38, 29, 6, 260, orchard),
    "banner_road": (38, 26, 4, 220, banner_road),
    "ballista_wreck": (34, 30, 4, 260, ballista_wreck),
    "scarab_mound": (36, 28, 6, 140, scarab_mound),
    "twin_keeps": (40, 28, 4, 280, twin_keeps),
    "obsidian_spires": (36, 31, 4, 260, obsidian_spires),
    "lava_falls": (36, 29, 4, 140, lava_falls),
    "glass_shards": (38, 28, 4, 260, glass_shards),
    "titan_hand": (38, 31, 4, 220, titan_hand),
}

# each landmark's level: placed beside that level's node on the map
LEVEL_OF = {"drowned_chapel": 15, "wasp_hive": 19, "sunken_village": 20, "hydra_heads": 24,
            "burned_village": 28, "windmill": 30, "watchtowers": 33, "siege_lines": 34, "war_camp": 36,
            "drake_ribs": 40, "oasis_palms": 41, "bone_gate": 47, "fallen_elder": 48,
            "monastery": 51, "cinder_forge": 56, "phoenix_roost": 58, "black_gate": 59,
            "mire_gate": 14, "giant_frog": 17, "causeway": 18, "drowned_trees": 22,
            "scarecrow": 25, "haystack_farm": 26, "water_mill": 27, "orchard": 31, "banner_road": 35,
            "ballista_wreck": 39, "scarab_mound": 42, "twin_keeps": 45,
            "obsidian_spires": 50, "lava_falls": 52, "glass_shards": 55, "titan_hand": 57}
# spots set by hand (map units, top-left), where the scored search picks a poor one: the palms belong by the oasis
# pool south west of level 41, not on the lava land's edge
MANUAL = {"oasis_palms": (580, 290)}
# landmarks that bring their own pool may stand over water
WET = {"drowned_chapel", "sunken_village", "hydra_heads", "mire_gate", "giant_frog", "causeway", "drowned_trees",
       "water_mill"}
MAP_PIXEL = 2  # map units per art pixel
# MapFog's NODE_RADIUS and TRAIL_RADIUS (map units): keep in step with map_fog.gd
FOG_NODE_RADIUS = 56.0
FOG_TRAIL_RADIUS = 34.0


def node_name(name):
    return "Landmark_" + "".join(p.capitalize() for p in name.split("_"))


def place_landmarks(names):
    """writes an AnimatedSprite2D per landmark into game_world_map.tscn, beside its level's node: the spot round the
    node (map units) that covers the fewest trail dots and other nodes, stays on land (unless it brings its own
    pool) and is close to the node. Rerunnable: replaces the landmark nodes it wrote before."""
    sys.path.insert(0, str(ROOT / "tools"))
    import map_trail_routes as mtr
    import tres_edit
    art = Image.open(mtr.MAP_ART).convert("RGB")
    water = mtr.water_mask(Image.open(mtr.MAP_ART).convert("RGBA"))
    head, sections, nodes = mtr.load_nodes()
    dots = [d for level in nodes if level - 1 in nodes for d in mtr.dots(mtr.trail_points(nodes, level))]
    centres = {k: v["centre"] for k, v in nodes.items()}
    placed = []
    for name in names:
        w, h = LANDMARKS[name][0] * MAP_PIXEL, LANDMARKS[name][1] * MAP_PIXEL
        cx, cy = centres[LEVEL_OF[name]]
        # the land round the level's own node: the landmark stands on ground of those colours, so it stays in its
        # area (the Hydra once landed on the Wasted Lands' farm terraces next door)
        home = {art.getpixel((px, py)) for py in range(int(cy / MAP_PIXEL) - 14, int(cy / MAP_PIXEL) + 15)
                for px in range(int(cx / MAP_PIXEL) - 14, int(cx / MAP_PIXEL) + 15)
                if 0 <= px < art.width and 0 <= py < art.height and not water[py][px]}
        best = None
        if name in MANUAL:
            best = (0, MANUAL[name][0], MANUAL[name][1])
        for radius in range(20, 84, 4) if best is None else ():
            for step in range(16):
                a = step / 16 * math.tau
                x = cx + math.cos(a) * radius - w / 2
                y = cy + math.sin(a) * radius - h / 2
                if x < 0 or y < 0 or x + w > art.width * MAP_PIXEL or y + h > art.height * MAP_PIXEL:
                    continue
                inside = lambda px, py, m=0: x - m <= px <= x + w + m and y - m <= py <= y + h + m
                score = sum(8 for d in dots if inside(*d, 2))
                score += sum(60 for k, c in centres.items() if inside(c[0], c[1], 12))
                score += sum(300 for r in placed if not (x + w < r[0] or r[0] + r[2] < x or y + h < r[1] or r[1] + r[3] < y))
                if name not in WET:
                    wet = sum(1 for py in range(int(y), int(y + h), 4) for px in range(int(x), int(x + w), 4)
                              if water[py // MAP_PIXEL][px // MAP_PIXEL])
                    score += wet * 3
                cells = [(px, py) for py in range(int(y), int(y + h), 4) for px in range(int(x), int(x + w), 4)]
                foreign = sum(1 for px, py in cells if not water[py // MAP_PIXEL][px // MAP_PIXEL]
                              and art.getpixel((px // MAP_PIXEL, py // MAP_PIXEL)) not in home)
                score += foreign * 4
                # in the clear: MapFog lifts NODE_RADIUS round each node and TRAIL_RADIUS along each trail
                fogged = sum(1 for px, py in cells
                             if min((px - c[0]) ** 2 + (py - c[1]) ** 2 for c in centres.values()) > FOG_NODE_RADIUS ** 2
                             and min((px - d[0]) ** 2 + (py - d[1]) ** 2 for d in dots) > FOG_TRAIL_RADIUS ** 2)
                score += fogged * 3
                # beside its own level: not nearer any other level's node
                mx, my = x + w / 2, y + h / 2
                nearest = min(centres, key=lambda k: (centres[k][0] - mx) ** 2 + (centres[k][1] - my) ** 2)
                if nearest != LEVEL_OF[name]:
                    score += 1000
                score += radius * 0.4
                if best is None or score < best[0]:
                    best = (score, round(x / MAP_PIXEL) * MAP_PIXEL, round(y / MAP_PIXEL) * MAP_PIXEL)
        placed.append((best[1], best[2], w, h))
        print("%s by level %d at (%d, %d), score %.0f" % (name, LEVEL_OF[name], best[1], best[2], best[0]))
    # write the nodes: drop the ones written before, add an ext_resource and a node per landmark before MapTrails
    text = MAP_SCENE.read_text(encoding="utf-8")
    for name in names:
        text = re.sub(r'\[ext_resource type="SpriteFrames" path="res://scenes/ui/game_world_map/frames/%s_frames\.tres" id="[^"]+"\]\n' % name, "", text)
        text = re.sub(r'\[node name="%s" type="AnimatedSprite2D" parent="MapView/Map"[^\]]*\]\n(?:[^\[\n][^\n]*\n)*\n' % node_name(name), "", text)
    ext = "".join('[ext_resource type="SpriteFrames" path="res://scenes/ui/game_world_map/frames/%s_frames.tres" id="lm_%s"]\n' % (n, n) for n in names)
    first_node = text.index("\n[node ")
    text = text[:first_node].rstrip("\n") + "\n" + ext + text[first_node:]
    node = ('[node name="%s" type="AnimatedSprite2D" parent="MapView/Map"]\nposition = Vector2(%d, %d)\nscale = Vector2(2, 2)\n'
            'sprite_frames = ExtResource("lm_%s")\nanimation = &"IDLE"\nautoplay = "IDLE"\ncentered = false\n\n')
    block = "".join(node % (node_name(n), r[0], r[1], n) for n, r in zip(names, placed))
    # before the trails (the editor adds a unique_id to the header when it saves the scene)
    at = re.search(r'\[node name="MapTrails" type="Control" parent="MapView/Map"[^\]]*\]', text).start()
    text = text[:at] + block + text[at:]
    MAP_SCENE.write_text(text, encoding="utf-8", newline="\n")


def frames_of(name):
    w, h, count, _, draw = LANDMARKS[name]
    out = []
    for f in range(count):
        cv = hb.Canvas(w, h)
        draw(cv, f, count)
        out.append(cv)
    return out


def preview(names, out, ground=(0x26, 0x5c, 0x42)):
    sets = [(n, frames_of(n)) for n in names]
    cols = max(len(fr) for _, fr in sets)
    cw = max(LANDMARKS[n][0] for n in names) + 4
    ch = max(LANDMARKS[n][1] for n in names) + 4
    sheet = Image.new("RGBA", (cw * cols, ch * len(sets)), ground + (255,))
    for row, (name, frames) in enumerate(sets):
        for col, cv in enumerate(frames):
            sheet.alpha_composite(cv.image(), (col * cw + 2, row * ch + 2))
    sheet.resize((sheet.width * 5, sheet.height * 5), Image.NEAREST).save(out)


def build(name):
    w, h, count, ms, _ = LANDMARKS[name]
    tags = [("IDLE", ms, count)]
    note = "Generated by tools/art/map_landmarks.py (a story landmark on the world map); edit that and rerun."
    hb.build(name, frames_of(name), (w, h), tags, note)
    hb.write_sprite_frames(name, w, h, count, tags)


def main(argv):
    args = [a for a in argv[1:]]
    out = None
    if "--preview" in args:
        out = args[args.index("--preview") + 1]
        args = [a for a in args if a not in ("--preview", out)]
    args = [a for a in args if a != "--no-place"]
    names = args or list(LANDMARKS)
    if out:
        preview(names, out)
        return 0
    hb.ART.mkdir(parents=True, exist_ok=True)
    hb.FRAMES.mkdir(parents=True, exist_ok=True)
    for name in names:
        build(name)
    if "--no-place" not in argv:
        place_landmarks(names)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
