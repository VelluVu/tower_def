extends Node


signal building_destroyed(building : Building)
signal building_placed(building : Building)
signal building_is_removed()
signal sell_building(building : Building)
signal building_placement_change(is_placing : bool)

signal enemy_reached_end_point(enemy : Enemy)
signal enemy_destroyed(enemy : Enemy)
signal enemy_spawned(enemy : Enemy)
signal damage_taken(position : Vector2, damage_data : DamageData)
#an enemy took a hit (after its effects were added); element reactions listen to it
signal enemy_hit(enemy : Enemy, damage_data : DamageData)
signal element_reaction(position : Vector2, reaction : ElementReaction)
#every attack of a tower, trap or enemy; the audio plays skill.activate_sound
signal skill_activated(skill : Skill)

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

#early_start_bonus is what starting the next wave now would pay, 0 during a break
signal wave_state_changed(wave_number : int, wave_count : int, can_start_next : bool, early_start_bonus : float)
signal wave_cleared(wave_number : int)

signal upgrade_xp_changed(xp : float, xp_needed : float, upgrade_level : int)
signal upgrade_level_gained(new_level : int, cards : Array[UpgradeCard])
signal upgrade_cards_closed()
signal gold_upgrade_bought(building : Building, is_evolve : bool)

signal developer_mode_changed(is_enabled : bool)

#turned on from the console (gitignored cheat set), never saved
var developer_mode : bool = false :
	set = _set_developer_mode
#buildings and upgrades cost nothing; only while developer mode is on
var free_build : bool = false


func _set_developer_mode(value : bool) -> void:
	if value == developer_mode:
		return

	developer_mode = value

	if not developer_mode:
		free_build = false

	developer_mode_changed.emit(developer_mode)
