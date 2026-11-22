#!/usr/bin/env python3
"""Draws the title screen logo, "PUFFE TD", from 5x7 block glyphs.

    python tools/art/title_logo.py

Writes assets/art/ui/title/title_logo.png. Each glyph pixel is a SCALE x SCALE block; every block
row takes its colour from the word's gradient (Puffe's mint for PUFFE, coin gold for TD, from his
portrait and Endesga 32), then the letters get a 1 px dark outline and a drop shadow. Edit the
glyphs, gradients or scale here and rerun.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "ui" / "title" / "title_logo.png"

SCALE = 3
LETTER_GAP = 1          # glyph pixels between letters
WORD_GAP = 3            # glyph pixels between the words
SHADOW = (0, 2)         # drop shadow offset in output pixels
OUTLINE = (0x0A, 0x17, 0x12, 255)
SHADOW_COLOR = (0x18, 0x14, 0x25, 255)

GLYPHS = {
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
}

# one colour per output row of a letter (7 glyph rows x SCALE), top to bottom
MINT = ["a2f6db"] * 3 + ["87ffdb"] * 4 + ["68ffd0"] * 5 + ["2effb8"] * 5 + ["06c374"] * 3 + ["0b9b55"]
GOLD = ["fee761"] * 6 + ["feae34"] * 9 + ["f77622"] * 5 + ["be4a2f"]
WORDS = [("PUFFE", MINT), ("TD", GOLD)]


def rgba(hex_colour):
    return tuple(int(hex_colour[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def draw_letters():
    """The letters alone, with a 1 px margin left for the outline and room for the shadow."""
    glyph_columns = 0
    for word_index, (word, _) in enumerate(WORDS):
        glyph_columns += len(word) * 5 + (len(word) - 1) * LETTER_GAP
        if word_index < len(WORDS) - 1:
            glyph_columns += WORD_GAP
    width = glyph_columns * SCALE + 2 + SHADOW[0]
    height = 7 * SCALE + 2 + SHADOW[1]
    letters = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    x = 1
    for word_index, (word, gradient) in enumerate(WORDS):
        for letter_index, letter in enumerate(word):
            for gy, row in enumerate(GLYPHS[letter]):
                for gx, cell in enumerate(row):
                    if cell != "#":
                        continue
                    for dy in range(SCALE):
                        colour = rgba(gradient[gy * SCALE + dy])
                        for dx in range(SCALE):
                            letters.putpixel((x + gx * SCALE + dx, 1 + gy * SCALE + dy), colour)
            x += 5 * SCALE
            if letter_index < len(word) - 1:
                x += LETTER_GAP * SCALE
        if word_index < len(WORDS) - 1:
            x += WORD_GAP * SCALE
    return letters


def main():
    letters = draw_letters()
    width, height = letters.size
    logo = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    filled = {(x, y) for x in range(width) for y in range(height) if letters.getpixel((x, y))[3] > 0}
    outline = {(x + dx, y + dy) for x, y in filled for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))} - filled
    body = filled | outline
    for x, y in body:
        shadow = (x + SHADOW[0], y + SHADOW[1])
        if shadow not in body and 0 <= shadow[0] < width and 0 <= shadow[1] < height:
            logo.putpixel(shadow, SHADOW_COLOR)
    for x, y in outline:
        if 0 <= x < width and 0 <= y < height:
            logo.putpixel((x, y), OUTLINE)
    for x, y in filled:
        logo.putpixel((x, y), letters.getpixel((x, y)))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    logo.save(OUT)
    print("saved %s (%dx%d)" % (OUT, width, height))


if __name__ == "__main__":
    main()
