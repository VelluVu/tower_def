"""The level pass for the Caves, levels 1-12 (2026-11-26, the user's pick: waves per level, composition first).

    python tools/caves_pass_2026_11_26.py            write the wave files and health ramps of levels 1-12
    python tools/caves_pass_2026_11_26.py 5 6        only those levels

Owns the Caves' waves from now on: every wave file of 1-12 is written whole from WAVES below (each file keeps its uid
and early start bonus), and each LevelData gets its health ramp from RAMPS with health_scale 1.0 (the tuner's uneven
scales are gone). The curve (design doc, Normal's difficulty curve): each level a little harder than the one before,
the Broodmother's lair (12) the peak. More enemies, in surges from several spawners with gaps, the later cave kinds
mixed in towards 12; each kind still first comes on the level and wave whose Puffe line introduces it. No elites:
they are first met in Wasp Hollow (19). Then: python tools/match_spawns.py (nothing should move) and gd.py levels.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WAVE_FILE = os.path.join(ROOT, "scenes", "level", "level_data", "waves", "level_%03d_wave_%d.tres")
DATA_FILE = os.path.join(ROOT, "scenes", "level", "level_data", "level_%03d_data.tres")
ENEMY = "res://scenes/unit/enemy/enemies/%s.tscn"


def g(enemy, count, interval, spawner=0, delay=0.0):
    return (enemy, count, interval, spawner, delay)


# level -> (first wave health, last wave health); the wave health ramp, health_scale 1.0
# a wave 1 must fall to what the start gold builds: the first bot check lost 8, 10 and 12 at wave 1 with x2.9-3.4
RAMPS = {1: (1.0, 2.4), 2: (1.3, 2.9), 3: (1.6, 3.4), 4: (1.9, 4.6), 5: (2.2, 5.2), 6: (2.5, 5.0),
         7: (2.2, 5.0), 8: (1.8, 5.6), 9: (2.2, 5.9), 10: (2.3, 6.2), 11: (3.0, 6.0), 12: (2.3, 6.8)}

# level -> waves -> groups; spawner ids per level (python tools/match_spawns.py's kinds):
# 1, 2 caves 0-2 | 3 roost 0, caves 1-2 | 4 cave 0, den 1 | 5 hollow 0, den 1, cave 2 | 6 cave 0, den 1, roost 2,
# cave 3 (the new tunnel from wave 5) | 7 cave 0, den 1, roost 2 | 8 den 0, cave 1 | 9 cave 0, den 1, roost 2, cave 3
# | 10 den 0, cave 1, plain 2 (the scouts) | 11 plain 0, 1 | 12 cave 0, den 1 (the nest), cave 2
WAVES = {
    # Puffe's Hollow: the tutorial, weaklings only, Bolters only
    1: [[g("weakling", 12, 3.0, 0)],
        [g("weakling", 18, 2.6, 1)],
        [g("weakling", 12, 2.6, 2), g("weakling", 6, 2.6, 0, 14.0)]],
    # Mossy Keep: the fastlings (wave 3), the Beamer
    2: [[g("weakling", 14, 3.0, 1)],
        [g("weakling", 20, 2.4, 2)],
        [g("fastling", 22, 1.5, 0)],
        [g("fastling", 14, 1.4, 1), g("weakling", 12, 2.2, 0, 2.0), g("weakling", 8, 2.0, 2, 10.0)]],
    # Stonebrook Castle: the swarms (wave 2), the Nova
    3: [[g("weakling", 16, 3.0, 1)],
        [g("swarmling", 12, 0.3, 0), g("weakling", 12, 2.4, 2, 3.0), g("swarmling", 12, 0.3, 0, 14.0)],
        [g("fastling", 14, 1.5, 2), g("swarmling", 12, 0.3, 0, 4.0), g("weakling", 10, 2.2, 1, 6.0),
         g("swarmling", 12, 0.3, 0, 18.0)],
        [g("weakling", 16, 1.8, 1), g("swarmling", 14, 0.3, 0, 2.0), g("fastling", 12, 1.4, 2, 6.0),
         g("swarmling", 14, 0.3, 0, 14.0), g("swarmling", 14, 0.3, 0, 26.0)]],
    # Forest Fork: the beeflings (wave 2), the Leopard Trap
    4: [[g("weakling", 16, 2.4, 0), g("fastling", 6, 1.8, 0, 20.0)],
        [g("beefling", 5, 3.6, 1), g("weakling", 12, 2.6, 0)],
        [g("fastling", 20, 1.4, 0), g("swarmling", 12, 0.3, 1, 4.0), g("swarmling", 12, 0.3, 1, 16.0)],
        [g("beefling", 9, 3.4, 1), g("weakling", 18, 1.8, 0), g("fastling", 10, 1.3, 0, 18.0)],
        [g("beefling", 12, 2.8, 1), g("weakling", 20, 1.6, 0), g("swarmling", 14, 0.3, 1, 6.0),
         g("fastling", 14, 1.2, 0, 12.0), g("swarmling", 14, 0.3, 1, 24.0)]],
    # Crossroads: the spore carriers (wave 4), the Spike Field
    5: [[g("weakling", 10, 3.0, 2), g("weakling", 10, 3.0, 2, 15.0), g("fastling", 6, 2.0, 2, 30.0)],
        [g("beefling", 5, 3.6, 1), g("weakling", 18, 1.8, 2), g("swarmling", 12, 0.3, 0, 10.0)],
        [g("beefling", 7, 3.4, 1), g("fastling", 20, 1.2, 2), g("swarmling", 12, 0.3, 0, 4.0),
         g("swarmling", 12, 0.3, 0, 20.0)],
        [g("beefling", 12, 2.8, 1), g("fastling", 20, 1.4, 2), g("spore_carrier", 5, 2.5, 2, 4.0),
         g("weakling", 22, 1.5, 2, 8.0)],
        [g("beefling", 16, 2.4, 1), g("fastling", 24, 1.1, 2), g("swarmling", 14, 0.3, 0, 6.0),
         g("weakling", 24, 1.4, 2, 10.0), g("spore_carrier", 6, 2.2, 2, 20.0), g("swarmling", 14, 0.3, 0, 26.0)]],
    # Echo Crossing: the batlings (wave 2), the new tunnel in the north-east (3) from wave 5
    6: [[g("weakling", 12, 2.8, 0), g("fastling", 8, 2.2, 0, 12.0)],
        [g("batling", 6, 1.8, 2), g("weakling", 12, 2.2, 0), g("swarmling", 10, 0.3, 2, 8.0),
         g("swarmling", 8, 0.3, 2, 22.0)],
        [g("beefling", 7, 3.2, 1), g("fastling", 20, 1.2, 0), g("swarmling", 12, 0.3, 2, 4.0),
         g("batling", 10, 1.6, 2, 10.0)],
        [g("beefling", 10, 2.8, 1), g("fastling", 22, 1.1, 0), g("swarmling", 12, 0.3, 2, 4.0),
         g("batling", 10, 1.6, 2, 10.0), g("spore_carrier", 4, 2.5, 0, 16.0), g("swarmling", 12, 0.3, 2, 26.0)],
        [g("beefling", 13, 2.5, 1), g("weakling", 24, 1.3, 0), g("swarmling", 16, 0.3, 2, 4.0),
         g("fastling", 18, 1.1, 3, 6.0), g("batling", 14, 1.3, 2, 10.0), g("spore_carrier", 6, 2.2, 0, 18.0),
         g("swarmling", 16, 0.3, 2, 26.0)],
        [g("beefling", 16, 2.2, 1), g("fastling", 26, 1.0, 3), g("swarmling", 16, 0.3, 2, 2.0),
         g("weakling", 24, 1.3, 0, 6.0), g("batling", 18, 1.1, 2, 8.0), g("swarmling", 16, 0.3, 2, 18.0),
         g("spore_carrier", 6, 2.0, 0, 20.0), g("swarmling", 16, 0.3, 2, 34.0)]],
    # Bat Roost: flyers all through, the glow moths (wave 3), the tunnel rats (wave 5), the Egg Bomb
    7: [[g("weakling", 14, 2.4, 0), g("fastling", 10, 1.8, 0, 10.0), g("batling", 6, 2.0, 2, 16.0)],
        [g("batling", 10, 1.6, 2), g("weakling", 16, 1.8, 0), g("swarmling", 12, 0.3, 2, 12.0)],
        [g("fastling", 18, 1.2, 0), g("batling", 9, 1.6, 2, 4.0), g("glow_moth", 8, 0.5, 2, 10.0),
         g("swarmling", 10, 0.3, 2, 16.0), g("beefling", 6, 3.0, 1, 18.0)],
        [g("beefling", 10, 2.8, 1), g("batling", 14, 1.3, 2), g("weakling", 22, 1.4, 0, 4.0),
         g("glow_moth", 12, 0.5, 2, 18.0), g("swarmling", 14, 0.3, 2, 28.0)],
        [g("beefling", 14, 2.4, 1), g("fastling", 24, 1.0, 0), g("swarmling", 16, 0.3, 2, 4.0),
         g("batling", 18, 1.1, 2, 6.0), g("tunnel_rat", 12, 0.4, 0, 14.0), g("swarmling", 16, 0.3, 2, 24.0),
         g("glow_moth", 12, 0.5, 2, 30.0)]],
    # Crystal Deep: burrowers (wave 2), crystal brutes and wall crawlers (3), destroyerlings (4); no roost
    8: [[g("weakling", 12, 2.6, 1), g("beefling", 3, 3.6, 0, 10.0), g("fastling", 8, 1.8, 1, 16.0)],
        [g("burrower", 8, 2.2, 1), g("beefling", 5, 3.4, 0), g("weakling", 14, 2.0, 1, 4.0)],
        [g("crystal_brute", 5, 3.8, 0), g("fastling", 18, 1.2, 1), g("burrower", 10, 1.8, 1, 10.0),
         g("wall_crawler", 6, 2.0, 1, 20.0)],
        [g("destroyerling", 5, 3.6, 1), g("beefling", 10, 2.8, 0), g("weakling", 22, 1.4, 1, 6.0),
         g("wall_crawler", 8, 1.8, 1, 24.0)],
        [g("crystal_brute", 6, 3.4, 0), g("burrower", 14, 1.4, 1), g("fastling", 24, 1.0, 1, 4.0),
         g("destroyerling", 5, 3.4, 1, 12.0), g("wall_crawler", 6, 1.8, 1, 30.0)],
        [g("crystal_brute", 7, 3.0, 0), g("destroyerling", 6, 3.0, 1), g("burrower", 16, 1.3, 1, 6.0),
         g("fastling", 26, 0.9, 1, 14.0), g("beefling", 12, 2.4, 0, 20.0), g("wall_crawler", 8, 1.6, 1, 34.0)]],
    # Collapsed Tunnels: everything so far from four mouths, the cave shamans (wave 5)
    9: [[g("weakling", 16, 2.2, 0), g("fastling", 12, 1.6, 3, 8.0)],
        [g("weakling", 14, 1.8, 0), g("swarmling", 8, 0.4, 2, 8.0), g("batling", 8, 1.8, 2, 14.0),
         g("burrower", 6, 2.2, 3, 18.0), g("swarmling", 8, 0.4, 2, 30.0)],
        [g("beefling", 10, 2.8, 1), g("fastling", 22, 1.1, 0), g("batling", 12, 1.4, 2, 8.0),
         g("burrower", 8, 1.8, 3, 16.0)],
        [g("beefling", 12, 2.6, 1), g("weakling", 24, 1.3, 0), g("batling", 14, 1.3, 2, 4.0),
         g("swarmling", 14, 0.3, 2, 12.0), g("wall_crawler", 6, 1.8, 3, 18.0), g("glow_moth", 12, 0.5, 2, 24.0)],
        [g("beefling", 15, 2.3, 1), g("fastling", 26, 1.0, 3), g("swarmling", 14, 0.3, 2, 4.0),
         g("batling", 16, 1.2, 2, 6.0), g("cave_shaman", 3, 5.0, 0, 10.0), g("weakling", 16, 1.4, 0, 14.0),
         g("swarmling", 14, 0.3, 2, 24.0)],
        [g("beefling", 18, 2.0, 1), g("fastling", 28, 0.9, 0), g("swarmling", 16, 0.3, 2, 4.0),
         g("weakling", 26, 1.2, 3, 6.0), g("batling", 20, 1.0, 2, 8.0), g("cave_shaman", 3, 4.0, 3, 18.0),
         g("swarmling", 16, 0.3, 2, 26.0), g("crystal_brute", 4, 3.4, 1, 30.0)]],
    # Lakeshore Watch: the cave folk's last push, human scouts at the end (wave 6), the Hoard Keeper
    10: [[g("weakling", 14, 2.4, 1), g("fastling", 10, 1.8, 1, 14.0), g("beefling", 3, 3.6, 0, 18.0)],
         [g("beefling", 8, 3.0, 0), g("batling", 12, 1.6, 1), g("swarmling", 14, 0.3, 0, 6.0),
          g("swarmling", 14, 0.3, 1, 20.0)],
         [g("fastling", 26, 1.0, 1), g("beefling", 10, 2.8, 0), g("swarmling", 14, 0.3, 1, 4.0),
          g("swarmling", 14, 0.3, 0, 18.0), g("burrower", 8, 1.8, 1, 24.0)],
         [g("beefling", 14, 2.4, 0), g("weakling", 26, 1.2, 1), g("batling", 16, 1.2, 1, 6.0),
          g("cave_shaman", 3, 5.0, 1, 8.0), g("wall_crawler", 6, 1.8, 1, 20.0)],
         [g("beefling", 18, 2.1, 0), g("fastling", 28, 0.9, 1), g("swarmling", 14, 0.3, 0, 4.0),
          g("batling", 18, 1.1, 1, 6.0), g("tunnel_rat", 14, 0.4, 1, 12.0), g("swarmling", 14, 0.3, 1, 22.0),
          g("crystal_brute", 5, 3.4, 0, 26.0)],
         [g("beefling", 20, 2.0, 0), g("fastling", 28, 0.9, 1), g("swarmling", 16, 0.3, 0, 4.0),
          g("batling", 18, 1.0, 1, 6.0), g("cave_shaman", 3, 4.0, 1, 14.0), g("scout", 10, 1.4, 2, 20.0),
          g("swarmling", 16, 0.3, 1, 24.0)]],
    # Barricade Bridge: the humans hold the bridge: soldiers, scouts, dogs (wave 3), eagles (wave 3), the Hatchery
    11: [[g("soldier", 14, 2.6, 0)],
         [g("soldier", 14, 2.3, 1), g("scout", 10, 1.8, 0, 6.0)],
         [g("assault_dog", 12, 0.3, 0), g("soldier", 14, 2.1, 1), g("giant_eagle", 4, 1.8, 0, 8.0),
          g("assault_dog", 12, 0.3, 1, 14.0)],
         [g("soldier", 18, 1.8, 0), g("scout", 16, 1.3, 1, 4.0), g("assault_dog", 14, 0.3, 1, 12.0),
          g("giant_eagle", 5, 1.6, 0, 18.0)],
         [g("soldier", 24, 1.5, 1), g("assault_dog", 14, 0.3, 0, 4.0), g("scout", 20, 1.1, 0, 6.0),
          g("giant_eagle", 7, 1.4, 0, 14.0), g("assault_dog", 14, 0.3, 1, 22.0)]],
    # Broodmother's Lair: the Caves' peak, the whole brood, then her (wave 6, from the nest)
    12: [[g("weakling", 14, 2.4, 2), g("fastling", 10, 1.8, 0, 12.0)],
         [g("beefling", 6, 3.2, 1), g("weakling", 18, 1.6, 2), g("swarmling", 14, 0.3, 0, 6.0),
          g("burrower", 8, 2.0, 0, 16.0)],
         [g("fastling", 20, 1.2, 0), g("beefling", 8, 3.0, 1), g("swarmling", 12, 0.3, 2, 6.0),
          g("batling", 10, 1.6, 2, 10.0), g("swarmling", 12, 0.3, 0, 24.0), g("wall_crawler", 6, 1.8, 2, 28.0)],
         [g("beefling", 10, 2.8, 1), g("fastling", 22, 1.2, 2), g("weakling", 18, 1.4, 0, 6.0),
          g("cave_shaman", 3, 5.0, 0, 10.0), g("crystal_brute", 3, 3.4, 1, 20.0),
          g("destroyerling", 3, 3.4, 2, 26.0)],
         [g("beefling", 16, 2.2, 1), g("fastling", 28, 0.9, 0), g("weakling", 24, 1.2, 2, 4.0),
          g("swarmling", 16, 0.3, 0, 4.0), g("batling", 16, 1.1, 2, 8.0), g("wall_crawler", 8, 1.6, 0, 14.0),
          g("swarmling", 16, 0.3, 2, 24.0), g("tunnel_rat", 14, 0.4, 0, 30.0)],
         [g("beefling", 10, 2.8, 1), g("fastling", 20, 1.2, 2), g("weakling", 18, 1.4, 0),
          g("batling", 12, 1.4, 2, 8.0), g("cave_shaman", 3, 5.0, 0, 12.0), g("broodmother", 1, 1.0, 1, 20.0)]],
}


def wave_text(uid, bonus, groups):
    kinds = sorted({group[0] for group in groups})
    lines = ['[gd_resource type="Resource" script_class="WaveData" format=3%s]' % (' uid="%s"' % uid if uid else ""), "",
             '[ext_resource type="Script" uid="uid://cpw7ia3ek2yvs" path="res://scenes/level/level_data/wave_data.gd" id="1_wave"]',
             '[ext_resource type="Script" uid="uid://bbhd3iyjav4h2" path="res://scenes/level/level_data/spawn_group_data.gd" id="2_group"]']
    lines += ['[ext_resource type="PackedScene" path="%s" id="e_%s"]' % (ENEMY % kind, kind) for kind in kinds]
    lines.append("")
    ids = []
    for index, (enemy, count, interval, spawner, delay) in enumerate(groups, 1):
        ids.append("Resource_group%d" % index)
        lines += ['[sub_resource type="Resource" id="%s"]' % ids[-1], 'script = ExtResource("2_group")',
                  'enemy_scene = ExtResource("e_%s")' % enemy, "count = %d" % count, "interval = %r" % float(interval)]
        if delay:
            lines.append("delay = %r" % float(delay))
        if spawner:
            lines.append("spawner_id = %d" % spawner)
        lines.append("")
    lines += ["[resource]", 'script = ExtResource("1_wave")',
              "spawn_groups = Array[ExtResource(\"2_group\")]([%s])" % ", ".join('SubResource("%s")' % i for i in ids)]
    if bonus:
        lines.append("early_start_bonus = %s" % bonus)
    return "\n".join(lines) + "\n"


def write_level(level):
    for number, groups in enumerate(WAVES[level], 1):
        path = WAVE_FILE % (level, number)
        old = open(path, encoding="utf-8").read()
        uid = re.search(r'^\[gd_resource[^\]]*uid="([^"]+)"', old)
        bonus = re.search(r"^early_start_bonus = (\S+)", old, re.M)
        with open(path, "w", encoding="utf-8", newline="\n") as file:
            file.write(wave_text(uid[1] if uid else "", bonus[1] if bonus else "", groups))
    data = DATA_FILE % level
    text = open(data, encoding="utf-8").read()
    first, last = RAMPS[level]
    for key, value in (("first_wave_health", first), ("last_wave_health", last), ("health_scale", 1.0)):
        line = "%s = %r" % (key, float(value))
        if re.search(r"^%s = " % key, text, re.M):
            text = re.sub(r"^%s = .*$" % key, line, text, flags=re.M)
        else:
            text = re.sub(r"^(waves = .*)$", r"\1\n" + line.replace("\\", "\\\\"), text, count=1, flags=re.M)
    with open(data, "w", encoding="utf-8", newline="\n") as file:
        file.write(text)
    print("level %d: %d waves, %d enemies, health x%s -> x%s" % (level, len(WAVES[level]),
          sum(group[1] for wave in WAVES[level] for group in wave), first, last))


def main():
    levels = [int(arg) for arg in sys.argv[1:]] or sorted(WAVES)
    for level in levels:
        old_count = len([n for n in range(1, 20) if os.path.exists(WAVE_FILE % (level, n))])
        if old_count != len(WAVES[level]):
            sys.exit("level %d has %d wave files, the table %d: Puffe's lines count on the wave numbers" % (level, old_count, len(WAVES[level])))
        write_level(level)


if __name__ == "__main__":
    main()
