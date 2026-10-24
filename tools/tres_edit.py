"""Read and change Godot .tres / .tscn text files section by section (no regex over the whole file).

    python tools/tres_edit.py list <file>                       the sections and how to select them
    python tools/tres_edit.py get <file> <section>              print one section
    python tools/tres_edit.py set <file> <section> key=value... set (or add) properties in one section
    python tools/tres_edit.py scale-waves [--count 1.5] [--interval 0.8] <wave files...>

A section is selected by node path in a scene ("." root, "Stats/MaxHealth", "LaunchProjectile/Stats/Damage"),
by sub_resource id ("Resource_group1"), or "resource" for the [resource] block.
Values are written as Godot text: set wall.tscn Stats/MaxHealth base_value=25.0 value=25.0
scale-waves knows SpawnGroupData's defaults (count 5, interval 3.0) for groups that leave them out.
"""
import math
import re
import sys

SPAWN_GROUP_DEFAULTS = {"count": 5, "interval": 3.0}
HEADER = re.compile(r"^\[(\w+)(.*)\]$")
ATTRIBUTE = re.compile(r'(\w+)=("[^"]*"|\S+)')


class Section:
    def __init__(self, header, lines):
        self.header = header
        self.lines = lines  # property lines, then the blank lines that followed them in the file

    @property
    def kind(self):
        m = HEADER.match(self.header)
        return m[1] if m else ""

    @property
    def attributes(self):
        m = HEADER.match(self.header)
        return {k: v.strip('"') for k, v in ATTRIBUTE.findall(m[2])} if m else {}

    @property
    def selector(self):
        a = self.attributes
        if self.kind == "node":
            parent = a.get("parent")
            if parent is None:
                return "."
            return a["name"] if parent == "." else parent + "/" + a["name"]
        if self.kind == "sub_resource":
            return a.get("id", "")
        if self.kind == "resource":
            return "resource"
        return ""

    def get(self, key):
        for line in self.lines:
            if line.startswith(key + " = "):
                return line.split(" = ", 1)[1]
        return None

    def set(self, key, value):
        for i, line in enumerate(self.lines):
            if line.startswith(key + " = "):
                self.lines[i] = "%s = %s" % (key, value)
                return
        # a new property goes after the last property, before the blank lines
        end = len(self.lines)
        while end > 0 and self.lines[end - 1] == "":
            end -= 1
        self.lines.insert(end, "%s = %s" % (key, value))

    def text(self):
        return "\n".join([self.header] + self.lines).rstrip("\n")


def parse(text):
    head, sections = [], []
    for line in text.split("\n"):
        if HEADER.match(line):
            sections.append(Section(line, []))
        elif sections:
            sections[-1].lines.append(line)
        else:
            head.append(line)
    return head, sections


# the exact text back, blank lines included, so an unchanged file round-trips byte for byte
def render(head, sections):
    lines = list(head)
    for s in sections:
        lines += [s.header] + s.lines
    return "\n".join(lines)


def load(path):
    with open(path, encoding="utf-8") as f:
        return parse(f.read())


def save(path, head, sections):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(render(head, sections))


def find(sections, selector):
    matches = [s for s in sections if s.selector == selector]
    if len(matches) != 1:
        sys.exit("%d sections match %r; use `list` to see the selectors" % (len(matches), selector))
    return matches[0]


def scale_waves(files, count_factor, interval_factor):
    for path in files:
        head, sections = load(path)
        summary = []
        for s in sections:
            if s.kind != "sub_resource" or s.get("enemy_scene") is None:
                continue
            count = int(s.get("count") or SPAWN_GROUP_DEFAULTS["count"])
            interval = float(s.get("interval") or SPAWN_GROUP_DEFAULTS["interval"])
            s.set("count", str(math.ceil(count * count_factor)))
            s.set("interval", str(round(interval * interval_factor, 2)))
            summary.append("%s %s/%s" % (s.selector, s.get("count"), s.get("interval")))
        save(path, head, sections)
        print(path, ", ".join(summary))


def main(args):
    if len(args) < 2:
        sys.exit(__doc__)
    command = args[0]
    if command == "scale-waves":
        count, interval = 1.0, 1.0
        while args[1].startswith("--"):
            if args[1] == "--count":
                count = float(args[2])
            elif args[1] == "--interval":
                interval = float(args[2])
            args = [args[0]] + args[3:]
        scale_waves(args[1:], count, interval)
        return
    path = args[1]
    head, sections = load(path)
    if command == "list":
        for s in sections:
            print("%-40s %s" % (s.selector or "-", s.header[:90]))
    elif command == "get":
        print(find(sections, args[2]).text())
    elif command == "set":
        s = find(sections, args[2])
        for pair in args[3:]:
            key, value = pair.split("=", 1)
            s.set(key, value)
        save(path, head, sections)
        print(s.text())
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
