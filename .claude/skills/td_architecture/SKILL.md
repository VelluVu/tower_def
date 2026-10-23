---
name: td_architecture
description: Use when writing, reviewing or refactoring GDScript in Puffe TD (puffetd). Covers the signal buses, the child-node composition of units, the stats and modifier pipeline, skills and timers, pathing, and the project's code style. Load before touching any .gd file.
---

# Puffe TD Architecture (Godot 4.7)

## Signal buses
- `GameSignals`: gameplay events. Emitters: `Building.place` → `building_placed`, `destroy_building` → `building_destroyed`, `Enemy._ready` → `enemy_spawned`, `Enemy.die` → `enemy_destroyed`, end point → `enemy_reached_end_point`, `Level._ready` → `level_loaded`, `Level._check_level_end_conditions` → `level_completed`, `PlayerStats.lose` → `lose_game`.
- `UISignals`: UI requests and selection display. The UI never calls gameplay nodes directly. Gameplay never reaches into UI nodes.
- Add a new cross-system event to the matching bus, with typed parameters. Keep node-local events as local signals (`Building.stats_changed`, `EvolveTree.evolved`, `Skill.is_ready_signal`).
- Short-lived nodes (enemies, projectiles) connect to the buses in `_ready`. Bus connections to freed objects are dropped automatically, but pooled projectiles must not connect twice: guard with `is_connected`.

## Unit composition
A unit (`Building`/`Tower`/`Wall`/`Trap` on StaticBody2D, `Enemy` on RigidBody2D) is assembled from children:

| Child | Role |
| --- | --- |
| `Stats` + `Stat` children | base values, one `Stat` node per `Utils.StatType` |
| one `Skill` subclass | attack; has its own `Stats`, `DamageData`, `SkillStateTimers/{CastTimer,CooldownTimer,ActiveTimer}` |
| `ModifierManager` | applies `ModifierData` to unit or skill stats |
| `OvertimeEffectHandler` | burns, slows, poison ticks/stacks |
| `EvolveTree` (buildings) | holds the type's `upgrade_data` (gold upgrades), the `ElementEvolveLeaf` options and the current element; purchases live in `BuildingTypeUpgrades`, XP cards in `LevelUpgrades` |
| `BeehaveTree` | behaviour; one script per leaf in `scenes/unit/behaviour_trees/<tree>/` |
| `AnimatedSprite2D` with `AnimationControl` | animations named by `GlobalAnimationNames` (IDLE, WALK, START_ATTACK, ATTACK, STOP_ATTACK, DEATH, FADE) |
| `SelectableUnit`, `PopUpSpot` | selection and damage number anchor |

New behaviour goes into a new child component or a Beehave leaf, not into `building.gd`/`enemy.gd` (already 300+ lines each).

## Stats and modifiers
- Effective skill stat = `(unit base + skill base + flats) × (1 + Σ Additive) × Π(1 + Multiply)` (`ModifierManager.combine`). The result is written to the skill stat if the skill has that stat, otherwise to the unit stat.
- Read stats with `stats.get_stat_value(Utils.StatType.X)`; it returns 0.0 for a missing stat, so a missing node fails silently. Check the scene has the `Stat` node.
- `Stat.add_modifier` picks the list from `calculate_type` (Flat/Additive/Multiply) and whether `modifier_type` is GlobalModifier. Additive percent bonuses sum with each other; Multiply ones compound. Use Additive for cards and upgrades, Multiply for slows and rare big bonuses.

## Skills and time
- `Skill.use(target)` → `start_skill_cast` → cast timer → `activate()` → active + cooldown timers → `is_ready`. Override `activate`, `_on_active_end`, `_interrupted_active`, `stop`/`clear` in subclasses (`LaunchProjectile`, `Beam`, `Emitter`, `MeleeAttack`).
- `skill.damage_data` returns a fresh duplicate with crit rolled; pass that one to `take_damage`.
- Game speed is manual: use `CustomTimer` (never a plain `Timer` or `create_timer`) for anything gameplay-timed, and scale per-frame movement by `current_time_scale` like `Enemy._process`. Set durations through `unscaled_base_value`/`base_wait_time`, not `wait_time`.

## Level and pathing
- Grid conversions only through `level.grid` (`LevelGrid`: `world_position_to_grid`, `grid_position_to_world`, `snap_position_to_grid`). Tiles are 16 px (`Utils.TILE_SIZE`).
- Walkability and buildability come from the `TileType` custom data flags on every tile map layer; add new tile behaviour as a flag, not as tile-ID checks.
- Buildings change cell weight, not solidity. Emit `GameSignals.astar_grid_updated` after any grid change; every enemy repaths on it, so do not emit it per frame.
- Get the level from the building's parent chain or `Utils.game_control.scene_manager.current_level`; do not add new `get_node("../..")` paths.

## Code style
- Static types everywhere, spaced colon style: `var target : Node2D = null`, `func flip(target_direction : Vector2) -> void:`.
- New signals at the top of the file. Strings: local consts (`..._WARNING`, `..._ERROR`, `..._MESSAGE`), names from `GroupNames`/`GlobalAnimationNames`/input action consts.
- Getter/setter pairs as `get = _get_x, set = _set_x`; setters return early on unchanged values.
- Comments short, on the why. Do not add `print` to hot paths; prefer removing existing noisy ones in files you touch.
- Pure maths (XP curve, damage, modifier sums) belongs in small static functions so it can be tested once a test setup exists.
