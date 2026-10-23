---
name: td_shaders
description: Use when writing or reviewing Godot shaders (.gdshader or VisualShader .tres) in Puffe TD (puffetd) - outlines, hit flashes, fades, beams, element effects, particles - on its 16 px pixel art with the Mobile renderer.
---

# Shaders in Puffe TD

## What exists (`assets/shaders/`, materials in `shader_materials/`)
| Shader | Used for | Notes |
| --- | --- | --- |
| `outline.gdshader` | selection outline (`outline_shader_material.tres`) | Loops over a (2·width+1)² neighbourhood per pixel; fine at width 1-2, expensive above. Grows the quad with `add_margins`. |
| `hit_flash.tres` (VisualShader) | `building_/enemy_hit_shader_material.tres` | `hit_color` + `enabled` bool, keyed by the unit's "hit" `AnimationPlayer` animation (`AnimationControl.play_hit_animation`). |
| `fade.gdshader` | dithered fade-out (`fade` 0-4 steps) | Ordered-dither look that suits pixel art better than alpha. |
| `beam_animation.gdshader` | Beamer beam scroll | Scrolls UV by `TIME * speed`. |
| `cutout_shader.gdshader`, `paint_texture.gdshader` | masking / texture swap tests | `paint_texture` has empty stubs; `test_paint_shader.tscn` is a test scene. |

Check a material's users with a grep for its path in `.tscn` files before changing its uniforms; materials are shared resources.

## Pixel art rules
- Textures are nearest-filtered (project default). Declare samplers `filter_nearest` so a material never smooths a sprite: `uniform sampler2D mask : filter_nearest;`.
- Work in texel units: use `TEXTURE_PIXEL_SIZE` for offsets so outlines and effects stay one art pixel wide at any zoom (the camera zooms 2x and up).
- Snap animated UVs to whole texels when the motion should look pixel-true: `floor(uv / TEXTURE_PIXEL_SIZE) * TEXTURE_PIXEL_SIZE`.
- Prefer stepped/dithered transitions (like `fade`) over smooth alpha ramps; colours should come from the sprites' palette or a `source_color` uniform.

## Game time vs shader time
- `TIME` keeps running while the tree is paused (level-up menu, pause menu) and ignores the 1x-3x game speed. For effects that must follow game speed or stop on pause (beam scroll, burning flicker), drive a `uniform float game_time` from GDScript (accumulate `delta * time_scale` in `_process` of a pausable node) instead of `TIME`.

## Element look
- Elements (Physical, Fire, Frost, Poison) are colour-coded: Fire `Color.RED`/`0xff8472`, Frost `Color.SKY_BLUE`/`0x7effff`, Poison `Color.YELLOW_GREEN`/`0x92ff7e` (see `ElementEvolveLeaf`). Reuse these for tints, glows and particles so a Fire Bolter's effects match its sprite.
- Element evolutions swap sprite frames, projectile scenes and beam textures; a shader effect per element should be a uniform on a shared shader, not a copied shader per element.

## Style
- Explicit types and hints on every uniform: `uniform vec4 hit_color : source_color = vec4(0.83, 0.13, 0.0, 1.0);`, `uniform float strength : hint_range(0.0, 1.0) = 1.0;`, `uniform sampler2D noise : filter_nearest, repeat_enable;`.
- snake_case uniform names; colour/texture uniforms first, then numbers, then toggles.
- Per-pixel branches on data become `mix`/`step`/`smoothstep`; a bool toggle multiplies (`COLOR.rgb = mix(COLOR.rgb, hit_color.rgb, float(enabled) * strength);`). Loops with constant bounds are fine.
- Sample each texture once per UV. Avoid `discard` unless it is a true cutout.
- Set parameters from GDScript with `material.set_shader_parameter(&"hit_color", color)`; if one unit needs its own value, make the material `resource_local_to_scene` or use per-instance uniforms (`instance uniform`), otherwise every unit sharing the material changes.

## Renderer
- The project uses the Mobile renderer. A web export would need Compatibility (GLES3): avoid features it lacks (compute, some texture formats) in shaders that should ship to web.
