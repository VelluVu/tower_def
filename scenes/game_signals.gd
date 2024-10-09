extends Node


signal building_destroyed(building : Building)
signal building_placed(building : Building)
signal building_is_removed()
signal navigation_rebaked()
signal astar_grid_updated()
signal enemy_reached_end_point(enemy : Enemy)
signal enemy_destroyed(enemy : Enemy)
signal enemy_spawned(enemy : Enemy)
signal resource_change(new_value : int, resource_index : int)
signal lose_game()
signal building_placement_change(is_placing : bool)
signal selected_unit(unit : Node2D)
signal deselected_unit(unit : Node2D)
signal enemy_path_blocked_change(is_blocked : bool)
signal sell_building(building : Building)
