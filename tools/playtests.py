"""Summarise the playtest log the game writes after every level run (debug builds).

    python tools/playtests.py             your runs (user://playtests.jsonl)
    python tools/playtests.py --bot       the soak bot's runs (user://bot_playtests.jsonl)
    python tools/playtests.py --level 3   one level only
    python tools/playtests.py --last 20   the last 20 runs (default 30)

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


def main(args):
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
        print(f"{r.get('time', '')[:16]}  L{r.get('level')} {r.get('result'):8} wave {r.get('wave')}/{r.get('waves')}"
              f"  life {r.get('life', 0):.0f}/{r.get('start_life', 0):.0f} [{lives}]"
              f"  gold +{r.get('gold_earned')} -{r.get('gold_spent')} ({short_spend(r.get('spent_on', {}))})"
              f"  talents {talents}  cards {len(r.get('cards', []))}  early {r.get('early_starts')}"
              f"  {r.get('game_seconds')}s x{r.get('max_speed')}{cheats}  {r.get('player', '')}")

    print("\nlevel  runs  won  avg life left  avg gold earned  avg leaks")
    for number in sorted({r.get("level") for r in runs}):
        level_runs = [r for r in runs if r.get("level") == number and not r.get("cheats")]
        if not level_runs:
            continue
        won = [r for r in level_runs if r.get("result") == "won"]
        avg_life = sum(r.get("life", 0) for r in won) / len(won) if won else 0
        avg_gold = sum(r.get("gold_earned", 0) for r in level_runs) / len(level_runs)
        avg_leaks = sum(sum(r.get("leaked", {}).values()) for r in level_runs) / len(level_runs)
        print(f"{number:5}  {len(level_runs):4}  {len(won):3}  {avg_life:13.1f}  {avg_gold:15.0f}  {avg_leaks:9.1f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
