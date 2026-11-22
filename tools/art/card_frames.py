#!/usr/bin/env python3
"""Draws the level-up card frames: a 9-slice sheet, one 24x24 cell per rarity and state.

    python tools/art/card_frames.py

Writes assets/art/ui/cards/card_frames.png: row 0 common, row 1 rare; columns normal, hover,
pressed. LevelUpMenu slices each cell with CORNER px margins (keep them in step with
LevelUpMenu.FRAME_MARGIN). The fill is flat so the centre can stretch; the frame is a dark
outline, a 2 px border with a light inner edge, and corner ornaments (notches on common cards,
gems on rare ones). Colours from Endesga 32 and Puffe's mint.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "ui" / "cards" / "card_frames.png"

CELL = 24
CORNER = 7

OUTLINE = "0a1712"
STYLES = {
    # border, border shade, inner edge, fill per state (normal, hover, pressed)
    "common": {"border": "0b9b55", "shade": "265c42", "edge": "68ffd0", "ornament": "a2f6db",
               "fills": ["193c3e", "1f4b4a", "122b2c"]},
    "rare": {"border": "feae34", "shade": "be4a2f", "edge": "fee761", "ornament": "ffffff",
             "fills": ["2b2a3c", "3a3650", "1d1c2a"]},
}
ROWS = ["common", "rare"]


def rgba(hex_colour):
    return tuple(int(hex_colour[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def draw_cell(image, ox, oy, style, state):
    fill = style["fills"][state]
    last = CELL - 1
    for y in range(CELL):
        for x in range(CELL):
            edge_distance = min(x, y, last - x, last - y)
            if edge_distance == 0:
                colour = OUTLINE
            elif edge_distance <= 2:
                # the border: lit on the top and left, shaded on the bottom and right
                colour = style["shade"] if (x >= last - 2 or y >= last - 2) else style["border"]
            elif edge_distance == 3:
                colour = style["edge"] if state != 2 else style["border"]
            else:
                colour = fill
            image.putpixel((ox + x, oy + y), rgba(colour))
    # the outline's corner pixels cut off, so the card has rounded corners
    for cx, cy in ((0, 0), (last, 0), (0, last), (last, last)):
        image.putpixel((ox + cx, oy + cy), (0, 0, 0, 0))
    # corner ornaments on the border
    for cx, cy in ((1, 1), (last - 3, 1), (1, last - 3), (last - 3, last - 3)):
        if style is STYLES["rare"]:
            # a 3x3 diamond gem in Puffe's mint: dark corners, white glint in the middle
            for dy in range(3):
                for dx in range(3):
                    corner = dx != 1 and dy != 1
                    image.putpixel((ox + cx + dx, oy + cy + dy), rgba(OUTLINE if corner else ("ffffff" if (dx, dy) == (1, 1) else "2effb8")))
        else:
            image.putpixel((ox + cx + 1, oy + cy + 1), rgba(style["ornament"]))


def main():
    sheet = Image.new("RGBA", (CELL * 3, CELL * len(ROWS)), (0, 0, 0, 0))
    for row, name in enumerate(ROWS):
        for state in range(3):
            draw_cell(sheet, state * CELL, row * CELL, STYLES[name], state)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print("saved %s" % OUT)


if __name__ == "__main__":
    main()
