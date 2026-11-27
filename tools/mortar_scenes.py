"""The Mortar's scenes and data (2026-11-24), rerunnable:

    python tools/mortar_scenes.py      then  python tools/tier_data.py  (the T2/T3 tiers and the leaves' tiers)

Art first: tools/sprite/parts/mortar_art.py (drakelings, shells, blasts) and tower_tiers.py ... mortar (T2/T3).
Writes
- scenes/unit/evolve_tree/puffe_mortar_evolve/<sheet>_frames.tres: SpriteFrames for the four drakeling sheets,
  the shells and the blasts (regions found on each packed .png, like tools/tier_data.py)
- scenes/unit/skills/projectiles/<element>_mortar_shell.tscn: the MortarShell with its shell and blast sprites
- scenes/unit/evolve_tree/puffe_mortar_evolve/: the element sprite swaps (drakeling on its element tower) and damage
  data (copies of the Bolter's: burn, slow and poison stacks, which every enemy in the blast can get)
- scenes/unit/building/buildings/puffe_mortar.tscn: from the Bolter's scene with the Mortar's stats, skill, art and
  element leaves; puffe_mortar.tres (the build tray, unlocks on level 13); the upgrade data (a copy of the Bolter's)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import enemy_scene as es

ROOT = es.ROOT
ART = "assets/art/units/building/puffe/puffe_mortar"
PROJ_ART = "assets/art/projectile"
EVOLVE = "scenes/unit/evolve_tree/puffe_mortar_evolve"
PROJ = "scenes/unit/skills/projectiles"
BOLTER_EVOLVE = "scenes/unit/evolve_tree/puffe_bolter_evolve"
ELEMENTS = ("physical", "fire", "frost", "poison")
COLOUR = {"physical": "", "fire": "red", "frost": "blue", "poison": "green"}
TOWER_BASE = {"physical": "basic_tower", "fire": "red_tower", "frost": "blue_tower", "poison": "green_tower"}
BOLTER_DAMAGE = {"physical": "physical", "fire": "red", "frost": "blue", "poison": "green"}
LOOPING = ("IDLE", "ATTACK", "FLY")
UNLOCK_LEVEL = 16
LIST_ID = 10

# the Mortar's numbers (placeholders until playtests): a slow, long-range lob that hits groups
PRICE = 6.0
DAMAGE = 10.4  # 1.3 in game (small numbers: divide by 8); 1.1 until 2026-11-27
RANGE_TILES = 4.5
MIN_RANGE_TILES = 1.5
CRIT_CHANCE = 0.05
CAST_SECONDS = 0.4
COOLDOWN_SECONDS = 3.0
# Utils.ModifyType Flat 0, Multiply 1; stat types (Utils.StatType)
FLAT, MULTIPLY = 0, 1
DAMAGE_STAT, CRIT_STAT, SPLASH, KNOCKBACK, PATCH_DURATION, PATCH_SHARE = 2, 7, 20, 24, 25, 26
# the element leaves (design doc, New Towers: bigger splash and knockback / burning patch / area slow / gas cloud)
LEAF_MODIFIERS = {
    "physical": [("DamageModifier", MULTIPLY, DAMAGE_STAT, 0.11), ("BlastModifier", FLAT, SPLASH, 0.25)],
    "fire": [("DamageModifier", MULTIPLY, DAMAGE_STAT, 0.07), ("PatchModifier", FLAT, PATCH_DURATION, 1.5),
             ("PatchShareModifier", FLAT, PATCH_SHARE, 0.2)],
    # the slow comes with every enemy in the blast (the damage data's slow stacks)
    "frost": [("DamageModifier", MULTIPLY, DAMAGE_STAT, 0.04)],
    "poison": [("CloudModifier", FLAT, PATCH_DURATION, 2.0), ("CloudShareModifier", FLAT, PATCH_SHARE, 0.15)],
}
LEAF = {"physical": "PhysicalElementEvolveLeaf", "fire": "FireElementEvolveLeaf",
        "frost": "FrostElementEvolveLeaf", "poison": "PoisonElementEvolveLeaf"}


def write(path, text):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf8", newline="\n") as f:
        f.write(text)


def sheet_name(element):
    return (COLOUR[element] + "_" if COLOUR[element] else "") + "puffe_mortar"


def frames(base, out_name):
    """SpriteFrames .tres for the sheet base (no extension); returns its res path."""
    aseprite, png = os.path.join(ROOT, base + ".aseprite"), os.path.join(ROOT, base + ".png")
    w, h, durs, tags = es.info(aseprite)
    where = es.regions(aseprite, png, w, h, len(durs))
    text = '[gd_resource type="SpriteFrames" format=3]\n\n[ext_resource type="Texture2D" path="res://%s.png" id="1_sheet"]\n\n' % base
    anims = []
    for tag, a, b in tags:
        refs = []
        for i in range(a, b + 1):
            text += '[sub_resource type="AtlasTexture" id="AtlasTexture_f%02d"]\natlas = ExtResource("1_sheet")\nregion = Rect2(%d, %d, %d, %d)\n\n' % (
                i, where[i][0], where[i][1], w, h)
            refs.append('{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_f%02d")\n}' % i)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (
            ", ".join(refs), "true" if tag in LOOPING else "false", tag, 1000.0 / durs[a]))
    text += "[resource]\nanimations = [%s]\n" % ", ".join(anims)
    path = "%s/%s_frames.tres" % (EVOLVE, out_name)
    write(path, text)
    return "res://" + path


def shell_scene(element, shell_frames, blast_frames):
    name = "%s_mortar_shell" % element
    title = "".join(p.capitalize() for p in name.split("_"))
    text = ('[gd_scene format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/skills/projectiles/mortar_shell.gd" id="1_script"]\n'
            '[ext_resource type="SpriteFrames" path="%s" id="2_shell"]\n'
            '[ext_resource type="SpriteFrames" path="%s" id="3_blast"]\n\n'
            '[node name="%s" type="Node2D"]\n'
            'script = ExtResource("1_script")\nprojectile_name = "%s"\n\n'
            '[node name="Shell" type="AnimatedSprite2D" parent="."]\ntexture_filter = 1\n'
            'sprite_frames = ExtResource("2_shell")\nanimation = &"FLY"\n\n'
            '[node name="Blast" type="AnimatedSprite2D" parent="."]\nvisible = false\ntexture_filter = 1\n'
            'sprite_frames = ExtResource("3_blast")\nanimation = &"BLAST"\n') % (shell_frames, blast_frames, title, title)
    path = "%s/%s.tscn" % (PROJ, name)
    write(path, text)
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
            'position = Vector2(0, 1)\ntexture = ExtResource("4_base")\n') % (drakeling_frames, TOWER_BASE[element], title)
    path = "%s/%s.tscn" % (EVOLVE, name)
    write(path, text)
    return "res://" + path


def damage_scene(element):
    src = open(os.path.join(ROOT, "%s/%s_puffe_bolter_evolve_damage_data.tscn" % (BOLTER_EVOLVE, BOLTER_DAMAGE[element])), encoding="utf8").read()
    text = re.sub(r' uid="[^"]+"', "", src, count=1)
    text = re.sub(r'load_steps=\d+ ', "", text)
    title = "%sMortarDamageData" % element.capitalize()
    text = re.sub(r'\[node name="[^"]+" type="Node"\]', '[node name="%s" type="Node"]' % title, text, count=1)
    path = "%s/%s_mortar_damage_data.tscn" % (EVOLVE, element)
    write(path, text)
    return "res://" + path


def set_props(text, node_header, props):
    """Sets props (name -> raw value) on the node whose header line starts with node_header."""
    m = re.search(r'%s[^\n]*\]\n(?:[^\[\n][^\n]*\n)*' % re.escape(node_header), text)
    block = m.group(0)
    for key, value in props.items():
        if re.search(r'^%s = ' % re.escape(key), block, re.M):
            block = re.sub(r'^%s = [^\n]*$' % re.escape(key), '%s = %s' % (key, value), block, flags=re.M)
        else:
            block = block.rstrip("\n") + "\n%s = %s\n" % (key, value)
    return text[:m.start()] + block + text[m.end():]


def remove_node_metadata(text, node_header):
    m = re.search(r'%s[^\n]*\]\n(?:[^\[][^\n]*\n|\n(?!\[))*' % re.escape(node_header), text)
    block = re.sub(r'metadata/_aseprite_wizard_[a-z_]+_ = (\{[^}]*\}|"[^"]*")\n', "", m.group(0))
    return text[:m.start()] + block + text[m.end():]


def tower_scene(drakeling_frames, shells, swaps, damages):
    text = open(os.path.join(ROOT, "scenes/unit/building/buildings/puffe_bolter.tscn"), encoding="utf8").read()
    text = re.sub(r'\[gd_scene [^\]]*\]', '[gd_scene format=3]', text, count=1)
    # the Bolter's own drakeling frames and their atlases go; the Mortar's frames come from a .tres
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("4_04kgf"\)\nregion = [^\n]*\n\n', "", text)
    text = re.sub(r'\[sub_resource type="SpriteFrames" id="SpriteFrames_udt3q"\]\nanimations = \[.*?\]\n\n', "", text, flags=re.S)
    text = text.replace('sprite_frames = SubResource("SpriteFrames_udt3q")', 'sprite_frames = ExtResource("m_frames")')
    # tiers come back from tools/tier_data.py with the Mortar's own
    text = re.sub(r'\[ext_resource type="Resource" path="res://scenes/unit/evolve_tree/tiers/[^\n]*\n', "", text)
    text = re.sub(r'\[ext_resource type="Script" path="res://scenes/unit/evolve_tree/evolve_tier_data.gd" id="tier_script"\]\n', "", text)
    text = re.sub(r'^tiers = [^\n]*\n', "", text, flags=re.M)
    replace_ext = {
        "4_04kgf": None,
        "snd_activate": '[ext_resource type="AudioStream" path="res://assets/audio/sfx/retro/nova_burst.ogg" id="snd_activate"]',
        "19_tlf38": '[ext_resource type="Texture2D" path="res://%s/puffe_mortar_icon.png" id="19_tlf38"]' % ART,
        "20_qaoyh": '[ext_resource type="Texture2D" path="res://%s/red_puffe_mortar_icon.png" id="20_qaoyh"]' % ART,
        "26_nwa4t": '[ext_resource type="Texture2D" path="res://%s/blue_puffe_mortar_icon.png" id="26_nwa4t"]' % ART,
        "29_pjst3": '[ext_resource type="Texture2D" path="res://%s/green_puffe_mortar_icon.png" id="29_pjst3"]' % ART,
        "9_elqq4": '[ext_resource type="PackedScene" path="%s" id="9_elqq4"]' % shells["physical"],
        "21_t17ii": '[ext_resource type="PackedScene" path="%s" id="21_t17ii"]' % shells["fire"],
        "26_k77d7": '[ext_resource type="PackedScene" path="%s" id="26_k77d7"]' % shells["frost"],
        "29_bqugu": '[ext_resource type="PackedScene" path="%s" id="29_bqugu"]' % shells["poison"],
        "22_ll5c1": '[ext_resource type="PackedScene" path="%s" id="22_ll5c1"]' % swaps["fire"],
        "26_alotc": '[ext_resource type="PackedScene" path="%s" id="26_alotc"]' % swaps["frost"],
        "28_4x4pp": '[ext_resource type="PackedScene" path="%s" id="28_4x4pp"]' % swaps["poison"],
        "20_ccteo": '[ext_resource type="PackedScene" path="%s" id="20_ccteo"]' % damages["physical"],
        "23_pbrrj": '[ext_resource type="PackedScene" path="%s" id="23_pbrrj"]' % damages["fire"],
        "27_pf0qb": '[ext_resource type="PackedScene" path="%s" id="27_pf0qb"]' % damages["frost"],
        "29_ajupy": '[ext_resource type="PackedScene" path="%s" id="29_ajupy"]' % damages["poison"],
        "0_upgradedata": '[ext_resource type="Resource" path="res://scenes/upgrades/building_upgrades/mortar_upgrade_data.tres" id="0_upgradedata"]',
    }
    for ext_id, line in replace_ext.items():
        pattern = r'\[ext_resource [^\n]*id="%s"\]\n' % re.escape(ext_id)
        assert re.search(pattern, text), ext_id
        text = re.sub(pattern, "" if line is None else line + "\n", text)
    first_sub = text.index("[sub_resource")
    text = text[:first_sub] + '[ext_resource type="SpriteFrames" path="%s" id="m_frames"]\n\n' % drakeling_frames + text[first_sub:]
    text = text.replace('[node name="PuffeBolter" type="StaticBody2D" node_paths=PackedStringArray("skill")]',
                        '[node name="PuffeMortar" type="StaticBody2D" node_paths=PackedStringArray("skill")]')
    text = set_props(text, '[node name="PuffeMortar"', {"can_hit_air": "false", "min_range_tiles": repr(MIN_RANGE_TILES)})
    text = remove_node_metadata(text, '[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."')
    text = remove_node_metadata(text, '[node name="TowerBaseSprite" type="Sprite2D" parent="AnimatedSprite2D"')
    text = set_props(text, '[node name="LaunchProjectile" parent="."', {
        "skill_type": "16", "skill_name": '"Shell"', "base_cast_time": repr(CAST_SECONDS), "base_cooldown": repr(COOLDOWN_SECONDS)})
    for node, value in (("Damage", DAMAGE), ("AttackRange", RANGE_TILES), ("CriticalChance", CRIT_CHANCE)):
        text = set_props(text, '[node name="%s" type="Node" parent="LaunchProjectile/Stats"' % node,
                         {"base_value": repr(value), "value": repr(value)})
    text = set_props(text, '[node name="Price" type="Node" parent="Stats"', {"base_value": repr(PRICE), "value": repr(PRICE)})
    text = set_props(text, '[node name="SelectableUnit" parent="."', {"display_name": '"Mortar"'})
    # the leaves' modifiers: the Bolter's go, the Mortar's come in
    text = re.sub(r'\[node name="[A-Za-z]+Modifier" type="Node" parent="EvolveTree/EvolveBranch\d?/[A-Za-z]+ElementEvolveLeaf"\]\n(?:[^\[\n][^\n]*\n)*\n?', "", text)
    branch = {"physical": "EvolveBranch", "fire": "EvolveBranch2", "frost": "EvolveBranch3", "poison": "EvolveBranch4"}
    for element in ELEMENTS:
        leaf_path = "EvolveTree/%s/%s" % (branch[element], LEAF[element])
        nodes = ""
        for name, modify, stat, value in LEAF_MODIFIERS[element]:
            nodes += ('[node name="%s" type="Node" parent="%s"]\nscript = ExtResource("24_v32av")\ncalculate_type = %d\n'
                      'stat_type = %d\nvalue = %s\n\n') % (name, leaf_path, modify, stat, repr(value))
        m = re.search(r'\[node name="%s" type="Node" parent="[^"]+"\]\n(?:[^\[\n][^\n]*\n)*\n?' % LEAF[element], text)
        text = text[:m.end()] + nodes + text[m.end():]
    # the physical leaf now swaps in the physical shell like the others (the Bolter's keeps its base bolt)
    text = set_props(text, '[node name="PhysicalElementEvolveLeaf"', {"new_projectile_scene": 'ExtResource("9_elqq4")'})
    text = text.replace("\n\n\n", "\n\n")
    write("scenes/unit/building/buildings/puffe_mortar.tscn", text)


def list_element():
    text = ('[gd_resource type="Resource" script_class="BuildingListElement" format=3]\n\n'
            '[ext_resource type="Script" path="res://scenes/unit/building/building_list_element.gd" id="1_script"]\n'
            '[ext_resource type="Texture2D" path="res://%s/puffe_mortar_icon.png" id="2_icon"]\n'
            '[ext_resource type="PackedScene" path="res://scenes/unit/building/buildings/puffe_mortar.tscn" id="3_scene"]\n\n'
            '[resource]\nscript = ExtResource("1_script")\nscene = ExtResource("3_scene")\nid = %d\nicon = ExtResource("2_icon")\n'
            'unlock_level = %d\ndescription = "Lobs shells that burst on every ground enemy around where they land. '
            'Long range, but cannot fire at enemies right next to it, nor at flyers."\n') % (ART, LIST_ID, UNLOCK_LEVEL)
    write("scenes/unit/building/buildings/puffe_mortar.tres", text)


def upgrade_data():
    path = "scenes/upgrades/building_upgrades/mortar_upgrade_data.tres"
    if os.path.exists(os.path.join(ROOT, path)):
        return
    src = open(os.path.join(ROOT, "scenes/upgrades/building_upgrades/bolter_upgrade_data.tres"), encoding="utf8").read()
    write(path, re.sub(r' uid="[^"]+"', "", src, count=1))


def main():
    drakelings = {e: frames("%s/%s" % (ART, sheet_name(e)), sheet_name(e)) for e in ELEMENTS}
    shells = {}
    for element in ELEMENTS:
        shell_frames = frames("%s/%s_mortar_shell" % (PROJ_ART, element), "%s_mortar_shell" % element)
        blast_frames = frames("%s/%s_mortar_blast" % (PROJ_ART, element), "%s_mortar_blast" % element)
        shells[element] = shell_scene(element, shell_frames, blast_frames)
    swaps = {e: swap_scene(e, drakelings[e]) for e in ELEMENTS}
    damages = {e: damage_scene(e) for e in ELEMENTS}
    upgrade_data()
    tower_scene(drakelings["physical"], shells, swaps, damages)
    list_element()
    print("mortar scenes written; now run python tools/tier_data.py")


if __name__ == "__main__":
    main()
