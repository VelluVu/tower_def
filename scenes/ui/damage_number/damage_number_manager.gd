class_name DamageNumberManager
extends Node


const damage_number_scene : PackedScene = preload("res://scenes/ui/damage_number/damage_number.tscn")
const NUMBER_LAYER_NAME : String = "DamageNumberLayer"
const REACTION_TEXT_SUFFIX : String = "!"
const REACTION_TEXT_OFFSET : Vector2 = Vector2(0, -8)
#with health bars on, numbers start above the bar instead of over it (the user's playtest, 2026-10-28)
#(the bar: 2 px plus its 1 px frame, then a pixel of air)
const HEALTH_BAR_CLEARANCE : Vector2 = Vector2(0, -5)
const LIFE_LOST_TEXT : String = "-%d"
#Endesga 32 red, the life counter's flash colour
const LIFE_LOST_COLOR : Color = Color("e43b44")
const GOLD_EARNED_TEXT : String = "+%d"
#Endesga 32 gold, the gold counter's colour
const GOLD_EARNED_COLOR : Color = Color("feae34")
#a little under the leak and reaction words, so a kill's gold and a reaction never sit on each other
const GOLD_EARNED_OFFSET : Vector2 = Vector2(0, -2)
const NEED_GOLD_TEXT : String = "Need %dg"
const UPGRADED_TEXT : String = "Upgraded"
const EVOLVED_TEXT : String = "Evolved!"
#Endesga 32 light gold, the upgrade flash's colour
const UPGRADED_COLOR : Color = Color("fee761")
const UPGRADED_OFFSET : Vector2 = Vector2(0, -14)
#hits under this are not shown, the rest as whole numbers (the user, 2026-11-26: a basic Beamer or Nova hit stays
#unseen until upgrades lift it past 1; a beam's running total shows once it reaches 1)
const MIN_SHOWN_DAMAGE : float = 1.0
#game seconds a beam's running number waits for its next tick before it floats off (the Beamer ticks every 1.5 s
#at base attack speed)
const RUNNING_HOLD_TIME : float = 1.6

var damage_number_pool : Array[DamageNumber]
#screen space, so the numbers stay crisp at any camera zoom; drawn under the UI layer that follows in Main
var number_layer : CanvasLayer = null
var spawned_count : int = 0
#the parts of one sell (price, Salvage) that arrive in the same frame, shown as one "+N" at the end of it
var pending_refunds : Dictionary[Vector2, float] = {}
#the beam's running numbers by enemy instance id (an id, so a freed enemy never sits in a typed key)
var running_numbers : Dictionary[int, DamageNumber] = {}
var time_scale : float = 1.0


func _ready() -> void:
	number_layer = CanvasLayer.new()
	number_layer.name = NUMBER_LAYER_NAME
	add_child(number_layer)
	GameSignals.damage_taken.connect(_on_damage_taken)
	GameSignals.enemy_hit.connect(_on_enemy_hit)
	GameSignals.time_scale_change.connect(func(new_time_scale : float) -> void: time_scale = new_time_scale)
	GameSignals.element_reaction.connect(_on_element_reaction)
	GameSignals.life_lost.connect(_on_life_lost)
	GameSignals.gold_earned.connect(_on_gold_earned)
	GameSignals.gold_refunded.connect(_on_gold_refunded)
	GameSignals.not_enough_gold.connect(_on_not_enough_gold)
	GameSignals.gold_upgrade_bought.connect(_on_gold_upgrade_bought)


func _on_damage_taken(_position : Vector2, _damage_data : DamageData) -> void:
	if absf(_damage_data.damage) < MIN_SHOWN_DAMAGE or not SettingsManager.get_option(SettingsManager.OPTION_DAMAGE_NUMBERS):
		return
	#crits only: the big hits and heals still show, the stream of small ones does not
	if SettingsManager.get_option(SettingsManager.OPTION_DAMAGE_NUMBERS_CRITS_ONLY) and not _damage_data.is_critical and not _damage_data.is_healing:
		return
	#a beam tick adds to the enemy's running number instead (_on_enemy_hit)
	if _damage_data.is_continuous and not _damage_data.is_healing and not SettingsManager.get_option(SettingsManager.OPTION_DAMAGE_NUMBERS_CRITS_ONLY):
		return
	var damage_number : DamageNumber = _get_damage_number()
	damage_number.activate(_position + _clearance(), _damage_data)


## A beam tick: one number per enemy counts up while the beam keeps hitting, so a beam reads as one growing
## total, not a stream of small pops (the user, 2026-11-26). With crits only, crit ticks pop on their own instead.
func _on_enemy_hit(enemy : Enemy, _damage_data : DamageData) -> void:
	if not _damage_data.is_continuous or _damage_data.damage <= 0.0 or not SettingsManager.get_option(SettingsManager.OPTION_DAMAGE_NUMBERS):
		return
	if SettingsManager.get_option(SettingsManager.OPTION_DAMAGE_NUMBERS_CRITS_ONLY):
		return
	var id : int = enemy.get_instance_id()
	var number : DamageNumber = running_numbers.get(id)
	if number != null and number.is_running():
		number.add_running(_damage_data)
		return
	number = _get_damage_number()
	running_numbers[id] = number
	number.activate_running(enemy, _clearance(), _damage_data)


func _process(_delta : float) -> void:
	if running_numbers.is_empty():
		return
	for id : int in running_numbers.keys():
		var number : DamageNumber = running_numbers[id]
		if not number.is_running():
			running_numbers.erase(id)
		elif not is_instance_valid(instance_from_id(id)) or number.running_since_hit * time_scale > RUNNING_HOLD_TIME:
			number.release()
			running_numbers.erase(id)


func _clearance() -> Vector2:
	return HEALTH_BAR_CLEARANCE if SettingsManager.get_option(SettingsManager.OPTION_HEALTH_BARS) else Vector2.ZERO

func _on_element_reaction(_position : Vector2, reaction : ElementReaction) -> void:
	if not SettingsManager.get_option(SettingsManager.OPTION_DAMAGE_NUMBERS):
		return
	#a bit higher, so the word does not cover the hit's own number
	_get_damage_number().activate_text(_position + REACTION_TEXT_OFFSET + _clearance(), reaction.display_name + REACTION_TEXT_SUFFIX, reaction.color)


#always shown, also with damage numbers off: a leak is news, not noise
func _on_life_lost(_position : Vector2, amount : int) -> void:
	if amount <= 0:
		return
	_get_damage_number().activate_text(_position + REACTION_TEXT_OFFSET, LIFE_LOST_TEXT % amount, LIFE_LOST_COLOR)


func _on_gold_earned(_position : Vector2, amount : float) -> void:
	if roundi(amount) <= 0 or not SettingsManager.get_option(SettingsManager.OPTION_KILL_GOLD):
		return
	_get_damage_number().activate_text(_position + GOLD_EARNED_OFFSET, GOLD_EARNED_TEXT % roundi(amount), GOLD_EARNED_COLOR)


#always shown, unlike kill gold: it answers the player's Sell
func _on_gold_refunded(_position : Vector2, amount : float) -> void:
	if pending_refunds.is_empty():
		_flush_refunds.call_deferred()
	pending_refunds[_position] = pending_refunds.get(_position, 0.0) + amount


func _flush_refunds() -> void:
	for at : Vector2 in pending_refunds:
		var amount : int = roundi(pending_refunds[at])
		if amount > 0:
			_get_damage_number().activate_text(at + GOLD_EARNED_OFFSET, GOLD_EARNED_TEXT % amount, GOLD_EARNED_COLOR)
	pending_refunds.clear()


#always shown: it answers a click
func _on_not_enough_gold(_position : Vector2, price : float) -> void:
	_get_damage_number().activate_text(_position + REACTION_TEXT_OFFSET, NEED_GOLD_TEXT % ceili(price), LIFE_LOST_COLOR)


#over the building's head; an element or tier says Evolved
func _on_gold_upgrade_bought(building : Building, is_evolve : bool) -> void:
	if not is_instance_valid(building):
		return
	_get_damage_number().activate_text(building.global_position + UPGRADED_OFFSET, EVOLVED_TEXT if is_evolve else UPGRADED_TEXT, UPGRADED_COLOR)


func _get_damage_number() -> DamageNumber:
	var number : DamageNumber = null
	
	if damage_number_pool.is_empty():
		number = damage_number_scene.instantiate()
		spawned_count += 1
		number.name = number.name + str(spawned_count)
		number_layer.add_child(number)
	else:
		number = damage_number_pool.pop_back()
	
	#a number comes back to the pool when its float ends
	if not number.deactivated.is_connected(_on_damage_number_available):
		number.deactivated.connect(_on_damage_number_available)
		
	return number


func _on_damage_number_available(damage_number : DamageNumber) -> void:
	if damage_number_pool.has(damage_number):
		return
		
	damage_number_pool.push_back(damage_number)
