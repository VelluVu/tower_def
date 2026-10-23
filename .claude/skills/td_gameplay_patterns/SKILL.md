---
name: td_gameplay_patterns
description: Use when designing or changing gameplay systems and algorithms in Puffe TD (puffetd) - enemy AI and pathing, tower targeting, waves, damage and effects over time, pooling, game speed, upgrade/card rolls and balance maths. Load before adding behaviour or a new cross-system mechanic.
---

# Gameplay Patterns and Algorithms (Puffe TD)

## Behaviour: Beehave trees, not hand-written state machines
- Enemy and tower behaviour lives in Beehave trees (`scenes/unit/behaviour_trees/basic_enemy_behaviour_tree/`, `basic_tower_behaviour_tree/`). One script per leaf: conditions (`is_dead`, `has_path`, `is_colliding_building`) extend `ConditionLeaf`, actions (`move_towards_next_waypoint`, `attack_closest_building`) extend `ActionLeaf`, and return SUCCESS/FAILURE/RUNNING from `tick(actor, blackboard)`.
- New behaviour = a new leaf plus a composite (selector/sequence) change in the tree scene. Leaves read and call the actor's methods (`actor.path_to`, `actor.skill.use`); keep the logic on the actor or a component, the leaf only decides.
- A Building's tree is disabled while placing (`Tower._set_is_placing`) and enabled in `_enable_tower`.
- Use a plain enum state only for tiny UI flows; anything an actor does over time belongs in its tree.

## Components and buses
- New capabilities are child nodes found by type or `@onready`, like `Stats`, `Skill`, `ModifierManager`, `OvertimeEffectHandler`. A component owns its data, emits local signals, and never reaches into its parent's other children.
- Cross-system events go through `GameSignals` (gameplay) and `UISignals` (UI requests). Local parent-child events stay local signals.

## Pathing (AStarGrid2D)
- `Level._create_astar_grid` builds the grid from the ground layer's used rect; tile `TileType` flags decide solid cells. No diagonals.
- Buildings raise the cell weight (`Building.astar_weight` = 100) instead of making it solid, so a full wall-off still has a path: enemies route around towers when they can and walk into (and attack) a building when that is cheaper. Traps keep weight 1 and are walkable.
- Every `GameSignals.astar_grid_updated` makes every living enemy call `path_to` again: emit it once per placement/removal, never per frame. For many enemies, consider sharing one path per spawner and only repathing enemies whose remaining path crosses the changed cell.
- Grid maths only via `Level` helpers (`world_position_to_grid`, `grid_position_to_world`, `snap_position_to_grid`); cells are 16 px.

## Targeting
- Towers collect bodies in `RangeArea` (`targets`) and remove them on exit or `enemy_destroyed`.
- Priorities: `get_first_target` (oldest in range) and `get_closest_target_to_end` (fewest remaining waypoints; the usual TD "first"). New priorities (strongest, weakest, most HP, not yet burning) go next to these as `get_*_target` functions on `Tower`, chosen by an exported enum, and the tree leaf calls the chosen one.
- Validate before use: `Skill._is_target_valid` checks null, still in range, not dead. Freed enemies are `deactivate()`d and hidden, not always freed immediately: check `is_dead`/`is_deactivated`, not only `is_instance_valid`.

## Waves and spawning
- `LevelData.waves` → `WaveData.spawn_groups` → `SpawnGroupData` (enemy, count, interval, delay, spawner id). `WaveRunner` starts a wave on `UISignals.start_wave_pressed`; each group runs as a `SpawnGroupRunner` (`CustomTimer`, so game speed applies) under its `Spawner`.
- `Level._check_level_end_conditions`: nothing spawning and no enemy alive → `wave_cleared`, or `level_completed` after the last wave. The next wave can start once the current one has finished spawning; starting while enemies are alive pays `WaveData.early_start_bonus`.

## Damage, crits and effects over time
- `skill.damage_data` returns a fresh duplicate with the crit rolled (`CriticalChance`, `CriticalMultiplier`); pass that to `take_damage`.
- Effects over time are `OvertimeEffectData` children of the damage data (Tick or Stack type) handled by the target's `OvertimeEffectHandler`; slows are `Modifier` children with negative multiply values on Speed, added on apply and removed on expiry.
- The killing hit calls `source.dealt_damage(target, data)`: hook "on kill" effects there (and per-tower-type XP, see CLAUDE.md "Open Design").

## Stat maths
- Effective value = `(unit base + skill base + flats) × (1 + Σ Additive) × Π(1 + Multiply)` in `ModifierManager.combine` (globals included in each group). Flat on stats whose base is 0 (AttackSpeed, ActiveDuration); Additive or Multiply on stats with a base (Damage). Slows must stay Multiply so stacks compound toward 0 instead of going negative.
- Attack speed is a bonus fraction: timers use `base / (1 + attack_speed)`, so +0.1 = 10% faster, with diminishing returns built in.
- Never set `Stat.value` directly for upgrades; add a `ModifierData` so the value can be recomputed and removed.

## Game speed and pause
- Game speed (1x-3x) is manual: gameplay timers are `CustomTimer`s that rescale on `time_scale_change`, and per-frame motion multiplies `delta` by `current_time_scale`. Don't use plain `Timer`, `get_tree().create_timer` or `Engine.time_scale` for gameplay.
- Pausing is `GameSignals.game_pause` → `get_tree().paused`; units are `PROCESS_MODE_PAUSABLE`, the UI `CanvasLayer` is always processing. Signal handlers still run while paused.

## Pooling
- Short-lived visuals are pooled: `DamageNumberManager` (`damage_number_pool`), `GoreEffect` (`sub_gore_pool`), and projectiles (`LaunchProjectile.projectile_pool`, cleared when an element swaps the projectile scene). Follow the same pattern for new frequent spawns: pop or instantiate, reset state, push back on finish; connect signals once, guarded by `is_connected`.

## Randomness and roguelike rolls
- Keep rolls testable: pure functions take the random number as a parameter (`UpgradeRules.roll_value(resource, roll)`), the caller passes `randf()`.
- Card offers: build the pool of what fits the current towers, shuffle, take N distinct (`LevelUpgrades._get_stat_cards`). For weighted pools, add a `weight` export to the resource and pick by cumulative weight; never mutate the shared `.tres` at runtime (resources are cached and shared between all users).
- Seeded runs: if repeatable runs are wanted, hold one `RandomNumberGenerator` on the level and pass it down instead of calling global `randf()`.

## Balance maths to keep in mind
- XP curve: `UpgradeRules.xp_required(level) = FIRST_LEVEL_XP + 100 · level · (level − 1) / 2` (300, 400, 600, 900, ...; the first level-up after 10 Weakling kills); kill XP = enemy max health × 2.
- Roll odds: 20% ×3, 30% ×2, 50% ×1 (expected ×1.9 on randomized cards).
- Gold: start 6, kill gives enemy Price, selling refunds full Price (cheap to reposition; consider a refund ratio).
