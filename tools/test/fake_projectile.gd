extends Node2D

## A projectile stand-in for tests: records the damage of each launch instead of flying.
## TestKit's Main is not in the tree, so real projectiles never run there.

signal finished(node : Node2D)

static var launched_damage : Array[float] = []

var is_old : bool = false


func launch(skill_data : SkillData) -> void:
	launched_damage.append(skill_data.damage_data.damage)


func clear() -> void:
	queue_free()


static func packed() -> PackedScene:
	var node : Node2D = Node2D.new()
	node.set_script(load("res://tools/test/fake_projectile.gd"))
	var scene : PackedScene = PackedScene.new()
	scene.pack(node)
	node.free()
	return scene
