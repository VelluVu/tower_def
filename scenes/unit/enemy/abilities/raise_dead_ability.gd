class_name RaiseDeadAbility
extends EnemyAbility

## The grave caller: raises its staff (ATTACK) and a bone thrall (raised_scene) climbs out where an enemy fell nearby.
## It remembers the last `max_corpses` places where ground enemies were killed; each place rises once.

## In tiles.
@export var raise_range : float = 3.5
@export var raised_scene : PackedScene = null
@export var max_corpses : int = 6

var corpses : Array[Vector2] = []
var corpse : Vector2 = Vector2.INF


func setup(_enemy : Enemy) -> void:
	super(_enemy)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)


func _on_enemy_destroyed(dead : Enemy) -> void:
	if dead == enemy or not dead.is_dead or not dead.gives_reward or dead.is_boss or dead.is_flying:
		return
	corpses.append(dead.global_position)
	if corpses.size() > max_corpses:
		corpses.pop_front()


func _can_use() -> bool:
	if raised_scene == null or enemy == null:
		return false
	var reach : float = raise_range * Utils.TILE_SIZE
	corpse = Vector2.INF
	for place in corpses:
		if place.distance_to(enemy.global_position) > reach:
			continue
		if corpse == Vector2.INF or place.distance_squared_to(enemy.global_position) < corpse.distance_squared_to(enemy.global_position):
			corpse = place
	return corpse != Vector2.INF


func _run() -> void:
	var place : Vector2 = corpse
	corpses.erase(place)
	if not await _play_and_wait(GlobalAnimationNames.ATTACK_ANIMATION):
		return
	EnemySummon.summon(raised_scene, enemy, place)
	_finish()
