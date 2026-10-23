# Project Instructions and Context - Puffe TD

Project name `puffetd` (`config/name`, so saves are in `%APPDATA%/Godot/app_userdata/puffetd/`; the old `tower_def` folder there holds the pre-rename save). The GitHub repo and the project folder are still `tower_def` until the user renames them.

## Game Description
- **Genre:** 2D tower defense roguelike, top-down pixel art (16 px tiles).
- **Theme:** You play the dragons ("Puffe"). Dragon towers defend old castles from waves of invading creatures; the usual TD roles reversed.
- **Loop:** Pick a level on the world map, place towers and walls on a grid, start the waves; enemies walk from spawners to the end point. Each enemy reaching the end costs life; killing one gives gold and XP. XP fills one bar per level (not per tower); each level-up pauses the game and offers 4 global stat cards (the roguelike layer) that apply to every matching tower, placed or placed later. Gold also buys upgrades per building type in the selection panel: two upgrades, then an element choice (Physical/Fire/Frost/Poison) that changes every building of that type, then more upgrades. Upgrades reset when the level ends. Clearing a level unlocks the next level; every building is available from the start.
- **Player resources (per level, `PlayerStats`):** gold and life, set per level in its `LevelData` (start gold 8, 8, 12; life 10).
- **Language:** Code, comments and in-game text are English.
- **Engine:** Godot 4.7 (the editor upgraded `project.godot` from 4.6; the README still says 4.3), Mobile renderer, `default_texture_filter=0` (nearest), viewport stretch.

## Content
- **Towers** (`scenes/unit/building/buildings/`, each a `.tscn` plus a `BuildingListElement` `.tres`): `puffe_bolter` (homing bolts), `puffe_nova` (area burst), `puffe_beamer` (continuous beam), `leopard_trap` (trap, enemies walk over it), `wall` (cheap blocker for mazing).
- **Enemies** (`scenes/unit/enemy/enemies/`): weakling, fastling, swampling, fastswampling, beefling, swbeefling. All share `enemy.gd` and the Beehave tree in `scenes/unit/behaviour_trees/basic_enemy_behaviour_tree/`.
- **Levels** (`scenes/level/levels/level_00N.tscn`): three. The number in the file name is the level number used by `SceneManager.load_level_by_number`. Each has a `LevelData` `.tres` in `scenes/level/level_data/` (starting gold/life, waves; wave files in `level_data/waves/`). Keep data out of `levels/`: `SceneManager` loads every file there as a level.
- **Stat cards** (`scenes/unit/evolve_tree/evolve_resources/*.tres`, `EvolveResource`): loaded from the folder by the `RandomEvolveResourceCollection` autoload. Each offer rolls its own value (`UpgradeRules.roll_value`: 20% ×3, 30% ×2).
- **Gold upgrades and elements:** each building's `EvolveTree.upgrade_data` (`BuildingUpgradeData` `.tres` in `scenes/upgrades/building_upgrades/`: upgrade modifiers, upgrade and evolve prices) plus the `ElementEvolveLeaf` nodes under its `EvolveTree` (in the tower `.tscn`) as the element choices; their swap scenes are in `scenes/unit/evolve_tree/puffe_*_evolve/`. Prices are ratios of the building's own Price (`UpgradeRules.gold_price`, rounded up). One data file per building type (`bolter_upgrade_data.tres`, ..., `wall_upgrade_data.tres`); walls and the Leopard Trap have no element leaves, so they only get upgrades.
- **Elements / damage types:** Physical, Fire, Frost, Poison (bit flags in `Utils`; Physical was called Normal before 2026-10-23, and some art files still use `normal_` names). Overtime effects (burn, slow, poison) are `OvertimeEffectData` children of a skill's `DamageData`.

## Project Structure
The game is under `scenes/` (scripts sit next to their scenes); there is no `src/` split. Reusable systems copied from Pimeä Panimo are in `systems/`, dev tools in `tools/`.
- `scenes/` root: `main.tscn`/`main.gd` (time scale, pause, level flow) and the autoload scripts.
- `scenes/level/`: `Level` (tile layers, `AStarGrid2D` pathing, building and enemy bookkeeping, wave cleared / win check), `WaveRunner` (created by `Level`, starts waves), `PathPreview` (created by `Level`: spawn and castle markers, dotted enemy routes while building), `LevelBackdrop` (dark fill around the level), `PlayerStats`, `Tiles`, the level scenes, `level_data/` (`LevelData`, `WaveData`, `SpawnGroupData`).
- `scenes/unit/`: shared unit parts (`AnimationControl`, `ModifierManager`, gore), plus
  - `building/`: `Building` (StaticBody2D base), `Tower`, `Wall`, `Trap`, `Builder` (placement input), `PlacementValidator`, `RangeArea`
  - `enemy/`: `Enemy` (RigidBody2D)
  - `skills/`: `Skill` base and `LaunchProjectile`, `Beam`, `Emitter`, `MeleeAttack`; `DamageData`, overtime effects; `projectiles/`
  - `stats/`: `Stats` (container node), `Stat` (one value node), `Modifier`, `ModifierData`
  - `evolve_tree/`: `EvolveTree` (holds the element leaves and the tower's current element), branches, leaves, `EvolveResource`
  - `behaviour_trees/`: Beehave trees, one leaf script per condition/action
  - `spawner/`: `Spawner` (a spawn point: `id`, `end_point`) and `SpawnGroupRunner` (a `CustomTimer` that spawns one group, then frees itself); `unit_selection/`
- `scenes/upgrades/`: the level upgrades, created by `Level` in `_ready`. `BuildingTypeUpgrades` (gold upgrades and element per building type, bought through `UISignals.gold_upgrade_pressed`, shown via `gold_upgrades_changed`; created before `LevelUpgrades` so a new building gets its element before the cards), `GoldUpgradeOption` (one button), `BuildingUpgradeData`; `LevelUpgrades` (XP, level, chosen stat cards, applies cards), `UpgradeCard` (one offer), `UpgradeRules` (static: XP curve, value roll, which cards fit a tower, `next_gold_step`).
- `scenes/ui/`: bottom panel (build and selection panels), `level_up_menu/` (the card choice), `wave_panel/` (wave counter, start / early-start button), menus, world map, damage numbers, speed control, resource display (gold, life, upgrade XP).
- `scenes/camera/`: `GameCamera` (WASD/arrows pan, wheel zoom, middle mouse drag; a level starts zoomed to fit its spawners and castle, and never zooms out past the level's width).
- `assets/`: `art/` (`.aseprite` sources next to their exported `.png`), `shaders/` (outline, hit flash, fade, beam, cutout, paint), `ui_themes/`.
- `scenes/console/`: the game's console command sets. `dev_mode_commands.gd` and `level_cheat_commands.gd` are gitignored and left out of the export (`export_presets.cfg` exclude filter).
- `systems/`: self-contained systems from Pimeä Panimo, one folder each: `input/` (`InputBindings`, actions registered in `InputMap` at runtime), `console/` (`DevConsole`, command registry, command sets) and `save/` (`SaveFile` crash-safe writes with a `.bak.tres` fallback, `SaveSlot` versioned save with `_migrate`). A system references only its own folder; its `*_wiring.gd` is the only file that knows the game. They keep Pimeä Panimo's `name: Type` colon style so they can be synced back. Run `python tools/check_systems.py` after changing one. Planned next: `tooltip`, `settings`, `audio`.
- `addons/`: `beehave` 2.8.0 (behaviour trees), `AsepriteWizard` 8.0.1 (imports `.aseprite` into SpriteFrames), `godot_ai` 4.2.3 (live editor MCP plugin, copied from Pimeä Panimo; it adds its `_mcp_game_helper` autoload to `project.godot` on the first editor start).
- No tests yet. The plugin's `McpTestSuite` (`addons/godot_ai/testing/`) is available when they are added.

## Godot AI MCP (live editor)
- With the editor open on this project, use the `godot-ai` tools: `scene_get_hierarchy`/`node_find` before relying on a node path, `project_run` + `logs_read` (`source="game"`) after a change, `editor_screenshot` for UI changes.
- If Pimeä Panimo's editor is open at the same time, both connect to the same server: check `session_manage` and activate this project's session (`session_activate`) before any call.
- A `game_eval` that crashes freezes the game: stop and relaunch it. Evals abort after about 8 s, so poll in short calls.

## Architecture
- **Two signal buses (autoloads):** `GameSignals` for gameplay events (building placed/destroyed/sold, enemy spawned/destroyed/reached end, damage taken, resource change, level loaded/completed, lose, time scale, pause) and `UISignals` for UI requests (building option selected, upgrade chosen, menu buttons, speed buttons). UI only talks to gameplay through these.
- **Console and developer mode:** `DevConsole` sits in `Main/ConsoleLayer` (process always, so it works while paused); C opens it, Esc closes it. `ConsoleWiring` registers the commands and logs gameplay events. `iddqd` toggles `GameSignals.developer_mode` (never saved, shows the DEVELOPER MODE ON label); dev-only cheats then work: `gold`, `life`, `xp`, `levelup`, `free` (`GameSignals.free_build`: buildings and upgrades cost nothing), `wave`, `kill`, `spawn`, `win`, `lose`, `speed`, `unlock`, `reset confirm`. New game input that reads keys should skip them while a `LineEdit` has focus (see `GameCamera`, `Builder._input`).
- **Other autoloads:** `GroupNames` and `GlobalAnimationNames` (string constants), `Utils` (enums `StatType`, `TileType`, `DamageType`, `Element`, `SkillType`, `ModifyType`, `ModifierType`, plus `game_control` = the `Main` node), `InputManager` (extends `InputWiring`: the console and cancel actions; the camera, build and click actions are still in `project.godot`), `PlayerProgress` (owns a `SaveWiring` child that saves a `ProgressData` resource, `scenes/progress_data.gd`, to `user://player_progress.tres`; the old JSON `user://player_progress.save` is imported once and renamed to `.save.old`), `BuildingPlacementDrawer`, `RandomEvolveResourceCollection`, and Beehave's two debug autoloads.
- **Composition by child nodes:** a unit is a body with children found by type: `Stats` (with `Stat` children), one `Skill` (with its own `Stats`, `DamageData` and `SkillStateTimers`), `ModifierManager`, `OvertimeEffectHandler`, `EvolveTree`, a `BeehaveTree`, `SelectableUnit`, `AnimationControl` (the AnimatedSprite2D). Getters fall back to scanning `get_children()` when an export is empty.
- **Stats:** a skill's effective stat = `(unit base + skill base + flats) × (1 + Σ Additive) × Π(1 + Multiply)` (`ModifierManager.combine`, called from `calculate_modifier`; the result goes to the skill stat when the skill has the stat). `Utils.ModifyType`: Flat, Multiply (compounds, "more"), Additive (summed, "increased"). Cards and gold upgrades use Additive, slows and element leaves Multiply. `Stat.changed` drives reactions such as the range area radius and timer scaling.
- **Skills:** cast timer → `activate()` → active timer and cooldown timer. Continuous skills (beam) restart when the target changes. Attack speed scales the timers (`CustomTimer.scale_wait_time`). An element can swap the whole skill (`ElementEvolveLeaf.new_skill_scene` → `Building.replace_skill`): the skill scenes have no `Stats`/`DamageData`, so the new skill takes the old skill's nodes over, modifiers included; a skill scene with its own `Stats` gets the modifiers copied instead. Swap the sprite too (`new_animated_sprite_scene`) so the animations match.
- **Time scale:** game speed 1x-3x is done by hand: every `CustomTimer` and `Enemy` listens to `GameSignals.time_scale_change` and rescales itself; `Engine.time_scale` is not used.
- **Pathing:** `Level` builds an `AStarGrid2D` from the ground layer; tile custom data `TileType` (flags Normal/Blocking/OnlyBuildable/OnlyWalkable) decides walkable and buildable cells. Buildings do not block the grid, they raise the cell weight (`astar_weight`, 100), so enemies route around towers and attack them when there is no other way. Every `astar_grid_updated` makes every enemy repath.
- **Flow:** `Main` → menu → `PlayerProgress` new/continue → world map → `SceneManager.load_level_by_number` → `Level._ready` applies its `LevelData` and emits `level_loaded` → `Builder` and UI hook in → build phase → `UISignals.start_wave_pressed` → `WaveRunner` runs the wave's groups → `GameSignals.wave_cleared` (break) or, after the last wave, `level_completed`; or `lose_game`. `GameSignals.wave_state_changed` keeps the wave panel up to date.

## Code Style (as written in this project)
- Godot 4 syntax only, static typing on vars, params and returns. The existing style puts spaces around the colon: `var gold : float = 6.0`, `func take_damage(damage_data : DamageData) -> void:`. Match it.
- `class_name` on every reusable script, PascalCase; snake_case files, methods, signals; UPPER_CASE consts.
- Log and warning strings are local `const`s (`..._WARNING`, `..._ERROR`, `..._MESSAGE`); action, group and animation names come from consts or the name autoloads, never inline literals.
- Properties with `get =`/`set =` pointing at `_get_x`/`_set_x` methods; setters return early when the value is unchanged.
- Signals are declared after the vars in older scripts; put new signals at the top.
- Node refs with `@onready var x : Type = $Path`. Connect signals with `signal.connect(callable)` and guard with `is_connected` where a node can re-enter the tree.
- Prefer data in `.tres` resources over lists in scripts (the evolve resources and building list already work this way).

## Open Design: Progression (2026-10-22)
The full plan is in `docs/design/progression.md`; read it before working on upgrades, evolves, talent trees, modes or enemies, and keep it updated as planning continues. Nothing in it is built yet.
- **Planned:** element talent trees (Fire, Frost, Poison, Building) in the menu, earned with talent points (max 5 per level and mode); gold upgrades and evolves bought per building type during a level; the XP cards stay as the roguelike layer.
- **Replaced:** the type-XP / `EvolveGlow` idea, and element cards in `LevelUpgrades`.
- **Levels (decided):** any size and shape, camera bounds from the tilemap; set waves with a build break after each (skip the break for bonus gold); spawns anywhere; several castles share one life pool per level; map in the `.tscn`, waves and settings in a `LevelData` `.tres`. Enemies stay on the 16 px grid but spread inside tiles. See the doc's "Levels" section.
- **Enemies (decided):** factions with resistance profiles (always 0-75%; a weakness is just the lowest resistance, never bonus damage) and faction mechanics; unique abilities; flyers from later levels (Bolter and Beamer hit them, Nova and traps do not); elites mixed into waves; keep Beehave but slim the trees (one `FollowPath` action, abilities as subtrees, no `Cooldown`/`Delayer` decorators since they ignore game speed); bog walkers cross bog through level-placed entry/exit marker pairs. See the doc's "Enemies" section.
- **Current code:** the level-wide XP cards (`scenes/upgrades/`) are built, uncommitted and waiting for the user's playtest. The gold upgrades per building type in the selection panel (2026-10-23) replace the element cards: only T1 (the element) exists, later tiers stay locked, no talent locks yet; prices and per-type upgrade effects decided (see the doc), numbers to tune after playtests. Waves and `LevelData` are built (2026-10-23), see the doc's Levels -> Data.

## Known Issues (found 2026-10-20)
- The stat upgrade resources have no `evolve_icon`; their cards show Godot's default icon.

## Commands
- Run: `godot --path .` (from the project folder)
- Headless load check: `godot --headless --quit`; to compile the unit scripts too, run a level: `godot --headless --quit-after 900 res://scenes/level/levels/level_001.tscn`. `godot` is not on PATH: the exe is `C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`. `Capture not registered: 'beehave'` in headless is harmless.
- The user's Godot is the Steam 4.7.2 build; the desktop shortcut is `Godot_v4.6.3-stable_win64`.

## Working Rules
- Never rewrite whole files unless asked; change the functions that need it.
- Check node paths in the `.tscn` before using `$Path`; the unit scenes rely on exact child names (`Stats`, `SkillStateTimers/CastTimer`, `RangeArea/CollisionShape2D`, ...).
- Art is hand-made in Aseprite and imported with AsepriteWizard. Edit the `.aseprite` source, not only the `.png`. Ask before generating or replacing any art.
- Do not change `project.godot` settings without asking.
- Commit or push only when the user asks. The branch is `master`.
- Skills for this project: `td_architecture` (code and structure rules), `td_gameplay_patterns` (behaviour trees, pathing, targeting, damage, pooling, rolls and balance maths), `td_content` (how to add towers, enemies, upgrades, levels) and `td_shaders` (pixel-art shaders). Load the matching one before editing.
