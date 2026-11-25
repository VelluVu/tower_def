#!/usr/bin/env python3
"""The Ashen Wyrm's volcano throne on the world map (2026-11-25, the user: the last boss needs a huge landmark).

    python tools/art/wyrm_throne.py [--preview <out.png>]

A tall black volcano on the island inside the lava loop, drawn like the map's other rock (seen from above, flat lit
ledges in TERRACE steps, dark south faces), lava cracks running down its front, the crater glowing, and the Ashen
Wyrm coiled round the rim: folded red wings, ash grey body, its head over the front rim with glowing eyes. Smoke
and embers rise; the eyes blink. Writes assets/art/ui/map_landmarks/wyrm_throne.txt/.aseprite/.png (IDLE, FRAMES
frames) and scenes/ui/game_world_map/frames/wyrm_throne_frames.tres. The map shows it as an AnimatedSprite2D at 2x
(WyrmThrone in game_world_map.tscn, under the fog, the trails and the nodes); FOOT is the canvas pixel at art
pixel (478, 162) of world_map_big.png, inside the loop of volcano levels, level 60's node at its south west foot.
"""
import math
import os
import sys
import zlib
from pathlib import Path

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hoard_backdrop as hb  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
hb.ART = ROOT / "assets" / "art" / "ui" / "map_landmarks"
hb.FRAMES = ROOT / "scenes" / "ui" / "game_world_map" / "frames"
NAME = "wyrm_throne"
W, H = 84, 92
FRAMES = 8
FRAME_MS = 150

# the volcano's ground footprint (canvas px): centre x, south edge, half width; its height, the crater's share
CX, SOUTH, HALF = 42, 89, 34
RY = HALF * 0.4
CY = SOUTH - RY
HEIGHT = 32
TERRACE = 7
# the ledges wander up and down round the cone by this much (px), so they never read as rings
LEDGE_WANDER = 3.0
CRATER = 0.3
CRATER_DEPTH = 3
# the coil lies on the rim at one height, so it reads as one smooth body
RIM_HEIGHT = HEIGHT - 3
FOOT = (CX, SOUTH)

hb.C.update({
    "v0": "181425", "v1": "262b44", "v2": "3a4466", "v3": "5a6988", "v4": "8b9bb4",
    "l0": "5d1d2c", "l1": "a22633", "l2": "e43b44", "l3": "f77622", "l4": "feae34", "l5": "fee761",
    # the Ashen Wyrm's own colours (its sprite): ash body, dark red wings
    "w0": "2a2028", "w1": "5e5458", "w2": "847a80", "w3": "a89ea4", "w4": "ece6d8",
    "wing0": "3e2731", "wing1": "5d1d2c", "wing2": "74202e", "wing3": "a22633",
})
FACES = ["v2", "v1", "v1", "v0", "v0"]


def rnd(*key):
    return (zlib.crc32(repr(key).encode()) % 10007) / 10007.0


def elevation(x, y):
    """the cone's height at a ground point, None off the footprint; the crater a bowl in its top"""
    angle = math.atan2(y - CY, x - CX)
    wobble = 1.0 + 0.06 * math.sin(angle * 5 + 1.3) + 0.04 * math.sin(angle * 9 + 0.4)
    r = math.hypot((x - CX) / HALF, (y - CY) / RY) / wobble
    if r >= 1.0:
        return None, r
    if r < CRATER:
        return HEIGHT - CRATER_DEPTH, r
    t = (r - CRATER) / (1.0 - CRATER)
    return HEIGHT * (1.0 - t) ** 1.9, r


def terraced(x, y, e, r):
    """the drawn height: whole TERRACE steps whose edges wander round the cone; the crater floor just below the rim"""
    if r < CRATER:
        return HEIGHT - CRATER_DEPTH
    angle = math.atan2(y - CY, x - CX)
    wander = LEDGE_WANDER * (math.sin(angle * 3 + 0.7) + 0.6 * math.sin(angle * 7 + 2.1))
    return max(2, int(TERRACE * round((e + wander) / TERRACE) - wander * 0.5) + 2)


def ground_to_screen(x, y, e):
    return x, y - e


def draw_volcano(cv):
    """back to front, every ground point a column from the ground up to its (terraced) height, like rock_mass"""
    cells = {}
    for y in range(int(CY - RY - 2), SOUTH + 1):
        for x in range(int(CX - HALF - 4), int(CX + HALF + 5)):
            e, r = elevation(x, y)
            if e is not None:
                cells[(x, y)] = (e, r)
    drawn = {}
    for (x, y) in sorted(cells, key=lambda p: p[1]):
        e, r = cells[(x, y)]
        crater = r < CRATER
        e = terraced(x, y, e, r)
        top = y - e
        for k in range(e, 0, -1):
            depth = e - k
            drawn[(x, y - k + 1)] = ("face", depth, e)
        drawn[(x, top)] = ("crater", r, e) if crater else ("top", r, e)
    tops = {p for p, v in drawn.items() if v[0] == "top"}
    for (x, y), (kind, a, e) in drawn.items():
        if kind == "face":
            colour = FACES[min(len(FACES) - 1, a * len(FACES) // max(6, e // 2))]
            if rnd(x, y, "ash streak") < 0.04 and colour == "v1":
                colour = "v2"
        elif kind == "top":
            # lit ledges, the west rim of each ledge in shadow, ash specks near the summit
            colour = "v3" if e > HEIGHT * 0.3 else "v2"
            if (x - 1, y) not in tops and (x - 1, y) in drawn:
                colour = "v2"
            elif x > CX + HALF * 0.35 and rnd(x // 2, y, "east") < 0.5:
                colour = "v2"
            elif e <= HEIGHT * 0.3 and rnd(x // 2, y, "low") < 0.25:
                colour = "v1"
            elif a < 0.45 and rnd(x, y, "ash") < 0.12:
                colour = "v4"
        else:
            colour = "l0"
        cv.put(x, y, colour)
    return drawn


def crater_glow(cv, frame):
    """the molten floor of the crater, pulsing; only where the crater floor shows"""
    top = SOUTH - RY - (HEIGHT - CRATER_DEPTH)
    pulse = 0.5 + 0.5 * math.sin(frame / FRAMES * math.tau)
    for y in range(H):
        for x in range(W):
            if cv.get(x, y) != "l0":
                continue
            d = math.hypot((x - CX) / (HALF * CRATER), (y - top) / (RY * CRATER))
            heat = 1.0 - d + pulse * 0.25 + (rnd(x, y, frame // 2, "bubble") - 0.5) * 0.3
            cv.put(x, y, "l5" if heat > 0.95 else "l4" if heat > 0.7 else "l3" if heat > 0.45 else "l2" if heat > 0.2 else "l1")


CRACKS = [(-2.05, 0.92, 3), (-1.35, 0.97, 7), (-0.7, 0.8, 2)]


def lava_cracks(cv, frame):
    """lava running from the rim down the front (south) slope, a bright bead sliding down each"""
    for i, (angle, reach, phase) in enumerate(CRACKS):
        angle = -angle  # canvas y grows south: positive angles face the viewer
        points = []
        steps = 40
        for s in range(steps + 1):
            r = CRATER + 0.03 + (reach - CRATER) * s / steps
            a = angle + 0.07 * math.sin(s * 0.35 + phase)
            gx, gy = CX + math.cos(a) * r * HALF, CY + math.sin(a) * r * RY
            e, _ = elevation(gx, gy)
            if e is None:
                break
            e = terraced(gx, gy, e, r)
            sx, sy = round(gx), round(gy - e)
            if points and points[-1] != (sx, sy):
                # down a ledge's face: a straight fall, so the crack stays one stream
                px, py = points[-1]
                for k in range(1, max(abs(sx - px), abs(sy - py)) + 1):
                    n = max(abs(sx - px), abs(sy - py))
                    points.append((round(px + (sx - px) * k / n), round(py + (sy - py) * k / n)))
            elif not points:
                points.append((sx, sy))
        bead = (frame * 3 + phase * 4) % max(1, len(points))
        for k, (x, y) in enumerate(points):
            if cv.get(x, y) is None:
                continue
            colour = "l2" if k < len(points) * 0.6 else "l1"
            if abs(k - bead) <= 1:
                colour = "l4" if k == bead else "l3"
            cv.put(x, y, colour)
            if k < len(points) * 0.35 and cv.get(x + 1, y) not in (None, "l2", "l3", "l4"):
                cv.put(x + 1, y, "l1")


def ring_point(t, grow=0.0):
    """a point on the crater rim (screen), t in radians (0 east, pi/2 south, toward the viewer)"""
    r = CRATER + 0.04 + grow
    gx, gy = CX + math.cos(t) * r * HALF, CY + math.sin(t) * r * RY
    return gx, gy - RIM_HEIGHT


# the left wing, raised and half folded: the arm (A, its shadow a) up the inner edge to the wrist claw (c), the
# membrane (m) hanging to a scalloped outer edge, finger bones (f); its shoulder is the bottom right pixel
WING = [
    ".......c........",
    "......cA........",
    ".....mAa........",
    "....mmAa........",
    "...mmfAa........",
    "..mmmfAa........",
    ".mmmfmmAa.......",
    ".mmmfmmAa.......",
    "mmmfmmmmAa......",
    "mmmfmmmmAa......",
    ".mmfmmmmmAa.....",
    "..mmfmmmmAa.....",
    ".mmmfmmmmmAa....",
    "mmmmfmmmmmAa....",
    ".mmmmfmmmmmAa...",
    "..mmmfmmmmmAa...",
    "...mmmfmmmmmAa..",
    "..mmmmfmmmmmmAa.",
    "...mmmmmmmmmmmAa",
    "....mmmmmmmmmmmA",
]
WING_COLOURS = {
    -1: {"c": "w4", "A": "w3", "a": "w1", "m": "wing1", "f": "wing0"},
    1: {"c": "w4", "A": "w2", "a": "w1", "m": "wing0", "f": "w0"},
}


def wings(cv, frame):
    """the wings raised behind the crater from the back of the coil; they lift a pixel as it breathes"""
    lift = 1 if frame in (2, 3, 4) else 0
    rows, cols = len(WING), len(WING[0])
    for side in (-1, 1):
        sx, sy = ring_point(-math.pi / 2 + side * 0.75)
        sx, sy = round(sx), round(sy) - lift
        for row, text in enumerate(WING):
            for col, ch in enumerate(text):
                if ch == ".":
                    continue
                colour = WING_COLOURS[side][ch]
                if ch == "m" and rnd(col, row, side, "vein") < 0.06:
                    colour = WING_COLOURS[side]["f"]
                x = sx - (cols - 1 - col) if side < 0 else sx + (cols - 1 - col)
                cv.put(x, sy - (rows - 1 - row), colour)


# the coil runs from the head's west side round the back to the east rim, where the tail spills down; the front east
# arc stays open so the crater glows through and the body reads as a creature, not a ring
COIL_FROM = math.pi / 2 + 0.6
COIL_TO = math.tau + 0.15


def body(cv, frame, front):
    """the coil on the rim, thick at the shoulders and thinner toward the tail, lit on top, a dark belly line against
    the rock; the back half (front False) goes under the crater's front rim"""
    steps = 180
    for k in range(steps + 1):
        share = k / steps
        t = COIL_FROM + (COIL_TO - COIL_FROM) * share
        south = math.sin(t) > 0
        if south != front:
            continue
        x, y = ring_point(t)
        x, y = round(x), round(y)
        thick = 5 if share < 0.3 else 4 if share < 0.7 else 3
        lit = math.cos(t + 0.6) < 0.2
        for o in range(thick):
            colour = ("w3" if lit else "w2") if o == 0 else "w1" if o == thick - 1 else "w2"
            if o == 1 and k % 7 == 0:
                colour = "w1"  # scale bands
            cv.put(x, y - thick + 2 + o, colour)
        if front:
            cv.put(x, y + 2, "w0")
        if k % 9 == 0 and share < 0.9:  # spine ridges
            cv.put(x, y - thick + 1, "wing3")


def tail(cv):
    """the tail spilling off the east rim and down the slope, tapering"""
    sx, sy = ring_point(0.15)
    points = [(sx, sy)]
    for s in range(1, 26):
        r = CRATER + 0.05 + s * 0.025
        a = 0.15 + s * 0.045
        gx, gy = CX + math.cos(a) * r * HALF, CY + math.sin(a) * r * RY
        e, _ = elevation(gx, gy)
        if e is None:
            break
        points.append((gx, gy - terraced(gx, gy, e, r) - 1))
    for i, (x, y) in enumerate(points):
        w = 2 if i < len(points) * 0.6 else 1
        for o in range(w):
            cv.put(round(x), round(y) + o, "w2" if o == 0 else "w1")
        if i % 4 == 0 and i < len(points) - 3:
            cv.put(round(x), round(y) - 1, "wing2")
    ex, ey = points[-1]
    cv.put(round(ex) + 1, round(ey) + 1, "wing3")  # the tail spade
    cv.put(round(ex) + 2, round(ey) + 1, "wing2")


def head(cv, frame):
    """the head over the front rim, facing the viewer a little to the west (toward the trail), eyes glowing"""
    nx, ny = ring_point(math.pi / 2 + 0.1)
    hx, hy = round(nx) - 2, round(ny) + 2
    shape = [
        "..h.......h..",
        "..hh.....hh..",
        "...bbbbbbb...",
        "..bBBBBBBBb..",
        ".bBBeBBBeBBb.",
        ".bBBBBBBBBBb.",
        "..bBBBBBBBb..",
        "...bbSSSbb...",
        "....bsssb....",
        ".....bbb.....",
    ]
    colours = {"h": "w4", "b": "w1", "B": "w2", "S": "w3", "s": "w2", "e": "l5"}
    blink = frame == 5
    for row, line_text in enumerate(shape):
        for col, ch in enumerate(line_text):
            if ch == ".":
                continue
            colour = colours[ch]
            if ch == "e":
                colour = "w0" if blink else ("l5" if frame % 4 else "l4")
            elif ch == "B" and col < 6 and row < 6:
                colour = "w3" if row in (3, 4) and col in (3, 4) else "w2"
            cv.put(hx - 6 + col, hy - 6 + row, colour)
    if not blink:  # the eyes' glow on the snout below them
        cv.put(hx - 2, hy - 1, "l3")
        cv.put(hx + 2, hy - 1, "l3")
    # nostril smoke wisp now and then
    if frame in (1, 2):
        cv.put(hx - 1, hy + 4 - frame, "v3")
        cv.put(hx + 1, hy + 3 - frame, "v3")


def smoke(cv, frame):
    """a column of puffs rising from the crater behind the wyrm, growing, drifting east and thinning out at the top"""
    base_x, base_y = ring_point(-math.pi / 2, -0.15)
    puffs = 8
    for p in range(puffs):
        age = ((frame / FRAMES) + p / puffs) % 1.0
        cx = base_x + 2 + age * 12 + math.sin(p * 2.1) * 2
        cy = base_y - 2 - age * 30
        r = 3.0 + age * 4.5
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                d = math.hypot(x - cx, (y - cy) * 1.2)
                if d > r:
                    continue
                if age > 0.65 and (x + y) % 2:
                    continue
                if cv.get(x, y) not in (None, "v2", "v3", "v4"):
                    continue
                if cv.get(x, y) == "v4" and d > r * 0.45:
                    continue  # a puff in front keeps its lit core
                cv.put(x, y, "v4" if d < r * 0.45 and y < cy else "v3" if d < r * 0.8 else "v2")


def embers(cv, frame):
    base_x, base_y = ring_point(-math.pi / 2, -0.1)
    for e in range(6):
        age = (frame + e * 1.7) % FRAMES / FRAMES
        x = round(base_x + (rnd(e, "ex") - 0.5) * 18 + math.sin(age * 6 + e) * 2)
        y = round(base_y - 2 - age * 20 - rnd(e, "ey") * 4)
        if cv.get(x, y) is None or cv.get(x, y).startswith("v"):
            cv.put(x, y, "l4" if age < 0.5 else "l3")


def foot_glow(cv, frame):
    """lava pooling where the cracks reach the foot, merging into the lava round the island"""
    for i, (angle, reach, phase) in enumerate(CRACKS):
        if reach < 0.85:
            continue
        a = -angle
        gx, gy = CX + math.cos(a) * 0.98 * HALF, CY + math.sin(a) * 0.98 * RY
        for dx in range(-2, 3):
            cv.put(round(gx) + dx, round(gy), "l2" if abs(dx) < 2 else "l1")
        cv.put(round(gx) + (frame % 3) - 1, round(gy), "l3")


def fill_polygon(cv, points, colour_at):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    for y in range(int(min(ys)), int(max(ys)) + 1):
        for x in range(int(min(xs)), int(max(xs)) + 1):
            if inside(points, x + 0.5, y + 0.5):
                cv.put(x, y, colour_at(x, y))


def inside(points, x, y):
    result = False
    j = len(points) - 1
    for i in range(len(points)):
        xi, yi = points[i]
        xj, yj = points[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            result = not result
        j = i
    return result


def line(cv, x0, y0, x1, y1, colour):
    steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for s in range(steps + 1):
        cv.put(round(x0 + (x1 - x0) * s / steps), round(y0 + (y1 - y0) * s / steps), colour)


def frame_canvas(frame):
    cv = hb.Canvas(W, H)
    smoke(cv, frame)
    wings(cv, frame)
    draw_volcano(cv)
    crater_glow(cv, frame)
    lava_cracks(cv, frame)
    foot_glow(cv, frame)
    body(cv, frame, front=False)
    body(cv, frame, front=True)
    tail(cv)
    head(cv, frame)
    embers(cv, frame)
    return cv


def main(argv):
    frames = [frame_canvas(f) for f in range(FRAMES)]
    if "--preview" in argv:
        out = argv[argv.index("--preview") + 1]
        sheet = Image.new("RGBA", ((W + 4) * 4, (H + 4) * 2), (0xa2, 0x26, 0x33, 255))
        for i, cv in enumerate(frames):
            sheet.alpha_composite(cv.image(), ((i % 4) * (W + 4), (i // 4) * (H + 4)))
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out)
        return 0
    hb.ART.mkdir(parents=True, exist_ok=True)
    hb.FRAMES.mkdir(parents=True, exist_ok=True)
    note = "Generated by tools/art/wyrm_throne.py (the Ashen Wyrm's volcano on the world map); edit that and rerun."
    tags = [("IDLE", FRAME_MS, FRAMES)]
    hb.build(NAME, frames, (W, H), tags, note)
    hb.write_sprite_frames(NAME, W, H, FRAMES, tags)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
