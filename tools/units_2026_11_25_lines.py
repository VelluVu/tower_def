"""Puffe's line introducing each enemy of 2026-11-25, on the level and wave where it first comes
(tools/units_2026_11_25_waves.py). Each line plays on its own trigger, but an AfterPrevious line follows the one listed
before it, so the new line goes in wave order, before the first line of a later wave and never inside such a chain.
Rerunnable: it replaces the lines it added before.

    python tools/units_2026_11_25_lines.py
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "scenes", "level", "level_data")
LINE_SCRIPT = "res://scenes/level/level_data/puffe_line.gd"
MARK = "u1125"
AFTER_PREVIOUS, WAVE_STARTED, WAVE_CLEARED = 1, 3, 4
NEUTRAL, HAPPY, WORRIED, ANGRY, SMUG = 0, 1, 2, 3, 4

# unit: (level, wave, mood, text)
LINES = {
    "spore_carrier": (5, 4, WORRIED, "Mushroom folk! Kill them away from the others, or their spores heal the whole crowd. Fire burns the cloud away."),
    "glow_moth": (7, 3, WORRIED, "Glow moths, a whole flock on the wind! Bolters and Beamers, look up!"),
    "cave_shaman": (9, 5, ANGRY, "That old shaman wraps its friends in stone. The first hit just bounces off: hit them twice!"),
    "wall_crawler": (8, 3, WORRIED, "Crawlers! They climb right over our walls. Only towers stop them."),
    "snapping_turtle": (15, 5, NEUTRAL, "Snapping turtles! A big hit makes them hide in their shells. Many small bites work better."),
    "leech_mother": (16, 4, WORRIED, "That fat leech drops babies as she crawls. Get her before the fen fills up!"),
    "mosquito": (17, 3, ANGRY, "Mosquitoes, a whole cloud of them! A Nova or a Breather swats many at once."),
    "bog_witch": (18, 4, ANGRY, "A bog witch! Her hex makes our towers sluggish. Strike her down first!"),
    "war_drummer": (25, 5, ANGRY, "Hear that drum? Every soldier near the drummer marches faster. Silence him!"),
    "shieldbearer": (26, 5, WORRIED, "Tower shields! Bolts glance off everyone near them. Beams, bursts and fire go round a shield."),
    "battering_ram": (29, 5, WORRIED, "A battering ram! It doesn't walk the maze, it breaks through it. Towers along the walls!"),
    "crossbow_sniper": (31, 4, ANGRY, "Crossbows! They shoot whichever of us reaches farthest, from afar, and stun it."),
    "sand_wurm": (38, 4, WORRIED, "The sand moves... Wurms! They dive and come up far along the road. Keep towers near the castle."),
    "bone_vulture": (40, 3, NEUTRAL, "Bone vultures! Shoot one down and its bones keep walking. Frost keeps them down for good."),
    "mummy_priest": (41, 4, WORRIED, "Careful with the wrapped priests: when one falls, its curse silences every tower nearby."),
    "ash_harpy": (50, 4, ANGRY, "Ash harpies! They dive at our towers with burning talons. Shoot them out of the sky!"),
    "tunnel_rat": (7, 5, WORRIED, "Rats! They scurry under our traps and eggs. Towers have to catch these ones."),
    "bog_lurker": (20, 4, WORRIED, "Something swims under the water... Bolts and beams can't reach it. Bursts and breath can!"),
    "standard_bearer": (27, 5, ANGRY, "Their standard! Near that banner no frost slows them down. Bring down the bearer first."),
    "ash_wraith": (39, 4, WORRIED, "Wraiths of ash: they fade away now and then and our beams lose them. Bursts catch them when they're back."),
}
# the second round's towers: Puffe presents each right after the opening line of its unlock level, like the others
TOWERS = {
    "spike_field": (5, HAPPY, "A new trap: the Spike Field! Cheap, and it stabs everything that walks over it, again and again. It never breaks."),
    "hoard_keeper": (10, SMUG, "Meet the Hoard Keeper. It never fights, it just sits on gold and pays us after every wave. Two of them pay in full."),
    "shredder": (25, HAPPY, "Their armour is thick, so meet the Shredder! Its pulse barely hurts, but it tears armour, and every tower near it hits harder."),
    "elder_drake": (37, HAPPY, "An Elder Drake joins us! Costly, but once every wave it breathes along the road through everything it can line up."),
}


def order_key(block, previous):
    """when a line can play: its wave (started before cleared); lines without a wave come after the one before"""
    trigger = re.search(r"\ntrigger = (\d+)", block)
    wave = re.search(r"\nwave_number = (\d+)", block)
    trigger = int(trigger.group(1)) if trigger else 1
    wave = int(wave.group(1)) if wave else 0
    if trigger in (WAVE_STARTED, WAVE_CLEARED) and wave > 0:
        return wave * 2 + (1 if trigger == WAVE_CLEARED else 0)
    return previous


def main():
    by_level = {}
    for unit, (level, wave, mood, text) in LINES.items():
        by_level.setdefault(level, []).append((unit, wave, mood, text))
    for name in sorted(os.listdir(DATA)):
        match = re.fullmatch(r"level_(\d+)_data\.tres", name)
        if not match:
            continue
        path = os.path.join(DATA, name)
        text = open(path, encoding="utf8").read()
        new = re.sub(r'\[sub_resource type="Resource" id="PuffeLine_%s_[^"]*"\]\n(?:[^\[\n][^\n]*\n)*\n' % MARK, "", text)
        new = re.sub(r', SubResource\("PuffeLine_%s_[^"]*"\)|SubResource\("PuffeLine_%s_[^"]*"\), ?' % (MARK, MARK), "", new)
        for unit, wave, mood, line in by_level.get(int(match.group(1)), []):
            new = add_line(new, unit, wave, mood, line)
        for tower, (level, mood, line) in TOWERS.items():
            if level == int(match.group(1)):
                new = add_line(new, tower, 0, mood, line, AFTER_PREVIOUS)
        if new != text:
            open(path, "w", encoding="utf8", newline="\n").write(new)
            print("wrote", name)


def add_line(text, unit, wave, mood, line, trigger=WAVE_STARTED):
    script_id = re.search(r'\[ext_resource type="Script"[^\n]*path="%s" id="([^"]+)"\]' % re.escape(LINE_SCRIPT), text)
    if script_id is None:
        last_ext = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', text)][-1]
        text = text[:last_ext] + '[ext_resource type="Script" path="%s" id="9_line"]\n' % LINE_SCRIPT + text[last_ext:]
        sid = "9_line"
    else:
        sid = script_id.group(1)
    rid = "PuffeLine_%s_%s" % (MARK, unit)
    block = ('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("%s")\ntrigger = %d\nwave_number = %d\ntext = "%s"\nmood = %d\n\n'
             % (rid, sid, trigger, wave, line.replace('"', '\\"'), mood))
    resource = text.index("[resource]")
    text = text[:resource] + block + text[resource:]

    lines = re.search(r'puffe_lines = Array\[ExtResource\("[^"]+"\)\]\(\[([^\]]*)\]\)', text)
    if lines is None:
        # no lines yet: the list goes after the waves
        waves = re.search(r'\nwaves = [^\n]+\n', text)
        entry = 'puffe_lines = Array[ExtResource("%s")]([SubResource("%s")])\n' % (sid, rid)
        return text[:waves.end()] + entry + text[waves.end():]
    ids = re.findall(r'SubResource\("([^"]+)"\)', lines.group(1))
    keys, previous = [], 0
    for other in ids:
        found = re.search(r'\[sub_resource type="Resource" id="%s"\]\n((?:[^\[\n][^\n]*\n)*)' % re.escape(other), text)
        previous = order_key("\n" + (found.group(1) if found else ""), previous)
        keys.append(previous)
    mine = wave * 2
    # a tower's line follows the level's opening line, as every tower's introduction does
    at = min(1, len(ids)) if trigger == AFTER_PREVIOUS else next((i for i, key in enumerate(keys) if key > mine), len(ids))
    ids.insert(at, rid)
    listed = ", ".join('SubResource("%s")' % i for i in ids)
    return text[:lines.start(1)] + listed + text[lines.end(1):]


if __name__ == "__main__":
    main()
