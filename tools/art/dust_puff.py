#!/usr/bin/env python3
"""Draws the dust puff: 4 frames of 16x16 side by side, for buildings placed or sold and enemies arriving.

    python tools/art/dust_puff.py

Writes assets/art/effects/dust_puff.png. Each frame is a few round blobs (light top-left, shade
bottom-right, a dark rim on the first frames) that spread and rise; the last two frames break up
with an ordered dither so the cloud thins out instead of fading. Endesga 32 dust colours.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "effects" / "dust_puff.png"

SIZE = 16
LIGHT = (0xEA, 0xD4, 0xAA, 255)
MID = (0xC0, 0xCB, 0xDC, 255)
SHADE = (0x8B, 0x9B, 0xB4, 255)
RIM = (0x5A, 0x69, 0x88, 255)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

# per frame: blobs as (centre x, centre y, radius), and how much of the cloud the dither keeps (16 = all)
FRAMES = [
    ([(8, 12, 2.5), (5, 13, 1.6), (11, 13, 1.6)], 16, True),
    ([(8, 10, 3.6), (4, 12, 2.4), (12, 12, 2.4)], 16, True),
    ([(8, 8, 4.0), (3, 11, 2.6), (13, 11, 2.6), (8, 13, 2.0)], 10, False),
    ([(8, 6, 3.6), (3, 9, 2.2), (13, 9, 2.2)], 5, False),
]


def draw_frame(image, ox, blobs, keep, has_rim):
    for y in range(SIZE):
        for x in range(SIZE):
            inside = None
            for cx, cy, r in blobs:
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                distance = (dx * dx + dy * dy) ** 0.5
                if distance <= r:
                    # the blob's light comes from the top left
                    side = dx + dy
                    colour = LIGHT if side < -r * 0.4 else MID if side < r * 0.5 else SHADE
                    if has_rim and distance > r - 0.9:
                        colour = RIM
                    inside = colour if inside is None or colour == LIGHT else inside
            if inside is None or BAYER[y % 4][x % 4] >= keep:
                continue
            image.putpixel((ox + x, y), inside)


def main():
    sheet = Image.new("RGBA", (SIZE * len(FRAMES), SIZE), (0, 0, 0, 0))
    for index, (blobs, keep, has_rim) in enumerate(FRAMES):
        draw_frame(sheet, index * SIZE, blobs, keep, has_rim)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print("saved %s" % OUT)


if __name__ == "__main__":
    main()
