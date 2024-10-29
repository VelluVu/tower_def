extends Node


signal building_destroyed(building : Building)
signal building_placed(building : Building)
signal building_is_removed()
signal sell_building(building : Building)
signal building_placement_change(is_placing : bool)

signal enemy_reached_end_point(enemy : Enemy)
signal enemy_destroyed(enemy : Enemy)
signal enemy_spawned(enemy : Enemy)

signal selected_unit(unit : Node2D)
signal deselected_unit(unit : Node2D)
signal forced_selection(unit : Node2D)
signal building_is_placing(unit : Node2D)

signal resource_change(new_value : int, resource_index : int)

signal navigation_rebaked()
signal astar_grid_updated()

signal lose_game()
signal time_scale_change(new_time_scale : float)
signal game_stop()
signal game_pause(is_paused : bool)

signal level_loaded(level : Level)
signal level_completed(level : Level)

var testing : bool = true
