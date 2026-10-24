class_name SkillData
extends RefCounted


var max_range : float = 0.0
var active_time : float = 0.0
var target : Node2D = null
#owned: a Skill.damage_data copy, freed with this data once the last projectile lets go of it
var damage_data : DamageData = null


func _notification(what : int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(damage_data):
		damage_data.queue_free()
