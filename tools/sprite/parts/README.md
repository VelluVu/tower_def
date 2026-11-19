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
| `elites.py` | the elite version of every enemy that comes as an elite: golden armour with a travelling glint for the armoured humans, crowns, a halo, plumes, horns, gold markings, hems and ridges for the rest; `<name>_elite.png` keeps `<name>.png`'s cell layout |
| `trap_elements_art.py` | the Fire, Frost and Poison Leopard Trap (`<element>_lebu_trap`), repainted from `lebu_trap.aseprite`'s colour roles (same cell layout as `lebu_trap.png`), and their paw print icons |

The generators that draw over existing art (`walls.py`, `tower_tiers.py`, `upgrade_fx.py`, `area_ground.py`, `elites.py`, `trap_elements_art.py`) read
their source sheets, so rerun them after the source changes. `<parts dir> <art dir>` are their arguments; see
each script's docstring.

Helpers (`limbs.py`: `line()` and `leg()` shared by the newer generators):
- `compose.py`: `part()` (an ASCII grid, `.` empty), `pts()`, `Frame.stamp()` (offset, flips), `write_spec()`. `write_spec` stops when a frame touches the canvas edge (the `unit_sprite` outline needs 1 px).
- `margin.py <spec> [dx] [dy]`: shifts every frame of a hand-written spec and clears pixels left on the edge.
- `icon_from_spec.py <spec> <icon grid> <icon png>`: a 16x16 icon grid cropped from the first IDLE frame; then `python tools/gd.py icon <grid> <png>`.

Keep a redraw's canvas size, frame count and tag order so the scene's `SpriteFrames` regions still fit the sheet.
