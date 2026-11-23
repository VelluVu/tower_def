class_name WallGroupSelect
extends Node2D

## Rectangle select for walls (created by Level): Shift + left drag draws a box, the walls inside become a group.
## The selection panel then offers to sell them all or to buy an element for the plain ones (UISignals
## wall_group_changed / wall_group_action). Right click or Esc lets go.

const BOX_FILL : Color = Color(0.79, 0.95, 0.86, 0.12)
const BOX_EDGE : Color = Color(0.79, 0.95, 0.86, 0.8)
const SELL_ACTION : int = -1
const GROUP_TITLE : String = "%d walls"
const SELL_TITLE : String = "Sell all"
const RIGHT_CLICK_ACTION_NAME : String = "RightClick"
const ESCAPE_ACTION_NAME : String = "Escape"

var is_dragging : bool = false
var drag_start : Vector2 = Vector2.ZERO
var drag_end : Vector2 = Vector2.ZERO
var is_placing_building : bool = false
var walls : Array[Wall] = []
#the element options on offer, in the order of the panel's buttons
var element_options : Array[GoldUpgradeOption] = []

@onready var level : Level = get_parent()


func _ready() -> void:
	z_index = 30
	GameSignals.building_placement_change.connect(func(is_placing : bool) -> void: is_placing_building = is_placing)
	GameSignals.selected_unit.connect(func(_unit : Node2D) -> void: _clear())
	GameSignals.resource_change.connect(func(_value : int, _index : int) -> void: _emit())
	UISignals.wall_group_action.connect(_on_action)


func _unhandled_input(event : InputEvent) -> void:
	if is_placing_building:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.shift_pressed:
			is_dragging = true
			drag_start = get_global_mouse_position()
			drag_end = drag_start
			get_viewport().set_input_as_handled()
		elif not event.pressed and is_dragging:
			is_dragging = false
			_collect()
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and is_dragging:
		drag_end = get_global_mouse_position()
		queue_redraw()
	elif not walls.is_empty() and (event.is_action_pressed(RIGHT_CLICK_ACTION_NAME) or event.is_action_pressed(ESCAPE_ACTION_NAME)):
		_clear()


func _draw() -> void:
	if not is_dragging:
		return
	var box : Rect2 = Rect2(drag_start, drag_end - drag_start).abs()
	draw_rect(box, BOX_FILL)
	draw_rect(box, BOX_EDGE, false, 1.0)


func _collect() -> void:
	var box : Rect2 = Rect2(drag_start, drag_end - drag_start).abs().grow(Utils.TILE_SIZE * 0.5)
	walls.clear()
	for building in level.all_buildings:
		if is_instance_valid(building) and building is Wall and building.is_placed and box.has_point(building.global_position):
			walls.append(building)
	#the group takes the selection panel, so a selected unit lets go first (its card would show through)
	if not walls.is_empty():
		GameSignals.selection_clear_requested.emit()
	_emit()


func _clear() -> void:
	if walls.is_empty():
		return
	walls.clear()
	_emit()


## The plain walls of the group (no element yet), the ones an element is bought for.
#the lambdas take the wall untyped: a wall destroyed while grouped is freed, and a freed element in a typed
#parameter fails the whole filter (a script error, after the element's gold was already spent)
func get_plain_walls() -> Array[Wall]:
	return walls.filter(func(wall) -> bool: return is_instance_valid(wall) and wall.element == Utils.Element.None)


func _emit() -> void:
	walls = walls.filter(func(wall) -> bool: return is_instance_valid(wall) and not wall.is_dead)
	element_options.clear()
	var plain : int = get_plain_walls().size()
	var upgrades : BuildingTypeUpgrades = level.building_type_upgrades
	if plain > 0 and upgrades.get_upgrade_steps(walls[0]) >= BuildingTypeUpgrades.WALL_ELEMENT_MIN_UPGRADES:
		for element in BuildingTypeUpgrades.WALL_ELEMENTS:
			if element == Utils.Element.Physical and PlayerProgress.get_talent_ranks(BuildingTypeUpgrades.FORTRESS_TREE).get(BuildingTypeUpgrades.FORTRESS_NODE, 0) <= 0:
				continue
			var entry : Array = BuildingTypeUpgrades.WALL_ELEMENTS[element]
			var option : GoldUpgradeOption = GoldUpgradeOption.wall_element_option(element, entry[0], load(entry[1]), BuildingTypeUpgrades.WALL_ELEMENT_PRICE * plain)
			option.is_affordable = level.player_stats.has_enough_gold(option.cost)
			element_options.append(option)
	UISignals.wall_group_changed.emit(GROUP_TITLE % walls.size() if not walls.is_empty() else "", element_options)


func _on_action(index : int) -> void:
	if walls.is_empty():
		return
	if index == SELL_ACTION:
		for wall in walls.duplicate():
			if is_instance_valid(wall):
				GameSignals.sell_building.emit(wall)
		walls.clear()
	elif index >= 0 and index < element_options.size():
		var option : GoldUpgradeOption = element_options[index]
		if level.player_stats.spend_gold(option.cost):
			for wall in get_plain_walls():
				wall.set_element(option.wall_element)
	_emit()
