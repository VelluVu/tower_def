class_name Spawner
extends Node2D

#a spawn point, the level's WaveRunner tells it what to spawn

const NO_SPAWNABLE_SCENE_WARNING : String = " There are no spawnable scene!"
const SPAWN_GROUP_RUNNER_NAME : String = "SpawnGroupRunner"

@export var id : int = 0
@export var end_point : Marker2D
#the flyers' route: they fly through its points in order, then to the end point; none = straight
#to the end point. Lead it over the best maze spots, or around them on frustrating maps
@export var flight_route : Path2D
#the spawn point's look is the Art sprite's frames, set in the spawn_points/ scenes (cave, den, hollow,
#roost) so the editor shows it too; a plain Spawner has none and shows only the path preview marker
@onready var art_sprite : AnimatedSprite2D = $Art


func _ready() -> void:
	if not is_in_group(GroupNames.SPAWNER):
		add_to_group(GroupNames.SPAWNER)
	_play_art()


#the cells the art covers, without the mouth (this spawner's own cell, the art's bottom middle);
#Level reserves them so nothing walks or builds under the cave
func get_footprint_cells(grid : LevelGrid) -> Array[Vector2i]:
	var cells : Array[Vector2i] = []
	var frames : SpriteFrames = art_sprite.sprite_frames
	if frames == null or not frames.has_animation(GlobalAnimationNames.IDLE_ANIMATION):
		return cells

	var size : Vector2i = Vector2i((frames.get_frame_texture(GlobalAnimationNames.IDLE_ANIMATION, 0).get_size() / Utils.TILE_SIZE).round())
	var mouth : Vector2i = grid.world_position_to_grid(global_position)
	var left : int = mouth.x - (size.x >> 1)
	for y in range(mouth.y - size.y + 1, mouth.y + 1):
		for x in range(left, left + size.x):
			if Vector2i(x, y) != mouth:
				cells.append(Vector2i(x, y))
	return cells


#each spawner starts on a random frame, so neighbouring caves do not blink together
func _play_art() -> void:
	var frames : SpriteFrames = art_sprite.sprite_frames
	if frames == null or not frames.has_animation(GlobalAnimationNames.IDLE_ANIMATION):
		return

	art_sprite.play(GlobalAnimationNames.IDLE_ANIMATION)
	art_sprite.frame = randi() % frames.get_frame_count(GlobalAnimationNames.IDLE_ANIMATION)


#on_finished is connected before the first spawn, so a group without delay still reports back
func spawn_group(group : SpawnGroupData, on_finished : Callable) -> void:
	var runner : SpawnGroupRunner = SpawnGroupRunner.new()
	runner.name = SPAWN_GROUP_RUNNER_NAME
	add_child(runner, true)
	runner.group_finished.connect(on_finished)
	runner.run(group, self)


func spawn(spawnable_packed_scene : PackedScene) -> void:
	if spawnable_packed_scene == null:
		push_warning(name, NO_SPAWNABLE_SCENE_WARNING)
		return

	var spawned : Node = spawnable_packed_scene.instantiate()

	if spawned is Enemy:
		spawned.end_point = end_point
		_give_flight_route(spawned)

	add_child(spawned)


#before the enemy enters the tree, so its first path already has the route
func _give_flight_route(enemy : Enemy) -> void:
	if flight_route == null or flight_route.curve == null:
		return

	for child in enemy.get_children():
		if child is FlightMovement:
			child.route_points = get_flight_route_points()


func get_flight_route_points() -> PackedVector2Array:
	var points : PackedVector2Array = []
	if flight_route == null or flight_route.curve == null:
		return points

	for i in flight_route.curve.point_count:
		points.append(flight_route.to_global(flight_route.curve.get_point_position(i)))
	return points
