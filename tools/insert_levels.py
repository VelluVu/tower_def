"""Make room for new levels: every level numbered `at` or higher moves up by `count` (its .tscn, LevelData, wave
files, the references between them, and its world map node), and the free numbers get world map nodes placed
between their neighbours (provisional, for the user to move). The new levels' own files are made separately
(swamp_levels.py, field_levels.py, ...). Saves need a SaveWiring._migrate step for the same insertion.

    python tools/insert_levels.py <at> <count>
    python tools/insert_levels.py rotate <from> <to>     (2026-11-24) level `from` moves to `to` and the levels between
        close up behind it (rotate 8 12: 8 -> 12, 9-12 -> 8-11); the world map nodes keep their numbers and places
        (move them by hand), the tuner's results follow their levels. Saves need a _migrate step for it too.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEVELS = os.path.join(ROOT, "scenes", "level", "levels")
DATA = os.path.join(ROOT, "scenes", "level", "level_data")
WAVES = os.path.join(DATA, "waves")
MODES = os.path.join(DATA, "modes")
TUNE_REPORT = os.path.join(ROOT, "tools", "reports", "tune_levels.json")
MAP = os.path.join(ROOT, "scenes", "ui", "game_world_map", "game_world_map.tscn")


def level_numbers():
    return sorted(int(re.search(r"(\d+)", n).group(1)) for n in os.listdir(LEVELS) if n.endswith(".tscn"))


def rename(old, new):
    """Moves one level's files from number old to new and fixes the references inside them."""
    moves = [(os.path.join(LEVELS, "level_%03d.tscn" % old), os.path.join(LEVELS, "level_%03d.tscn" % new)),
             (os.path.join(DATA, "level_%03d_data.tres" % old), os.path.join(DATA, "level_%03d_data.tres" % new))]
    for name in os.listdir(WAVES):
        m = re.match(r"level_%03d_(wave_\d+\.tres)$" % old, name)
        if m:
            moves.append((os.path.join(WAVES, name), os.path.join(WAVES, "level_%03d_%s" % (new, m.group(1)))))
    # a level's own Hard mode (modes/level_NNN_hard.tres and its wave files)
    for name in os.listdir(MODES):
        m = re.match(r"level_%03d_(hard\w*\.tres)$" % old, name)
        if m:
            moves.append((os.path.join(MODES, name), os.path.join(MODES, "level_%03d_%s" % (new, m.group(1)))))
    for src, dst in moves:
        if not os.path.exists(src):
            continue
        text = open(src, encoding="utf8").read()
        text = text.replace("level_%03d_" % old, "level_%03d_" % new).replace("Level%03d" % old, "Level%03d" % new)
        with open(dst, "w", encoding="utf8", newline="\n") as f:
            f.write(text)
        os.remove(src)


def map_blocks(text):
    """level number -> (start, end) of its node block (the Panel and its children) in the world map scene."""
    blocks = {}
    starts = [(m.start(), int(m.group(1))) for m in re.finditer(r'\[node name="Level_(\d+)" type="Panel"', text)]
    for i, (start, number) in enumerate(starts):
        end = starts[i + 1][0] if i + 1 < len(starts) else None
        if end is None:
            nxt = re.search(r'\n\[node name="[^"]+" type="[^"]+" parent="(?!MapView/Map/Level_)', text[start:])
            end = start + nxt.start() + 1 if nxt else len(text)
        blocks[number] = (start, end)
    return blocks


def renumber_block(block, old, new):
    block = block.replace("Level_%03d" % old, "Level_%03d" % new)
    return re.sub(r"level_number = %d\b" % old, "level_number = %d" % new, block)


def offsets(block):
    return [float(v) for v in re.search(r"offset_left = ([-\d.]+)\noffset_top = ([-\d.]+)", block).groups()]


def place(block, left, top):
    return re.sub(r"(\[node name=\"Level_\d+\" type=\"Panel\"[^\n]*\n(?:[^\[\n][^\n]*\n)*?)offset_left = [-\d.]+\noffset_top = [-\d.]+\noffset_right = [-\d.]+\noffset_bottom = [-\d.]+",
                  lambda m: m.group(1) + "offset_left = %.1f\noffset_top = %.1f\noffset_right = %.1f\noffset_bottom = %.1f" % (left, top, left + 20, top + 20),
                  block, count=1)


def shift_map(at, count):
    text = open(MAP, encoding="utf8").read()
    blocks = map_blocks(text)
    if not blocks:
        return
    pieces = {n: text[s:e] for n, (s, e) in blocks.items()}
    first = min(s for s, _ in blocks.values())
    last = max(e for _, e in blocks.values())
    new_pieces = {}
    for number, block in pieces.items():
        new_number = number + count if number >= at else number
        new_pieces[new_number] = renumber_block(block, number, new_number) if new_number != number else block
    # the new numbers: copies of the level before them, spread on the line to the level after them
    before, after = new_pieces.get(at - 1), new_pieces.get(at + count)
    if before is not None:
        x0, y0 = offsets(before)
        x1, y1 = offsets(after) if after is not None else (x0 + 30.0 * (count + 1), y0)
        for i in range(count):
            t = (i + 1) / (count + 1)
            new_pieces[at + i] = place(renumber_block(before, at - 1, at + i), x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)
    body = "".join(new_pieces[n] for n in sorted(new_pieces))
    with open(MAP, "w", encoding="utf8", newline="\n") as f:
        f.write(text[:first] + body + text[last:])


def shift_tune_report(at, count):
    """tools/tune_levels.py's results move with their levels (the new numbers have none yet)"""
    if not os.path.exists(TUNE_REPORT):
        return
    import json
    with open(TUNE_REPORT, encoding="utf8") as f:
        report = json.load(f)
    moved = {str(int(k) + count if int(k) >= at else int(k)): v for k, v in report.items()}
    with open(TUNE_REPORT, "w", encoding="utf8", newline="\n") as f:
        json.dump(moved, f, indent=1)


TEMP_NUMBER = 999


def rotate(start, end):
    """level `start` to `end`, the ones between one step towards start (either direction)"""
    step = 1 if end > start else -1
    rename(start, TEMP_NUMBER)
    for number in range(start + step, end + step, step):
        rename(number, number - step)
        print("level %d -> %d" % (number, number - step))
    rename(TEMP_NUMBER, end)
    print("level %d -> %d" % (start, end))
    if os.path.exists(TUNE_REPORT):
        import json
        with open(TUNE_REPORT, encoding="utf8") as f:
            report = json.load(f)
        lo, hi = min(start, end), max(start, end)
        moved = {}
        for k, v in report.items():
            n = int(k)
            new = end if n == start else n - step if lo <= n <= hi else n
            moved[str(new)] = v
        with open(TUNE_REPORT, "w", encoding="utf8", newline="\n") as f:
            json.dump(moved, f, indent=1)


def main(argv):
    if len(argv) == 4 and argv[1] == "rotate":
        rotate(int(argv[2]), int(argv[3]))
        return
    if len(argv) != 3:
        sys.exit(__doc__)
    at, count = int(argv[1]), int(argv[2])
    for number in sorted((n for n in level_numbers() if n >= at), reverse=True):
        rename(number, number + count)
        print("level %d -> %d" % (number, number + count))
    shift_map(at, count)
    shift_tune_report(at, count)
    print("world map: levels from %d moved up %d, %d new nodes" % (at, count, count))


if __name__ == "__main__":
    main(sys.argv)
