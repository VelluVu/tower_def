#!/usr/bin/env python3
"""Draws the hit effects: what a tower's hit looks like on an enemy, per element and tower kind.

    python tools/art/hit_effects.py

Writes assets/art/effects/hits/:
  <element>_burst.png  4 frames of 16x16  a projectile's impact (Bolter)
  <element>_spark.png  3 frames of 8x8    a beam tick, a Nova burst, splash (small, frequent)
  <element>_claw.png   3 frames of 16x16  a trap's strike: three slashes
  <element>_cast.png   3 frames of 8x8    a tower's mouth flashing as it fires (Bolter, Nova)
  <element>_death.png  4 frames of 16x16  an enemy killed by Fire, Frost or Poison (burns up, shatters, gasses)
  crit_star.png        3 frames of 16x16  over any critical hit
Elements: physical (white steel rays), fire (fireball and embers), frost (ice shards), poison
(a splat and droplets). Each frame is drawn from simple shapes; the last frames break up with
an ordered dither so effects thin out instead of fading. Endesga 32 colours.
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "effects" / "hits"

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
DARK = "181425"

# light to dark: core, bright, mid, dark
PALETTES = {
    "physical": ["ffffff", "c0cbdc", "8b9bb4", "5a6988"],
    "fire": ["fff6c8", "fee761", "f77622", "be4a2f"],
    "frost": ["ffffff", "2ce8f5", "0099db", "124e89"],
    "poison": ["c7f0a0", "63c74d", "3e8948", "265c42"],
}


def rgba(hex_colour):
    return tuple(int(hex_colour[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class Frame:
    """One frame being drawn: later shapes go over earlier ones; keep (0-16) thins it with the dither."""

    def __init__(self, size, keep=16):
        self.size = size
        self.keep = keep
        self.pixels = {}

    def put(self, x, y, colour):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.size and 0 <= y < self.size:
            self.pixels[(x, y)] = colour

    def disc(self, cx, cy, r, colours):
        """A ball lit from the top left: colours light to dark by how far round the far side a pixel is."""
        for y in range(self.size):
            for x in range(self.size):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                distance = math.hypot(dx, dy)
                if distance > r:
                    continue
                side = (dx + dy) / max(r, 0.01)
                index = 0 if side < -0.6 else 1 if side < 0.1 else 2 if side < 0.7 else 3
                self.put(x, y, colours[min(index, len(colours) - 1)])

    def ray(self, cx, cy, angle, start, end, colour):
        steps = int((end - start) * 2) + 1
        for i in range(steps):
            distance = start + (end - start) * i / max(steps - 1, 1)
            self.put(cx + math.cos(angle) * distance - 0.5, cy + math.sin(angle) * distance - 0.5, colour)

    def diamond(self, cx, cy, r, colour, core=None):
        for y in range(self.size):
            for x in range(self.size):
                d = abs(x + 0.5 - cx) + abs(y + 0.5 - cy)
                if d <= r:
                    self.put(x, y, core if core and d <= r * 0.45 else colour)

    def save_into(self, sheet, ox):
        for (x, y), colour in self.pixels.items():
            if BAYER[y % 4][x % 4] >= self.keep:
                continue
            sheet.putpixel((ox + x, y), rgba(colour))


def outlined(frame):
    """A dark 1 px rim round the shape, so it reads on any ground."""
    filled = set(frame.pixels)
    for (x, y) in list(filled):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in filled and 0 <= n[0] < frame.size and 0 <= n[1] < frame.size:
                frame.pixels[n] = DARK
    return frame


def burst_frames(element, p):
    c = 8
    frames = []
    if element == "physical":
        f = Frame(16); f.diamond(c, c, 2.2, p[1], p[0]); frames.append(outlined(f))
        f = Frame(16)
        for i in range(8):
            f.ray(c, c, i * math.pi / 4, 1, 5 if i % 2 == 0 else 3.5, p[1] if i % 2 else p[0])
        f.diamond(c, c, 1.6, p[0]); frames.append(outlined(f))
        f = Frame(16)
        for i in range(8):
            f.ray(c, c, i * math.pi / 4 + 0.2, 4, 7 if i % 2 == 0 else 5.5, p[1] if i % 2 else p[0])
        #no rim: the flying sparks are thin, a rim would turn them into a dark ring
        frames.append(f)
        f = Frame(16, keep=8)
        for i in range(0, 8, 2):
            f.ray(c, c, i * math.pi / 4 + 0.3, 6, 7.5, p[2])
        frames.append(f)
    elif element == "fire":
        f = Frame(16); f.disc(c, c, 2.5, [p[0], p[0], p[1], p[2]]); frames.append(outlined(f))
        f = Frame(16); f.disc(c, c, 4.2, p); f.disc(c - 0.5, c - 0.5, 2.0, [p[0], p[0], p[1], p[1]]); frames.append(outlined(f))
        f = Frame(16)
        f.disc(c, c + 0.5, 4.6, [p[1], p[2], p[2], p[3]])
        for x, y, r in ((c - 2, c - 4, 2.2), (c + 2, c - 5, 1.8), (c, c - 6.5, 1.4)):
            f.disc(x, y, r, [p[1], p[1], p[2], p[3]])
        frames.append(outlined(f))
        f = Frame(16, keep=9)
        f.disc(c, c - 1, 3.6, [p[2], p[2], p[3], p[3]])
        for x, y in ((c - 4, c - 6), (c + 3, c - 7), (c + 5, c - 3), (c - 1, c - 9)):
            f.put(x, y, p[1]); f.put(x, y + 1, p[2])
        frames.append(f)
    elif element == "frost":
        f = Frame(16); f.diamond(c, c, 2.5, p[1], p[0]); frames.append(outlined(f))
        f = Frame(16)
        for angle in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
            f.ray(c, c, angle, 1, 6, p[1])
        for angle in (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4):
            f.ray(c, c, angle, 1, 3.5, p[2])
        f.diamond(c, c, 2.0, p[1], p[0]); frames.append(outlined(f))
        f = Frame(16)
        for i in range(6):
            angle = i * math.pi / 3 + 0.3
            f.diamond(c + math.cos(angle) * 5, c + math.sin(angle) * 5, 1.4, p[1], p[0])
        frames.append(outlined(f))
        f = Frame(16, keep=8)
        for i in range(6):
            angle = i * math.pi / 3 + 0.5
            f.diamond(c + math.cos(angle) * 6.8, c + math.sin(angle) * 6.8, 1.0, p[2])
        frames.append(f)
    else:  # poison
        f = Frame(16); f.disc(c, c, 2.6, p); frames.append(outlined(f))
        f = Frame(16)
        f.disc(c, c, 3.4, p)
        for i in range(5):
            angle = i * 2 * math.pi / 5 - math.pi / 2
            f.disc(c + math.cos(angle) * 5, c + math.sin(angle) * 5, 1.3, [p[0], p[1], p[2], p[2]])
        frames.append(outlined(f))
        f = Frame(16)
        f.disc(c, c + 1, 3.0, [p[2], p[2], p[3], p[3]])
        for i in range(5):
            angle = i * 2 * math.pi / 5 - math.pi / 2 + 0.3
            f.disc(c + math.cos(angle) * 6.5, c + math.sin(angle) * 6.5 + 1, 1.1, [p[1], p[1], p[2], p[2]])
        frames.append(outlined(f))
        f = Frame(16, keep=8)
        f.disc(c, c + 2, 3.0, [p[2], p[3], p[3], p[3]])
        for x, y in ((c - 6, c + 4), (c + 6, c + 3), (c - 3, c + 6), (c + 4, c + 6)):
            f.put(x, y, p[1])
        frames.append(f)
    return frames


def spark_frames(p):
    c = 4
    f0 = Frame(8); f0.diamond(c, c, 1.6, p[1], p[0]); outlined(f0)
    #a 2x2 core and four diagonal sparks, exact pixels (rounded angles drew stray shapes), no rim
    f1 = Frame(8)
    for x, y in ((1, 1), (6, 1), (1, 6), (6, 6)):
        f1.put(x, y, p[1])
    for x, y in ((3, 3), (4, 3), (3, 4), (4, 4)):
        f1.put(x, y, p[0])
    f2 = Frame(8, keep=10)
    for i in range(4):
        angle = i * math.pi / 2 + math.pi / 4
        f2.put(c + math.cos(angle) * 3.4 - 0.5, c + math.sin(angle) * 3.4 - 0.5, p[2])
    return [f0, f1, f2]


def claw_frames(p):
    frames = []
    for index, (length, keep, colour, core) in enumerate(((0.55, 16, p[1], p[0]), (1.0, 16, p[1], p[0]), (1.0, 8, p[2], p[2]))):
        f = Frame(16, keep=keep)
        for offset in (-4, 0, 4):
            x0, y0 = 3 + offset, 3
            for t in range(int(10 * length) + 1):
                x, y = x0 + t, y0 + t
                f.put(x, y, core if index < 2 and 2 < t < 8 else colour)
                f.put(x + 1, y, colour)
        frames.append(outlined(f) if index < 2 else f)
    return frames


def crit_frames():
    gold, light, white = "feae34", "fee761", "ffffff"
    frames = []
    for length, keep in ((3.5, 16), (6.5, 16), (7.5, 8)):
        f = Frame(16, keep=keep)
        for angle in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
            f.ray(8, 8, angle, 0, length, light)
        for angle in (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4):
            f.ray(8, 8, angle, 0, length * 0.45, gold)
        f.diamond(8, 8, 1.2, white)
        frames.append(outlined(f) if keep == 16 else f)
    return frames


def cast_frames(p):
    """A tower's mouth flashing as it fires: a bright ball, a ring round a core, the ring breaking up."""
    c = 4
    f0 = Frame(8); f0.disc(c, c, 2.6, [p[0], p[0], p[1], p[1]]); outlined(f0)
    f1 = Frame(8)
    for y in range(8):
        for x in range(8):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
            if 2.4 <= d <= 3.6:
                f1.put(x, y, p[1])
    f1.put(3, 3, p[0]); f1.put(4, 3, p[0]); f1.put(3, 4, p[0]); f1.put(4, 4, p[0])
    f2 = Frame(8, keep=8)
    for y in range(8):
        for x in range(8):
            if 3.2 <= math.hypot(x + 0.5 - c, y + 0.5 - c) <= 4.2:
                f2.put(x, y, p[2])
    return [f0, f1, f2]


def death_frames(element, p):
    """How an enemy killed by an element goes: burns up, shatters, or melts into gas. None for physical."""
    c = 8
    frames = []
    if element == "fire":
        for heights, keep in (((3, 5, 3), 16), ((5, 8, 6), 16), ((4, 6, 5), 12)):
            f = Frame(16, keep=keep)
            for column, height in zip((c - 3, c, c + 3), heights):
                for t in range(height):
                    colour = p[0] if t > height - 3 else p[1] if t > height / 2 else p[2]
                    f.put(column, 13 - t, colour); f.put(column + 1, 13 - t, p[2] if t < 2 else colour)
            if keep == 12:
                for x, y in ((c - 5, 4), (c + 4, 3), (c, 2), (c + 6, 6)):
                    f.put(x, y, p[1])
            frames.append(outlined(f) if keep == 16 else f)
        f = Frame(16, keep=7)
        for x, y in ((c - 4, 2), (c + 3, 1), (c - 1, 4), (c + 5, 5), (c - 6, 7)):
            f.put(x, y, p[1]); f.put(x, y + 1, p[3])
        f.disc(c, 13, 3.0, ["5a6988", "3a4466", "3a4466", "262b44"])
        frames.append(f)
    elif element == "frost":
        f = Frame(16); f.diamond(c, c + 1, 5.5, p[1], p[0]); frames.append(outlined(f))
        f = Frame(16)
        for dx, dy in ((-3, -2), (3, -2), (-3, 3), (3, 3)):
            f.diamond(c + dx, c + 1 + dy, 2.6, p[1], p[0])
        frames.append(outlined(f))
        f = Frame(16)
        for dx, dy in ((-5, 0), (5, 1), (-4, 6), (4, 6), (0, 3)):
            f.diamond(c + dx, c + 1 + dy, 1.8, p[1], p[0])
        frames.append(outlined(f))
        f = Frame(16, keep=8)
        for dx, dy in ((-6, 5), (6, 6), (-3, 7), (3, 7), (0, 6)):
            f.diamond(c + dx, c + 1 + dy, 1.0, p[2])
        frames.append(f)
    elif element == "poison":
        gas = [p[0], p[1], p[2], p[3]]
        f = Frame(16); f.disc(c, c + 3, 3.0, gas); frames.append(outlined(f))
        f = Frame(16)
        for x, y, r in ((c, c + 1, 3.6), (c - 3, c + 3, 2.6), (c + 3, c + 3, 2.6)):
            f.disc(x, y, r, gas)
        frames.append(outlined(f))
        #the cloud keeps a light core and its rim one frame longer: green gas on grass needs both to show
        f = Frame(16)
        for x, y, r in ((c, c - 1, 4.2), (c - 4, c + 1, 3.0), (c + 4, c + 1, 3.0)):
            f.disc(x, y, r, gas)
        frames.append(outlined(f))
        f = Frame(16, keep=7)
        for x, y, r in ((c, c - 3, 4.6), (c - 4, c - 1, 3.2), (c + 4, c - 1, 3.2)):
            f.disc(x, y, r, [p[0], p[1], p[1], p[2]])
        frames.append(f)
    return frames


def save(frames, size, name):
    sheet = Image.new("RGBA", (size * len(frames), size), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        frame.save_into(sheet, index * size)
    sheet.save(OUT / name)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for element, palette in PALETTES.items():
        save(burst_frames(element, palette), 16, "%s_burst.png" % element)
        save(spark_frames(palette), 8, "%s_spark.png" % element)
        save(claw_frames(palette), 16, "%s_claw.png" % element)
        save(cast_frames(palette), 8, "%s_cast.png" % element)
        if element != "physical":
            save(death_frames(element, palette), 16, "%s_death.png" % element)
    save(crit_frames(), 16, "crit_star.png")
    print("saved hit effects to %s" % OUT)


if __name__ == "__main__":
    main()
