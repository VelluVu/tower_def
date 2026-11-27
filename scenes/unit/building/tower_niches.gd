class_name TowerNiches
extends RefCounted

## Where the newer towers shine (the user, 2026-11-26): "spotter would be really good in big maze, the breather should be
## really strong in tight corridors, mortar is strongest when stacked enemies and even better if enemies are attacking
## wall or slowed; traps are good when need to min max damage inside the mazes to win hard modes or hardest levels".
## The user added the same evening: "nova is really strong in corners where enemies walk around, frost slow etc."
## Then the Harpooner (flyers and fast runners) and the Shredder (pinned enemies, elites and bosses: TowerHitEffects).
## The Buffer got no factor (the user's pick: flat pips; it throws timed buffs instead, BufferAuras).
## A factor on a tower's own hit (no effect ticks, no reactions; flyers are above the maze), applied in Enemy.take_damage.
## Stacked enemies already feed the Mortar through its burst; a big maze keeps more of the Spotter's long reach on maze cells.
## 2026-11-27 (the user): the towers' damage bonuses are gone (Spotter in the maze, Mortar on pinned enemies, Nova at
## corners, Harpooner on flyers and fast runners); the traps' maze bonus stays, and the Breather's corridor bonus at 1.5x
## ("the breath bounces from the walls and deals 1.5x damage"). The Harpooner's longer tether on fast runners and the
## Shredder's rules (TowerHitEffects) stay.

#starting numbers, to tune with the bots
const TRAP_MAZE_BONUS : float = 0.4
#the breath bounces off the corridor's sides
const BREATHER_CORRIDOR_BONUS : float = 0.5
#a base speed from this counts as fast (scouts, cavalry, assault dogs, bone riders, ash runners)
const FAST_SPEED : float = 28.0
#a fast enemy's harpoon tether lasts this much longer
const FAST_TETHER_FACTOR : float = 1.5
#the Shredder: stacks on a pinned or slowed enemy, and how much longer its shred stays on elites and bosses
const SHRED_PINNED_STACKS : int = 2
const SHRED_TOUGH_SECONDS_FACTOR : float = 2.0
#an enemy moving slower than this share of its base speed counts as slowed for the Mortar
const SLOWED_SPEED_SHARE : float = 0.95


static func get_factor(enemy : Enemy, hit : DamageData) -> float:
	if hit.is_overtime or hit.is_reaction or enemy.level == null:
		return 1.0
	#untyped first: a source freed mid-flight would be a script error in a typed variable
	var source : Variant = hit.source
	if not is_instance_valid(source) or not source is Building:
		return 1.0
	#flyers are above the maze and its corridors
	if enemy.is_flying:
		return 1.0
	var building : Building = source
	if building is Trap:
		return 1.0 + TRAP_MAZE_BONUS if enemy.level.grid.is_maze_cell(enemy.grid_position) else 1.0
	if building.skill != null and building.skill.skill_type & Utils.SkillType.Breath:
		return 1.0 + BREATHER_CORRIDOR_BONUS if enemy.level.grid.is_corridor_cell(enemy.grid_position) else 1.0
	return 1.0


## A fast runner, by its base speed (the Harpooner's prey).
static func is_fast(enemy : Enemy) -> bool:
	var speed : Stat = enemy.stats.get_stat(Utils.StatType.Speed)
	return speed != null and speed.base_value >= FAST_SPEED


## Held in place or slowed: attacking a building, held by a guard or a harpoon, frozen or chilled, on slow ground or in
## the maze, or moving under its base speed.
static func is_pinned(enemy : Enemy) -> bool:
	if enemy.is_colliding_building or enemy.is_held or enemy.is_frozen or is_instance_valid(enemy.held_by):
		return true
	if TalentEffect.enemy_in(enemy, TalentEffect.Condition.Chilled):
		return true
	if enemy.level.grid.get_move_speed_factor(enemy.grid_position) < 1.0:
		return true
	var speed : Stat = enemy.stats.get_stat(Utils.StatType.Speed)
	return speed != null and speed.value < speed.base_value * SLOWED_SPEED_SHARE
