class_name Sandstorm
extends Node2D

## The ash desert's sandstorms (created by Level when LevelData.sandstorm_every > 0): every sandstorm_every seconds
## of game time a band of blowing sand sweeps the map from east to west. Towers inside it see less far (a Multiply
## modifier on AttackRange while inside) and flyers inside it cannot be targeted (Enemy.is_concealed).

const BAND_TILES : float = 8.0
const SWEEP_SECONDS : float = 14.0
## AttackRange while inside the band, as a Multiply modifier: -35%.
const RANGE_CUT : float = -0.35
#darker than the desert's sand, so the band shows over dunes and salt flats alike
const SAND : Color = Color(0.55, 0.40, 0.27, 0.5)
const STREAK : Color = Color(0.96, 0.88, 0.68, 0.8)
const STREAK_STEP : int = 4

## Seconds between storms (set by Level from LevelData).
var every : float = 60.0
var level : Level = null
var playfield : Rect2 = Rect2()
var is_blowing : bool = false
#the band's west edge, in the level's coordinates
var band_x : float = 0.0
var current_time_scale : float = 1.0
var next_timer : CustomTimer = null
#towers inside the band (by instance id, so a tower freed inside it is dropped safely) and the modifier each got
var covered : Dictionary[int, ModifierData] = {}

var band_width : float :
	get:
		return BAND_TILES * Utils.TILE_SIZE

var speed : float :
	get:
		return (playfield.size.x + band_width) / SWEEP_SECONDS


func _ready() -> void:
	level = get_parent()
	playfield = level.grid.get_playfield_rect()
	z_index = 15
	next_timer = CustomTimer.new()
	next_timer.one_shot = true
	add_child(next_timer)
	next_timer.unscaled_base_value = every
	next_timer.timeout.connect(start)
	next_timer.start()
	GameSignals.time_scale_change.connect(func(time_scale : float) -> void: current_time_scale = time_scale)
	current_time_scale = Utils.game_control.time_scale if Utils.game_control != null else 1.0


func start() -> void:
	is_blowing = true
	band_x = playfield.end.x
	queue_redraw()


func get_band() -> Rect2:
	return Rect2(band_x, playfield.position.y, band_width, playfield.size.y)


func _process(delta : float) -> void:
	if not is_blowing:
		return
	band_x -= speed * delta * current_time_scale
	if band_x + band_width < playfield.position.x:
		_stop()
		return
	_update_cover()
	queue_redraw()


func _stop() -> void:
	is_blowing = false
	for id in covered.keys():
		_uncover(id)
	for enemy in level.existing_enemies:
		if is_instance_valid(enemy):
			enemy.is_concealed = false
	queue_redraw()
	next_timer.start()


func _update_cover() -> void:
	var band : Rect2 = get_band()
	for building in level.all_buildings:
		if not is_instance_valid(building) or building is not Tower or not building.is_placed:
			continue
		var inside : bool = band.has_point(building.global_position)
		var id : int = building.get_instance_id()
		if inside and not covered.has(id):
			var cut : ModifierData = Elite.multiply(Utils.StatType.AttackRange, 1.0 + RANGE_CUT)
			building.modifier_manager.add_modifier(cut)
			covered[id] = cut
		elif not inside and covered.has(id):
			_uncover(id)
	for id in covered.keys():
		if not is_instance_id_valid(id):
			covered.erase(id)
	for enemy in level.existing_enemies:
		if is_instance_valid(enemy):
			enemy.is_concealed = enemy.is_flying and band.has_point(enemy.global_position)


func _uncover(id : int) -> void:
	var building : Building = instance_from_id(id) as Building if is_instance_id_valid(id) else null
	if building != null:
		building.modifier_manager.remove_modifier(covered[id])
	covered.erase(id)


#a sand band with drifting streaks, on whole pixels
func _draw() -> void:
	if not is_blowing:
		return
	var band : Rect2 = get_band().intersection(playfield)
	if band.size.x <= 0.0:
		return
	draw_rect(Rect2(band.position.round(), band.size.round()), SAND)
	var offset : int = int(band_x) % STREAK_STEP
	for y in range(int(band.position.y), int(band.end.y), STREAK_STEP):
		var x : float = band.position.x + float((y * 7 + offset) % int(maxf(band.size.x, 1.0)))
		draw_line(Vector2(roundf(x), y), Vector2(roundf(minf(x + 5.0, band.end.x)), y), STREAK, 1.0)
