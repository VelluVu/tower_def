"""Tunes every level's strength against the talent budget a player has by then (the user, 2026-11-16: "normal is doable
without super tactics but it's expected the player spends his earned talents; hard modes are tough, the later hard levels
require most of the talent points spent or great tactics and builds").

Knobs: LevelData.health_scale (every mode) and hard_health_scale (on top, in Hard), one each per level.
Budgets (talent points before playing the level):
    average player, Normal:    AVERAGE_PER_LEVEL x (N - 1)
    thorough player, Hard:     THOROUGH x N - 3 (Normal of this level cleared first), capped at the trees' ranks
Targets, with the soak bot playing a simple build (few walls):
    Normal at the average budget:   won by each of the three builds (fire, frost, poison: one seed each, since "doable
                                    without super tactics" must hold for any reasonable build), average 5-9 lives left
                                    (10/10 everywhere = too easy)
    Normal without talents, 1-6:    won (the first levels teach the game)
    Hard at 85% of the thorough budget:  won on at least 2 of 3 seeds, with the area's fitting build (great builds count)
    Hard at 60% of it, levels 20+:       lost on at least 1 of 2 seeds

    python tools/tune_levels.py [levels...] [--passes 4] [--report] [--retune normal|hard|all]   (--retune: judge that side again)

Writes the knobs into scenes/level/level_data/level_0NN_data.tres after every pass and the table to
tools/reports/tune_levels.json (resumable: a rerun starts from the written knobs). --report prints the table only.
"""
import concurrent.futures
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "scenes", "level", "level_data", "level_%03d_data.tres")
TABLE = os.path.join(ROOT, "tools", "reports", "tune_levels.json")
LEVEL_COUNT = 60
AVERAGE_PER_LEVEL = 3
THOROUGH_PER_LEVEL = 8
TREE_RANKS = 526
NORMAL_RUNS = ((11, "fire"), (12, "frost"), (13, "poison"))
ZERO_SEEDS = (21, 22)
HARD_SEEDS = (31, 32, 33)
HARD_LOW_SEEDS = (41, 42)
WORKERS = 6
SCALE_RANGE = (0.4, 2.0)
HARD_RANGE = (0.6, 2.5)


def build_for(level):
    # each area's weakness: caves Fire, swamp Frost, humans Poison, the ash desert's dead Fire, the volcano Frost
    if level <= 12 or 37 <= level <= 48:
        return "fire"
    return "frost" if level <= 24 or level >= 49 else "poison"


def normal_budget(level):
    return AVERAGE_PER_LEVEL * (level - 1)


def hard_budget(level, share):
    return int(round(share * min(THOROUGH_PER_LEVEL * level - 3, TREE_RANKS)))


def read_knobs(level):
    text = open(DATA % level, encoding="utf8").read()
    get = lambda key: float(m.group(1)) if (m := re.search(r"^%s = ([\d.]+)$" % key, text, re.M)) else None
    scale = get("health_scale")
    hard = get("hard_health_scale")
    # Hard grows with the level by default: x1.0 at level 1 to x1.4 at 36, on top of the shared Hard mode
    return (scale if scale is not None else 1.0, hard if hard is not None else round(1.0 + 0.4 * (level - 1) / 35.0, 3))


def write_knobs(level, scale, hard):
    text = open(DATA % level, encoding="utf8").read()
    for key, value in (("health_scale", scale), ("hard_health_scale", hard)):
        line = "%s = %.3f" % (key, value)
        if re.search(r"^%s = " % key, text, re.M):
            text = re.sub(r"^%s = [\d.]+$" % key, line, text, flags=re.M)
        else:
            text = text.rstrip("\n") + "\n" + line + "\n"
    open(DATA % level, "w", encoding="utf8", newline="\n").write(text)


def play(level, mode, talents, seed, build):
    args = [sys.executable, os.path.join(ROOT, "tools", "gd.py"), "--timeout", "590", "run", "tools/reports/soak_level.gd",
            "level=%d" % level, "mode=%s" % mode, "build=%s" % build, "talents=%s" % talents,
            "walls=0.1", "seed=%d" % seed, "--raw"]
    out = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    m = re.search(r"SOAK result (\w+): wave (\d+)/(\d+), life (\d+)/(\d+)", out)
    if not m:
        return {"won": False, "life": 0, "wave": 0, "error": True}
    return {"won": m.group(1) == "won", "life": int(m.group(4)), "wave": int(m.group(2))}


def jobs_for(level, state):
    jobs = []
    if not state["normal_ok"]:
        jobs += [(level, "normal", "budget:%d" % normal_budget(level), s, b, "normal") for s, b in NORMAL_RUNS]
        if level <= 6:
            jobs += [(level, "normal", "none", s, build_for(level), "zero") for s in ZERO_SEEDS]
    if not state["hard_ok"]:
        jobs += [(level, "hard", "budget:%d" % hard_budget(level, 0.85), s, build_for(level), "hard") for s in HARD_SEEDS]
        if level >= 20:
            jobs += [(level, "hard", "budget:%d" % hard_budget(level, 0.6), s, build_for(level), "hard_low") for s in HARD_LOW_SEEDS]
    return jobs


def raise_below_failure(state, side, value, factor):
    """Raises a knob, but never back to a strength that already lost: when one build loses and the others are flawless
    (no single knob fits both), it would swing up and down forever, so it settles just below the failure instead
    (too easy beats too hard). Returns the new value, or None when there is no room left (the side is done)."""
    raised = value * factor
    failed = state.get(side + "_failed")
    if failed is not None and raised >= failed * 0.97:
        raised = failed * 0.97
        if raised <= value + 0.005:
            return None
    return raised


def remember_failure(state, side, value):
    state[side + "_failed"] = min(state.get(side + "_failed") or value, value)


def judge(level, state, results):
    """Moves the knobs by what the runs showed; marks a side done when it meets its target."""
    scale, hard = state["scale"], state["hard"]
    normal = [r for kind, r in results if kind == "normal"]
    zero = [r for kind, r in results if kind == "zero"]
    hard_runs = [r for kind, r in results if kind == "hard"]
    hard_low = [r for kind, r in results if kind == "hard_low"]
    if normal:
        lives = sum(r["life"] for r in normal) / len(normal)
        wins = sum(r["won"] for r in normal)
        zero_lost = any(not r["won"] for r in zero)
        state["normal_runs"] = "%d/%d won, %.1f lives" % (wins, len(normal), lives) + (", 0 talents lost" if zero_lost else "")
        if wins < len(normal) or lives < 5 or zero_lost:
            remember_failure(state, "normal", scale)
            scale *= 0.85 if wins < len(normal) - 1 or lives < 2 else 0.92
        elif lives >= 9.9 and level > 2 and (raised := raise_below_failure(state, "normal", scale, 1.12)) is not None:
            scale = raised
        else:
            state["normal_ok"] = True
    if hard_runs:
        wins = sum(r["won"] for r in hard_runs)
        low_wins = sum(r["won"] for r in hard_low)
        lives = sum(r["life"] for r in hard_runs) / len(hard_runs)
        state["hard_runs"] = "%d/%d won at 85%%, %.1f lives" % (wins, len(hard_runs), lives) + (
            ", %d/%d at 60%%" % (low_wins, len(hard_low)) if hard_low else "")
        too_easy = (hard_low and low_wins == len(hard_low)) or (not hard_low and wins == len(hard_runs) and lives >= 9.9 and level >= 8)
        if wins < 2:
            remember_failure(state, "hard", hard)
            hard *= 0.85 if wins == 0 else 0.93
        elif too_easy and (raised := raise_below_failure(state, "hard", hard, 1.12 if hard_low else 1.1)) is not None:
            hard = raised
        else:
            state["hard_ok"] = True
    state["scale"] = round(min(max(scale, SCALE_RANGE[0]), SCALE_RANGE[1]), 3)
    state["hard"] = round(min(max(hard, HARD_RANGE[0]), HARD_RANGE[1]), 3)
    # a knob at its limit cannot do more: stop moving it
    if state["scale"] in SCALE_RANGE:
        state["normal_ok"] = True
    if state["hard"] in HARD_RANGE:
        state["hard_ok"] = True


def load_table(levels):
    table = json.load(open(TABLE)) if os.path.exists(TABLE) else {}
    for level in levels:
        scale, hard = read_knobs(level)
        entry = table.get(str(level), {})
        entry.update({"scale": scale, "hard": hard})
        entry.setdefault("normal_ok", False)
        entry.setdefault("hard_ok", False)
        table[str(level)] = entry
    return table


def report(table):
    print("%-6s %-7s %-7s %-34s %s" % ("level", "scale", "hard", "normal (average budget)", "hard (85% / 60% budget)"))
    for key in sorted(table, key=int):
        e = table[key]
        print("%-6s %-7.3f %-7.3f %-34s %s" % (key, e["scale"], e["hard"], e.get("normal_runs", "-") + (" ok" if e["normal_ok"] else ""),
                                              e.get("hard_runs", "-") + (" ok" if e["hard_ok"] else "")))


def main(argv):
    passes = 4
    if "--passes" in argv:
        passes = int(argv[argv.index("--passes") + 1])
        del argv[argv.index("--passes"):argv.index("--passes") + 2]
    levels = [int(a) for a in argv[1:] if a.isdigit() and argv[argv.index(a) - 1] != "--passes"] or list(range(1, LEVEL_COUNT + 1))
    table = load_table(levels)
    if "--retune" in argv:
        side = argv[argv.index("--retune") + 1]
        for level in levels:
            for key in (("normal", "hard") if side == "all" else (side,)):
                table[str(level)][key + "_ok"] = False
                #a retune follows a game change: old failures say nothing about it
                table[str(level)].pop(key + "_failed", None)
    if "--report" in argv:
        report(table)
        return
    for number in range(passes):
        work = [(level, table[str(level)]) for level in levels if not (table[str(level)]["normal_ok"] and table[str(level)]["hard_ok"])]
        if not work:
            break
        for level, state in work:
            write_knobs(level, state["scale"], state["hard"])
        jobs = [job for level, state in work for job in jobs_for(level, state)]
        print("pass %d: %d levels, %d games" % (number + 1, len(work), len(jobs)), flush=True)
        results = {level: [] for level, _ in work}
        with concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
            futures = {pool.submit(play, level, mode, talents, seed, b): (level, kind) for level, mode, talents, seed, b, kind in jobs}
            for future in concurrent.futures.as_completed(futures):
                level, kind = futures[future]
                results[level].append((kind, future.result()))
        for level, state in work:
            judge(level, state, results[level])
            write_knobs(level, state["scale"], state["hard"])
        json.dump(table, open(TABLE, "w"), indent=1)
        report({str(level): table[str(level)] for level in levels})
    report({str(level): table[str(level)] for level in levels})


if __name__ == "__main__":
    main(sys.argv)
