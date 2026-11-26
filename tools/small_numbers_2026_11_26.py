"""Small numbers (2026-11-26, the user: "we should keep it very small, like bolter 1 damage, beamer 0.2 dmg per second,
nova 0.25"): one pass over the data, run once.

    python tools/small_numbers_2026_11_26.py          rewrite the enemy and tower scenes
    python tools/small_numbers_2026_11_26.py --dry    print what would change

Enemy side, by HEALTH_SCALE (1/8, the Bolter's 8 -> 1): every enemy's MaxHealth and Health, and its fixed regeneration
(an OvertimeEffectData with a negative tick_damage). Tower side: each tower's own Damage stat goes to 0 and its skill's
Damage holds the whole hit, the user's numbers for Bolter, Beamer and Nova, HEALTH_SCALE for the rest (so the Beamer
and the Nova end up weaker against the others than before: the user's call). The building side (building health,
enemy attacks on buildings, leak costs) keeps its numbers. Code constants that hit enemies with a fixed number
(MazeElements, the wall's strike-backs) and XP per max health change by hand with it.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEALTH_SCALE = 1.0 / 8.0
ENEMIES = os.path.join(ROOT, "scenes", "unit", "enemy", "enemies", "*.tscn")
TOWERS = os.path.join(ROOT, "scenes", "unit", "building", "buildings", "%s.tscn")
# tower -> (its skill node, the whole hit after the pass); the old hit is the tower's Damage + the skill's
TOWER_HITS = {
    "puffe_bolter": ("LaunchProjectile", 1.0),   # was 8
    "puffe_beamer": ("Beam", 0.3),               # was 5 a tick, a tick every 1.5 s: 0.2 a second
    "puffe_nova": ("LaunchProjectile", 0.25),    # was 5
    "leopard_trap": ("LeopardClaws", 1.6),       # was 13
    "egg_bomb": ("EggBlast", 10.0),              # was 81
    "puffe_breather": ("Breath", 0.31),          # was 2.5
    "puffe_elder": ("LaunchProjectile", 1.9),    # was 15
    "puffe_harpooner": ("LaunchProjectile", 0.75),  # was 6
    "puffe_hatchery": ("Hatch", 0.5),            # was 4
    "puffe_mortar": ("LaunchProjectile", 1.1),   # was 9
    "puffe_shredder": ("LaunchProjectile", 0.31),  # was 2.5
    "puffe_spotter": ("LaunchProjectile", 1.75),   # was 14
    "spike_field": ("Spikes", 0.5),              # was 4
    "puffe_buffer": ("Aura", 0.0),
    "puffe_hoard": ("Aura", 0.0),
}


def number(value):
    return repr(round(value, 4))


def set_stat(text, node_path, value):
    """Sets base_value and value of the Stat node at node_path (parent/name)."""
    parent, name = node_path.rsplit("/", 1)
    pattern = r'(\[node name="%s" type="Node" parent="%s"[^\]]*\][^\[]*?\nbase_value = )[-\d.e]+(\nvalue = )[-\d.e]+' % (re.escape(name), re.escape(parent))
    new, count = re.subn(pattern, lambda m: m.group(1) + number(value) + m.group(2) + number(value), text)
    if count != 1:
        raise SystemExit("%s: %d matches" % (node_path, count))
    return new


def get_stat(text, node_path):
    parent, name = node_path.rsplit("/", 1)
    match = re.search(r'\[node name="%s" type="Node" parent="%s"[^\]]*\][^\[]*?\nbase_value = ([-\d.e]+)' % (re.escape(name), re.escape(parent)), text)
    return float(match.group(1)) if match else None


def scale_enemy(text):
    for stat in ("MaxHealth", "Health"):
        old = get_stat(text, "Stats/" + stat)
        if old is not None:
            text = set_stat(text, "Stats/" + stat, old * HEALTH_SCALE)
    #fixed regeneration: a healing overtime effect's negative tick_damage
    return re.sub(r"\ntick_damage = (-[\d.]+)", lambda m: "\ntick_damage = " + number(float(m.group(1)) * HEALTH_SCALE), text)


def scale_tower(text, skill, hit):
    text = set_stat(text, "Stats/Damage", 0.0)
    return set_stat(text, skill + "/Stats/Damage", hit)


def main():
    dry = "--dry" in sys.argv
    changes = []
    for path in sorted(glob.glob(ENEMIES)):
        text = open(path, encoding="utf-8").read()
        new = scale_enemy(text)
        if new != text:
            changes.append((path, new, "health %s -> %s" % (get_stat(text, "Stats/MaxHealth"), get_stat(new, "Stats/MaxHealth"))))
    for tower, (skill, hit) in TOWER_HITS.items():
        path = TOWERS % tower
        text = open(path, encoding="utf-8").read()
        old = (get_stat(text, "Stats/Damage") or 0.0) + (get_stat(text, skill + "/Stats/Damage") or 0.0)
        changes.append((path, scale_tower(text, skill, hit), "hit %s -> %s" % (old, hit)))
    for path, new, note in changes:
        print("%-28s %s" % (os.path.basename(path), note))
        if not dry:
            with open(path, "w", encoding="utf-8", newline="\n") as file:
                file.write(new)


if __name__ == "__main__":
    main()
