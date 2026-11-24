"""Check that every wave group comes out of a spawn point of its own kind (cave folk from caves, tanks from dens,
swamp folk from hollows, flyers and swarms from roosts), and fix the groups that don't.

    python tools/match_spawns.py            report the groups whose spawner is of another kind
    python tools/match_spawns.py --fix      move them to a spawner of their kind (taking turns when there are several)

A group stays where it is when its level has no spawner of the enemy's kind, or when the enemy has no kind (the
humans march in from plain spawners and the map's edge, bosses come from wherever the level puts them).
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEVELS = os.path.join(ROOT, "scenes", "level", "levels")
KIND_OF_ENEMY = {
    "weakling": "cave", "fastling": "cave", "destroyerling": "cave",
    "beefling": "den", "swbeefling": "den", "plaguepig": "den",
    "swampling": "hollow", "fastswampling": "hollow", "leechling": "hollow",
    "batling": "roost", "swarmling": "roost", "giant_wasp": "roost",
    "burrower": "cave", "crystal_brute": "den", "leaper_frog": "hollow", "bloater": "den",
}
SPAWN_KIND = re.compile(r'spawn_points/spawn_(\w+)\.tscn')
# a boss lair's own spawn art stands in for a kind: the Broodmother's nest is the Brood Cavern's den
SPAWN_KIND_ALIAS = {"nest": "den"}


def res_path(path):
    return os.path.join(ROOT, path.replace("res://", "").replace("/", os.sep))


def spawners(level_text):
    """spawner id -> kind (cave, den, hollow, roost, or plain)."""
    ext = {m.group(2): m.group(1) for m in re.finditer(r'\[ext_resource type="PackedScene"[^\]]*path="([^"]+)" id="([^"]+)"\]', level_text)}
    found = {}
    # the header has groups=["Spawner"], so match to the line's end, not to the first ]
    for m in re.finditer(r'\[node name="Spawner\d*"[^\n]*instance=ExtResource\("([^"]+)"\)\]\n((?:[^\[\n][^\n]*\n)*)', level_text):
        kind = SPAWN_KIND.search(ext.get(m.group(1), ""))
        sid = re.search(r'^id = (\d+)', m.group(2), re.M)
        found[int(sid.group(1)) if sid else 0] = SPAWN_KIND_ALIAS.get(kind.group(1), kind.group(1)) if kind else "plain"
    return found


def waves(level_number):
    data = res_path("res://scenes/level/level_data/level_%03d_data.tres" % level_number)
    if not os.path.exists(data):
        return []
    text = open(data, encoding="utf8").read()
    return [res_path(p) for p in re.findall(r'path="(res://scenes/level/level_data/waves/[^"]+)"', text)]


def groups(wave_text):
    """(start, end, enemy name, spawner id) of every spawn group sub_resource."""
    ext = {m.group(2): os.path.splitext(os.path.basename(m.group(1)))[0]
           for m in re.finditer(r'\[ext_resource type="PackedScene"[^\]]*path="([^"]+)" id="([^"]+)"\]', wave_text)}
    out = []
    for m in re.finditer(r'\[sub_resource type="Resource" id="[^"]+"\]\n((?:[^\[\n][^\n]*\n)*)', wave_text):
        body = m.group(1)
        enemy = re.search(r'enemy_scene = ExtResource\("([^"]+)"\)', body)
        if not enemy:
            continue
        sid = re.search(r'^spawner_id = (\d+)', body, re.M)
        out.append((m.start(1), m.end(1), ext.get(enemy.group(1), "?"), int(sid.group(1)) if sid else 0))
    return out


def main(fix):
    moved = left = 0
    turns = {}
    for name in sorted(os.listdir(LEVELS)):
        number = int(re.search(r'(\d+)', name).group(1))
        kinds = spawners(open(os.path.join(LEVELS, name), encoding="utf8").read())
        wave_paths = waves(number)
        # a spawner a level first uses in a later wave opens then (Echo Crossing's north-east cave in wave 5):
        # never move a group onto it before that wave
        opens = {}
        for index, wave_path in enumerate(wave_paths):
            for _, _, _, sid in groups(open(wave_path, encoding="utf8").read()):
                opens.setdefault(sid, index)
        for index, wave_path in enumerate(wave_paths):
            text = open(wave_path, encoding="utf8").read()
            changed = False
            for start, end, enemy, sid in reversed(groups(text)):
                want = KIND_OF_ENEMY.get(enemy)
                if want is None or kinds.get(sid) == want:
                    continue
                matching = sorted(i for i, k in kinds.items() if k == want and opens.get(i, 0) <= index)
                wave = os.path.basename(wave_path)
                if not matching:
                    left += 1
                    print("level %d %s: %s from %s spawner %d, no %s in the level" % (number, wave, enemy, kinds.get(sid), sid, want))
                    continue
                # several spawners of the kind: the moved groups take turns, so the level keeps its spread
                turn = turns.get((number, want), 0)
                turns[(number, want)] = turn + 1
                target = matching[turn % len(matching)]
                print("level %d %s: %s from %s spawner %d -> %s spawner %d" % (number, wave, enemy, kinds.get(sid), sid, want, target))
                moved += 1
                if fix:
                    body = re.sub(r'^spawner_id = \d+\n', '', text[start:end], flags=re.M)
                    if target:
                        body = body.rstrip("\n") + "\nspawner_id = %d\n" % target
                    text = text[:start] + body + text[end:]
                    changed = True
            if changed:
                open(wave_path, "w", encoding="utf8", newline="\n").write(text)
    print("%d groups %s, %d without a spawner of their kind" % (moved, "moved" if fix else "to move", left))


if __name__ == "__main__":
    main("--fix" in sys.argv[1:])
