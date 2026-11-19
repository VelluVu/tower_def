"""Stronger waves for the levels the tuner left too easy at its health caps (2026-11-19, the user picked "fix the
too-easy levels"): Normal 17 and 38 were flawless at x2.0 health with every build, and Hard on 21, 27, 31, 33, 34, 39,
44, 45 and 47-50 was still won at 60% of the talent budget at x2.5.

    python tools/wave_pressure_2026_11.py          apply everything (rerunnable: earlier pushes are replaced)

- Normal 17, 38: PUSH_NORMAL groups added to the level's own wave files.
- Hard 21-34: a Hard of their own (the default Hard plus added groups, like 37-60 have), mixing in enemies that resist
  the area's best element: the swamp (Frost) gets armoured humans, eagles and priests; the Wasted Lands (Poison) get
  the poison-resistant swamp creatures (plaguepigs resist 75%, the others 40%).
- Hard 39-50: their added groups bring elites from the fourth wave, plus the area's flyers.
Then: python tools/match_spawns.py --fix and python tools/tune_levels.py <levels> --retune ...
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAVES = os.path.join(ROOT, "scenes", "level", "level_data", "waves", "level_%03d_wave_%d.tres")
DATA = os.path.join(ROOT, "scenes", "level", "level_data", "level_%03d_data.tres")
MODE = "res://scenes/level/level_data/modes/level_%03d_hard%s.tres"
PUSH_ID = "Resource_push%d"
HARD_DEFAULT = ["health_multiplier = 2.0", "speed_multiplier = 1.15", "count_multiplier = 1.4", "interval_multiplier = 0.85",
                "first_wave_share = 0.2", "last_wave_share = 1.0", "xp_multiplier = 1.5"]


def g(count, enemy, interval, spawner=0, delay=0.0, elites=0):
    return (count, enemy, interval, spawner, delay, elites)


# Normal: by wave number, the groups added to the level's own waves
PUSH_NORMAL = {
    # Frog Pools: hasted frogs, bloaters that burst on the maze, plaguepig tanks late
    17: {3: [g(4, "bloater", 2.4, 0, 6.0)],
         4: [g(3, "plaguepig", 3.6, 0, 4.0, 1)],
         5: [g(6, "bloater", 2.0, 0, 5.0), g(8, "leaper_frog", 1.2, 0, 10.0, 3)],
         6: [g(4, "plaguepig", 3.0, 0, 8.0, 2), g(10, "giant_wasp", 1.0, 1, 12.0, 2)]},
    # Ashen Road: grave callers raise thralls, revenant knights and drakes late
    38: {3: [g(2, "grave_caller", 4.0, 1, 6.0)],
         4: [g(3, "revenant_knight", 3.4, 2, 6.0, 1)],
         5: [g(3, "grave_caller", 3.6, 0, 8.0, 1), g(6, "ash_drake", 1.6, 1, 10.0)],
         6: [g(4, "revenant_knight", 3.0, 1, 6.0, 2), g(8, "ash_drake", 1.4, 2, 12.0, 2)]},
}

# Maze-friendly waves (the design doc's "Next, in order" 2: more, weaker enemies where a maze pays, since a maze pays per
# enemy walking it): the roomiest maps (`gd.py levels`, "maze room": 7+ open cells per route cell) get a swarm of their
# area's group unit from wave 2, growing each wave; the retune then lowers their health, so the waves end up with more,
# weaker enemies. Spawners are fixed afterwards by tools/match_spawns.py --fix (swarms come from roosts and hollows).
MAZE_LEVELS = {7: "swarmling", 14: "leechling", 15: "leechling", 16: "leechling", 25: "assault_dog", 31: "assault_dog",
               37: "scarab", 46: "scarab", 47: "scarab", 52: "ember_wisp", 53: "ember_wisp", 55: "ember_wisp", 59: "ember_wisp"}
SWARM_BASE, SWARM_GROWTH, SWARM_INTERVAL, SWARM_DELAY = 6, 3, 0.3, 4.0


def maze_swarms(level):
    return {n: [g(SWARM_BASE + SWARM_GROWTH * (n - 2), MAZE_LEVELS[level], SWARM_INTERVAL, 0, SWARM_DELAY)]
            for n in range(2, wave_count(level) + 1)}


# Hard of their own: by wave index (0-based), the first wave stays the level's own
SWAMP_MIX = [[], [g(4, "giant_eagle", 2.0, 0, 3.0)], [g(3, "armored_knight", 3.6, 0, 4.0)],
             [g(4, "cavalry", 3.0, 0, 4.0, 1), g(2, "priest", 4.4, 0, 8.0)],
             [g(8, "giant_eagle", 1.6, 0, 4.0, 2)], [g(6, "armored_knight", 3.0, 0, 4.0, 2), g(6, "cavalry", 2.6, 0, 9.0, 2)]]
FIELDS_MIX = [[], [g(10, "swampling", 1.2, 0, 3.0)], [g(3, "plaguepig", 3.6, 0, 4.0)],
              [g(8, "giant_wasp", 1.4, 0, 4.0, 1)], [g(4, "plaguepig", 3.2, 0, 4.0, 1), g(6, "bloater", 2.0, 0, 8.0)],
              [g(5, "swbeefling", 3.0, 0, 4.0, 2), g(5, "plaguepig", 3.0, 0, 9.0, 1)],
              [g(6, "plaguepig", 2.8, 0, 4.0, 2), g(10, "giant_wasp", 1.2, 0, 8.0, 2)]]
OWN_HARD = {21: SWAMP_MIX, 27: FIELDS_MIX, 31: FIELDS_MIX, 33: FIELDS_MIX, 34: FIELDS_MIX}

# Hard 39-50 (they have their mixes already): elites in the added groups from wave index 3, and flyers from index 3
PUSH_HARD = [39, 44, 45, 47, 48, 49, 50]
ELITES_FROM_WAVE = 3
ELITE_SHARE = 4  # one elite per this many enemies of a group, at least one


# Step two (after the first retune, 2026-11-19): these Hard sides still won at 60% of the budget at the x2.5 health
# cap, so their own Hard sends bigger, denser groups (the default Hard: count x1.4, interval x0.85)
HARD_DENSER = {level: ("1.8", "0.75") for level in (21, 39, 44, 45, 47, 48, 49, 50)}


# Step three (after the second retune, 2026-11-19, the user picked "stronger Hard waves"): these still won at 60% of
# the budget at x2.5, so a share of every group in their Hard waves (the level's own groups too) comes as elites,
# growing with the waves (LevelModeData.elite_share)
HARD_ELITES = {level: "0.3" for level in (21, 39, 44, 47, 48, 49)}


def set_elite_share(level):
    path = res_path(MODE % (level, ""))
    text = open(path, encoding="utf-8").read()
    text = re.sub(r"(?m)^elite_share = .*\n", "", text)
    text = re.sub(r"(?m)^(xp_multiplier = .*)$", r"\1\nelite_share = " + HARD_ELITES[level], text, count=1)
    open(path, "w", encoding="utf-8", newline="\n").write(text)


def make_denser(level):
    path = res_path(MODE % (level, ""))
    count, interval = HARD_DENSER[level]
    text = open(path, encoding="utf-8").read()
    text = re.sub(r"(?m)^count_multiplier = .*$", "count_multiplier = " + count, text)
    text = re.sub(r"(?m)^interval_multiplier = .*$", "interval_multiplier = " + interval, text)
    open(path, "w", encoding="utf-8", newline="\n").write(text)


def flyer_of(level):
    return "ash_drake" if level <= 48 else "phoenix"


def enemy_path(enemy):
    return "res://scenes/unit/enemy/enemies/%s.tscn" % enemy


def res_path(path):
    return os.path.join(ROOT, path.replace("res://", "").replace("/", os.sep))


def group_lines(sub_id, ext_id, group):
    count, enemy, interval, spawner, delay, elites = group
    lines = ['[sub_resource type="Resource" id="%s"]' % sub_id, 'script = ExtResource("2_group")',
             'enemy_scene = ExtResource("%s")' % ext_id, 'count = %d' % count, 'interval = %s' % float(interval)]
    if delay:
        lines.append('delay = %s' % float(delay))
    if spawner:
        lines.append('spawner_id = %d' % spawner)
    if elites:
        lines.append('elites = %d' % elites)
    return lines + ['']


def split_sections(text):
    """the header part (before the first sub_resource or resource) and the list of (header, lines) sections"""
    parts = re.split(r"(?m)^(?=\[(?:sub_resource|resource)\b)", text)
    head, sections = parts[0], []
    for part in parts[1:]:
        first, _, rest = part.partition("\n")
        sections.append((first, rest))
    return head, sections


def push_groups(path, groups):
    """adds groups to a WaveData file, after removing the ones an earlier run added (ids Resource_pushN)"""
    text = open(path, encoding="utf-8").read()
    head, sections = split_sections(text)
    kept = [(h, body) for h, body in sections if 'id="Resource_push' not in h]
    head_lines = head.rstrip("\n").split("\n")
    #enemy scene path -> its ext_resource id
    ext_ids = {p: i for p, i in re.findall(r'\[ext_resource type="PackedScene"[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"\]', head)}
    new_sections = []
    for n, group in enumerate(groups, 1):
        path_ = enemy_path(group[1])
        if path_ not in ext_ids:
            ext_ids[path_] = "e_push_%s" % group[1]
            head_lines.append('[ext_resource type="PackedScene" path="%s" id="%s"]' % (path_, ext_ids[path_]))
        new_sections.append(group_lines(PUSH_ID % n, ext_ids[path_], group))
    out = "\n".join(head_lines) + "\n\n"
    resource = None
    for h, body in kept:
        if h.startswith("[resource]"):
            resource = body
            continue
        out += h + "\n" + body
    for lines in new_sections:
        out += "\n".join(lines) + "\n"
    refs = ", ".join('SubResource("%s")' % (PUSH_ID % n) for n in range(1, len(groups) + 1))
    body = re.sub(r', SubResource\("Resource_push\d+"\)', "", resource)
    if refs:
        #the spawn_groups line, wherever it sits in the block (the early-start bonus may follow it)
        body = re.sub(r"(?m)^(spawn_groups = .*?)\]\)$", lambda m: m[1] + ", %s])" % refs, body)
    out += "[resource]\n" + body
    open(path, "w", encoding="utf-8", newline="\n").write(out.rstrip("\n") + "\n")


def write_wave_file(path, groups):
    enemies = sorted(set(group[1] for group in groups))
    out = ['[gd_resource type="Resource" script_class="WaveData" format=3]', '',
           '[ext_resource type="Script" uid="uid://cpw7ia3ek2yvs" path="res://scenes/level/level_data/wave_data.gd" id="1_wave"]',
           '[ext_resource type="Script" uid="uid://bbhd3iyjav4h2" path="res://scenes/level/level_data/spawn_group_data.gd" id="2_group"]']
    out += ['[ext_resource type="PackedScene" path="%s" id="e_%s"]' % (enemy_path(e), e) for e in enemies] + ['']
    ids = []
    for i, group in enumerate(groups, 1):
        ids.append('SubResource("Resource_group%d")' % i)
        out += group_lines("Resource_group%d" % i, "e_%s" % group[1], group)
    out += ['[resource]', 'script = ExtResource("1_wave")', 'spawn_groups = Array[ExtResource("2_group")]([%s])' % ', '.join(ids)]
    open(res_path(path), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")


def wave_count(level):
    return len(re.findall(r'path="res://scenes/level/level_data/waves/level_%03d_wave_\d+\.tres"' % level,
                          open(DATA % level, encoding="utf-8").read()))


def spawner_ids(level):
    """the spawner ids the level's own waves use (0 is the default)"""
    ids = {0}
    for n in range(1, wave_count(level) + 1):
        ids |= {int(i) for i in re.findall(r"spawner_id = (\d+)", open(WAVES % (level, n), encoding="utf-8").read())}
    return sorted(ids)


def write_own_hard(level, mix):
    spawners = spawner_ids(level)
    paths = []
    for i in range(wave_count(level)):
        groups = [(c, e, t, spawners[(i + k) % len(spawners)], d, el) for k, (c, e, t, _, d, el) in enumerate(mix[i] if i < len(mix) else mix[-1])]
        path = MODE % (level, "_wave_%d" % (i + 1))
        write_wave_file(path, groups)
        paths.append(path)
    out = ['[gd_resource type="Resource" script_class="LevelModeData" format=3]', '',
           '[ext_resource type="Script" path="res://scenes/level/level_data/level_mode_data.gd" id="1_mode"]',
           '[ext_resource type="Script" uid="uid://cpw7ia3ek2yvs" path="res://scenes/level/level_data/wave_data.gd" id="0_wave"]']
    out += ['[ext_resource type="Resource" path="%s" id="a%d"]' % (p, i) for i, p in enumerate(paths, 1)]
    out += ['', '[resource]', 'script = ExtResource("1_mode")'] + HARD_DEFAULT
    out.append('added_groups = Array[ExtResource("0_wave")]([%s])' % ", ".join('ExtResource("a%d")' % i for i in range(1, len(paths) + 1)))
    open(res_path(MODE % (level, "")), "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")

    data_path = DATA % level
    data = open(data_path, encoding="utf-8").read()
    if 'id="hard_mode"' not in data:
        ext = '[ext_resource type="Resource" path="%s" id="hard_mode"]' % (MODE % (level, ""))
        last_ext = list(re.finditer(r"(?m)^\[ext_resource[^\n]*\]$", data))[-1]
        data = data[:last_ext.end()] + "\n" + ext + data[last_ext.end():]
    #the property goes after the script line: one above it would be set before the script and lost
    data = data.replace('[resource]\nhard_mode = ExtResource("hard_mode")\n', '[resource]\n', 1)
    if 'hard_mode = ExtResource("hard_mode")' not in data:
        data = re.sub(r'(?m)^(\[resource\]\nscript = [^\n]*)$', r'\1' + '\nhard_mode = ExtResource("hard_mode")', data, count=1)
    open(data_path, "w", encoding="utf-8", newline="\n").write(data)


def push_hard(level):
    count = wave_count(level)
    spawners = spawner_ids(level)
    for n in range(1, count + 1):
        path = res_path(MODE % (level, "_wave_%d" % n))
        if not os.path.exists(path):
            continue
        text = open(path, encoding="utf-8").read()
        groups = []
        if n - 1 >= ELITES_FROM_WAVE:
            #elites in the existing added groups: written as push groups would double them, so set them in place
            def with_elites(m):
                block = m[0]
                if "elites = " in block or 'id="Resource_push' in block:
                    return block
                size = int(re.search(r"count = (\d+)", block)[1])
                return block.rstrip("\n") + "\nelites = %d\n\n" % max(1, size // ELITE_SHARE)
            text = re.sub(r'(?ms)^\[sub_resource type="Resource" id="Resource_group\d+"\].*?(?=^\[)', with_elites, text)
            open(path, "w", encoding="utf-8", newline="\n").write(text)
            groups.append(g(3 + n, flyer_of(level), 1.6, spawners[n % len(spawners)], 6.0, 1 if n >= count - 1 else 0))
        push_groups(path, groups)


def main():
    pushes = dict(PUSH_NORMAL)
    for level in MAZE_LEVELS:
        assert level not in pushes, "level %d has both a Normal push and a maze swarm" % level
        pushes[level] = maze_swarms(level)
    for level, waves in pushes.items():
        for n in range(1, wave_count(level) + 1):
            push_groups(WAVES % (level, n), waves.get(n, []))
        print("Normal %d: groups added to waves %s" % (level, sorted(waves)))
    for level, mix in OWN_HARD.items():
        write_own_hard(level, mix)
        print("Hard %d: its own Hard with %d waves of added groups" % (level, wave_count(level)))
    for level in PUSH_HARD:
        push_hard(level)
        print("Hard %d: elites from wave %d and %ss" % (level, ELITES_FROM_WAVE + 1, flyer_of(level)))
    for level in HARD_DENSER:
        make_denser(level)
        print("Hard %d: groups x%s, intervals x%s" % ((level,) + HARD_DENSER[level]))
    for level in HARD_ELITES:
        set_elite_share(level)
        print("Hard %d: elite share %s" % (level, HARD_ELITES[level]))


if __name__ == "__main__":
    main()
