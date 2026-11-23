#!/usr/bin/env python3
"""Draws the five area banners at the top of the world map's level panel.

    python tools/art/area_banners.py [--preview <dir>]

Writes assets/art/ui/area_banners/area_banner_<area>.txt/.aseprite/.png (80x22, drawn at 2x) for caves,
swamp, wasted_lands, ash_desert and volcano: a small landscape of the area inside a 1 px frame, light from
the top left. MapLevelElement shows the one for the level's area (12 levels each). Edit and rerun.
"""
import math
import os
import random
import sys
from pathlib import Path

from PIL import Image

import hoard_backdrop as hb

ROOT = Path(__file__).resolve().parents[2]
hb.ART = ROOT / "assets" / "art" / "ui" / "area_banners"
BW, BH = 80, 22
AREAS = ["caves", "swamp", "wasted_lands", "ash_desert", "volcano"]

EXTRA = {
    "frame0": "181425", "frame1": "3e2731", "frame2": "8b9bb4",
    "sw0": "17323a", "sw1": "1f5048", "sw2": "2d7356", "sw3": "4a9a5c", "sw4": "8fc46a", "fog": "5a8a7a",
    "wl0": "3e2731", "wl1": "733e39", "wl2": "be4a2f", "wl3": "f77622", "wl4": "feae34", "smoke": "5a6988",
    "sa0": "b86f50", "sa1": "e4a672", "sa2": "ead4aa", "sa3": "f2e3c6", "bone": "e8e0d0", "bone2": "b8b0a0",
    "sky_sand": "f4d9a8", "sun": "fffbe6",
    "vo0": "181425", "vo1": "3e2731", "vo2": "5d1d2c", "vo3": "a22633", "ash": "4e4e5f",
}
hb.C.update(EXTRA)


def sky(cv, stops):
    """stops: [(row, key)] top to bottom, plain bands (a checker seam is too busy at this size)."""
    for y in range(BH):
        key = stops[0][1]
        for row, k in stops:
            if y >= row:
                key = k
        for x in range(BW):
            cv.put(x, y, key)


def ridge(cv, base, amp, freq, phase, key, top_key=None, rough=0.0, seed=0):
    """A silhouette from row `base` up by a wave, filled to the bottom; its top pixel in top_key."""
    rnd = random.Random(seed)
    for x in range(BW):
        h = amp * math.sin(x * freq + phase) + amp * 0.5 * math.sin(x * freq * 2.3 + phase * 1.7)
        h += rnd.uniform(-rough, rough)
        top = int(round(base - h))
        for y in range(max(0, top), BH):
            cv.put(x, y, key)
        if top_key and 0 <= top < BH:
            cv.put(x, top, top_key)


def frame(cv):
    for x in range(BW):
        cv.put(x, 0, "frame0")
        cv.put(x, BH - 1, "frame0")
    for y in range(BH):
        cv.put(0, y, "frame0")
        cv.put(BW - 1, y, "frame0")
    # a light inner edge on the top and left, as the theme's panels
    for x in range(1, BW - 1):
        cv.put(x, 1, cv.get(x, 1) if False else blend_light(cv.get(x, 1)))
    for y in range(1, BH - 1):
        cv.put(1, y, blend_light(cv.get(1, y)))


def blend_light(key):
    return "frame2" if key in ("night0", "vo0", "s0", "frame0") else key


def caves():
    cv = hb.Canvas(BW, BH)
    sky(cv, [(0, "night0"), (8, "night1"), (15, "s0")])
    # far cave wall with a glow behind
    for x in range(BW):
        for y in range(8, 15):
            if (x - 52) ** 2 / 300 + (y - 12) ** 2 / 10 < 1:
                cv.put(x, y, "night2" if (x - 52) ** 2 / 300 + (y - 12) ** 2 / 10 < 0.5 else "night1")
    # stalactites from the roof and stalagmites from the floor
    rnd = random.Random(3)
    for x0 in range(2, BW, 7):
        length = rnd.randint(3, 8)
        for i in range(length):
            w = max(0, (length - i) // 3)
            for dx in range(-w, w + 1):
                cv.put(x0 + dx, 1 + i, "s2" if dx < 0 else "s1")
    ridge(cv, 17, 1.5, 0.3, 0.5, "s1", "s3", 0.6, 4)
    for x0 in (10, 31, 63, 72):
        h = rnd.randint(3, 6)
        for i in range(h):
            w = (h - i) // 3
            for dx in range(-w, w + 1):
                cv.put(x0 + dx, 17 - i, "s3" if dx < 0 else "s2")
    # glowing crystals
    for cx, cy, s in ((22, 16, 3), (46, 18, 4), (56, 17, 2), (70, 18, 3)):
        for i in range(s):
            cv.put(cx, cy - i, "b2" if i < s - 1 else "white")
            cv.put(cx + 1, cy - i + 1, "b1")
        cv.put(cx - 1, cy, "b0")
    # a batling flitting across
    for x, y in ((36, 7), (35, 6), (37, 6), (34, 7), (38, 7)):
        cv.put(x, y, "p1")
    cv.put(36, 7, "r2")
    frame(cv)
    return cv


def swamp():
    cv = hb.Canvas(BW, BH)
    sky(cv, [(0, "sw1"), (6, "sw2"), (11, "fog")])
    # the Hydra's three necks rising from the far water
    for nx, top, lean in ((52, 4, -1), (58, 3, 0), (64, 5, 1)):
        for y in range(top, 14):
            x = nx + round(lean * (14 - y) / 4 + math.sin(y * 0.6) * 0.8)
            cv.put(x, y, "sw0")
            cv.put(x + 1, y, "sw1")
        cv.put(nx + lean * 2 + 2, top, "sw0")
        cv.put(nx + lean * 2 + 2, top + 1, "sw0")
        cv.put(nx + lean * 2 + 1, top, "e2")       # an eye
    ridge(cv, 13, 0.8, 0.2, 1.0, "sw1", "sw2", 0.0, 1)
    # dead trees
    for tx, h in ((12, 10), (30, 7)):
        for y in range(13 - h, 14):
            cv.put(tx, y, "wood0")
        for i in range(3):
            cv.put(tx - 1 - i, 13 - h + 2 + i // 2 - i, "wood0")
            cv.put(tx + 1 + i, 13 - h + 4 - i, "wood0")
    # black water with light streaks, lily pads and reeds
    for y in range(14, BH):
        for x in range(BW):
            k = "sw0"
            if (x * 3 + y * 7) % 13 == 0 and y < 19:
                k = "sw2"
            cv.put(x, y, k)
    for px, py in ((20, 17), (44, 19), (70, 16)):
        for dx in range(-1, 2):
            cv.put(px + dx, py, "sw3")
        cv.put(px, py - 1, "sw4")
    for rx in (4, 6, 38, 40, 75):
        for y in range(10 + rx % 3, 15):
            cv.put(rx, y, "sw3" if y < 12 else "sw2")
    frame(cv)
    return cv


def wasted_lands():
    cv = hb.Canvas(BW, BH)
    sky(cv, [(0, "wl1"), (5, "wl2"), (10, "wl3"), (13, "wl4")])
    # smoke columns
    for sx in (18, 62):
        # round puffs, growing as they rise and drift right
        for i, (dy, r) in enumerate(((12, 1.4), (9, 2.0), (6, 2.6), (3, 3.0), (0, 3.2))):
            cx = sx + i * 1.6
            for y in range(int(dy - r) - 1, int(dy + r) + 2):
                for x in range(int(cx - r) - 1, int(cx + r) + 2):
                    d = math.hypot(x + 0.5 - cx, y + 0.5 - dy)
                    if d <= r:
                        lit = (x + 0.5 - cx) + (y + 0.5 - dy) < -r * 0.4
                        cv.put(x, y, "s6" if lit else "smoke")
    ridge(cv, 14, 1.5, 0.12, 2.0, "wl0", "wl1", 0.3, 2)
    # a human camp on the hill: two tents and a red banner
    for tx in (44, 52):
        for i in range(4):
            for dx in range(-i, i + 1):
                cv.put(tx + dx, 10 + i, "sa1" if dx <= 0 else "sa0")
    for y in range(6, 13):
        cv.put(48, y, "wood1")
    for y in range(6, 9):
        cv.put(49, y, "r2")
        cv.put(50, y, "r1")
    cv.put(51, 7, "r1")
    # burnt furrows and a broken fence
    for y in range(15, BH):
        for x in range(BW):
            cv.put(x, y, "wl1" if (x + 2 * y) % 6 else "wl0")
    for fx in range(4, 34, 5):
        tilt = 1 if fx % 3 == 0 else 0
        for y in range(13, 17):
            cv.put(fx + (tilt if y < 14 else 0), y, "wood1")
    for x in range(4, 26):
        cv.put(x, 14, "wood0" if x % 5 else "wood1")
    frame(cv)
    return cv


def ash_desert():
    cv = hb.Canvas(BW, BH)
    sky(cv, [(0, "sa1"), (4, "sky_sand"), (10, "sa3")])
    # a pale, hazy sun
    for y in range(1, 10):
        for x in range(54, 70):
            d = math.hypot(x - 61.5, y - 5)
            if d < 3.2:
                cv.put(x, y, "sun")
            elif d < 4.4 and (x + y) % 2 == 0:
                cv.put(x, y, "sun")
    ridge(cv, 13, 2.2, 0.09, 0.3, "sa2", "sa3", 0.0, 5)
    ridge(cv, 17, 1.8, 0.14, 2.2, "sa1", "sa2", 0.0, 6)
    # the ribcage of something huge, half buried
    for i, rx in enumerate(range(14, 34, 4)):
        h = 8 - abs(i - 2) * 2
        for y in range(16 - h, 18):
            cv.put(rx + (1 if y < 16 - h + 2 else 0), y, "bone" if y < 15 else "bone2")
    for x in range(12, 36):
        cv.put(x, 17, "bone2" if x % 3 else "bone")
    # a skull at the end of the spine
    for x, y, k in ((36, 16, "bone"), (37, 16, "bone"), (38, 16, "bone2"), (36, 17, "bone2"), (37, 17, "frame0"),
                    (38, 17, "bone2"), (39, 17, "bone2")):
        cv.put(x, y, k)
    for y in range(19, BH):
        for x in range(BW):
            cv.put(x, y, "sa0" if (x + y) % 7 == 0 else "sa1")
    frame(cv)
    return cv


def volcano():
    cv = hb.Canvas(BW, BH)
    sky(cv, [(0, "vo1"), (5, "vo2"), (11, "vo3")])
    # the cone, its plume and lava running down
    peak_x = 46
    for y in range(4, BH):
        half = (y - 4) * 1.6 + 2
        for x in range(int(peak_x - half), int(peak_x + half) + 1):
            cv.put(x, y, "night1" if x < peak_x else "vo0")
    for y in range(0, 5):
        for x in range(peak_x - 6 - y, peak_x + 4 + y):
            if (x * 5 + y * 3) % 4 and abs(x - peak_x + 1 - math.sin(y) * 2) < 3 + (4 - y):
                cv.put(x, y, "ash")
    cv.put(peak_x - 1, 4, "g4")
    cv.put(peak_x, 4, "g5")
    cv.put(peak_x + 1, 4, "g4")
    for start, drift in ((peak_x, -0.5), (peak_x + 1, 0.6)):
        for y in range(5, BH):
            x = round(start + drift * (y - 5) + math.sin(y * 0.8))
            cv.put(x, y, "g3" if y % 3 else "g4")
    # a glowing lava field with dark crusts in front
    for y in range(18, BH):
        for x in range(BW):
            k = "g2" if (x * 7 + y * 3) % 5 else "g3"
            if (x // 5 + y) % 3 == 0:
                k = "vo1"
            cv.put(x, y, k)
    for x in range(BW):
        cv.put(x, 17, "vo0" if x % 9 else "g1")
    frame(cv)
    return cv


DRAW = {"caves": caves, "swamp": swamp, "wasted_lands": wasted_lands, "ash_desert": ash_desert, "volcano": volcano}


def main(argv):
    pictures = {area: DRAW[area]() for area in AREAS}
    if "--preview" in argv:
        out = argv[argv.index("--preview") + 1]
        sheet = Image.new("RGBA", (BW, (BH + 2) * len(AREAS)), (0x26, 0x2b, 0x44, 255))
        for i, area in enumerate(AREAS):
            sheet.alpha_composite(pictures[area].image(), (0, i * (BH + 2)))
        sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save(os.path.join(out, "area_banners.png"))
        return 0
    hb.ART.mkdir(parents=True, exist_ok=True)
    note = "Generated by tools/art/area_banners.py for the world map's level panel; edit that and rerun."
    for area, cv in pictures.items():
        hb.build("area_banner_" + area, [cv], (BW, BH), [("IDLE", 100, 1)], note)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
