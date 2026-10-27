extends RefCounted

## Dragged wall lines: the route check counts the planned ghost walls and leaves the grid as it was.

const MAX_PLANNED : int = 200


func test_planned_walls_close_a_route(kit : TestKit) -> void:
	await kit.load_level(1)
	var grid : LevelGrid = kit.level.grid
	var routes : Array[PackedVector2Array] = kit.level.get_routes()
	var route : PackedVector2Array = routes[0]
	var weight : float = 100.0
	kit.check(grid.is_route_open(route[0], route[1]), "the route starts open")

	#plan walls on the route's path until the next one would close it
	var planned : Array[Vector2i] = []
	var closing_cell : Vector2i = Vector2i.MAX

	while planned.size() < MAX_PLANNED and closing_cell == Vector2i.MAX:
		var cell : Vector2i = _next_buildable_path_cell(grid, route, planned, weight)
		if cell == Vector2i.MAX:
			break
		if grid.would_close_route(cell, weight, routes, planned):
			closing_cell = cell
		else:
			planned.append(cell)

	kit.check(closing_cell != Vector2i.MAX, "a planned line can close the route (%d walls planned)" % planned.size())
	kit.check(grid.is_route_open(route[0], route[1]), "checking leaves the grid as it was")

	for cell in planned:
		grid.set_cell_weight(cell, weight)
	kit.check(grid.is_route_open(route[0], route[1]), "the planned walls alone keep it open")
	kit.check(grid.would_close_route(closing_cell, weight, routes), "the built walls agree with the plan")

	grid.set_cell_weight(closing_cell, weight)
	kit.check(not grid.is_route_open(route[0], route[1]), "the closing wall closes it")
	kit.check(not grid.would_close_route(closing_cell, weight, routes, []), "a closed route is never held back")


#the first buildable cell on the path, with the planned cells weighted like walls while it looks
func _next_buildable_path_cell(grid : LevelGrid, route : PackedVector2Array, planned : Array[Vector2i], weight : float) -> Vector2i:
	for cell in planned:
		grid.set_cell_weight(cell, weight)
	var path : PackedVector2Array = grid.find_path(route[0], route[1])
	for cell in planned:
		grid.set_cell_weight(cell, 1.0)

	for i in range(1, path.size() - 1):
		var cell : Vector2i = grid.world_position_to_grid(path[i])
		if not planned.has(cell) and grid.is_position_buildable(path[i]):
			return cell

	return Vector2i.MAX
