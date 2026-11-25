class_name ElderDrake
extends Tower

## The Elder Drake (2026-11-25, design doc "Second round of towers"): an expensive, big drakeling for the late levels.
## Between breaths it bites (its skill: heavy single bolts). Once a wave its breath is ready: as soon as an enemy is in
## range it breathes along the line through the most enemies, out to BREATH_LENGTH_TILES, hitting every ground and air
## enemy within BREATH_HALF_WIDTH of the line for BREATH_SHARE of its bite damage, with the element's effect (the
## bite's damage data: burn, slow stacks, poison). A new wave readies it again.

const BREATH_LENGTH_TILES : float = 7.0
const BREATH_HALF_WIDTH : float = 10.0
const BREATH_SHARE : float = 4.0
## Directions tried when picking the line (evenly round the drake).
const BREATH_DIRECTIONS : int = 24
const BREATH_ANIMATION : StringName = &"BREATH"
const FLAME_LAYERS : Dictionary[int, Array] = {
	Utils.Element.Physical: [Color("3a4466"), Color("8b9bb4"), Color("c0cbdc"), Color("ffffff")],
	Utils.Element.Fire: [Color("a22633"), Color("e43b44"), Color("f77622"), Color("fee761")],
	Utils.Element.Frost: [Color("124e89"), Color("0099db"), Color("2ce8f5"), Color("ffffff")],
	Utils.Element.Poison: [Color("265c42"), Color("3e8948"), Color("63c74d"), Color("b6d53c")],
}

signal breathed(hit_count : int)

var is_breath_ready : bool = true


func _ready() -> void:
	super()
	if not GameSignals.wave_started.is_connected(_on_wave_started):
		GameSignals.wave_started.connect(_on_wave_started)


func _physics_process(_delta : float) -> void:
	if is_breath_ready and is_placed and not is_dead and has_target:
		breathe()


## Breathes now along the best line; returns how many enemies it hit.
func breathe() -> int:
	is_breath_ready = false
	var direction : Vector2 = pick_direction()
	var reach : float = BREATH_LENGTH_TILES * Utils.TILE_SIZE
	var end : Vector2 = global_position + direction * reach
	var hit_count : int = 0
	for enemy in _enemies_on_line(direction, reach):
		var hit : DamageData = skill.damage_data
		hit.damage *= BREATH_SHARE
		enemy.take_damage(hit)
		hit.free()
		hit_count += 1
	var level : Level = Utils.game_control.scene_manager.current_level if Utils.game_control != null else null
	if level != null:
		var flame : TelegraphLine = TelegraphLine.make_flame(level, global_position, end, BREATH_HALF_WIDTH * 0.6)
		var element : int = evolve_tree.evolve_element if evolve_tree != null and evolve_tree.is_element_chosen else Utils.Element.Fire
		if FLAME_LAYERS.has(element):
			flame.flame_layers.assign(FLAME_LAYERS[element])
	flip(direction)
	if animation_control.sprite_frames.has_animation(BREATH_ANIMATION):
		animation_control.play(BREATH_ANIMATION)
	breathed.emit(hit_count)
	return hit_count


## The direction (of BREATH_DIRECTIONS) whose line passes the most enemies; toward the first target on a tie.
func pick_direction() -> Vector2:
	var reach : float = BREATH_LENGTH_TILES * Utils.TILE_SIZE
	var first : Node2D = get_first_target()
	var best : Vector2 = global_position.direction_to(first.global_position) if first != null else Vector2.RIGHT
	var best_count : int = _enemies_on_line(best, reach).size()
	for i in BREATH_DIRECTIONS:
		var direction : Vector2 = Vector2.RIGHT.rotated(TAU * i / BREATH_DIRECTIONS)
		var count : int = _enemies_on_line(direction, reach).size()
		if count > best_count:
			best = direction
			best_count = count
	return best


func _enemies_on_line(direction : Vector2, reach : float) -> Array[Enemy]:
	var found : Array[Enemy] = []
	var level : Level = Utils.game_control.scene_manager.current_level if Utils.game_control != null else null
	if level == null:
		return found
	var end : Vector2 = global_position + direction * reach
	for enemy in level.existing_enemies:
		if not EnemyQuery.is_hittable(enemy) or enemy.is_concealed:
			continue
		var on_line : Vector2 = Geometry2D.get_closest_point_to_segment(enemy.body_center, global_position, end)
		if on_line.distance_to(enemy.body_center) <= BREATH_HALF_WIDTH:
			found.append(enemy)
	return found


func _on_wave_started(_wave_number : int) -> void:
	is_breath_ready = true
