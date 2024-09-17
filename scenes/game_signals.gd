extends Node


signal building_destroyed(building : Building)
signal building_placed(building : Building)
signal navigation_rebaked()
signal astar_grid_updated()
signal enemy_reached_end_point(enemy : Enemy)
signal enemy_destroyed(enemy : Enemy)
signal resource_change(new_value : int, resource_index : int)
signal lose_game()
