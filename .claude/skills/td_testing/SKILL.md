---
name: td_testing
description: Use when verifying, testing, measuring or batch-editing anything in Puffe TD (puffetd) - running the tests, writing a new test, checking that scripts and levels load, level or unit balance numbers, editing .tres/.tscn values or waves, or drawing a 16x16 icon. Use these tools instead of writing throwaway Godot scripts or regexes.
---

# Testing and Tools (Puffe TD)

Everything runs through `python tools/gd.py` (headless, muted, simulated time, filtered output, timeout).
Run it from the project folder. It imports first when a script is newer than Godot's class cache.

| Need | Command |
|---|---|
| All tests (about 6 s) | `python tools/gd.py test` |
| Some tests | `python tools/gd.py test tools/tests/test_cards.gd` |
| Every level loads, no script errors | `python tools/gd.py check` |
| Waves, enemies, health, XP, cards, kill gold, routes (turns, slow cells) | `python tools/gd.py levels [numbers] [--map]` |
| Base stats of every building and enemy | `python tools/gd.py stats` |
| A one-off measurement | write a script with `func run(kit : TestKit, args : PackedStringArray)`, then `python tools/gd.py run <file.gd> [args]` |
| A section of a .tres/.tscn | `python tools/tres_edit.py list|get <file> [section]` |
| Change values safely | `python tools/tres_edit.py set <file> <section> key=value...` (section: node path like `Stats/MaxHealth`, sub_resource id, or `resource`) |
| Scale waves | `python tools/tres_edit.py scale-waves --count 1.5 --interval 0.8 <wave files>` |
| A 16x16 icon | grid file like `tools/icon/xp_gain_icon.txt`, then `python tools/gd.py icon <grid.txt> <out.png> [reference.png...]`; look at `<out>.preview.png` |

Options for `gd.py`: `--timeout <s>` (default 300), `--raw` (unfiltered Godot output).

## Writing a test
- Put `test_<topic>.gd` in `tools/tests/` (`extends RefCounted`); every `test_*` method gets a fresh `TestKit` and may `await`.
- `TestKit` (`tools/test/test_kit.gd`): `load_level(n)`, `level_data(n)`, `place("wall", cell)`, `spawn_enemy("weakling", spawner_index)`, `pick_card("damage", value)`, `run_until(callable, seconds)` (physics frames, game time), `frames(n)`, `find_cell(filter)`, `check(cond, msg)`, `check_near(a, b, msg)`.
- Game time is simulated (`--fixed-fps 60`): a 60 s enemy walk takes about a second of real time.
- Add a test when you build or fix a mechanic, so the next change is checked for free.

## Traps (each cost a lot of time once)
- `godot -s script.gd` has no autoloads (`GameSignals`, `Utils`, ...): game code fails to compile there. Only `tools/icon/draw_icon.gd` runs that way; everything else goes through the runner scene.
- Units need `Utils.game_control` (Main) with a `scene_manager.current_level`; `TestKit` sets a stub. Enemies read the level from it.
- `Building.level` is its parent's parent: buildings must sit in the level's `Buildings` container (`TestKit.place` does it).
- A new `class_name` is unknown to headless runs until an import (`gd.py` does it automatically).
- A script error after an `await` stops that coroutine for good; the runner's watchdog then prints `TIMEOUT in <test>`. Look for the SCRIPT ERROR line above it.
- Godot buffers its output when piped: a killed process prints nothing. Never kill it; let the runner's deadline or `--quit-after` end it.
- Never stop Godot with `taskkill /IM` (by image name): it also closes the user's editor. Stop a process only by its PID.
- The editor may be open on the project: files you change on disk (tile sets, scenes) can be written back by the editor in their old state if the user saves; tell them to reload.
