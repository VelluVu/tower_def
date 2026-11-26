"""Put the sixteen enemies of 2026-11-25 into their areas' waves: one extra spawn group each in two or three levels
(the first one introduces it). Placeholder counts: the balancing comes after the bug rounds. Rerunnable: it replaces
the groups it added before. Then run python tools/match_spawns.py --fix.

    python tools/units_2026_11_25_waves.py
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAVES = os.path.join(ROOT, "scenes", "level", "level_data", "waves")
MARK = "u1125"

# unit: [(level, wave, count, interval, delay)]; levels 6/7 and 8/9 swapped places on 2026-11-25 (the caves' new
# route), these follow their level, the tunnel rats stay at 7 with the Egg Bomb
PLACES = {
    # Caves: their waves are written whole by tools/caves_pass_2026_11_26.py since 2026-11-26 (it places these four)
    # Swamp
    "snapping_turtle": [(15, 5, 3, 4.0, 6.0), (22, 5, 4, 4.0, 5.0), (24, 5, 4, 4.0, 4.0)],
    "leech_mother": [(16, 4, 2, 8.0, 5.0), (20, 5, 3, 7.0, 4.0)],
    "mosquito": [(17, 3, 10, 0.4, 6.0), (19, 4, 12, 0.4, 5.0)],
    "bog_witch": [(18, 4, 2, 6.0, 8.0), (21, 5, 2, 6.0, 6.0), (23, 4, 3, 5.0, 6.0)],
    # Humans
    "war_drummer": [(25, 5, 2, 6.0, 3.0), (28, 4, 2, 6.0, 4.0)],
    "shieldbearer": [(26, 5, 2, 5.0, 4.0), (30, 5, 3, 5.0, 4.0), (34, 6, 3, 5.0, 4.0)],
    "battering_ram": [(29, 5, 2, 10.0, 6.0), (32, 6, 2, 10.0, 6.0), (35, 6, 3, 9.0, 5.0)],
    "crossbow_sniper": [(31, 4, 2, 6.0, 8.0), (33, 5, 2, 6.0, 6.0), (36, 5, 3, 6.0, 6.0)],
    # Scorched Lands
    "sand_wurm": [(38, 4, 3, 5.0, 5.0), (42, 4, 3, 5.0, 5.0), (46, 5, 4, 5.0, 5.0)],
    "bone_vulture": [(40, 3, 6, 0.6, 4.0), (44, 4, 8, 0.6, 4.0)],
    "mummy_priest": [(41, 4, 2, 6.0, 6.0), (45, 5, 3, 6.0, 6.0), (47, 5, 3, 6.0, 5.0)],
    "ash_harpy": [(50, 4, 4, 2.0, 5.0), (55, 4, 5, 2.0, 5.0), (58, 5, 6, 2.0, 5.0)],
    # the second round: each where the tower it answers has just come
    "tunnel_rat": [(7, 5, 10, 0.4, 4.0), (10, 5, 12, 0.4, 4.0), (12, 5, 12, 0.4, 6.0)],
    "bog_lurker": [(20, 4, 3, 4.0, 5.0), (22, 6, 4, 4.0, 5.0), (23, 5, 4, 4.0, 4.0)],
    "standard_bearer": [(27, 5, 2, 6.0, 5.0), (33, 6, 2, 6.0, 5.0), (36, 6, 3, 6.0, 5.0)],
    "ash_wraith": [(39, 4, 4, 3.0, 5.0), (43, 5, 5, 3.0, 5.0), (53, 4, 5, 3.0, 5.0)],
}


def clean(text):
    """drops what an earlier run added"""
    text = re.sub(r'\[ext_resource [^\n]*id="e_%s_[^"]*"\]\n' % MARK, "", text)
    text = re.sub(r'\[sub_resource type="Resource" id="Resource_%s_[^"]*"\]\n(?:[^\[\n][^\n]*\n)*\n' % MARK, "", text)
    text = re.sub(r', SubResource\("Resource_%s_[^"]*"\)' % MARK, "", text)
    return text


def add(text, unit, count, interval, delay):
    ext = '[ext_resource type="PackedScene" path="res://scenes/unit/enemy/enemies/%s.tscn" id="e_%s_%s"]\n' % (unit, MARK, unit)
    last_ext = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
    text = text[:last_ext] + ext + text[last_ext:]
    group = ('[sub_resource type="Resource" id="Resource_%s_%s"]\nscript = ExtResource("2_group")\nenemy_scene = ExtResource("e_%s_%s")\n'
             'count = %d\ninterval = %s\ndelay = %s\n\n' % (MARK, unit, MARK, unit, count, interval, delay))
    resource = text.index("[resource]")
    text = text[:resource] + group + text[resource:]
    return re.sub(r'(spawn_groups = Array\[ExtResource\("[^"]+"\)\]\(\[[^\]]*)\]', r'\1, SubResource("Resource_%s_%s")]' % (MARK, unit), text, count=1)


def main():
    by_file = {}
    for unit, places in PLACES.items():
        for level, wave, count, interval, delay in places:
            by_file.setdefault("level_%03d_wave_%d.tres" % (level, wave), []).append((unit, count, interval, delay))
    # earlier runs' groups go from every wave file, so a place taken out of the table goes too
    for name in sorted(os.listdir(WAVES)):
        if not name.endswith(".tres"):
            continue
        path = os.path.join(WAVES, name)
        text = open(path, encoding="utf8").read()
        new = clean(text)
        for unit, count, interval, delay in by_file.pop(name, []):
            if '"2_group"' not in new:
                raise SystemExit("%s: no SpawnGroupData script id 2_group" % name)
            new = add(new, unit, count, interval, delay)
        if new != text:
            open(path, "w", encoding="utf8", newline="\n").write(new)
            print("wrote", name)
    for name in by_file:
        print("MISSING wave file", name)


if __name__ == "__main__":
    main()
