"""Draw a talent tree's layout to a PNG, in the menu's manner (no labels): links, then the nodes by kind.

    python tools/talent_preview.py <tree> <out.png> [--mark id,id,...] [--scale N]

<tree> is building, fire, frost or poison (scenes/talents/trees/<tree>_tree.tres). Stat nodes are squares, side nodes
small squares, evolve (tier) nodes diamonds, capstones big circles, the start a ringed circle; one-way links are
drawn thinner. --mark rings the given node ids (or every id with a prefix ending in *) in white, to show new nodes.
Used to check a layout before handing it over (the user judges layouts by eye).
"""
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

TREES = Path(__file__).resolve().parent.parent / "scenes" / "talents" / "trees"
STAT, SIDE, EVOLVE, CAPSTONE = 0, 1, 2, 3


def load(tree_id):
    text = (TREES / f"{tree_id}_tree.tres").read_text(encoding="utf-8")
    nodes = {}
    for m in re.finditer(r'\[sub_resource type="Resource" id="Node_\w+"\]\n(.*?)(?=\n\[|\Z)', text, re.S):
        body = m[1]
        nid = re.search(r'^id = &"(\w+)"', body, re.M)[1]
        pos = re.search(r"^position = Vector2\(([-\d.]+), ([-\d.]+)\)", body, re.M)
        col = re.search(r"^color = Color\(([\d.]+), ([\d.]+), ([\d.]+)", body, re.M)
        kind = re.search(r"^kind = (\d+)", body, re.M)
        links = re.search(r"^links = (.*)$", body, re.M)
        one_way = re.search(r"^one_way_links = (.*)$", body, re.M)
        nodes[nid] = dict(pos=(float(pos[1]), float(pos[2])) if pos else (0.0, 0.0),
                          color=tuple(int(float(c) * 255) for c in col.groups()) if col else (200, 200, 200),
                          kind=int(kind[1]) if kind else STAT,
                          links=re.findall(r'&"(\w+)"', links[1]) if links else [],
                          one_way=re.findall(r'&"(\w+)"', one_way[1]) if one_way else [])
    start = re.search(r'^start_id = &"(\w+)"', text, re.M)
    return nodes, start[1] if start else None


def render(tree_id, out, marks=(), scale=24):
    nodes, start = load(tree_id)
    xs = [n["pos"][0] for n in nodes.values()]
    ys = [n["pos"][1] for n in nodes.values()]
    pad = 2.0
    x0, y0 = min(xs) - pad, min(ys) - pad
    w, h = int((max(xs) - x0 + pad) * scale), int((max(ys) - y0 + pad) * scale)
    im = Image.new("RGB", (w, h), (24, 20, 37))
    d = ImageDraw.Draw(im)

    def at(nid):
        x, y = nodes[nid]["pos"]
        return (x - x0) * scale, (y - y0) * scale

    for nid, n in nodes.items():
        for other, width in [(o, 3) for o in n["links"]] + [(o, 1) for o in n["one_way"]]:
            if other in nodes:
                d.line([at(nid), at(other)], fill=(90, 105, 136), width=width)
    def marked(nid):
        return any(nid == m or (m.endswith("*") and nid.startswith(m[:-1])) for m in marks)

    for nid, n in nodes.items():
        x, y = at(nid)
        c = n["color"]
        r = scale * 0.32
        if nid == start:
            d.ellipse([x - r * 1.4, y - r * 1.4, x + r * 1.4, y + r * 1.4], fill=c, outline=(254, 231, 97), width=3)
        elif n["kind"] == CAPSTONE:
            d.ellipse([x - r * 1.3, y - r * 1.3, x + r * 1.3, y + r * 1.3], fill=c, outline=(254, 174, 52), width=2)
        elif n["kind"] == EVOLVE:
            d.polygon([(x, y - r * 1.3), (x + r * 1.3, y), (x, y + r * 1.3), (x - r * 1.3, y)], fill=c, outline=(255, 255, 255))
        elif n["kind"] == SIDE:
            d.rectangle([x - r * 0.7, y - r * 0.7, x + r * 0.7, y + r * 0.7], fill=c)
        else:
            d.rectangle([x - r, y - r, x + r, y + r], fill=c)
        if marked(nid):
            d.ellipse([x - r * 1.8, y - r * 1.8, x + r * 1.8, y + r * 1.8], outline=(255, 255, 255), width=2)
    im.save(out)
    print(f"{out}: {len(nodes)} nodes, x {min(xs):.1f}..{max(xs):.1f}, y {min(ys):.1f}..{max(ys):.1f}")


if __name__ == "__main__":
    args = sys.argv[1:]
    marks, scale = (), 24
    if "--mark" in args:
        i = args.index("--mark")
        marks = tuple(args[i + 1].split(","))
        del args[i:i + 2]
    if "--scale" in args:
        i = args.index("--scale")
        scale = int(args[i + 1])
        del args[i:i + 2]
    render(args[0], args[1], marks, scale)
