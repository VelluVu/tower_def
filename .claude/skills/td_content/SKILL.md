---
name: td_content
description: Use when adding or changing Puffe TD (puffetd) content - a tower, enemy, evolve upgrade, element evolution, projectile or level - or its pixel art. Lists the files each one needs and the checks to run.
---

# Adding Content to Puffe TD

Always copy the closest existing piece and change it; the scenes depend on exact child names. Read the source `.tscn` first.

## Tower
1. Copy `scenes/unit/building/buildings/puffe_bolter.tscn` (projectile), `puffe_nova.tscn` (area) or `puffe_beamer.tscn` (beam).
2. Set the `Stats` children (Health, MaxHealth, Price, AttackRange in tiles, ...) and the skill's own `Stats`/`DamageData` (damage type, overtime effects).
3. Point `icon` and the `AnimatedSprite2D` frames at the new art.
4. Make a `BuildingListElement` `.tres` next to it; `Builder._get_buildings` loads every `.tres` in that folder. Its `id` is also the unlock order: building `id` N unlocks when `PlayerProgress.level_progress` > N.
5. Upgrades and element choices: set the `EvolveTree`'s `upgrade_data` (a `BuildingUpgradeData` `.tres` in `scenes/upgrades/building_upgrades/`; towers share `tower_upgrade_data.tres`), and add `ElementEvolveLeaf` nodes (under `EvolveBranch`es) to the `EvolveTree` (see `puffe_bolter.tscn` and `scenes/unit/evolve_tree/puffe_bolter_evolve/`). `BuildingTypeUpgrades` offers one button per leaf at the evolve step and applies the bought leaf to every building of that scene by its node path, so keep the names identical across edits. Set `icon` (button) and `info` (tooltip). Leaves can swap the projectile, beam texture, damage data or sprite, and add `Modifier` children.

## Enemy
1. Copy `scenes/unit/enemy/enemies/weakling.tscn`; keep the Beehave tree, `Hitbox`, `GoreEmitter`, `PopUpSpot`.
2. Stats: Health/MaxHealth, Speed, Damage (life taken at the end point, added to the skill's Damage), Price (gold on kill).
3. Use it in a wave: a `SpawnGroupData` in a `WaveData` `.tres` (`scenes/level/level_data/waves/`) with `enemy_scene`, `count`, `interval`, `delay`, `spawner_id`.

## Stat upgrade card
- Add an `EvolveResource` `.tres` to `scenes/unit/evolve_tree/evolve_resources/`; it is picked up from the folder automatically and offered when it fits at least one placed tower (`UpgradeRules.fits_tower`).
- `modifier_type`: StatModifier (unit stat), SkillModifier (skill stat; set the `skill_type` flags so only matching towers get it), GlobalModifier. `modify_type`: Flat, Additive (fraction summed with the other Additive bonuses, 0.1 = +10%; the default choice for cards) or Multiply (fraction that compounds, shown as ×; for rare big bonuses). A stat whose base is 0 (AttackSpeed, ActiveDuration) needs Flat, since a percent of 0 stays 0. `elements` flags restrict it to towers of that element. `evolve_level_reguirement` gates it by upgrade level. `is_randomized_modify_value` turns the ×2/×3 roll on.
- Set `evolve_icon`; the card shows it above `evolve_name` and the value.

## Level
1. Copy `scenes/level/levels/level_001.tscn` to `level_00N.tscn` (the number is parsed from the file name).
2. Paint the tile layers; walkable/buildable comes from each tile's `TileType` custom data in the tile set.
3. Place `Spawner`s (spawn points with a unique `id`, group `Spawner`) and the `EndPoint` marker. Make a `LevelData` `.tres` in `scenes/level/level_data/` (never in `levels/`, every file there is loaded as a level) with starting gold, life and `WaveData` files, and set it as the root's `level_data`. The level is won when the last wave has spawned and no enemy is left.
4. `SceneManager` loads every scene in `levels/` by itself; add a `MapLevelElement` to the world map (`scenes/ui/game_world_map/`).

## Pixel art
- Hand-made in Aseprite; `.aseprite` sources live next to the exported `.png` in `assets/art/`. AsepriteWizard imports them into SpriteFrames; animation tags must use the `GlobalAnimationNames` names (IDLE, WALK, ATTACK, START_ATTACK, STOP_ATTACK, DEATH).
- 16 px grid, nearest filtering. Match the existing palette and outline style of the neighbouring sprites.
- Ask before generating or replacing art. When editing, work on the user's current file.

## Checks after a content change
- Run `godot --headless --quit` from the project folder: missing `ext_resource`s and script errors show up there.
- Play the level: place the tower, let one wave through, watch the Output panel for null `get_stat` errors and pathing warnings.
- Remember `GameSignals.testing` is on (free buildings, all unlocked); test once with it off for balance.
