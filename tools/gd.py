"""Headless Godot helper for Puffe TD: tests, reports, load checks and icons.

    python tools/gd.py test [paths...]      run tools/tests (or the given test files / folders)
    python tools/gd.py run <script.gd> [args]  await the script's run(kit, args) (see tools/reports)
    python tools/gd.py levels [--map]       waves, enemies, XP, cards, gold and routes per level
    python tools/gd.py stats                stats of every building and enemy
    python tools/gd.py check                load every level headless and report script errors
    python tools/gd.py icon <grid.txt> <out.png> [ref.png...]   draw a 16x16 icon from an ASCII grid

Every run is muted (tools/mute_audio.flag), uses simulated time (--fixed-fps, so a 60 s walk
takes a few seconds), has a timeout, and prints only the useful lines of Godot's output.
Options: --timeout <s> (default 300), --raw (unfiltered output).
"""
import os
import re
import subprocess
import sys

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = "C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"
MUTE_FLAG = os.path.join(PROJECT, "tools", "mute_audio.flag")
RUNNER = "res://tools/test/test_runner.tscn"
LEVELS = "res://scenes/level/levels"

# Godot lines that never matter here
NOISE = [
    r"^Godot Engine v",
    r"^\[godot_ai game_helper\]",
    r"Capture not registered: 'beehave'",
    r"custom_samplers\.has",
    r"Can't send message\. No active debugger",
    r"ObjectDB instances were leaked",
    r"resources still in use at exit",
    r"Unreferenced static string",
    r"^Setting breakpad minidump",
    r"^SteamInternal_SetMinidumpSteamID",
    r"^SceneManager UI scene already exists",
    r"^\s*$",
]
ERROR_PREFIXES = ("SCRIPT ERROR", "ERROR", "WARNING", "USER ERROR", "USER WARNING")
# the line after an error that says where it happened is kept, the rest of the backtrace is not
LOCATION = re.compile(r"^\s+at: ")
BACKTRACE = re.compile(r"^\s+(GDScript backtrace|\[\d+\] )")


def filter_output(text):
    noise = re.compile("|".join(NOISE))
    lines = []
    wants_location = False
    for line in text.splitlines():
        if noise.search(line):
            wants_location = False
            continue
        if LOCATION.match(line):
            if wants_location:
                lines[-1] += "  " + line.strip()
            wants_location = False
            continue
        if BACKTRACE.match(line):
            continue
        wants_location = line.startswith(ERROR_PREFIXES)
        lines.append(line)
    # repeated errors and warnings (with their location) are shown once with a count; other lines stay as they are
    counts, shown = {}, []
    for line in lines:
        if line.startswith(ERROR_PREFIXES):
            counts[line] = counts.get(line, 0) + 1
            if counts[line] > 1:
                continue
        shown.append(line)
    return "\n".join(l + (" (x%d)" % counts[l] if counts.get(l, 1) > 1 else "") for l in shown)


def godot(args, timeout, raw=False, quiet_ok=False, silent=False):
    open(MUTE_FLAG, "w").close()
    try:
        result = subprocess.run([GODOT, "--headless", "--path", PROJECT] + args,
                                capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
        output, code = result.stdout + result.stderr, result.returncode
    except subprocess.TimeoutExpired as e:
        output = (e.stdout or b"").decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        output += "\nTIMEOUT after %d s (a test probably hit a script error after an await and never returned)" % timeout
        code = 124
    finally:
        if os.path.exists(MUTE_FLAG):
            os.remove(MUTE_FLAG)
    text = output if raw else filter_output(output)
    if silent:
        return code
    if text.strip() or not quiet_ok:
        print(text)
    return code


CLASS_CACHE = os.path.join(PROJECT, ".godot", "global_script_class_cache.cfg")
SCRIPT_FOLDERS = ["scenes", "systems", "tools"]
# one hour of game time at 60 fps: a runner that failed to load quits on this within seconds
# instead of waiting for the timeout, and quitting flushes Godot's buffered output
FRAME_CAP = str(60 * 3600)


def import_if_needed(timeout):
    """A new class_name is unknown to a headless run until the project is imported."""
    cache_time = os.path.getmtime(CLASS_CACHE) if os.path.exists(CLASS_CACHE) else 0
    for folder in SCRIPT_FOLDERS:
        for dirpath, _, files in os.walk(os.path.join(PROJECT, folder)):
            if any(f.endswith(".gd") and os.path.getmtime(os.path.join(dirpath, f)) > cache_time for f in files):
                print("(importing: scripts changed since the class cache)")
                godot(["--import"], timeout, silent=True)
                return


def run_runner(user_args, timeout, raw):
    import_if_needed(timeout)
    # the runner stops itself first, so its output is flushed and names the stuck test
    deadline = ["--deadline", str(max(timeout - 20, 10))]
    return godot(["--fixed-fps", "60", "--quit-after", FRAME_CAP, RUNNER, "--"] + deadline + user_args, timeout, raw)


def to_res(path):
    if path.startswith("res://"):
        return path
    return "res://" + os.path.relpath(os.path.abspath(path), PROJECT).replace("\\", "/")


def main():
    args = sys.argv[1:]
    timeout, raw = 300, False
    if "--timeout" in args:
        i = args.index("--timeout")
        timeout = int(args[i + 1])
        del args[i:i + 2]
    if "--raw" in args:
        args.remove("--raw")
        raw = True
    if not args:
        print(__doc__)
        return 1

    command, rest = args[0], args[1:]
    if command == "test":
        paths = [to_res(p) for p in rest] or ["res://tools/tests"]
        return run_runner(["--test"] + paths, timeout, raw)
    if command == "run":
        return run_runner(["--run", to_res(rest[0])] + rest[1:], timeout, raw)
    if command == "levels":
        return run_runner(["--run", "res://tools/reports/level_report.gd"] + rest, timeout, raw)
    if command == "stats":
        return run_runner(["--run", "res://tools/reports/stat_sheet.gd"] + rest, timeout, raw)
    if command == "check":
        code = godot(["--quit"], timeout, raw, quiet_ok=True)
        for name in sorted(os.listdir(os.path.join(PROJECT, "scenes", "level", "levels"))):
            if name.endswith(".tscn"):
                print("==", name)
                code |= godot(["--fixed-fps", "60", "--quit-after", "120", LEVELS + "/" + name], timeout, raw, quiet_ok=True)
        print("check done")
        return code
    if command == "icon":
        icon_args = [os.path.abspath(p) for p in rest]
        return godot(["-s", "res://tools/icon/draw_icon.gd", "--"] + icon_args, timeout, raw, quiet_ok=True)
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main())
