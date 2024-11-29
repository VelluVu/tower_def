class_name ModifierData
extends RefCounted


var type : Utils.ModifyType = Utils.ModifyType.Multiply
var stat : Utils.StatType = Utils.StatType.Speed
var value : float = 0.1


func _init(modifier : Modifier = null) -> void:
	if modifier == null:
		return

	type = modifier.type
	stat = modifier.stat
	value = modifier.value
