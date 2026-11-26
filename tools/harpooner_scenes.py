"""The Harpooner's scenes and data (2026-11-24), rerunnable:

    python tools/harpooner_scenes.py      then  python tools/tier_data.py  (the T2/T3 tiers and the leaves' tiers)

Art first: tools/sprite/parts/harpooner_art.py (drakelings, harpoons) and tower_tiers.py ... harpooner (T2/T3).
Writes
- scenes/unit/evolve_tree/puffe_harpooner_evolve/<sheet>_frames.tres: SpriteFrames for the drakelings and the harpoons
- scenes/unit/skills/projectiles/<element>_harpoon.tscn: a HomingBolt with the barbed harpoon
- scenes/unit/evolve_tree/puffe_harpooner_evolve/: the element sprite swaps and damage data (copies of the Bolter's:
  burn, slow and poison stacks)
- scenes/unit/building/buildings/puffe_harpooner.tscn: from the Bolter's scene with the Harpooner's stats, art, element
  leaves (Physical: Yank; Fire: a burning chain; Frost: a deeper, longer slow; Poison: barbed hooks), the TetherTime
  and TetherSlow stats (every harpoon tethers and slows; HarpoonTether drags flyers down) and the Flyers tactic by
  default; puffe_harpooner.tres (the build tray, unlocks on level 37); the upgrade data (a copy of the Bolter's)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mortar_scenes as ms

ART = "assets/art/units/building/puffe/puffe_harpooner"
PROJ_ART = "assets/art/projectile"
EVOLVE = "scenes/unit/evolve_tree/puffe_harpooner_evolve"
PROJ = "scenes/unit/skills/projectiles"
ELEMENTS = ms.ELEMENTS
UNLOCK_LEVEL = 19
LIST_ID = 11
FLYERS_TACTIC = 8  # Utils.TargetTactic.Flyers

# the Harpooner's numbers (placeholders until playtests): weaker than the Bolter, but every harpoon tethers its
# target (half speed for 2 s) and drags a flyer down to the maze
PRICE = 6.0
DAMAGE = 5.0
RANGE_TILES = 3.5
CRIT_CHANCE = 0.05
CAST_SECONDS = 0.4
COOLDOWN_SECONDS = 2.5
BOLT_SPEED = 160.0
TETHER_SECONDS = 2.0
TETHER_SLOW = 0.5
FLAT, MULTIPLY = 0, 1
DAMAGE_STAT, EFFECT_DURATION, EFFECT_STACKS, KNOCKBACK = 2, 12, 13, 24
TETHER_TIME, TETHER_SLOW_STAT = 34, 35
# the element leaves (the user's pick 2026-11-24: hook + element)
LEAF_MODIFIERS = {
    "physical": [("DamageModifier", MULTIPLY, DAMAGE_STAT, 0.11), ("YankModifier", FLAT, KNOCKBACK, 1.0)],
    "fire": [("BurningChainModifier", FLAT, EFFECT_DURATION, 1.0)],
    "frost": [("DeepChillModifier", FLAT, TETHER_SLOW_STAT, 0.15), ("LongChainModifier", FLAT, TETHER_TIME, 1.0)],
    "poison": [("BarbedHookModifier", FLAT, EFFECT_STACKS, 1.0)],
}
LOOPING = ("IDLE", "ATTACK", "FLY", "WALK")


def sheet_name(element):
    return (ms.COLOUR[element] + "_" if ms.COLOUR[element] else "") + "puffe_harpooner"


def frames(base, out_name):
    ms.EVOLVE = EVOLVE
    ms.LOOPING = LOOPING
    return ms.frames(base, out_name)


def bolt_scene(element, bolt_frames):
    name = "%s_harpoon" % element
    title = "".join(p.capitalize() for p in name.split("_"))
    text = ('[gd_scene format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/skills/projectiles/homing_bolt.gd" id="1_script"]\n'
            '[ext_resource type="SpriteFrames" path="%s" id="2_frames"]\n'
            '[ext_resource type="Script" path="res://scenes/unit/animation_control.gd" id="3_control"]\n'
            '[ext_resource type="Script" path="res://scenes/custom_timer.gd" id="4_timer"]\n\n'
            '[sub_resource type="CircleShape2D" id="CircleShape2D_bolt"]\nradius = 6.0\n\n'
            '[node name="%s" type="Area2D"]\ntop_level = true\ny_sort_enabled = true\ncollision_layer = 0\ncollision_mask = 2\n'
            'script = ExtResource("1_script")\nprojectile_name = "%s"\nprojectile_speed = %s\npierce = 0\n\n'
            '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\ntexture_filter = 1\n'
            'sprite_frames = ExtResource("2_frames")\nanimation = &"WALK"\nscript = ExtResource("3_control")\n\n'
            '[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\nshape = SubResource("CircleShape2D_bolt")\n\n'
            '[node name="LiveTimer" type="Timer" parent="."]\nwait_time = 5.0\none_shot = true\nscript = ExtResource("4_timer")\n\n'
            '[connection signal="area_entered" from="." to="." method="_on_area_entered"]\n'
            '[connection signal="body_entered" from="." to="." method="_on_body_entered"]\n') % (bolt_frames, title, title, repr(BOLT_SPEED))
    path = "%s/%s.tscn" % (PROJ, name)
    ms.write(path, text)
    return "res://" + path


def swap_scene(element, drakeling_frames):
    name = sheet_name(element)
    title = "".join(p.capitalize() for p in name.split("_"))
    text = ('[gd_scene format=3]\n\n'
            '[ext_resource type="Material" path="res://assets/shaders/shader_materials/building_hit_shader_material.tres" id="1_material"]\n'
            '[ext_resource type="Script" path="res://scenes/unit/animation_control.gd" id="2_control"]\n'
            '[ext_resource type="SpriteFrames" path="%s" id="3_frames"]\n'
            '[ext_resource type="Texture2D" path="res://assets/art/units/building/puffe/%s.png" id="4_base"]\n\n'
            '[node name="%s" type="AnimatedSprite2D"]\ntexture_filter = 1\nmaterial = ExtResource("1_material")\n'
            'sprite_frames = ExtResource("3_frames")\nanimation = &"IDLE"\nscript = ExtResource("2_control")\n\n'
            '[node name="TowerBaseSprite" type="Sprite2D" parent="."]\nshow_behind_parent = true\ntexture_filter = 1\n'
            'position = Vector2(0, 1)\ntexture = ExtResource("4_base")\n') % (drakeling_frames, ms.TOWER_BASE[element], title)
    path = "%s/%s.tscn" % (EVOLVE, name)
    ms.write(path, text)
    return "res://" + path


def damage_scene(element):
    src = open(os.path.join(ms.ROOT, "%s/%s_puffe_bolter_evolve_damage_data.tscn" % (ms.BOLTER_EVOLVE, ms.BOLTER_DAMAGE[element])), encoding="utf8").read()
    text = re.sub(r' uid="[^"]+"', "", src, count=1)
    text = re.sub(r'load_steps=\d+ ', "", text)
    title = "%sHarpoonerDamageData" % element.capitalize()
    text = re.sub(r'\[node name="[^"]+" type="Node"\]', '[node name="%s" type="Node"]' % title, text, count=1)
    path = "%s/%s_harpooner_damage_data.tscn" % (EVOLVE, element)
    ms.write(path, text)
    return "res://" + path


def tower_scene(drakeling_frames, bolts, swaps, damages):
    text = open(os.path.join(ms.ROOT, "scenes/unit/building/buildings/puffe_bolter.tscn"), encoding="utf8").read()
    text = re.sub(r'\[gd_scene [^\]]*\]', '[gd_scene format=3]', text, count=1)
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("4_04kgf"\)\nregion = [^\n]*\n\n', "", text)
    text = re.sub(r'\[sub_resource type="SpriteFrames" id="SpriteFrames_udt3q"\]\nanimations = \[.*?\]\n\n', "", text, flags=re.S)
    text = text.replace('sprite_frames = SubResource("SpriteFrames_udt3q")', 'sprite_frames = ExtResource("m_frames")')
    text = re.sub(r'\[ext_resource type="Resource" path="res://scenes/unit/evolve_tree/tiers/[^\n]*\n', "", text)
    text = re.sub(r'\[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="tier_script"\]\n', "", text)
    text = re.sub(r'^tiers = [^\n]*\n', "", text, flags=re.M)
    replace_ext = {
        "4_04kgf": None,
        "19_tlf38": '[ext_resource type="Texture2D" path="res://%s/puffe_harpooner_icon.png" id="19_tlf38"]' % ART,
        "20_qaoyh": '[ext_resource type="Texture2D" path="res://%s/red_puffe_harpooner_icon.png" id="20_qaoyh"]' % ART,
        "26_nwa4t": '[ext_resource type="Texture2D" path="res://%s/blue_puffe_harpooner_icon.png" id="26_nwa4t"]' % ART,
        "29_pjst3": '[ext_resource type="Texture2D" path="res://%s/green_puffe_harpooner_icon.png" id="29_pjst3"]' % ART,
        "9_elqq4": '[ext_resource type="PackedScene" path="%s" id="9_elqq4"]' % bolts["physical"],
        "21_t17ii": '[ext_resource type="PackedScene" path="%s" id="21_t17ii"]' % bolts["fire"],
        "26_k77d7": '[ext_resource type="PackedScene" path="%s" id="26_k77d7"]' % bolts["frost"],
        "29_bqugu": '[ext_resource type="PackedScene" path="%s" id="29_bqugu"]' % bolts["poison"],
        "22_ll5c1": '[ext_resource type="PackedScene" path="%s" id="22_ll5c1"]' % swaps["fire"],
        "26_alotc": '[ext_resource type="PackedScene" path="%s" id="26_alotc"]' % swaps["frost"],
        "28_4x4pp": '[ext_resource type="PackedScene" path="%s" id="28_4x4pp"]' % swaps["poison"],
        "20_ccteo": '[ext_resource type="PackedScene" path="%s" id="20_ccteo"]' % damages["physical"],
        "23_pbrrj": '[ext_resource type="PackedScene" path="%s" id="23_pbrrj"]' % damages["fire"],
        "27_pf0qb": '[ext_resource type="PackedScene" path="%s" id="27_pf0qb"]' % damages["frost"],
        "29_ajupy": '[ext_resource type="PackedScene" path="%s" id="29_ajupy"]' % damages["poison"],
        "0_upgradedata": '[ext_resource type="Resource" path="res://scenes/upgrades/building_upgrades/harpooner_upgrade_data.tres" id="0_upgradedata"]',
    }
    for ext_id, line in replace_ext.items():
        pattern = r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id)
        assert re.search(pattern, text), ext_id
        text = re.sub(pattern, "" if line is None else line + "\n", text)
    first_sub = text.index("[sub_resource")
    text = text[:first_sub] + '[ext_resource type="SpriteFrames" path="%s" id="m_frames"]\n\n' % drakeling_frames + text[first_sub:]
    text = text.replace('[node name="PuffeBolter" type="StaticBody2D" node_paths=PackedStringArray("skill")]',
                        '[node name="PuffeHarpooner" type="StaticBody2D" node_paths=PackedStringArray("skill")]')
    text = ms.set_props(text, '[node name="PuffeHarpooner"', {"target_tactic": str(FLYERS_TACTIC)})
    text = ms.remove_node_metadata(text, '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."')
    text = ms.remove_node_metadata(text, '[node name="TowerBaseSprite" type="Sprite2D" parent="AnimatedSprite2D"')
    text = ms.set_props(text, '[node name="LaunchProjectile" parent="."', {
        "skill_type": "256", "skill_name": '"Harpoon"', "base_cast_time": repr(CAST_SECONDS), "base_cooldown": repr(COOLDOWN_SECONDS)})
    for node, value in (("Damage", DAMAGE), ("AttackRange", RANGE_TILES), ("CriticalChance", CRIT_CHANCE)):
        text = ms.set_props(text, '[node name="%s" type="Node" parent="LaunchProjectile/Stats"' % node,
                            {"base_value": repr(value), "value": repr(value)})
    text = ms.set_props(text, '[node name="Price" type="Node" parent="Stats"', {"base_value": repr(PRICE), "value": repr(PRICE)})
    text = ms.set_props(text, '[node name="SelectableUnit" parent="."', {"display_name": '"Harpooner"'})
    # the tether stats, only the Harpooner has them
    m = re.search(r'\[node name="EvolveTree" type="Node" parent="\."\]', text)
    stat_script = re.search(r'\[node name="Price" type="Node" parent="Stats"\]\nscript = ExtResource\("([^"]+)"\)', text).group(1)
    stats = "".join('[node name="%s" type="Node" parent="Stats"]\nscript = ExtResource("%s")\ntype = %d\nbase_value = %s\nvalue = %s\n\n'
                    % (n, stat_script, t, repr(v), repr(v))
                    for n, t, v in (("TetherTime", TETHER_TIME, TETHER_SECONDS), ("TetherSlow", TETHER_SLOW_STAT, TETHER_SLOW)))
    text = text[:m.start()] + stats + text[m.start():]
    text = re.sub(r'\[node name="[A-Za-z]+Modifier" type="Node" parent="EvolveTree/EvolveBranch\d?/[A-Za-z]+ElementEvolveLeaf"\]\n(?:[^\[\n][^\n]*\n)*\n?', "", text)
    branch = {"physical": "EvolveBranch", "fire": "EvolveBranch2", "frost": "EvolveBranch3", "poison": "EvolveBranch4"}
    for element in ELEMENTS:
        leaf_path = "EvolveTree/%s/%s" % (branch[element], ms.LEAF[element])
        nodes = ""
        for name, modify, stat, value in LEAF_MODIFIERS[element]:
            nodes += ('[node name="%s" type="Node" parent="%s"]\nscript = ExtResource("24_v32av")\ncalculate_type = %d\n'
                      'stat_type = %d\nvalue = %s\n\n') % (name, leaf_path, modify, stat, repr(value))
        m = re.search(r'\[node name="%s" type="Node" parent="[^"]+"\]\n(?:[^\[\n][^\n]*\n)*\n?' % ms.LEAF[element], text)
        text = text[:m.end()] + nodes + text[m.end():]
    text = ms.set_props(text, '[node name="PhysicalElementEvolveLeaf"', {"new_projectile_scene": 'ExtResource("9_elqq4")'})
    text = re.sub(r"\n{3,}", "\n\n", text)
    ms.write("scenes/unit/building/buildings/puffe_harpooner.tscn", text)


def list_element():
    text = ('[gd_resource type="Resource" script_class="BuildingListElement" format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/building/building_list_element.gd" id="1_script"]\n'
            '[ext_resource type="Texture2D" path="res://%s/puffe_harpooner_icon.png" id="2_icon"]\n'
            '[ext_resource type="PackedScene" path="res://scenes/unit/building/buildings/puffe_harpooner.tscn" id="3_scene"]\n\n'
            '[resource]\nscript = ExtResource("1_script")\nscene = ExtResource("3_scene")\nid = %d\nicon = ExtResource("2_icon")\n'
            'unlock_level = %d\ndescription = "Harpoons flyers and drags them down into the maze. '
            'Every harpoon chains its target to the tower for a while and slows it hard."\n') % (ART, LIST_ID, UNLOCK_LEVEL)
    ms.write("scenes/unit/building/buildings/puffe_harpooner.tres", text)


def upgrade_data():
    path = "scenes/upgrades/building_upgrades/harpooner_upgrade_data.tres"
    if os.path.exists(os.path.join(ms.ROOT, path)):
        return
    src = open(os.path.join(ms.ROOT, "scenes/upgrades/building_upgrades/bolter_upgrade_data.tres"), encoding="utf8").read()
    ms.write(path, re.sub(r' uid="[^"]+"', "", src, count=1))


def main():
    drakelings = {e: frames("%s/%s" % (ART, sheet_name(e)), sheet_name(e)) for e in ELEMENTS}
    bolts = {e: bolt_scene(e, frames("%s/%s_harpoon" % (PROJ_ART, e), "%s_harpoon" % e)) for e in ELEMENTS}
    swaps = {e: swap_scene(e, drakelings[e]) for e in ELEMENTS}
    damages = {e: damage_scene(e) for e in ELEMENTS}
    upgrade_data()
    tower_scene(drakelings["physical"], bolts, swaps, damages)
    list_element()
    print("harpooner scenes written; now run python tools/tier_data.py")


if __name__ == "__main__":
    main()
