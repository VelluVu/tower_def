# Puffe TD - Progression Design

Status: planning, nothing built yet (except the XP cards). Started 2026-10-22.

## Story and World
- The legendary drakelings (Puffe), protectors of the world, wake from a deep sleep and return to these lands. They drive the humans out of their castles.
- The dangers the humans created (mutations, monsters) have been hiding and gathering strength. Now they attack the castles, and the humans return with even greater forces.
- Goal: defend the castles and drive the monsters and the humans out of these lands for good.
- The world map is split into areas. Each area is one enemy faction with its own enemies, tileset and boss level.

| Area | Faction | Enemy ideas |
|---|---|---|
| 1. Caves | Deep creatures that attack from the caves | Weaklings, fastlings, beeflings, destroyerlings, batlings |
| 2. Swamp | Swamp monsters | Swamplings, plaguepigs, giant wasps |
| 3. Fields | Humans | Armored soldiers, archers, wizards, priests, giant eagles |
| ... | Mutations | Later areas |

- Each faction has its own resistance profile, so the area shapes which trees you lean on (see Enemies).
- Each area ends in a boss level.

## Layers
| Layer | When | Currency | What it does |
|---|---|---|---|
| Talent trees (menu) | Between levels, permanent | Talent points | Unlock evolve tiers, capstones, deeper effects |
| Upgrades and evolves | During a level | Gold | Improve one building (walls: all walls); the element is chosen per type |
| XP cards | During a level, pauses | XP | One stat for all towers, roguelike, reset per level |

- All tower types are available from the start. Progress comes from the trees, the upgrades and the cards. This replaces "clearing a level unlocks a building".
- Cards and upgrades overlap on purpose. Stacking (decided 2026-10-23, Path of Exile style): `(unit base + skill base + flats) × (1 + Σ Additive) × Π(1 + Multiply)`. Additive ("increased") percent bonuses add up with each other; Multiply ("more") ones compound on top. Cards and gold upgrades are Additive; slows stay Multiply (50 stacks of -10% compound to 0.5% speed instead of going negative); element bonuses are Multiply as rarer, bigger effects. Cards show "+20%" for Additive and "×20%" for Multiply.

## In-Level Upgrades and Evolves (gold)
- Bought per building (decided 2026-10-23, replaces per type): each tower and trap has its own upgrades and tiers, and a newly placed one starts at the base. Why: a per-type upgrade costs the same but grows with every building of the type owned, which made "mass one type, then upgrade" the best play; local upgrades also make placement matter (upgrade the one at the chokepoint) and selling an upgraded building loses its upgrades (only the building price is refunded).
- The element stays per type: the first building of a type to evolve picks the element, and every other building of that type can then only evolve into it (one button at its own evolve step).
- Walls stay per type (`BuildingUpgradeData.is_per_type`): one purchase upgrades every wall, placed or placed later. Per-wall upgrades at 3-10 gold would make no sense.
- No "upgrade all of this type" button (decided 2026-10-23, the user's call): each upgrade is bought on its building.
- Bought from buttons in the selection panel (decided 2026-10-23): select a building and the panel shows its next step and the gold price. At an evolve step the buttons are the element choices.
- The element choice leaves the XP cards (decided 2026-10-23). The XP cards stay as the roguelike layer: global upgrades offered on each player level-up.
- Built (2026-10-23): `BuildingTypeUpgrades` + `BuildingUpgradeData` (`scenes/upgrades/`), one data `.tres` per building type; per-building states, the per-type element and per-type wall state (2026-10-23). Prices are ratios of the building's own price (see Gold Economy). Only T1 exists, T2/T3 stay locked and the upgrades continue past them; no talent locks; step visuals are placeholder pips only (see Visuals per step). The Leopard Trap and walls have no element leaves, so they only get upgrades.
- Upgrade effects (decided 2026-10-23, first numbers, tune after playtests). Every step gives the same bonus, before and after the element:

| Type | Each upgrade (Up 1-6) |
|---|---|
| Bolter | +30% damage, +10% attack speed |
| Nova | +30% damage, +0.25 tiles radius |
| Beamer | +30% damage, +0.25 tiles range |
| Leopard Trap | +30% damage, +10% re-arm speed |
| Wall | +25% max health (the wall keeps the damage it has taken) |

  - Damage went from +15% to +30% with the move to per-building upgrades: a step improves one tower for half a tower's price or more, so +15% lost to just buying another tower. Up 1 (+30% damage, +10% speed, about +43% DPS) at 0.5 of a tower is close to a new tower per gold, without using space; later steps are worth less per gold (Additive plus the rising price), so they are for space-limited maps.
  - Damage and max health are Additive; attack speed and range are Flat (attack speed is a bonus stat: +0.1 = 10% faster, like the cards).
  - Up 3-6 do not strengthen the element effect yet: burn, slow and poison strength wait for an "effect potency" stat that comes with the talent trees.
- Each type picks one path (element) per level (the first building of the type to evolve picks it) and keeps it until the level ends. A different level can use a different path.
- Rhythm, two upgrades before each evolve:
  `Base -> Up 1 -> Up 2 -> [T1] -> Up 3 -> Up 4 -> [T2] -> Up 5 -> Up 6 -> [T3]`
- Upgrades improve all stats of the type. Evolves change the ability.
- If the talent tree has not unlocked an evolve tier, the upgrades still give stats, but the evolve step stays locked.
- 3 tiers per path for now. Data-driven so a T4 is new data, not new code.
- Each evolve entry: element, tier, swap scene, gold cost, required talent node.

### Paths per building type
| Type | Fire / Frost / Poison | Physical path | Unlocked in |
|---|---|---|---|
| Towers (Bolter, Nova, Beamer) | 3 tiers each | Base tower | Element tree branch, Building tree -> Physical towers |
| Traps (Leopard Trap) | 3 tiers each | Leopard Trap | Element tree branch, Building tree -> Traps |
| Walls | 3 tiers each | Fortress | Element tree side nodes, Building tree -> Walls |

### Trap evolves
| Path | T1 -> T3 | Capstone |
|---|---|---|
| Fire | Burning ground patch, bigger and longer patch, explodes on trigger | Burning enemies set off nearby traps |
| Frost | Short root, slows nearby, freezes | Frozen enemies shatter for extra damage |
| Poison | Poison cloud, cloud stacks poison, spreads on death | Cloud follows the path for a while |
| Leopard (Physical) | Faster re-arm, bleed, double snap | Snaps several enemies at once |

### Wall evolves
Walls are the mazing tool, so they grow in holding and shaping the maze, not damage.

| Path | T1 -> T3 |
|---|---|
| Fire | Deals fire damage back to attackers, burns them, explodes when destroyed |
| Frost | Lowers attackers' attack speed, slows movement nearby, freezes attackers briefly |
| Poison | Poisons attackers, poisoned attackers deal less damage, poison spreads |
| Fortress (Physical) | Self-heal every few seconds, armor, enemies prefer longer detours (raise A* cell weight) |

- Upgrades never change a wall's footprint; the player's maze always stays valid.
- Wall upgrades cost a bit more than tower upgrades, since one purchase affects many walls.

### Visuals per step
Every upgrade should make the type look a bit stronger.

| Step | Visual |
|---|---|
| Up 1-2 | Pips under the building, slightly stronger outline |
| T1 | Element sprite (towers have these), element-colored outline |
| Up 3-4 | Pips, stronger glow pulse |
| T2 | Element particles. Placeholder: T1 sprite with stronger tint. Later: new sprite |
| Up 5-6 | More particles, brighter glow |
| T3 | Strongest glow, particles, ground aura. Later: new sprite |

- Attacks grow too: bigger bolts and trails, wider beam, nova visual matches its radius, stronger trap snap.
- Never scale 16 px sprites; use outline, glow, particles and overlays. 1 px pixel-aligned outlines (existing outline shader with a strength parameter).
- Later art: small overlay sprites per step (crest, crown).
- Walls: palisade -> stone -> battlements -> castle wall, with element details (embers, ice crust, dripping moss).
- Each step's visual settings (pips, outline strength, particles) live in the upgrade data.
- Built (2026-10-23, placeholder): `UpgradePips` (`scenes/upgrades/`), code-drawn 2 px pips on the bottom edge of the building, added on the first purchase. One pip per tier in the element color with a white ring (so a red Fire pip reads on the red Fire tower), then one gold pip per upgrade since the last tier; rows of 5 stack upwards (walls at Up 6 show two rows). No outline strength, glow or particles yet.
- Art comes later and is hand-made. Placeholders until then.

## Talent Trees (menu)
- Four trees, each its own tab and page, drawn in the element's shape:

| Tree | Trunk | Branches | Side nodes |
|---|---|---|---|
| Fire (flame) | Burn damage, duration, spread | Bolter, Nova, Beamer, Trap | Fire walls |
| Frost (ice crystal) | Slow strength, duration, freeze | Bolter, Nova, Beamer, Trap | Frost walls |
| Poison (dripping vine) | Poison damage, stacks, spread | Bolter, Nova, Beamer, Trap | Poison walls |
| Building | Gold and costs | Walls (Fortress), Traps (Leopard), Physical towers | Economy and utility |

- Main focus of the element trees: element effect, area, speed, projectile count, damage, evolves, capstones.
- Trees are big (about 30-40 nodes each, many with ranks). Nobody fills all of them; choosing what to skip is part of the game.
- 1 talent point = 1 rank. Nodes have different max ranks.
- 1 rank in a node is enough to move on to the next node.
- Many capstones: unique improvements or the next evolve tier unlock.
- Side nodes: short dead ends (1-3 nodes) off the trunk or a branch, for spending a little without heading to a capstone.
- Talent effects only apply to buildings on that element's path.
- Respec is free, at any time.
- Every new building type gets a branch in the Building tree and one in each element tree.

### Branch layout (towers and traps)
| Depth | Node |
|---|---|
| Start | T1 evolve unlock |
| Early | Stats, side nodes |
| Middle | T2 evolve unlock |
| Deep | Stats, side nodes |
| Near the tip | T3 evolve unlock |
| Tip | Capstone |

### Trunk capstone ideas
| Element | Capstone |
|---|---|
| Fire | Burning enemies explode on death and spread burn |
| Frost | Enough slow stacks freeze an enemy solid |
| Poison | Poison jumps to nearby enemies when its target dies |

### UI
- Tabs for each tree, Reset and Back buttons.
- Clicking a node opens an info window: description, rank / max rank, next-rank effect, buy button.

### Technical direction
- `TalentTree` `.tres` per tree holding `TalentNode` resources (id, parents, max rank, position in the shape, effects; reuse `ModifierData` where possible).
- `PlayerProgress` saves node ranks, unspent points, and best points per level and mode.
- At level start, the matching nodes are applied as modifiers (same way `LevelUpgrades` applies cards), matched by element and building type.
- Probably new `StatType`s: effect potency, effect area, projectile count.
- Replaces the earlier plans: type XP / `EvolveGlow`, and element cards in `LevelUpgrades`.

## Talent Points
- Earned by completing a level. Max 5 per level and mode.
- Score = lives left + gold left over.

| Point | Requirement |
|---|---|
| 1 | Clear the level |
| +1 | At least half the lives left |
| +1 | No lives lost |
| +1 | Gold left over >= the level's target |
| +1 | Gold left over >= the level's high target |

- Gold targets are set per level (exports on `Level` or a level data `.tres`).
- Points come from the best result; replays only earn the difference.
- 5 points should be easy to reach on the first levels.
- Budget: many levels x 4 modes x 5 points. About 20 levels gives about 400 points.

## Level Modes
| Mode | Unlocks | Change |
|---|---|---|
| Normal | From the start | Standard level |
| Hard | After clearing Normal | Stronger, faster waves, fewer lives |
| Survival | After clearing Normal | Non-stop waves that scale every wave; points at wave milestones |
| Challenge | After clearing Normal | A rule: "Bolters only", "no walls", "Frost only", "no XP cards" |

### Survival scaling (first draft, tune after playtesting)
```
enemy_health  = base_health * (1 + 0.12 * wave + 0.004 * wave^2)
enemy_count   = base_count + floor(wave / 3)
gold_per_kill = base_gold * (1 + 0.05 * wave)
boss_wave     = every 10th wave
```

## Waves
- Flow: see Levels -> Wave flow.
- Open: how the early-start bonus is sized (see Levels -> Early-start bonus).
- Wave types: normal, fast swarm, armored, wall breakers, boss.

## Levels
- Any size and shape. Blocked areas, the area's ground tiles and props. The camera bounds come from the used tilemap / pathing grid (`GameCamera` limits are set from the background size today).
- Many levels, each more interesting than the last. Some are frustrating on purpose, for variety.
- Spawns can appear anywhere, also mid-level (burrows, spawners that switch on later).
- A level can have several castles; enemies move to a castle.
- Boss levels: normal waves plus a boss with its own abilities.

### Wave flow
- The level opens with a build phase. The first wave starts when the player presses start.
- Each wave is set up in the level data. When a wave is cleared, a break follows where the player builds and upgrades; the player starts the next wave.
- Skipping the break (starting early) gives bonus gold. Building and upgrading work during waves too, so skipping costs only safety.
- Each wave should feel like a step up: more enemies, a new enemy type, a new spawn point, or a mini-boss.
- The level is complete when the last wave is cleared.

### Castles and lives
- Life is one pool per level (`PlayerStats`). More castles do not add lives.
- An enemy reaching any castle costs life. Life at 0 fails the level.
- Two castles far apart make a good "frustrating" level: the player splits the defence, and a leak at either castle costs life.

### Early-start bonus (proposal)
- The break has no timer, so the bonus cannot scale with time skipped.
- Option A: flat gold per wave, growing with the wave number (skipping late waves pays more and risks more).
- Option B: scaled by how many enemies of the current wave are still alive, so the player can call the next wave before the current one is cleared.

### Data
- The `.tscn` holds the map: tile layers, props, spawn points, castles.
- A `LevelData` `.tres` holds the rest: wave sets, starting gold and lives, gold targets, mode overrides, area, boss flag.
- Wave sets are made of reusable `WaveData` resources (enemy, count, interval, spawn point, delay), so new levels reuse existing waves.
- Spawners become spawn points driven by the wave runner instead of their own exports.
- Built (2026-10-23): `LevelData` (starting gold, starting life, waves) -> `WaveData` (spawn groups, early-start bonus) -> `SpawnGroupData` (enemy, count, interval, delay, spawner id), in `scenes/level/level_data/`. The groups are sub-resources of each wave file, so the reusable unit is the wave. `WaveRunner` starts waves on request; `Spawner` is now only a spawn point (id, end point). The level opens in a build phase; the wave panel (top right) starts the first wave, and starts the next one once the current wave has finished spawning. Starting it while enemies are still alive pays the next wave's `early_start_bonus` (placeholder data: option A, wave number - 1 gold). The current three levels were converted to three waves each, one old spawner per wave, same enemies and intervals. Not built yet: gold targets, mode overrides, area, boss flag, spawn points that switch on mid-level.

### Level ingredients
A level = map shape + enemy mix + one or two twists. Introduce one new ingredient per level.

| Kind | Examples |
|---|---|
| Map shape | Open field (mazing), corridors, islands joined by bridges, several castles far apart |
| Terrain | Mud (slow), only-walkable water, buildable-only cliffs, pre-placed ruins |
| Spawns | Spawn points that open mid-level, burrows inside the maze, spawns behind the defences |
| Frustrating twists | Tiny build area, low gold, one-tile paths, wall breakers, enemies that ignore the maze |

### Enemy movement on the grid
- Keep the 16 px `AStarGrid2D`; no finer grid.
- Spread enemies inside the tiles: each enemy gets a random offset (about +-4 px, so it never leaves the tile) added to its waypoints, plus a light separation push between nearby enemies.
  - Built (2026-10-22, `EnemySpacing`): a lane offset of +-3 px per enemy (limited so the body stays inside its tile; enemy body radius lowered from 5 to 3 px), and a spacing factor that slows an enemy (down to 50%) when another is close in front and speeds it up a little (up to 120%) when one is close behind. It only works along the move direction, so it never pushes an enemy sideways into a wall.
- Later, with several castles or big Survival waves: a flow field per castle set (one weighted Dijkstra from all castles per grid change) instead of one A* path per enemy. Each enemy then goes to its nearest castle by path cost, and a grid change costs one update instead of one repath per enemy.

## Enemies
Today: six enemies, all melee, one shared behaviour tree (walk the path, attack a building only when blocked). They differ only in stats; the swamp ones regenerate.

### Factions
"Weak to" means lowest resistance (0-75% range, no bonus damage; see Resistances).

| Faction | Feel | Weak to | Resistances | Faction mechanic |
|---|---|---|---|---|
| Caves | Easiest, starter enemies | Fire | Little; big ones resist all elements a bit | Dig up: mid-level, a new spawn opens at a random pathable cell closer to the target castle |
| Swamp | Tough, poisonous | Frost | Poison (up to 75% on obvious ones like the plaguepig) | Some swamp monsters wade through non-buildable bog areas that block others |
| Humans | Widest variety of units and skills | Physical, Poison (priests cure poison) | Armored units resist Physical; wizards and priests resist all elements but are weak to Physical | Variety itself |

### Rosters
| Faction | Ground | Flyer | Boss |
|---|---|---|---|
| Caves | Weakling, fastling, beefling, destroyerling | Batling (half bat, half weakling) | Broodmother |
| Swamp | Swampling, fastswampling, swbeefling, plaguepig | Giant wasp | Bog Hydra |
| Humans | Armored soldiers, archers, wizards, priests | Giant eagle | Dragonslayer |

Also wanted (to place in the rosters): burrower and crystal beetle (Caves), bloater and leaper frog (Swamp), cavalry and sapper/ram (Humans).

### Unique abilities
Some enemies have their own abilities; bosses have several.

| Enemy | Ability |
|---|---|
| Beefling | Stomp: when it attacks a tower, it damages all nearby towers |
| Destroyerling | Throws a rock at the farthest tower in its range; stops for a moment while throwing; area damage |
| Priest | Heals the unit with the lowest health in its range; cures poison |
| Wizard | Casts damaging spells at towers |
| Archer | Shoots buildings from range |
| Broodmother (boss) | Spawns building breakers (destroyerlings, beeflings); more abilities to design |
| Bog Hydra (boss) | Hits as many different nearby towers as it has heads; more abilities to design |
| Dragonslayer (boss) | Goes for towers; abilities to design |

- Enemies that attack towers on purpose appear in later levels. Building health and repair start to matter then.

### Flyers
- Not in the first levels. One per faction: batling, giant wasp, giant eagle.
- They ignore the maze and fly their own path to the castle: a bit wavy by default, or a tight route on frustrating maps (the level can set the route).
- Bolter and Beamer hit flyers; Nova and traps do not.
- Beamer is better against fast flyers, Bolter against slow flyers.
- Talent idea: more damage against flyers.

### Resistances
- Two kinds:
  - **Element:** Physical, Fire, Frost, Poison, as a percentage.
  - **Tower type:** for example, fast enemies resist Bolter; they also leave the Nova's area quickly, but Beamer and traps hit them at full power.
- Resistance is always 0-75%. No full immunity, and no negative resistance (no bonus damage).
- A "weakness" is not extra damage: the enemy has 0% (or low) resistance to that element and some resistance to the others. Keep the gap mild.
- 75% only on obvious enemies (plaguepig vs poison), so a player who went all in on one element in the talent trees is never stuck.
- Resistance penetration from cards and talents.

### Elites
- Mixed into normal waves, never a full elite wave.
- Different color from the basic version, maybe bigger. Needs shaders (color shift, outline).
- Look options, decide later (an exception to "never scale 16 px sprites" if scaling is chosen):
  - Recolor only.
  - Slight scale plus recolor.
  - A new hand-drawn unit.
  - Modular sprites: a base body plus swappable gear layers (helmet, weapon, armor), each an `AnimatedSprite2D` playing the same animation in sync. Elites swap to stronger gear at runtime. Needs the same frame counts and tags in every layer's Aseprite file.
- Affixes: Shielded, Hasted, Regenerating, Splitting, Enraged.

### Technical notes
- Units have one `Skill` today. Enemies with abilities and bosses need several skills, each picked by the behaviour tree.
- Flyers: a separate movement mode (no grid), a collision layer for air units, and a "can hit air" flag on tower skills.

### Behaviour trees (decided: keep Beehave)
- Beehave stays: abilities, bosses and per-enemy behaviour are what it is good at.
- Today the basic enemy tree is about 45 nodes, mostly small waypoint checks. Plan:
  - Fold the waypoint bookkeeping (reached, next, last, end reached) into one `FollowPath` action, so the trees show decisions, not steps.
  - One shared base tree (dead, move, blocked -> attack). Each ability is its own subtree scene inserted above movement (`UseAbility` sequences: condition + skill ready + use).
  - Bosses: a selector over their abilities, by priority.
  - Set `tick_rate` above 1 on common enemies if many enemies cost too much.
- Do not use Beehave's `Cooldown`/`Delayer` decorators: they count real physics time and ignore the game speed. Cooldowns stay on the skills' `CustomTimer`s.

### Bog wading
- Bog crossings are placed in the level: an entry marker and a linked exit marker on the other side of the bog. Bog stays blocked on the grid for everyone.
- Bog walkers choose between the normal path and a crossing: path to the entry + crossing cost + path from the exit to the castle, against the normal path. The cheapest wins. A few crossings per level keep this cheap; it reruns on every grid update like the normal repath.
- At the entry the enemy enters a wading state: it moves (lerps) from entry to exit with its own speed and animation, then goes back to normal grid movement.
- If a building blocks the exit, the enemy stops next to it and attacks it, then continues on the grid.
- Other enemies never use crossings.
- Resistances, armor and elite modifiers as stats and modifiers applied at spawn, the same way `LevelUpgrades` applies cards.

## Gold Economy (principles, numbers after playtests)
- Rewarding and progressive: gold per kill rises over the waves.
- Walls are cheap (about 1 gold), mainly for mazing and blocking.
- Building prices (2026-10-23): Wall 1, Bolter 4, Beamer 4, Nova 5, Leopard Trap 5. Bolter and Wall had no price before (they were free).
- Gold upgrade prices (decided 2026-10-23): ratio x the building's price, rounded up. Upgrades 0.5, 0.75, 1.0, 1.25, 1.5, 1.75 (a quarter tower more per step); evolves T1 1.5, T2 2.5, T3 4.0. A 4-gold tower: Up 2, 3, T1 6, Up 4, 5, (T2 10), Up 6, 7, (T3 16). A 5-gold tower: 3, 4, T1 8, 5, 7, (T2 13), 8, 9, (T3 20).
  - Why: Up 1 + Up 2 + T1 is about 2.5 towers, reachable in level 1 (about 29 gold in total) when the player commits to one type; maxing a type costs more than level 1 pays, so it is for later levels. (Written for per-type upgrades; with per-building upgrades the same ratios buy one tower's steps, see the upgrade effects for the bigger bonuses.)
- Start gold (first pass 2026-10-23, from playing each level with a simple Bolter-only build): level 1: 8 (two Bolters; won with no life lost), level 2: 8 (won with 5 of 10 life), level 3: 12 with wave 1 cut from 15 weaklings every 3 s to 10 every 4 s (won with 5 of 10 life; the first beefling wave costs the life). The old 6 gold bought one Bolter, which cannot kill a 15 HP weakling before it leaves range, so level 1 was lost with 0 kills.
- Wall upgrade prices (decided 2026-10-23): 3, 4, 5, 6, 8, 10 gold (ratios of the 1-gold wall price). The tower ratios would make them 1-2 gold, too cheap for a purchase that improves every wall.
- Towers cost about 3-5x a wall. Upgrades about half a tower. Evolves about 1-2 towers, rising per tier.
- Selling currently refunds the full price (`PlayerStats`). A partial refund (e.g. 75%) would make placement matter; the Building tree could improve it.

## Open
- Exact resistance numbers per enemy.
- Full ability sets for the three bosses.
- New tower types: decide after the enemy factions. Candidates: support (buffs nearby towers), anti-air (if flying enemies), long-range sniper.
- New tilesets per area. Ask before generating any art; placeholders to redraw in Aseprite, or the user draws all of it.
- Is Physical-element raw damage only in the Building tree, or does it need more?
- Gold costs and talent node lists per tree.
