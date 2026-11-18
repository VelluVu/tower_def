class_name UpgradeCard
extends RefCounted

## One level-up offer: an EvolveResource with its own rolled value.

const SOFT_CAP_TEXT : String = "\n(soft cap: half)"

var resource : EvolveResource = null
var value : float = 0.0
#a building the card fits is already past the stat's soft cap, so the card counts at half there
var is_past_soft_cap : bool = false

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
	var cap_text : String = SOFT_CAP_TEXT if is_past_soft_cap else ""

	if not resource.description.is_empty():
		var shown_value : float = value * 100.0 if resource.is_percent else value
		return "%s\n%s%s" % [title, resource.description.format({"value": _format_number(shown_value)}), cap_text]

	#a trade-off card names both stats: "Overcharge\n+30% Damage\n-20% Attack Range"
	if resource.has_drawback:
		return "%s\n%s %s\n%s %s%s" % [title, _format_value(value, resource.modify_type, resource.is_percent), _stat_name(resource.modify_stat_type),
			_format_value(resource.drawback_value, resource.drawback_modify_type, resource.drawback_is_percent), _stat_name(resource.drawback_stat_type), cap_text]

	return "%s %s%s" % [title, _format_value(value, resource.modify_type, resource.is_percent), cap_text]


static func _format_value(shown_value : float, modify_type : Utils.ModifyType, is_percent : bool) -> String:
	var sign_text : String = "-" if shown_value < 0.0 else "+"

	if is_percent:
		if modify_type == Utils.ModifyType.Multiply:
			sign_text = "×"
		return "%s%s%%" % [sign_text, _format_number(absf(shown_value) * 100.0)]

	return "%s%s" % [sign_text, _format_number(absf(shown_value))]


static func _stat_name(stat_type : Utils.StatType) -> String:
	return String(Utils.StatType.keys()[stat_type]).capitalize()


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
