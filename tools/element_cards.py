"""Element cards from the talent trees (2026-11-19, the design doc's last open card kind): each element tree puts its
own cards into the level-up deck once enough of its ranks are learned (EvolveResource.talent_tree / talent_ranks,
checked in LevelUpgrades._can_offer), and they fit only towers of that element. Commons at COMMON_RANKS, rares at
RARE_RANKS; every card uses a stat the towers already have, so the card pipeline needs nothing new.

    python tools/element_cards.py      (re)writes the cards in scenes/unit/evolve_tree/evolve_resources/
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "scenes", "unit", "evolve_tree", "evolve_resources", "%s.tres")
COMMON_RANKS = 5
RARE_RANKS = 15
# Utils.Element flags, StatType and ModifyType numbers
FIRE, FROST, POISON = 2, 4, 8
DAMAGE, EFFECT_POTENCY, EFFECT_CHANCE, EFFECT_DURATION, SPLASH_RADIUS, POISON_SPREAD = 2, 10, 11, 12, 20, 30
FLAT, ADDITIVE = 0, 2
ICONS = {FIRE: "fire_element_icon", FROST: "frost_element_icon", POISON: "poison_element_icon"}
TREES = {FIRE: "fire", FROST: "frost", POISON: "poison"}

# file: (name, element, stat, modify type, value, rolls, percent, rare, max picks, description)
CARDS = {
    "fire_kindled_fury": ("Kindled Fury", FIRE, DAMAGE, ADDITIVE, 0.1, True, True, False, 0, ""),
    "fire_wildfire": ("Wildfire", FIRE, SPLASH_RADIUS, FLAT, 1.0, False, False, True, 1,
                      "Fire hits splash on nearby enemies"),
    "fire_ignition": ("Ignition", FIRE, EFFECT_CHANCE, FLAT, 0.5, False, True, True, 1, "Fire towers ignite {value}% more often"),
    "frost_hoarfrost": ("Hoarfrost", FROST, EFFECT_DURATION, FLAT, 1.0, False, False, False, 2, "Frost slows last a tick longer"),
    "frost_glacier_heart": ("Glacier Heart", FROST, EFFECT_POTENCY, FLAT, 0.4, False, True, True, 1, "Frost towers slow {value}% deeper"),
    "poison_virulence": ("Virulence", POISON, EFFECT_POTENCY, FLAT, 0.1, True, True, False, 0, ""),
    "poison_contagion": ("Contagion", POISON, POISON_SPREAD, FLAT, 1.0, False, False, True, 1,
                         "Poisoned enemies spread it when they die"),
}


def write(file_name, card):
    name, element, stat, modify_type, value, rolls, percent, rare, max_picks, description = card
    lines = ['[gd_resource type="Resource" script_class="EvolveResource" load_steps=3 format=3]', '',
             '[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_resource.gd" id="1_evolve"]',
             '[ext_resource type="Texture2D" path="res://assets/art/ui/%s.png" id="2_icon"]' % ICONS[element], '',
             '[resource]', 'resource_local_to_scene = true', 'script = ExtResource("1_evolve")', 'evolve_icon = ExtResource("2_icon")']
    if max_picks:
        lines.append('max_picks = %d' % max_picks)
    lines += ['modifier_type = 0', 'elements = %d' % element, 'modify_stat_type = %d' % stat, 'modify_type = %d' % modify_type,
              'is_randomized_modify_value = %s' % ("true" if rolls else "false"), 'is_percent = %s' % ("true" if percent else "false"),
              'modify_value = %s' % float(value), 'evolve_name = "%s"' % name]
    if rare:
        lines.append('rarity = 1')
    if description:
        lines.append('description = "%s"' % description)
    lines += ['talent_tree = &"%s"' % TREES[element], 'talent_ranks = %d' % (RARE_RANKS if rare else COMMON_RANKS)]
    open(OUT % file_name, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("wrote", file_name)


if __name__ == "__main__":
    for file_name, card in CARDS.items():
        write(file_name, card)
