"""The difficulty layers in one table: the soak bot plays each level with no talents, with points spread
over every tree, and with each build focused on its own tree and picking fitting cards, over a few seeds.

    python tools/reports/build_matrix.py [--levels 1-12] [--mode normal|hard] [--seeds 1,2] [--setups none,spread,fire]
                                         [--per-clear 4] [extra soak options like towers=25]

Talent points for level N: per_clear x (N - 1) on Normal (the clears before it), per_clear x N on Hard
(Normal of it cleared too). Runs one Godot at a time: every run writes its talents to the shared test save.
A cell shows wins/runs and the average life left of the wins, or the furthest wave of the losses.
"""
import re
import subprocess
import sys
import os

PROJECT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TREES = ["building", "fire", "frost", "poison"]
BUILDS = ["fire", "frost", "poison", "physical"]
RESULT = re.compile(r"SOAK result (\w+): wave (\d+)/(\d+), life (\d+)/(\d+)")


def parse_levels(text):
    if "-" in text:
        first, last = text.split("-")
        return list(range(int(first), int(last) + 1))
    return [int(x) for x in text.split(",")]


def setup_args(setup, points):
    if setup == "none":
        return ["build=mixed", "talents=none", "cards=random"]
    if setup == "spread":
        share = points // len(TREES)
        extra = points - share * len(TREES)
        parts = [f"{tree}:{share + (1 if i < extra else 0)}" for i, tree in enumerate(TREES)]
        return ["build=mixed", "talents=" + ",".join(parts), "cards=random"]
    return [f"build={setup}", f"talents=focus:{points}", "cards=fit"]


def run_once(level, mode, seed, args):
    command = [sys.executable, os.path.join(PROJECT, "tools", "gd.py"), "run", "tools/reports/soak_level.gd",
               f"level={level}", f"mode={mode}", f"seed={seed}"] + args + ["--raw", "--timeout", "700"]
    output = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    if "SCRIPT ERROR" in output:
        print("\n".join(line for line in output.splitlines() if "SCRIPT ERROR" in line)[:600])
    match = RESULT.search(output)
    if match is None:
        return ("error", 0, 0, 0)
    return (match.group(1), int(match.group(2)), int(match.group(3)), int(match.group(4)))


def cell(results):
    wins = [r for r in results if r[0] == "won"]
    text = f"{len(wins)}/{len(results)}"
    if wins:
        return text + f" {sum(r[3] for r in wins) / len(wins):.0f}hp"
    furthest = max((r[1] for r in results), default=0)
    return text + f" w{furthest}"


def main(argv):
    options = {"--levels": "1-12", "--mode": "normal", "--seeds": "1,2", "--setups": "none,spread," + ",".join(BUILDS), "--per-clear": "4"}
    extra = []
    i = 0
    while i < len(argv):
        if argv[i] in options and i + 1 < len(argv):
            options[argv[i]] = argv[i + 1]
            i += 2
        else:
            extra.append(argv[i])
            i += 1

    levels = parse_levels(options["--levels"])
    mode = options["--mode"]
    seeds = options["--seeds"].split(",")
    setups = options["--setups"].split(",")
    per_clear = int(options["--per-clear"])

    print(f"mode {mode}, seeds {','.join(seeds)}, {per_clear} points per clear, extra {' '.join(extra) or '-'}")
    print("level  pts  " + "  ".join(f"{s:>11}" for s in setups), flush=True)
    for level in levels:
        points = per_clear * (level if mode == "hard" else level - 1)
        row = []
        for setup in setups:
            results = [run_once(level, mode, seed, setup_args(setup, points) + extra) for seed in seeds]
            row.append(cell(results))
        print(f"{level:5}  {points:3}  " + "  ".join(f"{c:>11}" for c in row), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
