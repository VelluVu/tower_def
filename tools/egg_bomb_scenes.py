"""The Egg Bomb's scenes and data (2026-11-25), rerunnable:

    python tools/egg_bomb_scenes.py      then  python tools/tier_data.py  (the T2/T3 tiers and the leaves' tiers)

Art first: tools/sprite/parts/egg_bomb_art.py (T1, T2 and T3 sheets per element); the blast is the Mortar's.
Writes
- scenes/unit/evolve_tree/egg_bomb_evolve/<element>_egg_bomb_frames.tres and the element sprite swaps
- scenes/unit/building/buildings/egg_bomb.tscn: from the Leopard Trap's scene with the EggBomb script, the EggBlast skill
  (its cast is the 0.6 s fuse, its cooldown the 20 s rebuild), a Blast sprite with the Mortar's element blasts, element
  leaves (Physical: a harder, wider blast; Fire: burning ground; Frost: freezes the enemy at the centre; Poison: a gas
  cloud and more stacks; the Fire, Frost and Poison damage data are the Nova's, like the Leopard Trap's);
  egg_bomb.tres (the build tray, unlocks on level 49); the upgrade data (a copy of the Leopard Trap's)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mortar_scenes as ms

ART = "assets/art/units/building/egg_bomb"
EVOLVE = "scenes/unit/evolve_tree/egg_bomb_evolve"
MORTAR_EVOLVE = "scenes/unit/evolve_tree/puffe_mortar_evolve"
ELEMENTS = ms.ELEMENTS
UNLOCK_LEVEL = 7
LIST_ID = 6

# the Egg Bomb's numbers (placeholders until playtests): about ten Bolter shots in one blast every 20 s
PRICE = 8.0
DAMAGE = 80.0
CRIT_CHANCE = 0.1
FUSE_SECONDS = 0.6
REBUILD_SECONDS = 20.0
BLAST_SKILL_TYPE = 1024  # Utils.SkillType.Blast
FLAT, MULTIPLY = 0, 1
DAMAGE_STAT, EFFECT_STACKS, SPLASH, FREEZE_CHANCE, FREEZE_TIME, PATCH_TIME, PATCH_SHARE = 2, 13, 20, 21, 22, 25, 26
LEAF_MODIFIERS = {
    "physical": [("DamageModifier", MULTIPLY, DAMAGE_STAT, 0.11), ("WideBlastModifier", FLAT, SPLASH, 0.25)],
    "fire": [("FirePitModifier", FLAT, PATCH_TIME, 2.0), ("FirePitHeatModifier", FLAT, PATCH_SHARE, 0.1)],
    "frost": [("FreezeModifier", FLAT, FREEZE_CHANCE, 1.0), ("FreezeTimeModifier", FLAT, FREEZE_TIME, 1.0)],
    "poison": [("GasModifier", FLAT, PATCH_TIME, 3.0), ("GasVenomModifier", FLAT, PATCH_SHARE, 0.1), ("StacksModifier", FLAT, EFFECT_STACKS, 1.0)],
}
LEAF_INFO = {
    "physical": "Physical: a harder blast, a quarter tile wider",
    "fire": "Fire: the blast ignites and leaves burning ground for 2 s",
    "frost": "Frost: the blast chills and freezes the enemy at its centre for 1 s",
    "poison": "Poison: the blast poisons and leaves a gas cloud for 3 s",
}
LEAF_NODE = {"physical": ("EvolveBranch", "PhysicalElementEvolveLeaf"), "fire": ("EvolveBranch2", "FireElementEvolveLeaf"),
             "frost": ("EvolveBranch3", "FrostElementEvolveLeaf"), "poison": ("EvolveBranch4", "PoisonElementEvolveLeaf")}
LOOPING = ("IDLE",)


def frames(element):
    ms.EVOLVE = EVOLVE
    ms.LOOPING = LOOPING
    return ms.frames("%s/%s_egg_bomb" % (ART, element), "%s_egg_bomb" % element)


def swap_scene(element, egg_frames):
    title = "%sEggBomb" % element.capitalize()
    text = ('[gd_scene format=3]\n\n'
            '[ext_resource type="Material" path="res://assets/shaders/shader_materials/building_hit_shader_material.tres" id="1_material"]\n'
            '[ext_resource type="Script" path="res://scenes/unit/animation_control.gd" id="2_control"]\n'
            '[ext_resource type="SpriteFrames" path="%s" id="3_frames"]\n\n'
            '[node name="%s" type="AnimatedSprite2D"]\ntexture_filter = 1\nmaterial = ExtResource("1_material")\n'
            'position = Vector2(0, -5)\nsprite_frames = ExtResource("3_frames")\nanimation = &"IDLE"\nscript = ExtResource("2_control")\n'
            ) % (egg_frames, title)
    path = "%s/%s_egg_bomb.tscn" % (EVOLVE, element)
    ms.write(path, text)
    return "res://" + path


def scene(eggs, swaps):
    text = open(os.path.join(ms.ROOT, "scenes/unit/building/buildings/leopard_trap.tscn"), encoding="utf8").read()
    text = re.sub(r'\[gd_scene [^\]]*\]', '[gd_scene format=3]', text, count=1)
    # the trap's own sprite: its atlases and SpriteFrames go, the egg's frames come from a .tres
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("6_hqhud"\)\nregion = [^\n]*\n\n', "", text)
    text = re.sub(r'\[sub_resource type="SpriteFrames" id="SpriteFrames_0yamy"\]\nanimations = \[.*?\]\n\n', "", text, flags=re.S)
    text = text.replace('sprite_frames = SubResource("SpriteFrames_0yamy")', 'sprite_frames = ExtResource("e_frames")')
    text = re.sub(r'\[ext_resource type="Resource" path="res://scenes/unit/evolve_tree/tiers/[^\n]*\n', "", text)
    text = re.sub(r'\[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="tier_script"\]\n', "", text)
    text = re.sub(r'^tiers = [^\n]*\n', "", text, flags=re.M)
    for ext_id in ("6_hqhud", "15_bukoe"):
        text = re.sub(r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id), "", text)
    replace_ext = {
        "snd_activate": '[ext_resource type="AudioStream" path="res://assets/audio/sfx/retro/nova_burst.ogg" id="snd_activate"]',
        "1_oqrf3": '[ext_resource type="Script" path="res://scenes/unit/building/egg_bomb/egg_bomb.gd" id="1_oqrf3"]',
        "2_g6rll": '[ext_resource type="Texture2D" path="res://%s/physical_egg_bomb_icon.png" id="2_g6rll"]' % ART,
        "trap_selected_icon": '[ext_resource type="Texture2D" path="res://%s/physical_egg_bomb_icon.png" id="trap_selected_icon"]' % ART,
        "trap_selected_icon_fire": '[ext_resource type="Texture2D" path="res://%s/fire_egg_bomb_icon.png" id="trap_selected_icon_fire"]' % ART,
        "trap_selected_icon_frost": '[ext_resource type="Texture2D" path="res://%s/frost_egg_bomb_icon.png" id="trap_selected_icon_frost"]' % ART,
        "trap_selected_icon_poison": '[ext_resource type="Texture2D" path="res://%s/poison_egg_bomb_icon.png" id="trap_selected_icon_poison"]' % ART,
        "trap_sprite_fire": '[ext_resource type="PackedScene" path="%s" id="trap_sprite_fire"]' % swaps["fire"],
        "trap_sprite_frost": '[ext_resource type="PackedScene" path="%s" id="trap_sprite_frost"]' % swaps["frost"],
        "trap_sprite_poison": '[ext_resource type="PackedScene" path="%s" id="trap_sprite_poison"]' % swaps["poison"],
        "0_upgradedata": '[ext_resource type="Resource" path="res://scenes/upgrades/building_upgrades/egg_bomb_upgrade_data.tres" id="0_upgradedata"]',
    }
    for ext_id, line in replace_ext.items():
        pattern = r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id)
        assert re.search(pattern, text), ext_id
        text = re.sub(pattern, line + "\n", text)
    first_sub = text.index("[sub_resource")
    text = text[:first_sub] + (
        '[ext_resource type="SpriteFrames" path="%s" id="e_frames"]\n'
        '[ext_resource type="Script" path="res://scenes/unit/skills/egg_blast.gd" id="e_skill"]\n'
        '[ext_resource type="PackedScene" path="res://scenes/unit/skills/skill_state_timers.tscn" id="e_timers"]\n'
        + "".join('[ext_resource type="SpriteFrames" path="res://%s/%s_mortar_blast_frames.tres" id="e_blast_%s"]\n' % (MORTAR_EVOLVE, e, e)
                  for e in ELEMENTS) + '\n') % eggs["physical"] + text[first_sub:]
    text = text.replace('[node name="LeopardTrap" type="StaticBody2D"', '[node name="EggBomb" type="StaticBody2D"')
    text = text.replace('skill = NodePath("LeopardClaws")', 'skill = NodePath("EggBlast")')
    text = ms.set_props(text, '[node name="EggBomb"', {"blast_frames": "Array[SpriteFrames]([%s])" % ", ".join(
        'ExtResource("e_blast_%s")' % e for e in ELEMENTS)})
    text = ms.remove_node_metadata(text, '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."')
    text = re.sub(r'^autoplay = "IDLE"\n', "", text, flags=re.M)
    # the claws become the blast: an EggBlast with its timers; the claws' Stats and DamageData move over
    m = re.search(r'\[node name="LeopardClaws" parent="\."[^\n]*\]\n(?:[^\[\n][^\n]*\n)*', text)
    text = text[:m.start()] + ('[node name="EggBlast" type="Node2D" parent="." node_paths=PackedStringArray("actor")]\n'
                               'script = ExtResource("e_skill")\nskill_type = %d\nskill_name = "Blast"\nbase_cast_time = %s\n'
                               'base_cooldown = %s\nactor = NodePath("..")\nactivate_sound = ExtResource("snd_activate")\n\n'
                               '[node name="SkillStateTimers" parent="EggBlast" instance=ExtResource("e_timers")]\n\n') % (
        BLAST_SKILL_TYPE, repr(FUSE_SECONDS), repr(REBUILD_SECONDS)) + text[m.end():]
    text = text.replace('parent="LeopardClaws', 'parent="EggBlast')
    text = ms.set_props(text, '[node name="Damage" type="Node" parent="EggBlast/Stats"', {"base_value": repr(DAMAGE), "value": repr(DAMAGE)})
    text = ms.set_props(text, '[node name="Price" type="Node" parent="Stats"', {"base_value": repr(PRICE), "value": repr(PRICE)})
    text = ms.set_props(text, '[node name="CriticalChance" type="Node" parent="Stats"', {"base_value": repr(CRIT_CHANCE), "value": repr(CRIT_CHANCE)})
    if '[node name="SelectableUnit" parent="."' in text:
        text = ms.set_props(text, '[node name="SelectableUnit" parent="."', {"display_name": '"Egg Bomb"'})
    # the blast sprite over the units
    m = re.search(r'\[node name="SelectableUnit" parent="\."', text)
    text = text[:m.start()] + ('[node name="Blast" type="AnimatedSprite2D" parent="."]\nvisible = false\nz_index = 12\n'
                               'texture_filter = 1\nposition = Vector2(0, -4)\nsprite_frames = ExtResource("e_blast_physical")\n\n') + text[m.start():]
    # the leaves: the egg's own modifiers and text
    text = re.sub(r'\[node name="Modifier\d" type="Node" parent="EvolveTree/EvolveBranch\d?/[A-Za-z]+ElementEvolveLeaf"\]\n(?:[^\[\n][^\n]*\n)*\n?', "", text)
    for element in ELEMENTS:
        branch, leaf = LEAF_NODE[element]
        text = ms.set_props(text, '[node name="%s" type="Node" parent="EvolveTree/%s"' % (leaf, branch), {"info": '"%s"' % LEAF_INFO[element]})
        nodes = "".join('[node name="%s" type="Node" parent="EvolveTree/%s/%s"]\nscript = ExtResource("trap_modifier_script")\n'
                        'calculate_type = %d\nstat_type = %d\nvalue = %s\n\n' % (name, branch, leaf, modify, stat, repr(value))
                        for name, modify, stat, value in LEAF_MODIFIERS[element])
        m = re.search(r'\[node name="%s" type="Node" parent="EvolveTree/%s"\]\n(?:[^\[\n][^\n]*\n)*\n?' % (leaf, branch), text)
        text = text[:m.end()] + nodes + text[m.end():]
    text = re.sub(r"\n{3,}", "\n\n", text)
    ms.write("scenes/unit/building/buildings/egg_bomb.tscn", text)


def list_element():
    text = ('[gd_resource type="Resource" script_class="BuildingListElement" format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/building/building_list_element.gd" id="1_script"]\n'
            '[ext_resource type="Texture2D" path="res://%s/physical_egg_bomb_icon.png" id="2_icon"]\n'
            '[ext_resource type="PackedScene" path="res://scenes/unit/building/buildings/egg_bomb.tscn" id="3_scene"]\n\n'
            '[resource]\nscript = ExtResource("1_script")\nscene = ExtResource("3_scene")\nid = %d\nicon = ExtResource("2_icon")\n'
            'unlock_level = %d\ndescription = "A trap on the path: the first enemy on it lights the fuse, then one big blast hits '
            'everything around it, flyers too. It rebuilds itself slowly."\n') % (ART, LIST_ID, UNLOCK_LEVEL)
    ms.write("scenes/unit/building/buildings/egg_bomb.tres", text)


def upgrade_data():
    path = "scenes/upgrades/building_upgrades/egg_bomb_upgrade_data.tres"
    if os.path.exists(os.path.join(ms.ROOT, path)):
        return
    src = open(os.path.join(ms.ROOT, "scenes/upgrades/building_upgrades/leopard_trap_upgrade_data.tres"), encoding="utf8").read()
    ms.write(path, re.sub(r' uid="[^"]+"', "", src, count=1))


def main():
    eggs = {e: frames(e) for e in ELEMENTS}
    swaps = {e: swap_scene(e, eggs[e]) for e in ELEMENTS}
    upgrade_data()
    scene(eggs, swaps)
    list_element()
    print("egg bomb scenes written; now run python tools/tier_data.py")


if __name__ == "__main__":
    main()
