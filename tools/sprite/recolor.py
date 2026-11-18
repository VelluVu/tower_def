"""Make a new sprite spec by recolouring an existing sprite: a variant enemy that keeps the parent's frames,
tags and timing but has its own palette.

    python tools/sprite/recolor.py <source.txt | source.aseprite> <out.txt> old=new... [--note "header line"]

old and new are hex colours without '#' (e.g. 2d7356=5ac54f). A colour not named keeps its value. The source
can be a text spec or a hand-drawn .aseprite (its frames are read through `sprite.py view`, one colour per
letter). Then build it like any spec: python tools/sprite/sprite.py build <out.txt> <out.aseprite>
"""
import os
import re
import string
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITE = os.path.join(HERE, "sprite.py")
LETTERS = string.ascii_letters + string.digits


def spec_from_aseprite(path):
    out = subprocess.run([sys.executable, SPRITE, "info", path], capture_output=True, text=True).stdout
    w, h = (int(v) for v in re.search(r"(\d+)x(\d+)\s+mode", out).groups())
    durs = [int(v) for v in re.search(r"durations\(ms\): ([\d,]+)", out).group(1).split(",")]
    tags = [(m.group(1), int(m.group(2)) - 1, int(m.group(3)) - 1) for m in re.finditer(r"tag (\S+) (\d+)-(\d+)", out)]
    from PIL import Image
    row_path = path + ".row.png"
    subprocess.run([sys.executable, SPRITE, "view", path, row_path, "--scale", "1"], capture_output=True)
    row = Image.open(row_path).convert("RGBA")
    row.load()
    os.remove(row_path)
    letters, frames = {}, []
    for i in range(len(durs)):
        grid = []
        for y in range(h):
            line = ""
            for x in range(w):
                r, g, b, a = row.getpixel((i * w + x, y))
                if a < 128:
                    line += "."
                    continue
                hexa = "%02x%02x%02x" % (r, g, b)
                if hexa not in letters:
                    letters[hexa] = LETTERS[len(letters)]
                line += letters[hexa]
            grid.append(line)
        frames.append(grid)
    lines = ["size = %dx%d" % (w, h)] + ["%s = %s" % (k, v) for v, k in letters.items()] + ["---"]
    for tag, a, b in tags:
        lines.append("@%s %d" % (tag, durs[a]))
        for i in range(a, b + 1):
            lines += frames[i] + [""]
    return "\n".join(lines) + "\n"


def main(argv):
    args = argv[1:]
    note = None
    if "--note" in args:
        i = args.index("--note")
        note = args[i + 1]
        del args[i:i + 2]
    if len(args) < 2:
        sys.exit(__doc__)
    source, out = args[0], args[1]
    swaps = dict(a.lower().split("=") for a in args[2:])
    text = spec_from_aseprite(source) if source.endswith(".aseprite") else open(source, encoding="utf8").read()
    head, body = text.split("---", 1)
    head_lines = [l for l in head.splitlines() if not l.startswith("#")]
    for i, line in enumerate(head_lines):
        m = re.match(r"^(\S) = ([0-9a-fA-F]{6})$", line.strip())
        if m and m.group(2).lower() in swaps:
            head_lines[i] = "%s = %s" % (m.group(1), swaps[m.group(2).lower()])
    header = "# Source of %s (python tools/sprite/sprite.py build <this> %s).\n# Recoloured from %s by tools/sprite/recolor.py." % (
        os.path.basename(out).replace(".txt", ".aseprite"), os.path.basename(out).replace(".txt", ".aseprite"), os.path.basename(source))
    if note:
        header += "\n# " + note
    with open(out, "w", encoding="utf8", newline="\n") as f:
        f.write(header + "\n" + "\n".join(head_lines).strip("\n") + "\n---" + body)
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv)
