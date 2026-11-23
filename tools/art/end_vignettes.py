#!/usr/bin/env python3
"""Draws the pictures at the top of the level end screens, from the title screen's hoard hall.

    python tools/art/end_vignettes.py [--preview <dir>]

Writes into assets/art/ui/end_screens/ (text spec, .aseprite and packed .png through tools/sprite/sprite.py):
    end_win             160x60: the hoard hall close up, a gold pile under the gate, torches burning
    end_lose            160x60: the same hall with the torches out, the banners torn, the hoard carried
                        off and a cold cracked egg on the floor
    end_coin            a coin spinning as it falls (the win screen's gold rain)
    end_smoke           a puff of smoke rising (the lose screen)
and their SpriteFrames into scenes/ui/end_vignette/frames/. EndVignette places the hatchlings (from the
title's hatchling sheets, SAD for the lose screen) and the falling coins and smoke; keep the spots below in
step with its constants. Run tools/art/hoard_backdrop.py first when the hall or the hatchlings change.
"""
import math
import os
import random
import sys
from pathlib import Path

from PIL import Image

import hoard_backdrop as hb

ROOT = Path(__file__).resolve().parents[2]
hb.ART = ROOT / "assets" / "art" / "ui" / "end_screens"
hb.FRAMES = ROOT / "scenes" / "ui" / "end_vignette" / "frames"

VW, VH = 160, 60
CROP = (126, 52)               # the hall's top left that the picture shows
MINI_PILE = (206, 107, 44, 6, 17)   # hall x, floor y, half width, half depth, height
ASH = ["262b44", "3c3b4c", "4e4e5f", "5f6273", "717586", "9da5b6", "c0cbdc"]
for i, h in enumerate(ASH):
    hb.C["ash%d" % i] = h
hb.EGG_SPOT["ash"] = "ash2"
DARKER = {"s%d" % i: "s%d" % max(0, i - 2) for i in range(9)}
DARKER.update({"m2": "m0", "m1": "m0", "g4": "g2", "g3": "g1", "g5": "g3", "g2": "g1", "wood2": "wood1",
               "wood1": "wood0", "white": "s5"})


def hall(lit=True, torn=False):
    """The title's hall without its pile, eggs or treasures, the torches lit or out, the banners whole or torn."""
    cv = hb.Canvas(hb.W, hb.H)
    if not lit:
        hb_wall_light = hb.wall_light
        hb.wall_light = lambda x, y: 0.0
    hb.draw_sky(cv)
    hb.draw_wall(cv)
    for cx, r in hb.TOWERS:
        hb.draw_tower(cv, cx, r)
    hb.draw_gate(cv)
    bare = [row[:] for row in cv.px]
    for cx, top in hb.BANNERS:
        hb.draw_banner(cv, cx, top)
        if torn:
            # the lower half ripped away on a slant, a slash through the egg
            for y in range(top + 6, top + 28):
                for x in range(cx - 8, cx + 9):
                    ragged = 3 if (x * 7) % 5 == 0 else 0
                    slash = y == top + 5 + (x - cx + 3) and 0 <= x - cx + 3 < 7
                    if y > top + 14 + (x - cx) // 2 + ragged or slash:
                        cv.px[y][x] = bare[y][x]
    for tx, ty in hb.TORCH_SPOTS:
        hb.draw_torch_sconce(cv, tx, ty)
    hb.draw_floor(cv)
    if not lit:
        hb.wall_light = hb_wall_light
    return cv


def crop(cv):
    out = hb.Canvas(VW, VH)
    for y in range(VH):
        for x in range(VW):
            out.px[y][x] = cv.get(CROP[0] + x, CROP[1] + y)
    return out


def win_picture():
    cv = hall(lit=True)
    rnd = random.Random(5)
    keep = (hb.HOARD_X, hb.PILE_FLOOR_Y, hb.PILE_RX, hb.PILE_RY, hb.PILE_H)
    hb.HOARD_X, hb.PILE_FLOOR_Y, hb.PILE_RX, hb.PILE_RY, hb.PILE_H = MINI_PILE
    hb.draw_pile(cv, rnd)
    hb.HOARD_X, hb.PILE_FLOOR_Y, hb.PILE_RX, hb.PILE_RY, hb.PILE_H = keep
    # a few coins already rained down on the floor
    for x, y in ((140, 109), (150, 111), (262, 110), (272, 108), (236, 111), (171, 110)):
        coin(cv, x, y)
    return crop(cv)


def coin(cv, x, y):
    cv.put(x, y, "g5")
    cv.put(x + 1, y, "g4")
    cv.put(x - 1, y + 1, "g4")
    cv.put(x, y + 1, "g3")
    cv.put(x + 1, y + 1, "g3")
    cv.put(x + 2, y + 1, "g2")


def lose_picture():
    cv = hall(lit=False, torn=True)
    # what is left of the hoard: a few coins, dragged-coin streaks towards the gate
    rnd = random.Random(9)
    for _ in range(14):
        x, y = rnd.randrange(150, 266), rnd.randrange(103, 111)
        coin(cv, x, y)
    for y in range(101, 112):
        if y % 3 == 0:
            cv.put(hb.GATE[0] - 2 + (y % 5), y, "g1")
    # the cold egg, tipped over and broken open, its shards around it
    egg = hb.egg_frame("ash", empty=True)
    ex, ey = 232, 109
    for yy in range(hb.EGG_H - 4):
        for xx in range(hb.EGG_W):
            key = egg.px[yy][xx]
            if key and key.startswith("ash"):
                cv.put(ex - hb.EGG_W // 2 + xx, ey - (hb.EGG_H - 2) + yy, key)
    for x, y, k in ((217, 110, "ash4"), (218, 110, "ash3"), (246, 111, "ash3"), (247, 110, "ash5"), (213, 111, "ash2")):
        cv.put(x, y, k)
    out = crop(cv)
    # the light is gone: everything a step or two darker
    for y in range(VH):
        for x in range(VW):
            k = out.px[y][x]
            if k in DARKER and not (k.startswith("ash")):
                out.px[y][x] = DARKER[k]
    return out


def coin_frames():
    shapes = [[".55.", "5443", "4332", ".22."], [".54.", ".43.", ".32.", ".21."], ["..5.", "..4.", "..3.", "..2."],
              [".45.", ".34.", ".23.", ".12."]]
    keys = {"1": "g1", "2": "g2", "3": "g3", "4": "g4", "5": "g5"}
    frames = []
    for shape in shapes:
        cv = hb.Canvas(4, 4)
        for y, row in enumerate(shape):
            for x, ch in enumerate(row):
                if ch in keys:
                    cv.put(x, y, keys[ch])
        frames.append(cv)
    return frames, [("IDLE", 90, len(frames))]


def smoke_frames():
    """A puff that swells and thins as it rises; the script moves it up."""
    frames = []
    for i, r in enumerate((1.2, 2.0, 2.7, 3.2, 3.4, 3.4)):
        cv = hb.Canvas(9, 9)
        for y in range(9):
            for x in range(9):
                d = math.hypot(x - 4, y - 4)
                if d > r:
                    continue
                if i >= 4 and (x + y + i) % 2 == 0:
                    continue        # thinning out
                cv.put(x, y, "s5" if d < r - 1.2 and x <= 4 else ("s4" if i < 3 else "s3"))
        frames.append(cv)
    return frames, [("IDLE", 160, len(frames))]


def main(argv):
    preview_dir = argv[argv.index("--preview") + 1] if "--preview" in argv else None
    pictures = {"end_win": win_picture(), "end_lose": lose_picture()}
    sprites = {"end_coin": coin_frames(), "end_smoke": smoke_frames()}
    if preview_dir:
        for name, cv in pictures.items():
            cv.image().resize((VW * 6, VH * 6), Image.NEAREST).save(os.path.join(preview_dir, name + ".png"))
        return 0
    hb.ART.mkdir(parents=True, exist_ok=True)
    hb.FRAMES.mkdir(parents=True, exist_ok=True)
    note = "Generated by tools/art/end_vignettes.py for the level end screens; edit that and rerun."
    for name, cv in pictures.items():
        hb.build(name, [cv], (VW, VH), [("IDLE", 100, 1)], note)
    for name, (frames, tags) in sprites.items():
        hb.build(name, frames, (frames[0].w, frames[0].h), tags, note)
        hb.write_sprite_frames(name, frames[0].w, frames[0].h, len(frames), tags)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
