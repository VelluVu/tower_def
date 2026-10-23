class_name UpgradeCard
extends RefCounted

## One level-up offer: an EvolveResource with its own rolled value.

var resource : EvolveResource = null
var value : float = 0.0

var icon : Texture2D = null
var title : String = ""

static func from_resource(_resource : EvolveResource, rolled_value : float) -> UpgradeCard:
	var card : UpgradeCard = UpgradeCard.new()
	card.resource = _resource
	card.value = rolled_value
	card.icon = _resource.evolve_icon
	card.title = _resource.evolve_name
	return card


#"+" adds to the other percent bonuses, "×" multiplies on top of them
func get_text() -> String:
	if resource.is_percent:
		var sign : String = "×" if resource.modify_type == Utils.ModifyType.Multiply else "+"
		return "%s %s%s%%" % [title, sign, _format_number(value * 100.0)]

	return "%s +%s" % [title, _format_number(value)]


#"30" instead of "30.0", "0.25" stays
static func _format_number(number : float) -> String:
	var text : String = String.num(number, 2)

	if text.contains("."):
		text = text.rstrip("0").rstrip(".")

	return text


func get_modifier_data() -> ModifierData:
	var modifier_data : ModifierData = resource.get_modifier_data()
	modifier_data.value = value
	return modifier_data
