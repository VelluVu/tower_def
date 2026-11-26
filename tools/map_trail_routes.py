"""Keeps the world map's dotted trails off water and off the landmark pictures (2026-11-25, the user: a trail over a
lake is not ok; 2026-11-26: round the landmarks too). Landmarks are every AnimatedSprite2D under MapView/Map (the
Landmark_* nodes and the WyrmThrone): their first frame's opaque pixels count as water for the trails.

    python tools/map_trail_routes.py           report the trails whose dots land on water
    python tools/map_trail_routes.py --fix     reroute those: A* over the map art round the water (bridges are not
                                               water, so a route takes one), a few waypoints into the level's
                                               `trail_via` in game_world_map.tscn
    python tools/map_trail_routes.py --fix --all   reroute every trail, not only the wet ones
    python tools/map_trail_routes.py --fix --levels 10,21   reroute these trails (wet or not)
    python tools/map_trail_routes.py --water-only     ignore the landmarks (water alone, as before 2026-11-26)
    python tools/map_trail_routes.py --preview out.png   the map at 2x with every trail's dots (wet ones red)

Mirrors MapTrails (_bowed, _through, the dot spacing and clearance); keep the constants in step with map_trails.gd.
Rerun after moving a node or repainting water.
"""
import heapq
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import tres_edit  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENE = os.path.join(ROOT, "scenes/ui/game_world_map/game_world_map.tscn")
MAP_ART = os.path.join(ROOT, "assets/art/ui/world_map_big.png")
WATER = {(0x00, 0x99, 0xdb), (0x2c, 0xe8, 0xf5), (0x12, 0x4e, 0x89)}
UNITS_PER_PIXEL = 2.0
# map_trails.gd
DOT_SPACING = 12.0
NODE_CLEARANCE = 14.0
BEND = 0.16
SMOOTHING_PASSES = 3
# a dot is wet when water lies this many art pixels round its centre (the dot's fill is 2x2 art pixels)
DOT_REACH = 1
# the route keeps this far from water, and pays extra this far out, so smoothing never cuts back in
BLOCK_RADIUS = 1
SHY_RADIUS = 4
SHY_COST = 2.0
# routes keep clear of other nodes (art pixels) so a trail never runs over a token
NODE_RADIUS = 7
NODE_COST = 12.0
# a trail may cross the landmark of the node it leaves or reaches within this many map units of it
HOME_REACH = 40.0
# the water alone, set by main when landmarks are added to the mask
WATER_MASK = None
HOME_DIST = None


def res_path(path):
    return os.path.join(ROOT, path.replace("res://", ""))


def landmark_pixels(head, sections, size):
    """Art pixels covered by a landmark picture (first frame, alpha > 0), as a set of (x, y)."""
    resources = {}
    for s in sections:
        if s.kind == "ext_resource":
            resources[s.attributes.get("id")] = s.attributes.get("path")
    covered = set()
    for s in sections:
        a = s.attributes
        if s.kind != "node" or a.get("parent") != "MapView/Map" or a.get("type") != "AnimatedSprite2D":
            continue
        frames_ref = s.get("sprite_frames") or ""
        if "ExtResource" not in frames_ref:
            continue
        frames_path = resources.get(frames_ref[frames_ref.index('"') + 1:frames_ref.rindex('"')])
        if not frames_path:
            continue
        frames_head, frames_sections = tres_edit.load(res_path(frames_path))
        sheet = next(f.attributes.get("path") for f in frames_sections if f.kind == "ext_resource")
        atlas = next(f for f in frames_sections if f.kind == "sub_resource" and f.attributes.get("type") == "AtlasTexture")
        rx, ry, rw, rh = [int(float(n)) for n in atlas.get("region")[6:-1].split(",")]
        picture = Image.open(res_path(sheet)).convert("RGBA").crop((rx, ry, rx + rw, ry + rh))
        position = [float(n) for n in (s.get("position") or "Vector2(0, 0)")[8:-1].split(",")]
        scale = [float(n) for n in (s.get("scale") or "Vector2(1, 1)")[8:-1].split(",")]
        if s.get("centered") != "false":
            position = [position[0] - rw * scale[0] / 2.0, position[1] - rh * scale[1] / 2.0]
        alpha = picture.load()
        step = scale[0] / UNITS_PER_PIXEL
        for y in range(rh):
            for x in range(rw):
                if alpha[x, y][3] == 0:
                    continue
                for sy in range(max(1, int(step))):
                    for sx in range(max(1, int(step))):
                        px = int(position[0] / UNITS_PER_PIXEL + x * step) + sx
                        py = int(position[1] / UNITS_PER_PIXEL + y * step) + sy
                        if 0 <= px < size[0] and 0 <= py < size[1]:
                            covered.add((px, py))
    return covered


def load_nodes():
    head, sections = tres_edit.load(SCENE)
    nodes = {}
    for s in sections:
        a = s.attributes
        if s.kind != "node" or a.get("parent") != "MapView/Map" or not a.get("name", "").startswith("Level_"):
            continue
        number = int(s.get("level_number") or 1)
        left, top = float(s.get("offset_left")), float(s.get("offset_top"))
        right, bottom = float(s.get("offset_right")), float(s.get("offset_bottom"))
        nodes[number] = {"section": s, "centre": ((left + right) / 2.0, (top + bottom) / 2.0), "via": parse_via(s.get("trail_via")),
                         "underground": s.get("trail_underground") == "true"}
    return head, sections, nodes


def parse_via(text):
    if not text:
        return []
    numbers = [float(n) for n in text[text.index("(") + 1:text.rindex(")")].split(",") if n.strip()]
    return [(numbers[i], numbers[i + 1]) for i in range(0, len(numbers), 2)]


def bowed(start, end, level):
    length = math.dist(start, end)
    side = 1.0 if level % 2 == 0 else -1.0
    dx, dy = end[0] - start[0], end[1] - start[1]
    # Vector2.orthogonal() is (y, -x)
    ox, oy = dy / max(length, 0.001), -dx / max(length, 0.001)
    control = ((start[0] + end[0]) / 2 + ox * length * BEND * side, (start[1] + end[1]) / 2 + oy * length * BEND * side)
    steps = max(8, int(length / 2.0))
    points = []
    for i in range(steps + 1):
        t = i / steps
        a = lerp(start, control, t)
        b = lerp(control, end, t)
        points.append(lerp(a, b, t))
    return points


def through(start, via, end):
    points = [start] + list(via) + [end]
    for _ in range(SMOOTHING_PASSES):
        smoothed = [points[0]]
        for i in range(len(points) - 1):
            smoothed.append(lerp(points[i], points[i + 1], 0.25))
            smoothed.append(lerp(points[i], points[i + 1], 0.75))
        smoothed.append(points[-1])
        points = smoothed
    return points


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def dots(points):
    total = sum(math.dist(points[i - 1], points[i]) for i in range(1, len(points)))
    last = total - NODE_CLEARANCE
    travelled, next_dot, out = 0.0, NODE_CLEARANCE, []
    for i in range(1, len(points)):
        segment = math.dist(points[i - 1], points[i])
        while next_dot <= travelled + segment and next_dot <= last:
            out.append(lerp(points[i - 1], points[i], (next_dot - travelled) / max(segment, 0.001)))
            next_dot += DOT_SPACING
        travelled += segment
    return out


def trail_points(nodes, level):
    start, end = nodes[level - 1]["centre"], nodes[level]["centre"]
    via = nodes[level]["via"]
    return bowed(start, end, level) if not via else through(start, via, end)


def water_mask(image):
    w, h = image.size
    pixels = image.load()
    return [[pixels[x, y][:3] in WATER for x in range(w)] for y in range(h)]


def distance_to_water(mask):
    """Chebyshev distance (art pixels) from every pixel to the nearest water pixel, capped at SHY_RADIUS + 1."""
    h, w = len(mask), len(mask[0])
    cap = SHY_RADIUS + 1
    dist = [[0 if mask[y][x] else cap for x in range(w)] for y in range(h)]
    for _ in range(cap):
        changed = False
        for y in range(h):
            row = dist[y]
            for x in range(w):
                best = row[x]
                if best == 0:
                    continue
                for dy in (-1, 0, 1):
                    yy = y + dy
                    if 0 <= yy < h:
                        r = dist[yy]
                        for dx in (-1, 0, 1):
                            xx = x + dx
                            if 0 <= xx < w and r[xx] + 1 < best:
                                best = r[xx] + 1
                if best != row[x]:
                    row[x] = best
                    changed = True
        if not changed:
            break
    return dist


def wet_dots(mask, points):
    """Dots on water or a landmark; near the trail's own two nodes only water counts (a node may sit on its landmark)."""
    h, w = len(mask), len(mask[0])
    wet = []
    for d in dots(points):
        px, py = int(d[0] // UNITS_PER_PIXEL), int(d[1] // UNITS_PER_PIXEL)
        home = WATER_MASK is not None and min(math.dist(d, points[0]), math.dist(d, points[-1])) <= HOME_REACH
        check = WATER_MASK if home else mask
        if any(check[y][x] for y in range(max(0, py - DOT_REACH), min(h, py + DOT_REACH + 1))
               for x in range(max(0, px - DOT_REACH), min(w, px + DOT_REACH + 1))):
            wet.append(d)
    return wet


def route(dist, start, end, others):
    """A* in art pixels from start to end (map units), round water; None when there is no dry way."""
    h, w = len(dist), len(dist[0])
    sx, sy = int(start[0] // UNITS_PER_PIXEL), int(start[1] // UNITS_PER_PIXEL)
    ex, ey = int(end[0] // UNITS_PER_PIXEL), int(end[1] // UNITS_PER_PIXEL)
    other_pixels = [(o[0] / UNITS_PER_PIXEL, o[1] / UNITS_PER_PIXEL) for o in others]
    home_reach = HOME_REACH / UNITS_PER_PIXEL

    def cost(x, y):
        d = dist[y][x]
        # a node may sit on the shore, its token over the water: let the route leave and reach it (the dots
        # start NODE_CLEARANCE out, past the token)
        near_end = max(abs(x - sx), abs(y - sy)) <= 6 or max(abs(x - ex), abs(y - ey)) <= 6
        home = HOME_DIST is not None and min(math.hypot(x - sx, y - sy), math.hypot(x - ex, y - ey)) <= home_reach
        if home:
            d = HOME_DIST[y][x]
        if d <= BLOCK_RADIUS and not near_end:
            return None
        c = 1.0 + (SHY_COST * (SHY_RADIUS + 1 - d) / SHY_RADIUS if d <= SHY_RADIUS else 0.0)
        for ox, oy in other_pixels:
            if abs(x - ox) <= NODE_RADIUS and abs(y - oy) <= NODE_RADIUS:
                c += NODE_COST
        return c

    open_heap = [(0.0, 0.0, sx, sy)]
    came = {(sx, sy): None}
    best = {(sx, sy): 0.0}
    steps = [(dx, dy, math.hypot(dx, dy)) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy]
    while open_heap:
        _, g, x, y = heapq.heappop(open_heap)
        if (x, y) == (ex, ey):
            path = []
            at = (x, y)
            while at is not None:
                path.append(at)
                at = came[at]
            return [((px + 0.5) * UNITS_PER_PIXEL, (py + 0.5) * UNITS_PER_PIXEL) for px, py in reversed(path)]
        if g > best.get((x, y), math.inf):
            continue
        for dx, dy, step in steps:
            nx, ny = x + dx, y + dy
            if not (0 <= nx < w and 0 <= ny < h):
                continue
            c = cost(nx, ny)
            if c is None:
                continue
            ng = g + step * c
            if ng < best.get((nx, ny), math.inf):
                best[(nx, ny)] = ng
                came[(nx, ny)] = (x, y)
                heapq.heappush(open_heap, (ng + math.hypot(ex - nx, ey - ny), ng, nx, ny))
    return None


def simplify(points, epsilon):
    """Ramer-Douglas-Peucker."""
    if len(points) < 3:
        return list(points)
    a, b = points[0], points[-1]
    length = max(math.dist(a, b), 0.001)
    far, index = -1.0, 0
    for i in range(1, len(points) - 1):
        p = points[i]
        d = abs((b[0] - a[0]) * (a[1] - p[1]) - (a[0] - p[0]) * (b[1] - a[1])) / length
        if d > far:
            far, index = d, i
    if far <= epsilon:
        return [a, b]
    return simplify(points[:index + 1], epsilon)[:-1] + simplify(points[index:], epsilon)


def reroute(mask, dist, nodes, level):
    start, end = nodes[level - 1]["centre"], nodes[level]["centre"]
    others = [n["centre"] for number, n in nodes.items() if number not in (level, level - 1)]
    path = route(dist, start, end, others)
    if path is None:
        return None
    for epsilon in (8.0, 6.0, 4.0, 3.0, 2.0):
        waypoints = simplify(path, epsilon)[1:-1]
        if not waypoints:
            # no via means the bowed default, not a straight line: keep one point on the route
            waypoints = [path[len(path) // 2]]
        via = [(round(x / UNITS_PER_PIXEL) * UNITS_PER_PIXEL, round(y / UNITS_PER_PIXEL) * UNITS_PER_PIXEL) for x, y in waypoints]
        if not wet_dots(mask, through(start, via, end)):
            return via
    return None


def via_text(via):
    return "PackedVector2Array(%s)" % ", ".join("%g, %g" % p for p in via)


def preview(image, mask, nodes, path):
    big = image.convert("RGB").resize((image.size[0] * 2, image.size[1] * 2), Image.NEAREST)
    draw = ImageDraw.Draw(big)
    for level in sorted(nodes):
        if level - 1 not in nodes:
            continue
        points = trail_points(nodes, level)
        wet = set() if nodes[level]["underground"] else set(wet_dots(mask, points))
        for d in dots(points):
            colour = (255, 0, 0) if d in wet else (24, 20, 37) if nodes[level]["underground"] else (255, 255, 255)
            draw.rectangle([d[0] - 3, d[1] - 3, d[0] + 3, d[1] + 3], fill=(62, 39, 49))
            draw.rectangle([d[0] - 2, d[1] - 2, d[0] + 1, d[1] + 1], fill=colour)
    for n in nodes.values():
        c = n["centre"]
        draw.ellipse([c[0] - 10, c[1] - 10, c[0] + 10, c[1] + 10], outline=(255, 220, 0), width=2)
    big.save(path)


def main(args):
    image = Image.open(MAP_ART).convert("RGBA")
    mask = water_mask(image)
    head, sections, nodes = load_nodes()
    global WATER_MASK, HOME_DIST
    if "--water-only" not in args:
        WATER_MASK = [row[:] for row in mask]
        for px, py in landmark_pixels(head, sections, image.size):
            mask[py][px] = True
    # underground trails (MapLevelElement.trail_underground) pass under water by design
    wet_levels = [level for level in sorted(nodes) if level - 1 in nodes and not nodes[level]["underground"]
                  and wet_dots(mask, trail_points(nodes, level))]
    if "--preview" in args:
        preview(image, mask, nodes, args[args.index("--preview") + 1])
    if "--fix" not in args:
        for level in wet_levels:
            print("level %d: %d dots on water or a landmark" % (level, len(wet_dots(mask, trail_points(nodes, level)))))
        print("%d trails cross water or a landmark" % len(wet_levels))
        return
    dist = distance_to_water(mask)
    if WATER_MASK is not None:
        HOME_DIST = distance_to_water(WATER_MASK)
    targets = [level for level in sorted(nodes) if level - 1 in nodes] if "--all" in args else wet_levels
    if "--levels" in args:
        targets = [int(n) for n in args[args.index("--levels") + 1].split(",")]
    changed, failed = 0, []
    for level in targets:
        via = reroute(mask, dist, nodes, level)
        if via is None:
            failed.append(level)
            continue
        nodes[level]["via"] = via
        nodes[level]["section"].set("trail_via", via_text(via))
        changed += 1
        print("level %d: %s" % (level, via_text(via)))
    tres_edit.save(SCENE, head, sections)
    print("%d trails rerouted" % changed)
    if failed:
        print("no dry route for levels: %s (needs a bridge or a moved node)" % ", ".join(map(str, failed)))


if __name__ == "__main__":
    main(sys.argv[1:])
