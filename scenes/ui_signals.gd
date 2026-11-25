extends Node

signal mouse_on_gui()
## Asks GameCursor for a cursor mode (GameCursor.Mode) on behalf of `source`; POINTER lets go of it.
signal cursor_mode_requested(source : StringName, mode : int)

signal building_option_deselected(index : int)
signal building_option_selected(index : int)
signal focus_building_option(building_index : int)
signal on_sell_selected_building_pressed()
signal buildings_updated(available_buildings : int)
signal building_option_updated(building_index : int, new_icon : Texture2D)
#the tray slot's tooltip: name, key, cost and what it does
signal building_option_tooltip(building_index : int, text : String)
## What a tray slot's building costs now (its base price plus the tower price step).
signal building_option_price(building_index : int, price : float)
signal upgrade_card_selected(index : int)
signal gold_upgrades_changed(options : Array[GoldUpgradeOption])
signal gold_upgrade_pressed(index : int)
## A tactic picked in the selected tower's Target menu (Utils.TargetTactic); works during a wave too.
signal target_tactic_selected(tactic : Utils.TargetTactic)
## The selected tower's tactic (Utils.TargetTactic); -1 when the selection has none (the menu hides).
signal target_tactic_changed(tactic : int)
## Whether the selection is a placed Hatchery, whose card shows the Rally button.
signal rally_shown(is_shown : bool)
## The Rally button: the selected Hatchery waits for a click on its new rally cell.
signal rally_pressed()
## A rectangle-selected group of walls (WallGroupSelect): its title (empty = none) and the element options for its plain walls.
signal wall_group_changed(title : String, options : Array[GoldUpgradeOption])
## A button of the wall group: -1 sells them all, 0 and up buys that element option.
signal wall_group_action(index : int)

signal selected_unit(unit_name : String, stats : Stats, skill : Skill, icon : Texture2D, is_building : bool)
signal deselected_unit()

signal game_play_interface_loaded()
signal continue_next_level_pressed()
signal retry_level_pressed()
signal start_level_button_pressed(level_number : int, mode : Utils.LevelMode)
signal start_game()
signal options()
signal continue_from_pause_menu()
signal continue_last_save()
signal resign_level()
signal to_menu(to_main_menu : bool, from_scene_name : String)
signal talents(is_open : bool)
signal slower_speed_pressed()
signal faster_speed_pressed()
signal start_wave_pressed()
## The mouse went onto a level-up card (a hover sound).
signal upgrade_card_hovered()
