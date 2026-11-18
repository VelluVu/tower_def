"""Make an enemy scene from a template enemy and a sprite made by tools/sprite (its .aseprite and packed .png).

    python tools/enemy_scene.py <template> <name> [key=value...]

Copies scenes/unit/enemy/enemies/<template>.tscn to <name>.tscn, points the sprite and icon at
assets/art/units/enemy/<name>/, rebuilds the SpriteFrames from the .aseprite's tags and durations (each frame's
region found on the packed sheet), and sets what is given:
    health=, damage= (life taken at the castle), price= (kill gold), speed=, sprite_y=, popup_y=, gore=<spill scene name>,
    boss=1, death_bursts=, xp=<xp_multiplier>, attack_distance=, hitbox=WxH, display=<root node name>
Loops: IDLE and WALK loop, the other tags play once. Keep the template's skill, tree and effects; abilities
are separate children (see EnemyAbilities)."""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITE = os.path.join(ROOT, "tools", "sprite", "sprite.py")
ENEMIES = "scenes/unit/enemy/enemies/%s.tscn"
ART = "assets/art/units/enemy/%s/%s"
LOOPING = ("IDLE", "WALK")
STATS = {"health": ("MaxHealth", "Health"), "damage": ("Damage",), "price": ("Price",), "speed": ("Speed",)}


def info(path):
    out = subprocess.run([sys.executable, SPRITE, "info", path], capture_output=True, text=True).stdout
    size = re.search(r"(\d+)x(\d+)\s+mode", out)
    durs = [int(v) for v in re.search(r"durations\(ms\): ([\d,]+)", out).group(1).split(",")]
    tags = [(m.group(1), int(m.group(2)) - 1, int(m.group(3)) - 1) for m in re.finditer(r"tag (\S+) (\d+)-(\d+)", out)]
    return int(size.group(1)), int(size.group(2)), durs, tags


def regions(aseprite, png, w, h, n):
    from PIL import Image, ImageChops
    tmp = aseprite + ".frames.png"
    subprocess.run([sys.executable, SPRITE, "view", aseprite, tmp, "--scale", "1"], capture_output=True)
    row = Image.open(tmp).convert("RGBA")
    row.load()
    os.remove(tmp)
    sheet = Image.open(png).convert("RGBA")
    cols, rows = sheet.width // w, sheet.height // h
    slots = [((s % cols) * w, (s // cols) * h) for s in range(cols * rows)]
    out = []
    for i in range(n):
        frame = row.crop((i * w, 0, i * w + w, h))
        # the packed sheet keeps frame i at slot i unless it repeats an earlier frame
        order = ([slots[i]] if i < len(slots) else []) + slots
        for x, y in order:
            if ImageChops.difference(frame, sheet.crop((x, y, x + w, y + h))).getbbox() is None:
                out.append((x, y))
                break
        else:
            sys.exit("frame %d of %s is not on %s" % (i, aseprite, png))
    return out


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    template, name = argv[1], argv[2]
    opts = dict(a.split("=", 1) for a in argv[3:])
    text = open(os.path.join(ROOT, ENEMIES % template), encoding="utf8").read()
    # a copy must not keep the template's uid: references by uid (the Broodmother's tunnel beefling) would resolve to it
    first = text.index("\n")
    text = re.sub(r' (uid="[^"]+"|load_steps=\d+)', "", text[:first]) + text[first:]
    aseprite = os.path.join(ROOT, ART % (name, name + ".aseprite"))
    png = os.path.join(ROOT, ART % (name, name + ".png"))
    w, h, durs, tags = info(aseprite)
    where = regions(aseprite, png, w, h, len(durs))

    # textures: the template's sheet and icon become the new ones
    tex = re.search(r'\[ext_resource type="Texture2D"[^\]]*path="res://assets/art/units/enemy/%s/%s.png" id="([^"]+)"\]' % (template, template), text)
    icon = re.search(r'\[ext_resource type="Texture2D"[^\]]*path="res://assets/art/units/enemy/%s/%s_icon.png" id="([^"]+)"\]' % (template, template), text)
    sheet_id = tex.group(1)
    text = text.replace(tex.group(0), '[ext_resource type="Texture2D" path="res://%s" id="%s"]' % (ART % (name, name + ".png"), sheet_id))
    text = text.replace(icon.group(0), '[ext_resource type="Texture2D" path="res://%s" id="%s"]' % (ART % (name, name + "_icon.png"), icon.group(1)))
    if "gore" in opts:
        text = re.sub(r'(\[ext_resource type="PackedScene"[^\]]*?)(?: uid="[^"]+")?( path="res://scenes/unit/)\w+_spill\.tscn"',
                      r'\g<1>\g<2>%s.tscn"' % opts["gore"], text)

    # sprite frames
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="[^"]+"\]\natlas = ExtResource\("[^"]+"\)\nregion = Rect2\([^)]*\)\n\n', '', text)
    m = re.search(r'\[sub_resource type="SpriteFrames" id="([^"]+)"\]\nanimations = \[.*?\]\n\n', text, re.S)
    subs, anims = "", []
    for tag, a, b in tags:
        frames = []
        for i in range(a, b + 1):
            subs += '[sub_resource type="AtlasTexture" id="AtlasTexture_f%02d"]\natlas = ExtResource("%s")\nregion = Rect2(%d, %d, %d, %d)\n\n' % (
                i, sheet_id, where[i][0], where[i][1], w, h)
            frames.append('{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_f%02d")\n}' % i)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.4f\n}' % (
            ", ".join(frames), "true" if tag in LOOPING else "false", tag, 1000.0 / durs[a]))
    subs += '[sub_resource type="SpriteFrames" id="SpriteFrames_%s"]\nanimations = [%s]\n\n' % (name, ", ".join(anims))
    text = text[:m.start()] + subs + text[m.end():]
    text = text.replace('sprite_frames = SubResource("%s")' % m.group(1), 'sprite_frames = SubResource("SpriteFrames_%s")' % name)
    text = re.sub(r'"o_folder": "res://assets/art/units/enemy/%s"' % template, '"o_folder": "res://assets/art/units/enemy/%s"' % name, text)
    text = text.replace('"o_name": "%s"' % template, '"o_name": "%s"' % name)
    text = re.sub(r'"source": "res://assets/art/units/enemy/%s/[^"]+"' % template, '"source": "res://%s"' % (ART % (name, name + ".aseprite")), text)

    # root
    root = re.search(r'\[node name="([^"]+)" type="RigidBody2D"[^\]]*\]\n', text)
    display = opts.get("display", "".join(p.capitalize() for p in name.split("_")))
    text = text.replace(root.group(0), root.group(0).replace('name="%s"' % root.group(1), 'name="%s"' % display))
    root_props = ""
    if opts.get("boss") == "1" and "is_boss = true" not in text:
        root_props += "is_boss = true\n"
    if "xp" in opts:
        text = re.sub(r"\nxp_multiplier = [\d.]+", "", text)
        root_props += "xp_multiplier = %s\n" % float(opts["xp"])
    if root_props:
        text = re.sub(r'(\[node name="%s" type="RigidBody2D"[^\]]*\]\n(?:[^\[\n][^\n]*\n)*?)(icon = [^\n]+\n)' % display,
                      r'\g<1>\g<2>%s' % root_props, text, count=1)

    def node_prop(node, prop, value):
        nonlocal text
        pat = r'(\[node name="%s" type="[^"]+" parent="[^"]*"[^\]]*\]\n(?:[^\[\n][^\n]*\n)*?)%s = [^\n]+\n' % (node, prop)
        if re.search(pat, text):
            text = re.sub(pat, r'\g<1>%s = %s\n' % (prop, value), text, count=1)
        else:
            text = re.sub(r'(\[node name="%s" type="[^"]+" parent="[^"]*"[^\]]*\]\n)' % node, r'\g<1>%s = %s\n' % (prop, value), text, count=1)

    if "sprite_y" in opts:
        node_prop("AnimatedSprite2D", "position", "Vector2(0, %s)" % opts["sprite_y"])
    if "popup_y" in opts:
        node_prop("PopUpSpot", "position", "Vector2(0, %s)" % opts["popup_y"])
    if "death_bursts" in opts:
        node_prop("GoreEmitter", "death_bursts", opts["death_bursts"])
    if "attack_distance" in opts:
        text = re.sub(r"attack_distance = [\d.]+", "attack_distance = %s" % float(opts["attack_distance"]), text, count=1)
    if "hitbox" in opts:
        bw, bh = opts["hitbox"].split("x")
        hb = re.search(r'\[node name="CollisionShape2D" type="CollisionShape2D" parent="Hitbox"\]\n(?:[^\[\n][^\n]*\n)*?shape = SubResource\("([^"]+)"\)', text)
        text = re.sub(r'(\[sub_resource type="RectangleShape2D" id="%s"\]\n)size = Vector2\([^)]*\)' % hb.group(1),
                      r'\g<1>size = Vector2(%s, %s)' % (bw, bh), text)
    for key, nodes in STATS.items():
        if key in opts:
            for node in nodes:
                # since Godot 4.7 the editor writes a unique_id into the node line; without [^\]]* the stat silently
                # stayed the template's (the ash runner had the scout's health, the cinder imp the fastling's)
                text = re.sub(r'(\[node name="%s" type="Node" parent="Stats"[^\]]*\]\nscript = ExtResource\("[^"]+"\)\n)base_value = [\d.]+\nvalue = [\d.]+' % node,
                              r'\g<1>base_value = %s\nvalue = %s' % (float(opts[key]), float(opts[key])), text)
    out = os.path.join(ROOT, ENEMIES % name)
    open(out, "w", encoding="utf8", newline="\n").write(text)
    print("wrote", ENEMIES % name, "(%d frames, %s)" % (len(durs), ", ".join(t for t, _, _ in tags)))


if __name__ == "__main__":
    main(sys.argv)
