"""Summarise the playtest log the game writes after every level run (debug builds).

    python tools/playtests.py             your runs (user://playtests.jsonl)
    python tools/playtests.py --bot       the soak bot's runs (user://bot_playtests.jsonl)
    python tools/playtests.py --level 3   one level only
    python tools/playtests.py --last 20   the last 20 runs (default 30)
    python tools/playtests.py --compare   your runs next to the bot's tuning result and talent budget per level

Prints one line per run, then per level: runs, wins, average lives left, gold earned and spent.
"""
import json
import os
import sys

USER_DIR = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "puffetd")
PLAYER_LOG = os.path.join(USER_DIR, "playtests.jsonl")
BOT_LOG = os.path.join(USER_DIR, "bot_playtests.jsonl")


def read_runs(path):
    runs = []
    if not os.path.exists(path):
        return runs
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    runs.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    return runs


def short_spend(spent_on):
    parts = []
    for key, value in sorted(spent_on.items(), key=lambda kv: -kv[1]):
        if value:
            parts.append(f"{key.replace('puffe_', '')} {value:.0f}")
    return ", ".join(parts)


def mode_tag(run):
    """H after the level number for a Hard run, nothing for Normal."""
    mode = run.get("mode", "normal")
    return "" if mode == "normal" else mode[0].upper()


TUNE_TABLE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reports", "tune_levels.json")
# the tuner's budgets (tools/tune_levels.py): an average player on Normal, a thorough one on Hard
AVERAGE_PER_LEVEL, THOROUGH_PER_LEVEL, TREE_RANKS = 3, 8, 526


def compare(runs):
    """each of your runs (no cheats) next to what the tuner measured for the bot on that level and mode, with both
    talent budgets, so the bot's targets can be checked against how you play (design doc: Difficulty model)"""
    table = json.load(open(TUNE_TABLE, encoding="utf-8")) if os.path.exists(TUNE_TABLE) else {}
    print("level  mode    you                           your talents  bot budget  bot result")
    for r in runs:
        if r.get("cheats"):
            continue
        level, mode = r.get("level"), r.get("mode", "normal")
        entry = table.get(str(level), {})
        if mode == "hard":
            budget = min(TREE_RANKS, THOROUGH_PER_LEVEL * level - 3)
            bot = entry.get("hard_runs", "not tuned")
        else:
            budget = AVERAGE_PER_LEVEL * (level - 1)
            bot = entry.get("normal_runs", "not tuned")
        you = f"{r.get('result')} wave {r.get('wave')}/{r.get('waves')}, {r.get('life', 0):.0f} lives"
        print(f"{level:5}  {mode:6}  {you:28}  {sum(r.get('talents', {}).values()):12}  {budget:10}  {bot}")
    return 0


def main(args):
    if "--compare" in args:
        return compare(read_runs(PLAYER_LOG))
    path = BOT_LOG if "--bot" in args else PLAYER_LOG
    level = int(args[args.index("--level") + 1]) if "--level" in args else None
    last = int(args[args.index("--last") + 1]) if "--last" in args else 30

    runs = [r for r in read_runs(path) if level is None or r.get("level") == level]
    if not runs:
        print(f"no runs in {path}")
        return 0

    print(f"{len(runs)} runs in {path}\n")
    for r in runs[-last:]:
        talents = sum(r.get("talents", {}).values())
        cheats = " CHEATS" if r.get("cheats") else ""
        lives = "/".join(f"{x:.0f}" for x in r.get("life_by_wave", []))
        print(f"{r.get('time', '')[:16]}  L{r.get('level')}{mode_tag(r)} {r.get('result'):8} wave {r.get('wave')}/{r.get('waves')}"
              f"  life {r.get('life', 0):.0f}/{r.get('start_life', 0):.0f} [{lives}]"
              f"  gold +{r.get('gold_earned')} -{r.get('gold_spent')} ({short_spend(r.get('spent_on', {}))})"
              f"  talents {talents}  cards {len(r.get('cards', []))}  early {r.get('early_starts')}"
              f"  {r.get('game_seconds')}s x{r.get('max_speed')}{cheats}  {r.get('player', '')}")

    print("\nlevel  runs  won  avg life left  avg gold earned  avg leaks")
    for number, mode in sorted({(r.get("level"), r.get("mode", "normal")) for r in runs}):
        level_runs = [r for r in runs if r.get("level") == number and r.get("mode", "normal") == mode and not r.get("cheats")]
        if not level_runs:
            continue
        won = [r for r in level_runs if r.get("result") == "won"]
        avg_life = sum(r.get("life", 0) for r in won) / len(won) if won else 0
        avg_gold = sum(r.get("gold_earned", 0) for r in level_runs) / len(level_runs)
        avg_leaks = sum(sum(r.get("leaked", {}).values()) for r in level_runs) / len(level_runs)
        print(f"{str(number) + mode_tag(level_runs[0]):>5}  {len(level_runs):4}  {len(won):3}  {avg_life:13.1f}  {avg_gold:15.0f}  {avg_leaks:9.1f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
