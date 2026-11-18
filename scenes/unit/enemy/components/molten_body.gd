class_name MoltenBody
extends Node

## The volcano's creatures are molten inside: a Frost hit makes them brittle for a while, their Physical resistance
## BRITTLE_CUT lower (never below 0: a weakness is a low resistance, not bonus damage).

const BRITTLE_SECONDS : float = 3.0
const BRITTLE_CUT : float = 0.3

@onready var enemy : Enemy = get_parent()

var base_resistances : EnemyResistances = null
var brittle_resistances : EnemyResistances = null
var timer : CustomTimer = null

var is_brittle : bool :
	get:
		return timer != null and not timer.is_stopped()


func _ready() -> void:
	base_resistances = enemy.resistances
	if base_resistances == null:
		base_resistances = EnemyResistances.new()
	brittle_resistances = base_resistances.duplicate()
	brittle_resistances.physical = maxf(base_resistances.physical - BRITTLE_CUT, 0.0)
	timer = CustomTimer.new()
	timer.one_shot = true
	add_child(timer)
	timer.unscaled_base_value = BRITTLE_SECONDS
	timer.timeout.connect(_on_brittle_end)
	GameSignals.enemy_hit.connect(_on_enemy_hit)


func _on_enemy_hit(hit_enemy : Enemy, damage_data : DamageData) -> void:
	if hit_enemy != enemy or damage_data.damage_type != Utils.DamageType.Frost or damage_data.damage <= 0.0:
		return
	enemy.resistances = brittle_resistances
	timer.start()


func _on_brittle_end() -> void:
	enemy.resistances = base_resistances
