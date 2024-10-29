extends Node

signal mouse_on_gui()

signal building_option_deselected(index : int)
signal building_option_selected(index : int)
signal focus_building_option(building_index : int)
signal on_sell_selected_building_pressed()
signal buildings_updated(available_buildings : int)
signal building_option_updated(building_index : int, new_icon : Texture2D)

signal selected_unit(unit_name : String, stats : Stats, icon : Texture2D, is_placed_by_player : bool)
signal deselected_unit(unit_name : String, stats : Stats, icon : Texture2D, is_placed_by_player : bool)

signal game_play_interface_loaded()
signal continue_next_level_pressed()
signal start_level_button_pressed(level_number : int)
signal start_game()
signal options()
signal continue_from_pause_menu()
signal continue_last_save()
signal resign_level()
signal to_menu(to_main_menu : bool, from_scene_name : String)
signal slower_speed_pressed()
signal faster_speed_pressed()
