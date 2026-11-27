"""The thirteen level-up cards of 2026-11-27 (the user picked all four groups: hit effects, finishers, effect cards,
walls and economy). Writes scenes/unit/evolve_tree/evolve_resources/<name>.tres; rerunnable.

    python tools/new_cards_2026_11_27.py

Cards on paired stats (freeze, ground patch, split) carry their second stat in the drawback fields with a positive
value: the drawback is the uncapped second modifier, summed per pick. Icons borrow existing ones until the new
16x16 icons are drawn (ICON)."""
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "scenes", "unit", "evolve_tree", "evolve_resources")
ICONS = "res://assets/art/ui/card_icons/%s_icon.png"
COIN = "res://assets/art/ui/puffe_coin.png"
HEART = "res://assets/art/ui/heart.png"

# Utils.StatType
EFFECT_TICK_RATE, SPLASH_RADIUS, FREEZE_CHANCE, FREEZE_DURATION, PIERCE, KNOCKBACK = 14, 20, 21, 22, 23, 24
PATCH_DURATION, PATCH_SHARE, SPLIT_COUNT, SPLIT_SHARE, POISON_SPREAD, MARK_SHARE, EXECUTE_BELOW = 25, 26, 28, 29, 30, 32, 33
# EvolveResource.CardTarget
BUILDINGS, KILL_GOLD, UPGRADE_DISCOUNT, WALL_ARMOR = 0, 5, 6, 7
# Utils.ModifyType: Flat is 0
FLAT = 0
# element flags: Physical 1, Fire 2, Frost 4, Poison 8
ALL, ELEMENTS, POISON = 15, 14, 8
PROJECTILE = 2
COMMON, RARE = 0, 1

# name: fields; "second" = (stat, value) for a paired stat
CARDS = {
    "shrapnel": dict(title="Shrapnel", icon=ICONS % "area_damage", stat=SPLASH_RADIUS, value=0.5, percent=False,
        rolled=True, picks=3, text="Hits splash half their damage on enemies within {value} tiles"),
    "piercing_bolts": dict(title="Piercing Bolts", icon=ICONS % "projectile_damage", stat=PIERCE, value=1.0, percent=False,
        rarity=RARE, picks=2, skill=PROJECTILE, text="Bolts fly on through {value} more enemy"),
    "shockwave": dict(title="Shockwave", icon=ICONS % "heavy_blows", stat=KNOCKBACK, value=1.0, percent=False,
        rarity=RARE, picks=2, text="Hits push enemies back {value} cell (not bosses or flyers)"),
    "flash_freeze": dict(title="Flash Freeze", icon=ICONS % "effect_duration", stat=FREEZE_CHANCE, value=0.05,
        rolled=True, picks=3, second=(FREEZE_DURATION, 0.75), text="Hits have a {value}% chance to freeze for 0.75 s more"),
    "executioner": dict(title="Executioner", icon=ICONS % "critical_multiplier", stat=EXECUTE_BELOW, value=0.08,
        rarity=RARE, picks=2, text="Hits finish enemies under {value}% health (not bosses)"),
    "marked_prey": dict(title="Marked Prey", icon=ICONS % "long_sight", stat=MARK_SHARE, value=0.08,
        rolled=True, picks=3, text="Hits mark: the target takes {value}% more of that element from every tower"),
    "split_shot": dict(title="Split Shot", icon=ICONS % "ricochet", stat=SPLIT_COUNT, value=1.0, percent=False,
        rarity=RARE, picks=2, second=(SPLIT_SHARE, 0.3), text="Hits split into {value} more shard (30% damage)"),
    "quickening": dict(title="Quickening", icon=ICONS % "attack_speed", stat=EFFECT_TICK_RATE, value=0.12,
        rolled=True, elements=ELEMENTS, text="Burns, poisons and bleeds tick {value}% faster"),
    "lingering_ground": dict(title="Lingering Ground", icon=ICONS % "killing_ground", stat=PATCH_DURATION, value=2.0, percent=False,
        picks=3, second=(PATCH_SHARE, 0.1), text="Hits leave ground that hurts for {value} s more (10% a second)"),
    "spreading_plague": dict(title="Spreading Plague", icon=ICONS % "effect_stacks", stat=POISON_SPREAD, value=1.0, percent=False,
        rarity=RARE, picks=2, elements=POISON, text="A poisoned enemy that dies passes its poison to {value} more neighbour"),
    "stonemason": dict(title="Stonemason", icon=HEART, target=WALL_ARMOR, value=0.1, rolled=True, picks=3,
        text="Walls take {value}% less damage"),
    "bounty": dict(title="Bounty", icon=COIN, target=KILL_GOLD, value=0.2, rolled=True, picks=2,
        text="Kills have a {value}% chance to drop 1 more gold"),
    "thrift": dict(title="Thrift", icon=COIN, target=UPGRADE_DISCOUNT, value=0.1, rolled=True, picks=2,
        text="Upgrades and elements cost {value}% less"),
}


def card_text(card):
    lines = [
        '[gd_resource type="Resource" script_class="EvolveResource" format=3]',
        "",
        '[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_resource.gd" id="1_evolve"]',
        '[ext_resource type="Texture2D" path="%s" id="2_icon"]' % card["icon"],
        "",
        "[resource]",
        "resource_local_to_scene = true",
        'script = ExtResource("1_evolve")',
        'evolve_icon = ExtResource("2_icon")',
        "card_target = %d" % card.get("target", BUILDINGS),
        "max_picks = %d" % card.get("picks", 0),
        "modifier_type = 0",
        "skill_type = %d" % card.get("skill", 0),
        "elements = %d" % card.get("elements", ALL),
        "modify_stat_type = %d" % card.get("stat", 0),
        "modify_type = %d" % FLAT,
        "is_randomized_modify_value = %s" % ("true" if card.get("rolled", False) else "false"),
        "is_percent = %s" % ("true" if card.get("percent", True) else "false"),
        "modify_value = %r" % float(card["value"]),
        'evolve_name = "%s"' % card["title"],
        "rarity = %d" % card.get("rarity", COMMON),
        'description = "%s"' % card["text"],
    ]
    if "second" in card:
        stat, value = card["second"]
        lines += [
            "has_drawback = true",
            "drawback_stat_type = %d" % stat,
            "drawback_modify_type = %d" % FLAT,
            "drawback_value = %r" % float(value),
            "drawback_is_percent = false",
        ]
    return "\n".join(lines) + "\n"


def main():
    for name, card in CARDS.items():
        path = os.path.join(OUT, name + ".tres")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(card_text(card))
        print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
