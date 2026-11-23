class_name Fissure
extends Node2D

## A fissure in a volcano level (placed by tools/scorched_levels.py): grid cells that erupt at the start of the
## given waves. The wave before, the cells crack and glow (the warning); then lava floods them through the level's
## LavaField: what stands there burns, the road closes until a Frost tower cools it or lava_waves waves have passed.

## Grid cells (LevelGrid coordinates).
@export var cells : Array[Vector2i] = []
## Waves (1-based) at whose start the fissure erupts.
@export var erupt_waves : Array[int] = []
## Waves done after an eruption (its own wave included) until the lava sets by itself.
@export var lava_waves : int = 2

const CRACK_COLOR : Color = Color("f77622")
const CRACK_GLOW : Color = Color("fee761")
const HALF_TILE : float = Utils.TILE_SIZE * 0.5

var level : Level = null
var is_warning : bool = false
#the wave this fissure last erupted at, -1 when no lava of it is out. Counted by wave numbers, not clears: an early
#start never clears the wave it overtook, and the warning and the settle went missing then
var eruption_wave : int = -1


func _ready() -> void:
	level = get_parent()
	z_index = 1
	GameSignals.wave_started.connect(_on_wave_started)
	GameSignals.wave_cleared.connect(_on_wave_cleared)
	#the first wave can be one: warn from the start
	_set_warning(_erupts_at(1))


func get_lava_field() -> LavaField:
	return level.get_node_or_null(Level.LAVA_FIELD_NAME) as LavaField


## Survival loops the level's waves with growing numbers: wave 13 of a 12-wave level is its wave 1 again.
func _erupts_at(wave_number : int) -> bool:
	var runner : WaveRunner = level.wave_runner
	if runner != null and runner.is_endless and not runner.waves.is_empty():
		wave_number = (wave_number - 1) % runner.waves.size() + 1
	return erupt_waves.has(wave_number)


#the wave before an eruption warns from its start, so an early start into the erupting wave still saw the cracks
func _on_wave_started(wave_number : int) -> void:
	#waves done since the eruption: every wave before this one (an early start skips their clears)
	_settle_after(wave_number - 1)
	if _erupts_at(wave_number) and get_lava_field() != null:
		get_lava_field().erupt(cells)
		eruption_wave = wave_number
	_set_warning(_erupts_at(wave_number + 1))


func _on_wave_cleared(wave_number : int) -> void:
	_settle_after(wave_number)
	_set_warning(_erupts_at(wave_number + 1))


## The lava sets once lava_waves waves, the eruption's own wave included, are done.
func _settle_after(last_done_wave : int) -> void:
	if eruption_wave < 0 or last_done_wave - eruption_wave + 1 < lava_waves or get_lava_field() == null:
		return
	get_lava_field().settle(cells)
	eruption_wave = -1
	#an ability's cracks (EruptAbility) never erupt again: gone once their lava has set
	if erupt_waves.is_empty():
		queue_free()


func _set_warning(value : bool) -> void:
	if value == is_warning:
		return
	is_warning = value
	queue_redraw()


#a zigzag crack across each cell, on whole pixels, drawn in the level's own coordinates
func _draw() -> void:
	if not is_warning:
		return
	for cell in cells:
		var centre : Vector2 = to_local(level.grid.grid_position_to_world(cell)).round()
		var points : PackedVector2Array = [centre + Vector2(-6, -3), centre + Vector2(-2, 1), centre + Vector2(1, -2),
			centre + Vector2(6, 3)]
		draw_polyline(points, CRACK_COLOR, 1.0)
		draw_rect(Rect2(centre + Vector2(-1, -1), Vector2(2, 2)), CRACK_GLOW)
