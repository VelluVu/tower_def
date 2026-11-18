"""Makes every talent damage bonus a "more" bonus (ModifyType.Multiply) instead of an "increased" one (Additive).

Why (2026-11-16): Additive talent damage summed with the stat cards' Additive damage, so by mid-level (+100% and
more from cards) a talent's +15% added only a few percent and 30 talent points changed nothing in a bot game. The
user wants every talent path to have an encouraging, felt impact; a Multiply bonus is always its full size.

    python tools/talent_damage_more.py

Idempotent: rerun it after an editor autosave or a tree rewrite. Touches BuildingStat effects on Damage that have
no modify_type line (the Additive default) in scenes/talents/trees/*.tres.
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TREES = os.path.join(ROOT, "scenes", "talents", "trees")
DAMAGE = 2
MULTIPLY = 1


def convert(text):
    count = 0

    def fix(m):
        nonlocal count
        head, body = m.group(1), m.group(2)
        if 'script = ExtResource("3_effect")' not in body:
            return m.group(0)
        kind = re.search(r"^kind = (\d+)$", body, re.M)
        stat = re.search(r"^stat_type = (\d+)$", body, re.M)
        if (kind and int(kind.group(1)) != 0) or (stat and int(stat.group(1)) != DAMAGE):
            return m.group(0)
        if re.search(r"^modify_type = ", body, re.M):
            return m.group(0)
        count += 1
        return head + body.rstrip("\n") + "\nmodify_type = %d\n" % MULTIPLY

    text = re.sub(r'(\[sub_resource type="Resource" id="[^"]+"\]\n)(.*?\n)(?=\n\[)', fix, text, flags=re.S)
    return text, count


for name in sorted(os.listdir(TREES)):
    if not name.endswith(".tres"):
        continue
    path = os.path.join(TREES, name)
    text, count = convert(open(path, encoding="utf8").read())
    if count:
        open(path, "w", encoding="utf8", newline="\n").write(text)
    print("%s: %d damage effects made Multiply" % (name, count))
