class_name MazeElements
extends Node

## The ground next to Fire and Poison walls (created by Level): every second each walking enemy beside such a
## wall, or beside a tower touching one at T2+ (LevelGrid.get_maze_walls), takes its element's damage, the wall as the source. Frost and Fortress walls slow instead (LevelGrid).
## Starting numbers, to tune with the bot.

const TICK_SECONDS : float = 1.0
#on the small enemy-health scale (2026-11-26, 1/8 of the old 2 and 1)
const GROUND_DAMAGE : Dictionary[Utils.Element, float] = {Utils.Element.Fire: 0.25, Utils.Element.Poison: 0.125}
const DAMAGE_TYPES : Dictionary[Utils.Element, Utils.DamageType] = {
	Utils.Element.Fire: Utils.DamageType.Fire,
	Utils.Element.Poison: Utils.DamageType.Poison,
}

@onready var level : Level = get_parent()

var tick_timer : CustomTimer = null


func _ready() -> void:
	tick_timer = CustomTimer.new()
	add_child(tick_timer)
	tick_timer.unscaled_base_value = TICK_SECONDS
	tick_timer.timeout.connect(_tick)
	tick_timer.start()


func _tick() -> void:
	for enemy in level.existing_enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.is_dead or enemy.is_deactivated or enemy.is_flying or enemy.is_burrowed:
			continue
		#one tick per element, from the first such wall beside the enemy (or lent by a tower beside it, LevelGrid)
		var hit_elements : Array[Utils.Element] = []
		for wall in level.grid.get_maze_walls(enemy.grid_position):
			if not GROUND_DAMAGE.has(wall.element) or hit_elements.has(wall.element):
				continue
			hit_elements.append(wall.element)
			var hit : DamageData = DamageData.new()
			hit.damage_type = DAMAGE_TYPES[wall.element]
			#wall ranks raise the wall line's EffectPotency (RankData)
			hit.damage = GROUND_DAMAGE[wall.element] * (1.0 + wall.stats.get_stat_value(Utils.StatType.EffectPotency))
			hit.is_overtime = true
			hit.source = wall
			enemy.take_damage(hit)
			hit.free()
