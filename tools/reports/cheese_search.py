"""How much a level asks of a strong player: the smart soak bot (play=smart) plays it many times.

    python tools/reports/cheese_search.py [--levels 1-12] [--mode normal|hard] [--per-clear 3] [--seed 1] [--play smart|rules]
                                          [--skip-slack] [--skip-cheese] [extra soak options]

Slack: the highest enemy health multiplier (health=) the smart bot still wins at with the talent points a
player has by then (per_clear x the clears before it; Hard: including its own Normal clear), found by
doubling and then halving the step. A Normal level at x2 or more asks little; one under x1 is too hard
for the budget.

Cheapest win: the most restricted play that still wins, tried from the most restricted up: towers=1, 2, 3,
5 of one tower type (each unlocked type on its own), first without walls, then with walls. "3 Bolters, no
walls" on a level that should need a maze is a cheese to fix (the user found that one by hand, 2026-11-20).

Runs one Godot at a time (every run writes its talents to the shared test save).
"""
import os
import re
import subprocess
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RESULT = re.compile(r"SOAK result (\w+): wave (\d+)/(\d+), life (\d+)/(\d+)")
TOWER_TYPES = ["puffe_bolter", "puffe_beamer", "puffe_nova"]
#BuildingListElement.unlock_level of each tower type
UNLOCK = {"puffe_bolter": 1, "puffe_beamer": 2, "puffe_nova": 3}
SHORT = {"puffe_bolter": "Bolter", "puffe_beamer": "Beamer", "puffe_nova": "Nova"}
TOWER_COUNTS = [1, 2, 3, 5]
SLACK_START = 1.0
SLACK_MAX = 8.0
SLACK_PRECISION = 0.125
#--play: smart, or rules to compare with the old bot
PLAY = ["smart"]


def parse_levels(text):
    if "-" in text:
        first, last = text.split("-")
        return list(range(int(first), int(last) + 1))
    return [int(x) for x in text.split(",")]


def run_once(level, mode, seed, args):
    command = [sys.executable, os.path.join(PROJECT, "tools", "gd.py"), "run", "tools/reports/soak_level.gd",
               f"level={level}", f"mode={mode}", f"seed={seed}", f"play={PLAY[0]}"] + args + ["--raw", "--timeout", "900"]
    output = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    errors = [line for line in output.splitlines() if "SCRIPT ERROR" in line]
    if errors:
        print("   " + "\n   ".join(errors[:3]), flush=True)
    match = RESULT.search(output)
    if match is None:
        return {"result": "error", "wave": 0, "waves": 0, "life": 0}
    return {"result": match.group(1), "wave": int(match.group(2)), "waves": int(match.group(3)), "life": int(match.group(4))}


def wins(run):
    return run["result"] == "won"


def slack(level, mode, seed, talents, extra):
    """The highest health multiplier still won, or the furthest wave at x1 when even that is lost."""
    first = run_once(level, mode, seed, [talents] + extra)
    if not wins(first):
        return f"lost w{first['wave']}/{first['waves']}"
    low = SLACK_START
    high = None
    step = 1.0
    #double until a loss, then bisect between the last win and the loss
    while high is None:
        test = min(low + step, SLACK_MAX)
        if wins(run_once(level, mode, seed, [talents, f"health={test}"] + extra)):
            low = test
            if test >= SLACK_MAX:
                return f"x{SLACK_MAX:g}+"
            step *= 2.0
        else:
            high = test
    while high - low > SLACK_PRECISION:
        middle = (low + high) / 2.0
        if wins(run_once(level, mode, seed, [talents, f"health={middle}"] + extra)):
            low = middle
        else:
            high = middle
    return f"x{low:g}"


def cheapest(level, mode, seed, talents, extra):
    types = [t for t in TOWER_TYPES if UNLOCK[t] <= level]
    for walls in ("walls=0", "walls=1"):
        for count in TOWER_COUNTS:
            for tower_type in types:
                run = run_once(level, mode, seed, [talents, f"types={tower_type}", f"towers={count}", "traps=0", walls] + extra)
                if wins(run):
                    maze = "no walls" if walls == "walls=0" else "walls"
                    return f"{count} {SHORT[tower_type]}{'s' if count > 1 else ''}, {maze}, {run['life']} life"
    return "-"


def main(argv):
    options = {"--levels": "1-12", "--mode": "normal", "--per-clear": "3", "--seed": "1", "--play": "smart"}
    flags = set()
    extra = []
    i = 0
    while i < len(argv):
        if argv[i] in options and i + 1 < len(argv):
            options[argv[i]] = argv[i + 1]
            i += 2
        elif argv[i] in ("--skip-slack", "--skip-cheese"):
            flags.add(argv[i])
            i += 1
        else:
            extra.append(argv[i])
            i += 1

    mode = options["--mode"]
    PLAY[0] = options["--play"]
    per_clear = int(options["--per-clear"])
    seed = options["--seed"]
    print(f"{PLAY[0]} bot, mode {mode}, {per_clear} points per clear, seed {seed}, extra {' '.join(extra) or '-'}")
    print(f"{'level':>5}  {'pts':>4}  {'slack':>12}  cheapest win", flush=True)
    for level in parse_levels(options["--levels"]):
        points = per_clear * (level - 1 if mode == "normal" else level)
        talents = f"talents=budget:{points}"
        slack_text = "-" if "--skip-slack" in flags else slack(level, mode, seed, talents, extra)
        cheese_text = "-" if "--skip-cheese" in flags else cheapest(level, mode, seed, talents, extra)
        print(f"{level:>5}  {points:>4}  {slack_text:>12}  {cheese_text}", flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
