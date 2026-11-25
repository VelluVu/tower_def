"""The Spike Field's scenes and data (2026-11-25), rerunnable:

    python tools/spike_field_scenes.py

Art first: tools/sprite/parts/spike_field_art.py (then sprite.py build and the icons).
Writes
- scenes/unit/evolve_tree/spike_field_evolve/<sheet>_frames.tres and the element sprite swaps
- scenes/unit/building/buildings/spike_field.tscn: from the Leopard Trap's scene with the SpikeStrike skill (every enemy
  on the field takes the hit, a short slow), the Spike Field's stats, art and element leaves (the Leopard's element
  damage data: burn, slow stacks, poison); spike_field.tres (the build tray, unlocks on level 5); the upgrade data (a
  copy of the Leopard Trap's)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mortar_scenes as ms

ART = "assets/art/units/building/spike_field"
EVOLVE = "scenes/unit/evolve_tree/spike_field_evolve"
UNLOCK_LEVEL = 5
LIST_ID = 5
PREFIX = {"physical": "", "fire": "fire_", "frost": "frost_", "poison": "poison_"}

# placeholders until playtests: cheap, quick, weak per hit; it never breaks and hits every enemy on it
PRICE = 3.0
DAMAGE = 3.0
COOLDOWN_SECONDS = 0.9
CRIT_CHANCE = 0.05
SLOW_SHARE = 0.15
SLOW_SECONDS = 1.0
FLAT, MULTIPLY = 0, 1
DAMAGE_STAT, ATTACK_SPEED = 2, 6
LEAF_INFO = {
    "physical": "Iron: harder spikes (+20% damage)",
    "fire": "Fire: red-hot spikes set the feet burning",
    "frost": "Frost: ice spikes chill, the slow stacks",
    "poison": "Poison: venom on the spikes poisons all on the field",
}
LEAF_MODIFIERS = {
    "physical": [("DamageModifier", MULTIPLY, DAMAGE_STAT, 0.2)],
    "fire": [("DamageModifier", MULTIPLY, DAMAGE_STAT, 0.1)],
    "frost": [("SpeedModifier", FLAT, ATTACK_SPEED, 0.1)],
    "poison": [("SpeedModifier", FLAT, ATTACK_SPEED, 0.1)],
}


def frames(element):
    ms.EVOLVE = EVOLVE
    name = PREFIX[element] + "spike_field"
    return ms.frames("%s/%s" % (ART, name), name)


def swap_scene(element, sheet_frames):
    name = PREFIX[element] + "spike_field"
    title = "".join(p.capitalize() for p in name.split("_"))
    text = ('[gd_scene format=3]\n\n'
            '[ext_resource type="Material" path="res://assets/shaders/shader_materials/building_hit_shader_material.tres" id="1_material"]\n'
            '[ext_resource type="Script" path="res://scenes/unit/animation_control.gd" id="2_control"]\n'
            '[ext_resource type="SpriteFrames" path="%s" id="3_frames"]\n\n'
            '[node name="%s" type="AnimatedSprite2D"]\ntexture_filter = 1\nmaterial = ExtResource("1_material")\n'
            'position = Vector2(0, -5)\nsprite_frames = ExtResource("3_frames")\nanimation = &"IDLE"\nautoplay = "IDLE"\n'
            'script = ExtResource("2_control")\n') % (sheet_frames, title)
    path = "%s/%s.tscn" % (EVOLVE, name)
    ms.write(path, text)
    return "res://" + path


def trap_scene(base_frames, swaps):
    text = open(os.path.join(ms.ROOT, "scenes/unit/building/buildings/leopard_trap.tscn"), encoding="utf8").read()
    text = re.sub(r'\[gd_scene [^\]]*\]', '[gd_scene format=3]', text, count=1)
    text = re.sub(r' uid="[^"]+"', "", text)
    # the Leopard's own frames go; the Spike Field's come from a .tres
    frames_id = re.search(r'sprite_frames = SubResource\("([^"]+)"\)\nanimation = &"IDLE"\nautoplay = "IDLE"\nscript = ExtResource\("4_bksc7"\)', text).group(1)
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("6_hqhud"\)\nregion = [^\n]*\n\n', "", text)
    text = re.sub(r'\[sub_resource type="SpriteFrames" id="%s"\]\nanimations = \[.*?\]\n\n' % frames_id, "", text, flags=re.S)
    text = text.replace('sprite_frames = SubResource("%s")' % frames_id, 'sprite_frames = ExtResource("s_frames")')
    text = ms.remove_node_metadata(text, '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."')
    # tiers come later (tools/tier_data.py)
    text = re.sub(r'\[ext_resource type="Resource" path="res://scenes/unit/evolve_tree/tiers/[^\n]*\n', "", text)
    text = re.sub(r'\[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="tier_script"\]\n', "", text)
    text = re.sub(r'^tiers = [^\n]*\n', "", text, flags=re.M)
    replace_ext = {
        "6_hqhud": None,
        "2_g6rll": '[ext_resource type="Texture2D" path="res://%s/spike_field_icon.png" id="2_g6rll"]' % ART,
        "trap_selected_icon": '[ext_resource type="Texture2D" path="res://%s/spike_field_icon.png" id="trap_selected_icon"]' % ART,
        "trap_selected_icon_fire": '[ext_resource type="Texture2D" path="res://%s/fire_spike_field_icon.png" id="trap_selected_icon_fire"]' % ART,
        "trap_selected_icon_frost": '[ext_resource type="Texture2D" path="res://%s/frost_spike_field_icon.png" id="trap_selected_icon_frost"]' % ART,
        "trap_selected_icon_poison": '[ext_resource type="Texture2D" path="res://%s/poison_spike_field_icon.png" id="trap_selected_icon_poison"]' % ART,
        "trap_sprite_fire": '[ext_resource type="PackedScene" path="%s" id="trap_sprite_fire"]' % swaps["fire"],
        "trap_sprite_frost": '[ext_resource type="PackedScene" path="%s" id="trap_sprite_frost"]' % swaps["frost"],
        "trap_sprite_poison": '[ext_resource type="PackedScene" path="%s" id="trap_sprite_poison"]' % swaps["poison"],
        "0_upgradedata": '[ext_resource type="Resource" path="res://scenes/upgrades/building_upgrades/spike_field_upgrade_data.tres" id="0_upgradedata"]',
    }
    for ext_id, line in replace_ext.items():
        pattern = r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id)
        assert re.search(pattern, text), ext_id
        text = re.sub(pattern, "" if line is None else line + "\n", text)
    first_sub = text.index("[sub_resource")
    text = (text[:first_sub] + '[ext_resource type="SpriteFrames" path="%s" id="s_frames"]\n' % base_frames
            + '[ext_resource type="Script" path="res://scenes/unit/building/spike_field/spike_strike.gd" id="s_strike"]\n\n'
            + text[first_sub:])
    # the root and the skill
    text = text.replace('[node name="LeopardTrap" type="StaticBody2D"', '[node name="SpikeField" type="StaticBody2D"')
    text = text.replace('skill = NodePath("LeopardClaws")', 'skill = NodePath("Spikes")')
    text = text.replace('[node name="LeopardClaws" parent="."', '[node name="Spikes" parent="."')
    text = text.replace('parent="LeopardClaws', 'parent="Spikes')
    # the script first: properties set before it would be dropped when it loads
    header = '[node name="Spikes" parent="." node_paths=PackedStringArray("actor") instance=ExtResource("15_bukoe")]\n'
    text = text.replace(header, header + 'script = ExtResource("s_strike")\n')
    text = ms.set_props(text, '[node name="Spikes" parent="."', {
        "skill_name": '"Spikes"', "base_cooldown": repr(COOLDOWN_SECONDS),
        "slow_share": repr(SLOW_SHARE), "slow_seconds": repr(SLOW_SECONDS)})
    for node, value in (("Damage", DAMAGE), ("CriticalChance", CRIT_CHANCE)):
        text = ms.set_props(text, '[node name="%s" type="Node" parent="Spikes/Stats"' % node, {"base_value": repr(value), "value": repr(value)})
    text = ms.set_props(text, '[node name="Price" type="Node" parent="Stats"', {"base_value": repr(PRICE), "value": repr(PRICE)})
    # the leaves: their own text and modifiers
    text = re.sub(r'\[node name="Modifier\d" type="Node" parent="EvolveTree/EvolveBranch\d?/[A-Za-z]+ElementEvolveLeaf"\]\n(?:[^\[\n][^\n]*\n)*\n?', "", text)
    branch = {"physical": "EvolveBranch", "fire": "EvolveBranch2", "frost": "EvolveBranch3", "poison": "EvolveBranch4"}
    for element in ms.ELEMENTS:
        text = ms.set_props(text, '[node name="%s"' % ms.LEAF[element], {"info": '"%s"' % LEAF_INFO[element]})
        leaf_path = "EvolveTree/%s/%s" % (branch[element], ms.LEAF[element])
        nodes = ""
        for name, modify, stat, value in LEAF_MODIFIERS[element]:
            nodes += ('[node name="%s" type="Node" parent="%s"]\nscript = ExtResource("trap_modifier_script")\ncalculate_type = %d\n'
                      'stat_type = %d\nvalue = %s\n\n') % (name, leaf_path, modify, stat, repr(value))
        m = re.search(r'\[node name="%s" type="Node" parent="[^"]+"\]\n(?:[^\[\n][^\n]*\n)*\n?' % ms.LEAF[element], text)
        text = text[:m.end()] + nodes + text[m.end():]
    text = text.replace("\n\n\n", "\n\n")
    ms.write("scenes/unit/building/buildings/spike_field.tscn", text)


def list_element():
    text = ('[gd_resource type="Resource" script_class="BuildingListElement" format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/building/building_list_element.gd" id="1_script"]\n'
            '[ext_resource type="Texture2D" path="res://%s/spike_field_icon.png" id="2_icon"]\n'
            '[ext_resource type="PackedScene" path="res://scenes/unit/building/buildings/spike_field.tscn" id="3_scene"]\n\n'
            '[resource]\nscript = ExtResource("1_script")\nscene = ExtResource("3_scene")\nid = %d\nicon = ExtResource("2_icon")\n'
            'unlock_level = %d\ndescription = "A cheap bed of spikes in the road. Stabs every enemy walking over it again '
            'and again and slows them a little. Never breaks; flyers pass over."\n') % (ART, LIST_ID, UNLOCK_LEVEL)
    ms.write("scenes/unit/building/buildings/spike_field.tres", text)


def upgrade_data():
    path = "scenes/upgrades/building_upgrades/spike_field_upgrade_data.tres"
    if os.path.exists(os.path.join(ms.ROOT, path)):
        return
    src = open(os.path.join(ms.ROOT, "scenes/upgrades/building_upgrades/leopard_trap_upgrade_data.tres"), encoding="utf8").read()
    ms.write(path, re.sub(r' uid="[^"]+"', "", src, count=1))


def main():
    sheets = {e: frames(e) for e in ms.ELEMENTS}
    swaps = {e: swap_scene(e, sheets[e]) for e in ("fire", "frost", "poison")}
    upgrade_data()
    trap_scene(sheets["physical"], swaps)
    list_element()
    print("spike field scenes written")


if __name__ == "__main__":
    main()
