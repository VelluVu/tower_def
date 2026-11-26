class_name Enemy
extends RigidBody2D


const GRID_UPDATE_ERROR : String = ", level is still initializing, unable to react to grid update"
const END_POINT_PATHING_ERROR : String = " can't path to the end point distance: "
const MODULATE_ALPHA_PROPERTY : String = "modulate:a"
#a frozen enemy looks iced over
const FROZEN_TINT : Color = Color(0.6, 0.85, 1.0)
const CORPSE_FADE_TIME : float = 1.0
const NO_FREE_POSITION_WARNING : String = " unable to find free position, destroying building in the way."
#a short stop after every turn, so twisting mazes cost time
const TURN_PAUSE_TIME : float = 0.1
#directions closer than this (cosine) count as straight on: about 60 degrees
const TURN_DOT_LIMIT : float = 0.5

@onready var collider : CollisionShape2D = $CollisionShape2D
@onready var animation_control : AnimationControl = $AnimatedSprite2D
@onready var hit_box : Area2D = $Hitbox
@onready var gore_emitter : GoreEmitter = $GoreEmitter
@onready var selectable : SelectableUnit = $SelectableUnit
@onready var pop_up_spot : Node2D = $PopUpSpot
#only flyers carry one, see FlightMovement
@onready var flight_movement : FlightMovement = Utils.find_child_of_type(self, FlightMovement)

@onready var modifier_manager : ModifierManager = $ModifierManager :
	get:
		if modifier_manager == null:
			modifier_manager = $ModifierManager
		return modifier_manager 

@onready var overtime_effect_handler : OvertimeEffectHandler = $OvertimeEffectHandler :
	get:
		if overtime_effect_handler == null:
			overtime_effect_handler = $OvertimeEffectHandler
		return overtime_effect_handler

@onready var stats : Stats = $Stats :
	get:
		if stats == null:
			stats = $Stats
		return stats

@export var icon : Texture2D = null
#kill XP is 2 per max health times this; below 1 for enemies that come in big groups
@export var xp_multiplier : float = 1.0
#shows the boss health bar while alive
@export var is_boss : bool = false
## A boss's line under its name on the intro card (BossIntro).
@export var boss_title : String = ""
#takes a level's bog crossings when they are cheaper than the road (the toad, the leech)
@export var can_wade : bool = false
#the faction role's resistances (scenes/unit/enemy/resistances/); none = takes every hit in full
@export var resistances : EnemyResistances = null
## A Hatchery guard can stop it (the battering ram and the wall crawler go past).
@export var can_be_held : bool = true
## What a wall's cell costs on its path instead of the building weight (0 = the same as every building): the ram
## would rather break through a wall than walk the maze, the wall crawler climbs them (WallClimber).
@export var wall_path_weight : float = 0.0
## Runs under traps: the Leopard Trap and the Egg Bomb never fire on it, nor catch it in their blast (tunnel rats).
@export var ignores_traps : bool = false

@export var skill : Skill :
	get:
		if skill == null:
			skill = Utils.find_child_of_type(self, Skill)
		return skill

var beehave_tree : BeehaveTree :
	get:
		if beehave_tree == null:
			beehave_tree = Utils.find_child_of_type(self, BeehaveTree)
		return beehave_tree

#only enemies with abilities (bosses, egg sacs) carry one
var abilities : EnemyAbilities :
	get:
		if abilities == null:
			abilities = Utils.find_child_of_type(self, EnemyAbilities)
		return abilities

var is_colliding_building : bool = false :
	get:
		return collision_body != null

#ignores the grid, the maze, slow ground and buildings, and traps skip it
var is_flying : bool :
	get:
		return flight_movement != null

#on a bog crossing's stones, heading for its far shore
var is_wading : bool :
	get:
		return wade_crossing != null and wade_exit_index >= 0 and current_waypoint_index == wade_exit_index

var is_deactivated : bool = false
#underground (Broodmother's Dig Up): out of every tower's reach
var is_burrowed : bool = false
#a flyer hidden in a sandstorm (Sandstorm): towers cannot pick it
var is_concealed : bool = false
#an ember cultist's ward: soaks the next hit (FireWard)
var fire_ward : FireWard = null
#walks over walls instead of attacking them (WallClimber sets it)
var climbs_walls : bool = false
#under the water (Submerged): only area towers reach it (Nova, Mortar, Breather; traps)
var is_submerged : bool = false
#faded out (PhaseShift): no tower picks it and no direct hit lands; damage over time still ticks
var is_phased : bool = false
#near a standard bearer (SteadfastAura): no freezes, and slows do nothing
var is_steadfast : bool = false
#played while it moves; the Ashen Wyrm walks differently once it has landed
var walk_animation : String = GlobalAnimationNames.WALK_ANIMATION
#false for an enemy gone without a kill (a hatched egg sac): no gold or XP
var gives_reward : bool = true
#Frostplague, steam: cannot attack buildings while true (add_numb, remove_numb)
var is_numb : bool = false :
	get = _get_is_numb
#numbs on it now: two at once end only when both have
var numb_count : int = 0
#held where it is (a harpoon's chain on a boss flyer, HarpoonTether): no moving, bosses too
var is_held : bool = false
#share of the damage it takes (the Dragonslayer's oath halves it)
var damage_taken_factor : float = 1.0
## The Hatchery guard holding it (HatcheryGuard sets and clears it): it stands and fights the guard. Never a boss or a
## flyer. Untyped: a guard freed with its Hatchery must reach the is_instance_valid checks.
var held_by = null
#a freeze from a frost tower: no moving until it runs out
var freeze_timer : CustomTimer = null
var is_frozen : bool :
	get:
		return freeze_timer != null and not freeze_timer.is_stopped()
#the waypoint index of a bog crossing's far shore in point_path (-1: the path has no crossing)
var wade_exit_index : int = -1
var wade_crossing : BogCrossing = null
var current_waypoint_index : int = 0
var minimum_distance_to_end : float = 9.0
var minimum_distance_to_next_waypoint : float = 2.0
var current_time_scale : float = 1.0
var velocity : Vector2 = Vector2.ZERO
var last_position : Vector2 = Vector2.ZERO
var next_waypoint : Vector2 = Vector2.ZERO
var lane_offset : Vector2 = Vector2.ZERO
var collision_body : Node = null
var end_point : Marker2D = null
var point_path : PackedVector2Array
#LevelGrid.get_move_speed_factor of the cell the enemy last stood in
var cell_speed_factor : float = 1.0
var cell_speed_factor_cell : Vector2i = Vector2i.MAX
var turn_pause_timer : CustomTimer = null

var level : Level = null :
	get:
		if level == null:
			level = Utils.game_control.scene_manager.current_level
		return level

var grid_position : Vector2i :
	get:
		return level.grid.world_position_to_grid(global_position)

var body_center : Vector2 :
	get:
		return hit_box.global_position

var is_dead : bool :
	get:
		return stats.get_stat_value(Utils.StatType.Health) <= 0.0

var is_the_end_point_reached : bool :
	get = _get_is_the_end_point_reached,
	set = _set_is_the_end_point_reached

var has_path : bool :
	get:
		return not point_path.is_empty()


signal stats_changed() 
signal selected(is_selected : bool)


func take_damage(damage_data : DamageData) -> void:
	if is_dead:
		return
	if is_phased and not damage_data.is_overtime:
		return
	damage_data.drop_freed_source()
	if damage_data.damage > 0.0 and fire_ward != null and fire_ward.absorb(damage_data):
		return

	var raw_damage : float = damage_data.damage
	#the maze damage card: towers hit harder while the enemy squeezes past a building (flyers are above the maze)
	if damage_data.damage > 0.0 and damage_data.source is Building and not is_flying and level != null and level.upgrades != null:
		damage_data.damage *= 1.0 + level.upgrades.get_maze_damage_bonus(grid_position)
	if damage_data.damage > 0.0:
		damage_data.damage *= damage_taken_factor * get_resistance_factor(damage_data)
		#talents: burning, poisoned, frozen or chilled enemies take more
		if level != null and level.talents != null:
			damage_data.damage *= 1.0 + level.talents.get_vulnerability(self, damage_data)
		#a T2 Buffer's aura weakens the enemies in it
		if level != null and level.buffer_auras != null and damage_data.source is Building:
			damage_data.damage *= 1.0 + level.buffer_auras.get_weakness(self)
		#a Spotter's mark: more of the marked element from every tower
		if damage_data.source is Building:
			damage_data.damage *= 1.0 + EnemyMarks.get_bonus(self, damage_data.damage_type)
			#a shieldbearer's cover against bolts
			damage_data.damage *= ShieldAura.get_factor(self, damage_data)
			#synergies (Pinned: the spikes on an enemy the Leopard holds)
			if level != null and level.synergies != null:
				damage_data.damage *= level.synergies.get_damage_factor(self, damage_data)

	var health : Stat = stats.get_stat(Utils.StatType.Health)
	var maxHealth : Stat = stats.get_stat(Utils.StatType.MaxHealth)
	health.value -= damage_data.damage
	
	if health.value > maxHealth.value and damage_data.is_healing and not damage_data.is_shielding:
		health.value = maxHealth.value
		
	GameSignals.damage_taken.emit(pop_up_spot.global_position, damage_data)
	overtime_effect_handler.handle_overtime_effects(damage_data.overtime_effect_datas, damage_data.damage)
	GameSignals.enemy_hit.emit(self, damage_data)
	
	if damage_data.damage > 0.0:
		if damage_data.source != null:
			damage_data.source.dealt_damage(self, damage_data)
		gore_emitter.emit_gore(damage_data)
		animation_control.play_hit_animation(not damage_data.is_overtime)
		TowerHitEffects.apply(self, damage_data, raw_damage)


## Numbs it (cannot attack buildings) until a matching remove_numb.
func add_numb() -> void:
	numb_count += 1


func remove_numb() -> void:
	numb_count = maxi(numb_count - 1, 0)


func _get_is_numb() -> bool:
	return numb_count > 0


## Pushes it back along its own path by this many cells (a Physical Nova's burst); bosses, flyers and waders stay.
func knock_back(cells : int) -> void:
	if is_boss or is_flying or is_wading or is_dead or is_burrowed or point_path.is_empty():
		return
	current_waypoint_index = maxi(current_waypoint_index - cells, 0)
	global_position = point_path[current_waypoint_index] + lane_offset
	next_waypoint = global_position
	linear_velocity = Vector2.ZERO
	#Pushed onto spikes: a trap where it lands sets off at once
	if level != null and level.synergies != null:
		level.synergies.on_knocked_back(self)


## Stops it where it stands for a while (a frost tower's freeze); bosses never freeze. A new freeze restarts it.
func freeze_for(seconds : float) -> void:
	if is_boss or seconds <= 0.0 or is_dead or is_steadfast:
		return
	#Absolute Zero and Snap Freeze (talents)
	if level != null and level.talents != null:
		seconds = seconds * (1.0 + level.talents.get_total(TalentEffect.Kind.FreezeLonger)) + level.talents.get_total(TalentEffect.Kind.FreezeExtra)
	if freeze_timer == null:
		freeze_timer = CustomTimer.new()
		freeze_timer.one_shot = true
		add_child(freeze_timer)
		freeze_timer.timeout.connect(func() -> void: animation_control.self_modulate = Color.WHITE)
	freeze_timer.unscaled_base_value = seconds
	freeze_timer.start()
	animation_control.self_modulate = FROZEN_TINT
	linear_velocity = Vector2.ZERO


## The share of a hit that gets through this enemy's resistances (its element, and the tower kind when a tower hits).
func get_resistance_factor(damage_data : DamageData) -> float:
	if resistances == null:
		return 1.0

	#a Shredder's torn armour comes off every resistance
	var shred : float = ResistanceShred.get_share(self)
	var element_resistance : float = maxf(resistances.get_element(damage_data.damage_type) - shred, 0.0)
	var tower_resistance : float = 0.0
	if damage_data.source is Building:
		var source : Building = damage_data.source
		if source.skill != null:
			tower_resistance = maxf(resistances.get_tower(source.skill.skill_type) - shred, 0.0)
		#penetration (cards, talents) takes points off both; a crit with critical penetration ignores them all
		if damage_data.is_critical and source.stats.get_stat_value(Utils.StatType.CriticalPenetration) >= 1.0:
			return 1.0
		var penetration : float = source.stats.get_stat_value(Utils.StatType.ResistancePenetration)
		element_resistance = maxf(element_resistance - penetration, 0.0)
		tower_resistance = maxf(tower_resistance - penetration, 0.0)
	return EnemyResistances.get_damage_factor(element_resistance, tower_resistance)


func dealt_damage(_target : Node2D, _damage_data : DamageData) -> void:
	pass


func iterate_next_waypoint() -> void:
	if (current_waypoint_index + 1) >= point_path.size():
		next_waypoint = point_path[current_waypoint_index] + lane_offset
		return

	current_waypoint_index += 1
	next_waypoint = point_path[current_waypoint_index] + lane_offset
	_pause_if_turning()


func _pause_if_turning() -> void:
	if is_flying or turn_pause_timer == null or velocity.is_zero_approx() or not turn_pause_timer.is_stopped():
		return

	if velocity.normalized().dot(global_position.direction_to(next_waypoint)) < TURN_DOT_LIMIT:
		turn_pause_timer.start()


func is_waypoint_reached() -> bool:
	return global_position.distance_to(next_waypoint) < minimum_distance_to_next_waypoint


func is_last_waypoint() -> bool:
	return (current_waypoint_index + 1) >= point_path.size()


func is_end_point_in_reach() -> bool:
	return global_position.distance_to(end_point.global_position) < minimum_distance_to_end


func move_towards_next_waypoint() -> void:
	animation_control.play_animation(walk_animation)

	#velocity keeps the old direction, so the turn is not counted twice
	if not turn_pause_timer.is_stopped() or is_frozen or is_held or is_instance_valid(held_by):
		linear_velocity = Vector2.ZERO
		return

	var move_direction : Vector2 = global_position.direction_to(next_waypoint)

	if is_flying:
		flight_movement.move(move_direction)
		return

	#on the stones the bog cell's own factor means nothing, the crossing sets the pace
	var ground_factor : float = wade_crossing.wade_speed_factor if is_wading else _get_cell_speed_factor()
	var speed : float = stats.get_stat_value(Utils.StatType.Speed) * get_spacing_speed_factor(move_direction) * ground_factor
	velocity = speed * move_direction * current_time_scale
	linear_velocity = velocity
	last_position = global_position
	animation_control.flip_h = linear_velocity.x <= 0


#slow ground and the maze; looked up again only in a new cell or after the buildings change
func _get_cell_speed_factor() -> float:
	if grid_position != cell_speed_factor_cell:
		cell_speed_factor_cell = grid_position
		cell_speed_factor = level.grid.get_move_speed_factor(cell_speed_factor_cell)

	return cell_speed_factor


func path_to(from : Vector2, to : Vector2) -> void:
	if is_flying:
		point_path = flight_movement.get_route(from, to)
		current_waypoint_index = 0
		next_waypoint = point_path[0] + lane_offset
		return

	if is_wading:
		#halfway over the stones: no road starts in the bog, so finish the crossing and go on from its far shore
		point_path = PackedVector2Array([wade_crossing.exit_position]) + level.grid.find_path(wade_crossing.exit_position, to)
		wade_exit_index = 0
		current_waypoint_index = 0
		next_waypoint = point_path[0] + lane_offset
		return

	wade_exit_index = -1
	wade_crossing = null
	if can_wade and not level.grid.bog_crossings.is_empty():
		var route : WadingRoute = level.grid.find_wading_route(from, to)
		point_path = route.path
		wade_exit_index = route.exit_index
		wade_crossing = route.crossing
	elif wall_path_weight > 0.0:
		point_path = level.grid.find_path_with_wall_weight(from, to, wall_path_weight)
	else:
		point_path = level.grid.find_path(from, to)
	current_waypoint_index = 0

	if point_path.is_empty():
		point_path.append(level.grid.snap_position_to_grid(global_position))
		return
		
	var direction_to_first_waypoint : Vector2 = global_position.direction_to(point_path[0])
	var dot : float = velocity.dot(direction_to_first_waypoint)

	if dot < 0.0:
		iterate_next_waypoint()
		return

	next_waypoint = point_path[current_waypoint_index] + lane_offset


func clear_path() -> void:
	point_path.clear()
	current_waypoint_index = 0


func deactivate() -> void:
	overtime_effect_handler.clear_overtime_effects()
	linear_velocity = Vector2.ZERO
	contact_monitor = false
	collider.disabled = true
	hit_box.monitoring = false
	hit_box.monitorable = false
	is_deactivated = true


func reactivate() -> void:
	stats.get_stat(Utils.StatType.Health).value = stats.get_stat_value(Utils.StatType.MaxHealth)
	contact_monitor = true
	collider.disabled = false
	hit_box.monitoring = true
	hit_box.monitorable = true
	is_deactivated = false
	overtime_effect_handler.handle_start_overtime_effects(stats.get_stat_value(Utils.StatType.MaxHealth))


func die() -> void:
	if is_deactivated:
		return
		
	if abilities != null:
		abilities.interrupt()
	animation_control.play_animation(GlobalAnimationNames.DEATH_ANIMATION)
	gore_emitter.emit_death_gore()
	GameSignals.enemy_destroyed.emit(self)
	deactivate()
	_free_after_death()


#gone without a kill or a leak, keeping the animation it ends on (a hatched egg sac)
func remove_without_reward() -> void:
	if is_deactivated:
		return

	gives_reward = false
	if abilities != null:
		abilities.interrupt()
	GameSignals.enemy_destroyed.emit(self)
	deactivate()
	_free_after_death()


#out of every tower's reach and hidden, or back; the body stops touching anything meanwhile
func set_burrowed(value : bool) -> void:
	if value == is_burrowed:
		return

	is_burrowed = value
	visible = not value
	collider.set_deferred(&"disabled", value)
	hit_box.set_deferred(&"monitorable", not value)
	linear_velocity = Vector2.ZERO


#the corpse stays until the death animation and the gore (which leaves the blood splats) have finished
func _free_after_death() -> void:
	if animation_control.is_playing():
		await animation_control.animation_finished

	#an unloaded level takes the corpse out of the tree mid-wait; it is freed with the level
	while gore_emitter.is_emitting():
		if not is_inside_tree():
			return
		await get_tree().process_frame

	if not is_inside_tree():
		return

	var fade : Tween = create_tween()
	fade.set_speed_scale(current_time_scale)
	fade.tween_property(self, MODULATE_ALPHA_PROPERTY, 0.0, CORPSE_FADE_TIME)
	await fade.finished
	queue_free()


func get_building_in_next_waypoint() -> Building:
	if is_flying:
		return null

	var building : Building = level.grid.get_building_from_world_position(level.grid.snap_position_to_grid(next_waypoint))
	if building is Trap or (climbs_walls and building is Wall):
		return null
	return building


func get_first_nearby_free_position() -> Vector2:
	#find free position, a walkable position without tower or wall in it
	var cells : Array[Vector2i] = level.grid.get_walkable_surrounding_cells(grid_position)
	
	if not cells.is_empty():
		return level.grid.grid_position_to_world(cells.pick_random())
	
	var building_in_cell : Building = level.grid.get_building_from_cell_position(grid_position)

	if building_in_cell != null:
		building_in_cell.destroy_building()
		push_warning(name, NO_FREE_POSITION_WARNING)

	return global_position


func get_spacing_speed_factor(move_direction : Vector2) -> float:
	var neighbour_positions : Array[Vector2] = []
	var neighbour_speeds : Array[float] = []
	level.enemy_neighbours.collect(level.existing_enemies, self, neighbour_positions, neighbour_speeds)
	return EnemySpacing.get_speed_factor(global_position, move_direction, neighbour_positions,
		neighbour_speeds, stats.get_stat_value(Utils.StatType.Speed))


func get_remaining_path_waypoint_count() -> int:
	return maxi(point_path.size() - current_waypoint_index, 0)


#the building in this enemy's cell first, then one in a neighbour cell; traps are walked over, never attacked
func get_closest_building() -> Building:
	var building_in_cell : Building = level.grid.get_building_from_cell_position(grid_position)

	if building_in_cell != null and building_in_cell is not Trap:
		return building_in_cell

	for building in level.grid.get_neighbour_buildings_from_world_position(global_position):
		if building is not Trap:
			return building

	return null


func _ready() -> void:
	process_mode = ProcessMode.PROCESS_MODE_PAUSABLE
	
	if not is_in_group(GroupNames.ENEMIES):
		add_to_group(GroupNames.ENEMIES)
	
	var new_name : String = name + str(level.all_enemies.size())
	name = new_name
	last_position = global_position
	_roll_lane_offset()
	turn_pause_timer = CustomTimer.new()
	turn_pause_timer.one_shot = true
	add_child(turn_pause_timer)
	#Sharp Corners (talent) lengthens every turn pause
	var extra_pause : float = level.talents.get_total(TalentEffect.Kind.TurnPause) if level != null and level.talents != null else 0.0
	turn_pause_timer.unscaled_base_value = TURN_PAUSE_TIME + extra_pause
	body_entered.connect(_on_body_enter)
	body_exited.connect(_on_body_exit)
	GameSignals.astar_grid_updated.connect(_on_astar_grid_updated)
	GameSignals.enemy_spawned.emit(self)
	GameSignals.time_scale_change.connect(_on_time_scale_change)
	_on_time_scale_change(Utils.game_control.time_scale)
	overtime_effect_handler.handle_start_overtime_effects(stats.get_stat_value(Utils.StatType.MaxHealth))


func _roll_lane_offset() -> void:
	var body_radius : float = Utils.TILE_SIZE * 0.5
	if collider.shape is CircleShape2D:
		body_radius = collider.shape.radius
	var max_offset : float = EnemySpacing.get_max_lane_offset(body_radius, minimum_distance_to_next_waypoint)
	lane_offset = EnemySpacing.roll_lane_offset(max_offset, randf(), randf())


func _on_body_enter(body : Node) -> void:
	if is_flying:
		return

	if body.is_in_group(GroupNames.BUILDINGS):
		if body is Trap or (climbs_walls and body is Wall):
			return
		collision_body = body


#only the building it pushes against: another one sliding off must not let it walk on into the first
func _on_body_exit(body : Node) -> void:
	if body == collision_body:
		collision_body = null


func _on_astar_grid_updated() -> void:
	#out of the tree: a retried level's old enemy, still waiting to be freed, hears the new level's grid
	if is_dead or is_deactivated or is_flying or not is_inside_tree():
		return

	if level == null:
		push_warning(name, GRID_UPDATE_ERROR)
		return

	#a building placed or removed next to the enemy changes its speed
	cell_speed_factor_cell = Vector2i.MAX
	path_to(global_position, end_point.global_position)


func _on_time_scale_change(time_scale : float) -> void:
	current_time_scale = time_scale


func _get_is_the_end_point_reached() -> bool:
	return is_the_end_point_reached


func _set_is_the_end_point_reached(value : bool) -> void:
	if value == is_the_end_point_reached:
		return
			
	is_the_end_point_reached = value
	if not is_the_end_point_reached:
		var distance_to_end = global_position.distance_to(end_point.global_position)
		push_warning(name, END_POINT_PATHING_ERROR, distance_to_end)
	else:
		GameSignals.enemy_reached_end_point.emit(self)
		deactivate()
		hide()
		queue_free()

