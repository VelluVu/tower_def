class_name Hatchery
extends Building

## The Hatchery (2026-11-25, design doc New Towers): a brooding drakeling that never attacks itself. It keeps
## GuardCount guards (HatcheryGuard) on a path cell in its range, the rally cell: each guard holds one ground enemy
## and claws it while that enemy hits back; bosses are only slowed, flyers pass over. A fallen guard hatches again
## after RESPAWN_SECONDS. The rally cell is the path cell in range nearest the spawners along their routes, until
## the player picks another one (the Rally button on the selection card, then a click on a walkable cell in range).
## The guards' damage, crit and element come from its skill (Hatch), their attack speed from its AttackSpeed,
## their health from its GuardHealth.

signal rally_changed

const BASE_GUARDS : int = 3
const MAX_GUARDS : int = 6
const RESPAWN_SECONDS : float = 8.0
## Seconds between a guard's claws at attack speed 0.
const ATTACK_SECONDS : float = 1.0
## The first guards hatch this far apart when it is placed.
const HATCH_STAGGER : float = 0.5
## Each guard's post around the rally cell's centre, in pixels (the first BASE_GUARDS, then the extra ones).
const POST_OFFSETS : Array[Vector2] = [Vector2(0, -4), Vector2(-5, 3), Vector2(5, 3), Vector2(-5, -5), Vector2(5, -5), Vector2(0, 6)]
## Where guards hatch: in front of the nest, a little apart.
const NEST_OFFSETS : Array[Vector2] = [Vector2(0, 6), Vector2(-4, 7), Vector2(4, 7)]
const RALLY_MARKER_NAME : String = "RallyMarker"
const RALLY_CURSOR_SOURCE : StringName = &"hatchery_rally"
const LEFT_CLICK_ACTION_NAME : StringName = &"LeftClick"
const RIGHT_CLICK_ACTION_NAME : StringName = &"RightClick"
const ESCAPE_ACTION_NAME : StringName = &"Escape"
const MARKER_Z_INDEX : int = 15
const FLAG_POLE : Color = Color("733e39")
const FLAG_CLOTH : Color = Color("feae34")
const CELL_FILL : Color = Color(0.79, 0.95, 0.86, 0.14)
const CELL_EDGE : Color = Color(0.79, 0.95, 0.86, 0.45)

@export var guard_scene : PackedScene = null
## The guards' sprites by element: Physical (also before an element is chosen), Fire, Frost, Poison.
@export var guard_frames : Array[SpriteFrames] = []

var guards : Array[HatcheryGuard] = []
var rally_cell : Vector2i = Utils.BAD_CELL
var is_rally_manual : bool = false
var is_picking_rally : bool = false
var is_selected : bool = false
var is_cursor_on_gui : bool = false
var rally_marker : Node2D = null

## How many guards it keeps: BASE_GUARDS plus its GuardCount (tiers, talents), at most MAX_GUARDS.
var guard_count : int :
	get:
		return clampi(BASE_GUARDS + roundi(stats.get_stat_value(Utils.StatType.GuardCount)), 1, MAX_GUARDS)

var guard_health : float :
	get:
		return maxf(stats.get_stat_value(Utils.StatType.GuardHealth), 1.0)


func _ready() -> void:
	super()
	rally_marker = Node2D.new()
	rally_marker.name = RALLY_MARKER_NAME
	rally_marker.top_level = true
	rally_marker.z_index = MARKER_Z_INDEX
	rally_marker.draw.connect(_draw_rally)
	add_child(rally_marker)
	if evolve_tree != null:
		evolve_tree.element_changed.connect(func(_element : Utils.Element) -> void: _refresh_guards())
	stats_changed.connect(_refresh_guards)
	GameSignals.selected_unit.connect(_on_selected_unit)
	GameSignals.deselected_unit.connect(_on_deselected_unit)
	UISignals.mouse_on_gui.connect(func(is_on : bool) -> void: is_cursor_on_gui = is_on)


func _enable_tower() -> void:
	super()
	if not GameSignals.astar_grid_updated.is_connected(_on_grid_updated):
		GameSignals.astar_grid_updated.connect(_on_grid_updated)
	update_rally()
	_refresh_guards()
	if animation_control != null and animation_control.sprite_frames.has_animation(GlobalAnimationNames.IDLE_ANIMATION):
		animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)


## The rally cell's centre in the world.
func get_rally_position() -> Vector2:
	if rally_cell == Utils.BAD_CELL or level == null:
		return global_position
	return level.grid.grid_position_to_world(rally_cell)


## Guard index's post: around the rally cell.
func get_post(guard_index : int) -> Vector2:
	return get_rally_position() + POST_OFFSETS[guard_index % POST_OFFSETS.size()]


func get_nest_position(guard_index : int) -> Vector2:
	return global_position + NEST_OFFSETS[guard_index % NEST_OFFSETS.size()]


## Seconds between a guard's claws, faster with attack speed.
func get_attack_seconds() -> float:
	return ATTACK_SECONDS / maxf(1.0 + skill.stats.get_stat_value(Utils.StatType.AttackSpeed), 0.1)


func get_respawn_seconds() -> float:
	return RESPAWN_SECONDS


## How far from it (pixels) the rally cell may be: its range.
func get_rally_reach() -> float:
	return skill.stats.get_range_in_tiles()


## A cell the guards may stand on: walkable, no building but a trap on it, within its range.
func is_valid_rally_cell(cell : Vector2i) -> bool:
	if level == null or not level.grid.is_cell_walkable(cell):
		return false
	var building : Building = level.grid.get_building_from_cell_position(cell)
	if building != null and not building is Trap:
		return false
	return level.grid.grid_position_to_world(cell).distance_to(global_position) <= get_rally_reach()


## Keeps a picked rally cell while it stays valid, otherwise finds the automatic one.
func update_rally() -> void:
	if is_rally_manual and is_valid_rally_cell(rally_cell):
		return
	is_rally_manual = false
	_set_rally_cell(find_auto_rally_cell())


## The path cell in range that the enemies reach first: along every spawner's route, the earliest cell in range
## (fewest steps from its spawner). Without a route through its range, the walkable cell in range nearest to it.
func find_auto_rally_cell() -> Vector2i:
	if level == null:
		return Utils.BAD_CELL
	var best : Vector2i = Utils.BAD_CELL
	var best_step : int = 1 << 30
	#Hold the line (synergy): a trap on a route in reach comes first, the enemies' first one
	var best_trap : Vector2i = Utils.BAD_CELL
	var best_trap_step : int = 1 << 30
	for route in level.get_routes():
		var path : PackedVector2Array = level.grid.find_path(route[0], route[1])
		for step in path.size():
			var cell : Vector2i = level.grid.world_position_to_grid(path[step])
			if not is_valid_rally_cell(cell):
				continue
			if step < best_step:
				best = cell
				best_step = step
			if step < best_trap_step and level.grid.get_building_from_cell_position(cell) is Trap:
				best_trap = cell
				best_trap_step = step
				break
	if best_trap != Utils.BAD_CELL:
		return best_trap
	if best != Utils.BAD_CELL:
		return best
	var reach_cells : int = ceili(get_rally_reach() / Utils.TILE_SIZE)
	var best_distance : float = INF
	for y in range(-reach_cells, reach_cells + 1):
		for x in range(-reach_cells, reach_cells + 1):
			var cell : Vector2i = grid_position + Vector2i(x, y)
			var distance : float = Vector2(x, y).length()
			if cell != grid_position and distance < best_distance and is_valid_rally_cell(cell):
				best = cell
				best_distance = distance
	return best


## The player's pick: true when the cell was taken.
func set_manual_rally(cell : Vector2i) -> bool:
	if not is_valid_rally_cell(cell):
		return false
	is_rally_manual = true
	_set_rally_cell(cell)
	return true


func start_rally_pick() -> void:
	if not is_placed:
		return
	is_picking_rally = true
	UISignals.cursor_mode_requested.emit(RALLY_CURSOR_SOURCE, GameCursor.Mode.TARGET)
	rally_marker.queue_redraw()


func stop_rally_pick() -> void:
	if not is_picking_rally:
		return
	is_picking_rally = false
	UISignals.cursor_mode_requested.emit(RALLY_CURSOR_SOURCE, GameCursor.Mode.POINTER)
	rally_marker.queue_redraw()


## Plays the nest's crack and burst once (a guard hatching), then idles again.
func play_hatch() -> void:
	if animation_control == null or not animation_control.sprite_frames.has_animation(GlobalAnimationNames.STOP_ATTACK_ANIMATION):
		return
	animation_control.play_animation(GlobalAnimationNames.STOP_ATTACK_ANIMATION)
	if not animation_control.animation_finished.is_connected(_on_hatch_finished):
		animation_control.animation_finished.connect(_on_hatch_finished, CONNECT_ONE_SHOT)


func _on_hatch_finished() -> void:
	if animation_control != null and animation_control.sprite_frames.has_animation(GlobalAnimationNames.IDLE_ANIMATION):
		animation_control.play_animation(GlobalAnimationNames.IDLE_ANIMATION)


func _input(event : InputEvent) -> void:
	if not is_picking_rally:
		return
	if event.is_action_pressed(RIGHT_CLICK_ACTION_NAME) or event.is_action_pressed(ESCAPE_ACTION_NAME):
		stop_rally_pick()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(LEFT_CLICK_ACTION_NAME) and not is_cursor_on_gui:
		set_manual_rally(level.grid.world_position_to_grid(get_global_mouse_position()))
		stop_rally_pick()
		#the click picks a cell, it must not select or deselect a unit too
		get_viewport().set_input_as_handled()


func _set_rally_cell(cell : Vector2i) -> void:
	if cell == rally_cell:
		return
	rally_cell = cell
	rally_marker.queue_redraw()
	rally_changed.emit()


## Hatches guards up to guard_count (the first ones staggered), lets extra ones go, and gives every guard the
## current health and element sprites.
func _refresh_guards() -> void:
	if not is_placed or guard_scene == null:
		return
	var frames : SpriteFrames = _get_guard_frames()
	while guards.size() < guard_count:
		var guard : HatcheryGuard = guard_scene.instantiate()
		guard.hatchery = self
		guard.index = guards.size()
		guard.max_health = guard_health
		add_child(guard)
		guard.set_frames(frames)
		guard.hatch_after(HATCH_STAGGER * guard.index)
		guards.append(guard)
	while guards.size() > guard_count:
		var extra : HatcheryGuard = guards.pop_back()
		extra.queue_free()
	for guard in guards:
		guard.set_frames(frames)
		guard.set_max_health(guard_health)


func _get_guard_frames() -> SpriteFrames:
	if guard_frames.is_empty():
		return null
	var element : Utils.Element = evolve_tree.evolve_element if evolve_tree != null and evolve_tree.is_element_chosen else Utils.Element.Physical
	var slot : int = {Utils.Element.Fire: 1, Utils.Element.Frost: 2, Utils.Element.Poison: 3}.get(element, 0)
	return guard_frames[mini(slot, guard_frames.size() - 1)]


func _on_grid_updated() -> void:
	#out of the tree: a retried level's old Hatchery, still waiting to be freed, hears the new level's grid
	if is_placed and is_inside_tree():
		update_rally()


func _on_selected_unit(unit : Node2D) -> void:
	is_selected = unit == self
	if not is_selected:
		stop_rally_pick()
	rally_marker.queue_redraw()


func _on_deselected_unit(unit : Node2D) -> void:
	if unit != self:
		return
	is_selected = false
	stop_rally_pick()
	rally_marker.queue_redraw()


#the rally flag while selected; while picking also every cell it may take
func _draw_rally() -> void:
	if not is_placed or not (is_selected or is_picking_rally):
		return
	if is_picking_rally:
		var reach_cells : int = ceili(get_rally_reach() / Utils.TILE_SIZE)
		var half : Vector2 = Vector2.ONE * Utils.TILE_SIZE * 0.5
		for y in range(-reach_cells, reach_cells + 1):
			for x in range(-reach_cells, reach_cells + 1):
				var cell : Vector2i = grid_position + Vector2i(x, y)
				if is_valid_rally_cell(cell):
					var rect : Rect2 = Rect2(level.grid.grid_position_to_world(cell) - half + Vector2.ONE, half * 2.0 - Vector2.ONE * 2.0)
					rally_marker.draw_rect(rect, CELL_FILL)
					rally_marker.draw_rect(rect, CELL_EDGE, false, 1.0)
	if rally_cell == Utils.BAD_CELL:
		return
	var foot : Vector2 = get_rally_position().round() + Vector2(0, 5)
	rally_marker.draw_line(foot, foot + Vector2(0, -12), FLAG_POLE, 1.0)
	rally_marker.draw_colored_polygon(PackedVector2Array([foot + Vector2(1, -12), foot + Vector2(6, -10), foot + Vector2(1, -8)]), FLAG_CLOTH)
