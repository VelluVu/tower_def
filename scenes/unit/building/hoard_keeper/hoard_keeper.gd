class_name HoardKeeper
extends Building

## The Hoard Keeper (2026-11-25, design doc "Second round of towers"): a drakeling on a coin pile that never attacks.
## After every cleared wave it pays gold: BASE_PAY plus PAY_PER_STEP for each upgrade, element and tier bought on it.
## Only the first FULL_PAY_KEEPERS on the map (by when they were placed) pay in full, the others PARTIAL_SHARE of it,
## so a field of Keepers never feeds the late-game gold snowball (the user: a small pay).

const BASE_PAY : float = 2.0
const PAY_PER_STEP : float = 1.0
const FULL_PAY_KEEPERS : int = 2
const PARTIAL_SHARE : float = 0.5
const PAY_ANIMATION : StringName = &"PAY"


func _ready() -> void:
	super()
	if not GameSignals.wave_cleared.is_connected(_on_wave_cleared):
		GameSignals.wave_cleared.connect(_on_wave_cleared)


## What this Keeper pays at the next cleared wave.
func get_pay() -> float:
	var level : Level = Utils.game_control.scene_manager.current_level if Utils.game_control != null else null
	if level == null:
		return BASE_PAY
	var steps : int = level.building_type_upgrades.get_upgrade_steps(self) if level.building_type_upgrades != null else 0
	var pay : float = BASE_PAY + PAY_PER_STEP * steps
	return pay if get_rank(level) < FULL_PAY_KEEPERS else floorf(pay * PARTIAL_SHARE)


## 0 for the Keeper placed first, then 1, ...: the order of the level's building list.
func get_rank(level : Level) -> int:
	var rank : int = 0
	for building in level.all_buildings:
		if building == self:
			return rank
		if is_instance_valid(building) and building is HoardKeeper and building.is_placed:
			rank += 1
	return rank


func _on_wave_cleared(_wave_number : int) -> void:
	if not is_placed or is_dead:
		return
	var level : Level = Utils.game_control.scene_manager.current_level
	if level == null or level.player_stats == null:
		return
	level.player_stats.add_gold(get_pay())
	if animation_control.sprite_frames.has_animation(PAY_ANIMATION):
		animation_control.play(PAY_ANIMATION)
		await animation_control.animation_finished
		if is_instance_valid(self) and not is_dead:
			animation_control.play(GlobalAnimationNames.IDLE_ANIMATION)
