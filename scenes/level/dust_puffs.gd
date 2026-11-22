class_name DustPuffs
extends Node2D

## A small dust puff where a building is placed or sold and where a walking enemy arrives
## (polish, 2026-11-22), so things never just pop in or out. Made by Level. Art from
## tools/art/dust_puff.py: 4 frames of 16x16. Cosmetic: real time, not game time.

const SHEET : Texture2D = preload("res://assets/art/effects/dust_puff.png")
const FRAMES : int = 4
const FRAME_SECONDS : float = 0.07
## Over the units, under the damage numbers' layer.
const PUFF_Z_INDEX : int = 20
## The puff's bottom sits at the unit's feet.
const OFFSET : Vector2 = Vector2(0, -4)
## A swarm spilling out of one cave shows one puff at a time.
const SAME_SPOT_GAP_MSEC : int = 150
const SAME_SPOT_DISTANCE : float = 12.0
## A fallen boss: a ring of puffs this far around where it fell.
const BOSS_RING_PUFFS : int = 6
const BOSS_RING_RADIUS : float = 14.0

#[position, Time.get_ticks_msec()] of the puffs of the last SAME_SPOT_GAP_MSEC
var _recent : Array[Array] = []


func _ready() -> void:
	z_index = PUFF_Z_INDEX
	GameSignals.building_placed.connect(_on_building_placed)
	GameSignals.sell_building.connect(_on_building_sold)
	GameSignals.enemy_spawned.connect(_on_enemy_spawned)
	GameSignals.enemy_destroyed.connect(_on_enemy_destroyed)
	GameSignals.enemy_reached_end_point.connect(_on_enemy_reached_end)


func _on_building_placed(building : Building) -> void:
	puff(building.global_position)


func _on_building_sold(building : Building) -> void:
	puff(building.global_position)


#flyers come out of the air, not the dust
func _on_enemy_spawned(enemy : Enemy) -> void:
	if enemy.is_flying:
		return
	puff(enemy.global_position)


func _on_enemy_destroyed(enemy : Enemy) -> void:
	if not enemy.is_boss:
		return
	for i in BOSS_RING_PUFFS:
		var angle : float = TAU * i / BOSS_RING_PUFFS
		puff(enemy.global_position + Vector2.from_angle(angle) * BOSS_RING_RADIUS, true)


#rubble at the castle where it got in
func _on_enemy_reached_end(enemy : Enemy) -> void:
	if not enemy.is_flying:
		puff(enemy.global_position)


## One puff at a world position, unless one played on the same spot a moment ago.
func puff(at : Vector2, is_forced : bool = false) -> void:
	var now : int = Time.get_ticks_msec()
	_recent = _recent.filter(func(entry : Array) -> bool: return now - entry[1] < SAME_SPOT_GAP_MSEC)
	for entry in _recent:
		if not is_forced and (entry[0] as Vector2).distance_to(at) < SAME_SPOT_DISTANCE:
			return
	_recent.append([at, now])

	var sprite : Sprite2D = Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = FRAMES
	add_child(sprite)
	sprite.global_position = (at + OFFSET).round()
	var tween : Tween = sprite.create_tween()
	for frame in range(1, FRAMES):
		tween.tween_interval(FRAME_SECONDS)
		tween.tween_callback(sprite.set.bind(&"frame", frame))
	tween.tween_interval(FRAME_SECONDS)
	tween.tween_callback(sprite.queue_free)
