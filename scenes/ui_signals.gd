extends Node


signal building_option_deselected(index : int)
signal building_option_selected(index : int)
signal focus_building_option(building_index : int)
signal mouse_on_gui()
signal game_play_interface_loaded()
signal selected_unit(unit_name : String, stats : Stats, icon : Texture2D, is_placed_by_player : bool)
signal deselected_unit(unit_name : String, stats : Stats, icon : Texture2D, is_placed_by_player : bool)
signal on_sell_selected_building_pressed()
