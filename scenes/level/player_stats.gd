class_name PlayerStats
extends Node

#level based player resources
@export var gold : float = 6.0 :
	set = _set_gold
@export var life : float = 10.0 :
	set = _set_life

var has_lost : bool = false

var is_alive : bool :
	get:
		return life > 0


func _ready() -> void:
	GameSignals.enemy_reached_end_point.connect(_on_enemy_reach_base)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.sell_building.connect(_on_building_sell)
	UISignals.game_play_interface_loaded.connect(_on_game_play_interface_loaded)


func _on_enemy_reach_base(enemy : Enemy) -> void:
	#Keep Awakens (talent): the castle dragon stops the first enemy of each wave at each castle
	var level : Level = get_parent() as Level
	if level != null and level.talents != null and level.talents.mechanics != null and level.talents.mechanics.forgives_leak(enemy):
		return
	#the enemy's own damage is its leak cost, the melee skill's damage is only for hitting buildings
	var cost : int = roundi(enemy.stats.get_stat_value(Utils.StatType.Damage))
	life -= cost
	GameSignals.resource_change.emit(life, 1)
	GameSignals.life_lost.emit(enemy.global_position, cost)
	if life <= 0:
		lose()


func has_enough_gold(amount : float) -> bool:
	if GameSignals.free_build:
		return true
	return gold >= amount


func spend_gold(amount : float) -> bool:
	if not has_enough_gold(amount):
		return false

	#the free build cheat: nothing costs gold, so nothing is taken either
	if GameSignals.free_build:
		return true

	gold -= amount
	GameSignals.resource_change.emit(gold, 0)
	return true


func add_gold(amount : float) -> void:
	gold += amount
	GameSignals.resource_change.emit(gold, 0)


#once: enemies leaking in the same frame after the last life would stack lose menus and log the loss twice
func lose() -> void:
	if has_lost:
		return
	has_lost = true
	GameSignals.lose_game.emit()


func _on_game_play_interface_loaded() -> void:
	GameSignals.resource_change.emit(gold, 0)
	GameSignals.resource_change.emit(life, 1)


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if not enemy.gives_reward:
		return

	var reward : float = enemy.stats.get_stat_value(Utils.StatType.Price)
	gold += reward
	GameSignals.resource_change.emit(gold, 0)
	GameSignals.gold_earned.emit(enemy.global_position, reward)


func _on_building_placed(building : Building) -> void:
	if GameSignals.free_build:
		return

	gold -= building.stats.get_stat_value(Utils.StatType.Price)
	GameSignals.resource_change.emit(gold, 0)


func _on_building_sell(building : Building) -> void:
	gold += building.stats.get_stat_value(Utils.StatType.Price)
	GameSignals.resource_change.emit(gold, 0)


func _set_life(value : float) -> void:
	if life == value:
		return
	
	life = value
	
	if life < 0.0:
		life = 0.0


func _set_gold(value : float) -> void:
	if gold == value:
		return
	
	gold = value
	
	if gold < 0.0:
		gold = 0.0
