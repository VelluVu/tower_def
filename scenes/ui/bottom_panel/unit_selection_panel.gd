class_name UnitSelectionPanel
extends PanelContainer

## A small card fixed to the bottom-left corner: icon, name, the stats in two short lines,
## then the gold upgrades and Sell. Fixed width and a fixed corner, so it never moves.

const UPGRADE_BUTTON_TEXT : String = "%s\n%dg"
const EVOLVE_BUTTON_TEXT : String = "%dg"
#fixed width, long titles end in "..." and the tooltip has the full one
const UPGRADE_BUTTON_MIN_SIZE : Vector2 = Vector2(50, 0)
const EVOLVE_BUTTON_MIN_SIZE : Vector2 = Vector2(24, 0)
const UPGRADE_BUTTON_ICON_SIZE : int = 12
const UPGRADE_BUTTON_FONT_SIZE : int = 8
## On a tier whose talent node is not learned; the tooltip names the node.
const LOCKED_ICON : Texture2D = preload("res://assets/art/ui/lock.png")
## Space between the card and the window's bottom-left corner.
const CORNER_MARGIN : float = 4.0
const RESISTS_TEXT : String = "Resists: %s"
const RESISTS_COLOR : Color = Color("86b8a0")
const TACTIC_LABEL_TEXT : String = "Target"
const TACTIC_TOOLTIP : String = "Which enemy in range this tower shoots. Change it any time, during a wave too."

@onready var unit_info_grid_container : GridContainer = $HBoxContainer/InfoBox/UnitInfoGridContainer
@onready var unit_icon : TextureRect = $HBoxContainer/UnitIcon
@onready var name_value : Label = $HBoxContainer/InfoBox/NameLabel
@onready var sell_button : Button = $HBoxContainer/InfoBox/ButtonRow/SellButton
@onready var upgrade_option_container : HBoxContainer = $HBoxContainer/InfoBox/ButtonRow/UpgradeOptionContainer
@onready var button_row : HBoxContainer = $HBoxContainer/InfoBox/ButtonRow

var resists_label : Label = null
#a Bolter's or Beamer's targeting tactic: a label and a menu of every tactic
var tactic_row : HBoxContainer = null
var tactic_menu : OptionButton = null
#the rectangle-selected walls: a row of buttons, shown instead of a single unit's card
var wall_group_row : HBoxContainer = null

var horizontal_stat_fields : Array[HorizontalStatField] :
	get:
		if not horizontal_stat_fields.is_empty():
			return horizontal_stat_fields
		for child in unit_info_grid_container.get_children():
			if child is HorizontalStatField:
				horizontal_stat_fields.append(child)
		return horizontal_stat_fields

var listed_stat_enums : Array[Utils.StatType] = [
	Utils.StatType.Health, 
	Utils.StatType.Damage, 
	Utils.StatType.AttackSpeed, 
	#also shows the critical multiplier
	Utils.StatType.CriticalChance,
	Utils.StatType.AttackRange,
	Utils.StatType.Price]


func _ready() -> void:
	hide()
	unit_info_grid_container.hide()
	unit_icon.hide()
	sell_button.hide()
	button_row.hide()
	UISignals.selected_unit.connect(_on_unit_selected)
	UISignals.deselected_unit.connect(_on_unit_deselected)
	UISignals.gold_upgrades_changed.connect(_on_gold_upgrades_changed)
	#an enemy's resistances under its stats; the UI signal carries no unit, the gameplay one does
	resists_label = Label.new()
	resists_label.add_theme_color_override(&"font_color", RESISTS_COLOR)
	resists_label.hide()
	unit_info_grid_container.add_sibling(resists_label)
	GameSignals.selected_unit.connect(_on_selected_unit_node)
	_create_tactic_menu()
	resists_label.add_sibling(tactic_row)
	UISignals.target_tactic_changed.connect(_on_target_tactic_changed)
	wall_group_row = HBoxContainer.new()
	wall_group_row.hide()
	button_row.add_sibling(wall_group_row)
	UISignals.wall_group_changed.connect(_on_wall_group_changed)


func _on_wall_group_changed(title : String, options : Array[GoldUpgradeOption]) -> void:
	for child in wall_group_row.get_children():
		child.queue_free()
	if title.is_empty():
		wall_group_row.hide()
		if unit_icon.texture == null:
			hide()
		return
	show()
	unit_info_grid_container.hide()
	unit_icon.hide()
	button_row.hide()
	name_value.text = title
	var sell : Button = Button.new()
	sell.text = WallGroupSelect.SELL_TITLE
	sell.add_theme_font_size_override(&"font_size", UPGRADE_BUTTON_FONT_SIZE)
	sell.pressed.connect(func() -> void: UISignals.wall_group_action.emit(WallGroupSelect.SELL_ACTION))
	wall_group_row.add_child(sell)
	for index in options.size():
		var button : Button = _create_upgrade_button(options[index], index)
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
		button.pressed.connect(func() -> void: UISignals.wall_group_action.emit(index))
		wall_group_row.add_child(button)
	wall_group_row.show()
	_fit_to_corner.call_deferred()


func _create_tactic_menu() -> void:
	tactic_row = HBoxContainer.new()
	tactic_row.tooltip_text = TACTIC_TOOLTIP
	tactic_row.hide()
	var label : Label = Label.new()
	label.text = TACTIC_LABEL_TEXT
	tactic_row.add_child(label)
	tactic_menu = OptionButton.new()
	tactic_menu.add_theme_font_size_override(&"font_size", UPGRADE_BUTTON_FONT_SIZE)
	tactic_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tactic_menu.tooltip_text = TACTIC_TOOLTIP
	#in the menu's order, each item's id is its tactic
	for tactic in TargetPicker.MENU_ORDER:
		tactic_menu.add_item(TargetPicker.TACTIC_NAMES[tactic], tactic)
		tactic_menu.set_item_tooltip(tactic_menu.item_count - 1, TargetPicker.TACTIC_TOOLTIPS[tactic])
	tactic_menu.get_popup().add_theme_font_size_override(&"font_size", UPGRADE_BUTTON_FONT_SIZE)
	tactic_menu.item_selected.connect(func(index : int) -> void:
		UISignals.target_tactic_selected.emit(tactic_menu.get_item_id(index) as Utils.TargetTactic))
	tactic_row.add_child(tactic_menu)


func _on_target_tactic_changed(tactic : int) -> void:
	tactic_row.visible = tactic >= 0
	if tactic >= 0:
		#select() does not emit item_selected, so showing a tower's tactic never sets it again
		tactic_menu.select(tactic_menu.get_item_index(tactic))
	_fit_to_corner.call_deferred()


func _on_selected_unit_node(unit : Node2D) -> void:
	var summary : String = unit.resistances.get_summary() if unit is Enemy and unit.resistances != null else ""
	resists_label.text = RESISTS_TEXT % summary
	resists_label.visible = not summary.is_empty()


func _on_unit_selected(unit_name : String, actor_stats : Stats, main_skill : Skill, icon : Texture2D, _is_building : bool = false) -> void:
	show()
	wall_group_row.hide()
	unit_info_grid_container.show()
	unit_icon.show()
	unit_icon.texture = icon
	name_value.text = unit_name
	
	var index : int = 0
	for field in horizontal_stat_fields:
		field.set_field(listed_stat_enums[index],actor_stats, main_skill)
		index += 1
		
	sell_button.visible = _is_building
	_update_button_row()


func _on_unit_deselected() -> void:
	unit_icon.texture = null
	name_value.text = ""
	#nulls the stat fields
	for field in horizontal_stat_fields:
		field.set_field()
	unit_info_grid_container.hide()
	unit_icon.hide()
	sell_button.visible = false
	resists_label.hide()
	tactic_row.hide()
	hide()


func _on_sell_button_pressed() -> void:
	UISignals.on_sell_selected_building_pressed.emit()


func _on_gold_upgrades_changed(options : Array[GoldUpgradeOption]) -> void:
	for child in upgrade_option_container.get_children():
		upgrade_option_container.remove_child(child)
		child.queue_free()
	
	for index in options.size():
		upgrade_option_container.add_child(_create_upgrade_button(options[index], index))

	_update_button_row()


func _update_button_row() -> void:
	button_row.visible = sell_button.visible or upgrade_option_container.get_child_count() > 0
	_fit_to_corner.call_deferred()


## Shrinks to the content and keeps the bottom-left corner in place; resizing alone keeps
## the top edge, so a shorter card would float up. Deferred so new buttons have their size.
func _fit_to_corner() -> void:
	reset_size()
	position.y = get_parent_area_size().y - size.y - CORNER_MARGIN


func _create_upgrade_button(option : GoldUpgradeOption, index : int) -> Button:
	var button : Button = Button.new()
	button.theme = sell_button.theme
	button.custom_minimum_size = EVOLVE_BUTTON_MIN_SIZE if option.icon != null else UPGRADE_BUTTON_MIN_SIZE
	#an evolve button shows only its price: it grows to fit it (T2 and T3 cost two digits), never cut
	#(a button with an overrun mode leaves its text out of its minimum width)
	button.clip_text = option.icon == null
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if button.clip_text else TextServer.OVERRUN_NO_TRIMMING
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", UPGRADE_BUTTON_FONT_SIZE)
	button.add_theme_constant_override("icon_max_width", UPGRADE_BUTTON_ICON_SIZE)
	button.icon = LOCKED_ICON if option.is_locked else option.icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.text = EVOLVE_BUTTON_TEXT % option.cost if option.icon != null else UPGRADE_BUTTON_TEXT % [option.title, option.cost]
	button.tooltip_text = option.title
	button.disabled = not option.is_affordable
	button.pressed.connect(_on_upgrade_button_pressed.bind(index))
	return button


func _on_upgrade_button_pressed(index : int) -> void:
	UISignals.gold_upgrade_pressed.emit(index)
