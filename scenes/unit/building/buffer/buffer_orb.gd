class_name BufferOrb
extends Node2D

## A Buffer's throw made visible (2026-11-26): a small orb in its element's colour arcs from the Buffer to the tower it
## buffs, then is gone. Only the look: the buff is held from the moment of the throw (BufferAuras.throw_from).

const FLIGHT_SECONDS : float = 0.35
const ARC_HEIGHT : float = 10.0
const ORB_SIZE : float = 3.0
#where on the buildings the orb leaves and lands (their upper body)
const BODY_OFFSET : Vector2 = Vector2(0, -10)
#Endesga 32: mint for a Buffer without an element, light rims for the element ones
const NO_ELEMENT_COLOR : Color = Color("a2f6db")
const RIM_COLOR : Color = Color("ffffff")

var from_position : Vector2 = Vector2.ZERO
var to_position : Vector2 = Vector2.ZERO
var progress : float = 0.0 :
	set = _set_progress
var color : Color = NO_ELEMENT_COLOR


static func fly(buffer : Buffer, target : Building) -> void:
	if buffer.level == null or not buffer.is_inside_tree():
		return
	var orb : BufferOrb = BufferOrb.new()
	orb.from_position = buffer.global_position + BODY_OFFSET
	orb.to_position = target.global_position + BODY_OFFSET
	orb.color = _element_color(buffer.element)
	orb.z_index = 10
	buffer.level.add_child(orb)
	orb.global_position = orb.from_position
	var tween : Tween = orb.create_tween()
	#the game speed is done by hand (CustomTimer elsewhere): the orb keeps pace with it
	tween.set_speed_scale(Utils.game_control.time_scale if Utils.game_control != null else 1.0)
	tween.tween_property(orb, "progress", 1.0, FLIGHT_SECONDS)
	tween.tween_callback(orb.queue_free)


static func _element_color(element : Utils.Element) -> Color:
	match element:
		Utils.Element.Fire:
			return Utils.get_damage_type_color(Utils.DamageType.Fire)
		Utils.Element.Frost:
			return Utils.get_damage_type_color(Utils.DamageType.Frost)
		Utils.Element.Poison:
			return Utils.get_damage_type_color(Utils.DamageType.Poison)
		Utils.Element.Physical:
			return Utils.get_damage_type_color(Utils.DamageType.Physical)
	return NO_ELEMENT_COLOR


func _set_progress(value : float) -> void:
	progress = value
	#a low arc, on whole pixels like every unit
	var at : Vector2 = from_position.lerp(to_position, progress) + Vector2.UP * ARC_HEIGHT * sin(progress * PI)
	global_position = at.round()


func _draw() -> void:
	var half : float = ORB_SIZE * 0.5
	draw_rect(Rect2(-half - 1.0, -half - 1.0, ORB_SIZE + 2.0, ORB_SIZE + 2.0), color.darkened(0.5))
	draw_rect(Rect2(-half, -half, ORB_SIZE, ORB_SIZE), color)
	draw_rect(Rect2(-half, -half, 1.0, 1.0), RIM_COLOR)
