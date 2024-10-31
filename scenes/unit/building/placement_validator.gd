class_name PlacementValidator
extends Area2D


@onready var collider : CollisionShape2D = $CollisionShape2D

var bodies : Array[Node]
var is_valid : bool = false :
	get:
		return bodies.is_empty()


func activate(state : bool) -> void:
	collider.disabled = not state
	monitorable = state
	monitoring = state


func _on_body_entered(body: Node2D) -> void:
	if bodies.has(body):
		return
	
	bodies.append(body)


func _on_body_exited(body: Node2D) -> void:
	if not bodies.has(body):
		return
	
	bodies.erase(body)
