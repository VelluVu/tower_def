class_name UpgradePips
extends Node2D

## Code-drawn placeholder for the upgrade step visuals: one pip per evolve tier in the element
## color, then one pip per upgrade bought since the last tier, in rows under the building.
## BuildingTypeUpgrades adds it to a building on the first purchase and updates it.

const PIP_SIZE : Vector2 = Vector2(2, 2)
const PIP_GAP : float = 1.0
const PIPS_PER_ROW : int = 5
const OUTLINE_WIDTH : float = 1.0
#bottom edge of the 16 px tile, the building origin is the tile center
const BOTTOM_OFFSET : Vector2 = Vector2(0, 6)

#gold, so it stays apart from the white Physical tier pip
@export var upgrade_color : Color = Color(1.0, 0.8, 0.3)
@export var outline_color : Color = Color(0.1, 0.08, 0.1, 0.9)
#tier pips get a light ring, so a red Fire pip still reads on the red Fire tower
@export var tier_outline_color : Color = Color(1.0, 1.0, 1.0, 0.95)

var upgrade_count : int = 0
var tier_count : int = 0
var tier_color : Color = Color.WHITE


func set_steps(upgrades : int, tiers : int, _tier_color : Color) -> void:
	if upgrades == upgrade_count and tiers == tier_count and _tier_color == tier_color:
		return

	upgrade_count = upgrades
	tier_count = tiers
	tier_color = _tier_color
	queue_redraw()


func _draw() -> void:
	var colors : Array[Color] = []
	var outlines : Array[Color] = []

	for i in tier_count:
		colors.append(tier_color)
		outlines.append(tier_outline_color)

	for i in upgrade_count:
		colors.append(upgrade_color)
		outlines.append(outline_color)

	for index in colors.size():
		var row : int = floori(index / float(PIPS_PER_ROW))
		var pips_in_row : int = mini(PIPS_PER_ROW, colors.size() - row * PIPS_PER_ROW)
		var row_width : float = pips_in_row * PIP_SIZE.x + (pips_in_row - 1) * PIP_GAP
		var column : int = index % PIPS_PER_ROW
		#rows stack upwards from the bottom edge, so the first row is the lowest
		var offset : Vector2 = Vector2(
			-row_width * 0.5 + column * (PIP_SIZE.x + PIP_GAP),
			-row * (PIP_SIZE.y + PIP_GAP))
		var rect : Rect2 = Rect2((BOTTOM_OFFSET + offset).round(), PIP_SIZE)
		draw_rect(rect.grow(OUTLINE_WIDTH), outlines[index])
		draw_rect(rect, colors[index])
