# Sprite part generators

Some enemy sprites are generated from parts (body, head, tail, wings, legs drawn hip to foot) placed per frame,
so the shapes hold between frames. Each script writes the sprite's text spec; `tools/sprite/sprite.py build`
turns the spec into the `.aseprite` and its packed `.png` sheet.

```
python tools/sprite/parts/giant_wasp.py tools/sprite/parts assets/art/units/enemy/giant_wasp/giant_wasp.txt
python tools/sprite/sprite.py build assets/art/units/enemy/giant_wasp/giant_wasp.txt assets/art/units/enemy/giant_wasp/giant_wasp.aseprite
```

`humans.py` writes both `soldier.txt` and `scout.txt` into the folder given as its second argument.

| Script | Sprite |
|---|---|
| `giant_wasp.py` | giant wasp |
| `fastswampling.py` | toxic gecko |
| `assault_dog.py` | assault dog |
| `humans.py` | soldier, scout |
| `leechling.py` | leechling |
| `plaguepig.py` | plaguepig |
| `humans_more.py` | armored knight, archer, wizard, priest |
| `humans_big.py` | cavalry, giant eagle, Dragonslayer |
| `beasts.py` | destroyerling and its rock, Bog Hydra, leopard cub |
| `walls.py` | wall stages (palisade, battlements, castle) and the Fire/Frost/Poison wall overlays, repainted from `wall.png`'s pixel roles |
| `tower_tiers.py` | T2 and T3 of every drakeling (12 T1 sheets), drawn over the T1 frames |
| `upgrade_fx.py` | T2/T3 bolts and beams, the upgrade pips, the element spark particles |
| `area_ground.py` | Caves, Swamp and Human ground sheets, recoloured from `ground_tiles.png` (same layout) |
| `area_props.py` | cave decor, swamp ruins, human farm props, desert battlefield and volcano props |
| `scorched_enemies.py` | the Scorched Lands roster (37-48): most drawn over an existing enemy's frames with a new palette and overlays, the rusted ballista and the Ashen Wyrm from parts; the lava glob and bone shard shots |
| `units_2026_11_25_art.py` | the sixteen enemies of 2026-11-25 (cave shaman ... ash harpy): most over a parent's frames like `scorched_enemies.py` (it imports its helpers), the leech mother, sand wurm and battering ram from parts; the snapping turtle's SHELL tag |
| `elites.py` | the elite version of every enemy that comes as an elite: golden armour with a travelling glint for the armoured humans, crowns, a halo, plumes, horns, gold markings, hems and ridges for the rest; `<name>_elite.png` keeps `<name>.png`'s cell layout |
| `mortar_art.py` | the Mortar: the Bolter drakeling of each element (recoloured from the Bolter's element sheets) behind an iron mortar, its shells and blasts per element; T2/T3 by `tower_tiers.py ... mortar` |
| `breather_art.py` | the Breather: the Bolter drakeling of each element with a bronze gorget, breathing in (START_ATTACK), the jaw open and blazing (ATTACK), smoke after (STOP_ATTACK); its breath puffs per element (10x10); T2/T3 by `tower_tiers.py ... breather` |
| `spotter_art.py` | the Spotter: the Bolter drakeling of each element with a brass eyepiece and a long arbalest (drawn, loosed); its heavy bolts per element (16x16, WALK, DEATH, FADE); T2/T3 by `tower_tiers.py ... spotter` |
| `egg_bomb_art.py` | the Egg Bomb: a speckled egg with a fuse in a pebble scrape per element, 20x20 (IDLE, START_ATTACK the fuse burning down, ATTACK the shell bursting, REBUILD the shell growing back), its T2 (element pebble ring) and T3 (gold band) sheets drawn by the same script; the explosion is the Mortar's blast |
| `hatchery_art.py` | the Hatchery: the Bolter drakeling of each element brooding a clutch of eggs on a twig nest (IDLE rocks the eggs, START_ATTACK cracks the middle one, STOP_ATTACK bursts it and a new one settles); its 18x18 guard hatchling with a gold sweatband per element (IDLE, WALK, ATTACK, DEATH, HATCH); T2/T3 by `tower_tiers.py ... hatchery` |
| `harpooner_art.py` | the Harpooner: the Bolter drakeling of each element with a heavy harpoon gun and a chain coil (loaded, fired, reloaded); its barbed harpoons per element (16x16, WALK with a rattling chain, DEATH, FADE); the tether chain is drawn in code; T2/T3 by `tower_tiers.py ... harpooner` |
| `buffer_art.py` | the Buffer: the Bolter drakeling of each element beating a war drum (IDLE 8, ROAR 6 for Commander's Roar); T2/T3 by `tower_tiers.py ... buffer` |
| `trap_elements_art.py` | the Fire, Frost and Poison Leopard Trap (`<element>_lebu_trap`), repainted from `lebu_trap.aseprite`'s colour roles (same cell layout as `lebu_trap.png`), and their paw print icons |

The generators that draw over existing art (`walls.py`, `tower_tiers.py`, `upgrade_fx.py`, `area_ground.py`, `elites.py`, `trap_elements_art.py`) read
their source sheets, so rerun them after the source changes. `<parts dir> <art dir>` are their arguments; see
each script's docstring.

Helpers (`limbs.py`: `line()` and `leg()` shared by the newer generators):
- `compose.py`: `part()` (an ASCII grid, `.` empty), `pts()`, `Frame.stamp()` (offset, flips), `write_spec()`. `write_spec` stops when a frame touches the canvas edge (the `unit_sprite` outline needs 1 px).
- `margin.py <spec> [dx] [dy]`: shifts every frame of a hand-written spec and clears pixels left on the edge.
- `icon_from_spec.py <spec> <icon grid> <icon png>`: a 16x16 icon grid cropped from the first IDLE frame; then `python tools/gd.py icon <grid> <png>`.

Keep a redraw's canvas size, frame count and tag order so the scene's `SpriteFrames` regions still fit the sheet.
